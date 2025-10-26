extends Node3D
class_name RaycastWheel

@export_group("Wheel Properties")
@export var spring_strength := 5000
@export var spring_damping := 120.0
@export var rest_dist := 0.3
@export var over_extend := 0.3
@export var wheel_radius := 0.6
@export var z_traction := 0.05
@export var z_braking_traction := 0.2

@export_category("Motor")
@export var is_motor := false
@export var is_steer := false

@export_category("Grip")
@export var grip_curve : Curve
## old, zero_approx used currently --> @export var slip_exit := 0.02
@export var slip_enter := 0.33

@onready var wheel: Node3D = $Wheel
@onready var debug_label: Label3D = $DebugLabel
@onready var skid_marks: GPUParticles3D = $GPUParticles3D
@onready var rays : Array[RayCast3D]

@onready var forward_dir := -global_basis.z
var engine_force := 0.0
var grip_factor := 0.0
var is_braking := false
var vel := 0.0
var colliding := false
var spring_forces : Array[Vector3]
var wheel_center : Vector3
var force_pos : Vector3
var tire_vel : Vector3

func _update_ray_target(ray: RayCast3D) -> void:
	var radius := wheel_radius + rest_dist
	ray.target_position.y = -radius

func _update_ray_target_extended(ray: RayCast3D) -> void:
	#if not ray.is_colliding():
	#	_update_ray_target(ray)
	#else:
		var radius := wheel_radius + rest_dist + over_extend
		ray.target_position.y = -radius

func _ready() -> void:
	for child in $Rays.get_children():
		rays.append(child.get_child(0))
		_update_ray_target(child.get_child(0))

func get_grip_factor() -> float:
	return grip_factor

func collision_check() -> bool:
	return colliding

func apply_wheel_physics(car: RaycastCar) -> void:	
	## rotate wheel visuals
	forward_dir = -global_basis.z
	vel = forward_dir.dot(car.linear_velocity)
	wheel.rotate_x((-vel * get_process_delta_time()) / wheel_radius)
	
	## calculate ray forces
	spring_forces.clear()
	for ray in rays:
		# update rays to avoid physics lag
		ray.force_raycast_update()
		# update ray target positions 
		_update_ray_target(ray)
		# calculate spring forces
		_calc_spring_physics(ray, car)
	_update_ray_target_extended(rays[0])
	_apply_main_physics(rays[0], car)
	
	## setup force position
	wheel_center = wheel.global_position
	force_pos = wheel_center - car.global_position
	
	if spring_forces.is_empty(): return
	## average spring forces
	var final_force : Vector3
	final_force = spring_forces.pop_back()
	for force in spring_forces:
		final_force = final_force + force
	final_force = final_force / (spring_forces.size() + 1)
	car.apply_force(final_force, force_pos)

func _calc_spring_physics(ray: RayCast3D, car: RaycastCar) -> void:
	if not ray.is_colliding(): 
		colliding = false
		return
	# anything past here, the raycast is colliding
	colliding = true
	
	var contact_point := ray.get_collision_point()
	var current_spring_len := maxf(0.0, global_position.distance_to(contact_point) - wheel_radius)
	var offset := rest_dist - current_spring_len
	
	wheel.position.y = move_toward(wheel.position.y, -current_spring_len, 5 * get_physics_process_delta_time()) # local y position of the wheel
	
	## Spring forces
	var spring_force := spring_strength * offset
	tire_vel = car._get_point_velocity(wheel_center)
	var spring_damp_f := spring_damping * global_basis.y.dot(tire_vel)
	
	var y_force := (spring_force - spring_damp_f) * ray.get_collision_normal()
	spring_forces.append(y_force)

func _apply_main_physics(ray: RayCast3D, car: RaycastCar) -> void:
	if not ray.is_colliding(): 
		colliding = false
		return
	# anything past here, the raycast is colliding
	colliding = true
	
	## Acceleration
	if is_motor and car.motor_input:
		var speed_ratio := vel / car.max_speed
		var ac := car.accel_curve.sample_baked(speed_ratio)
		var accel_force := forward_dir * car.acceleration * car.motor_input * ac
		car.apply_force(accel_force, force_pos)
	
	## Tire X traction (Steering)
	tire_vel = car._get_point_velocity(wheel_center)
	var steering_x_vel := global_basis.x.dot(tire_vel)
	grip_factor = absf(steering_x_vel / tire_vel.length())
	debug_label.set_text(str(snappedf(grip_factor, 0.01)))
	var x_traction := grip_curve.sample_baked(grip_factor)
	
	if not car.hand_break and grip_factor < 0.2:
		car.is_slipping = false
	if car.hand_break:
		x_traction = 0.06
	elif car.is_slipping:
		x_traction = 0.1
	
	var gravity := -car.get_gravity().y
	var x_force := -global_basis.x * steering_x_vel * x_traction * ((car.mass * gravity) / car.total_wheels)
	
	## Tire Z traction (Longitudinal)
	var f_vel := forward_dir.dot(tire_vel)
	var z_friction := z_traction
	if is_braking:
		z_friction = z_braking_traction
	elif car.hand_break:
		z_friction = z_braking_traction * 0.5
	var z_force := global_basis.z * f_vel * z_friction * ((car.mass * gravity) / car.total_wheels)
	
	var total_force := x_force + z_force
	car.apply_force(total_force, force_pos)


func handle_slipping(car: RaycastCar) -> void:
	skid_marks.global_position = rays[0].get_collision_point() + Vector3.UP * 0.01
	skid_marks.look_at(skid_marks.global_position + car.global_basis.z)
	
	# exit slip
	if not car.hand_break and is_zero_approx(grip_factor):
		car.is_slipping = false
	
	# skid on handbreak
	if car.hand_break or grip_factor > slip_enter:
		car.is_slipping = true
	
	if car.is_slipping:
		skid_marks.emitting = true
	else:
		skid_marks.emitting = false
