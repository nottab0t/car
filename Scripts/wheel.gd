extends RayCast3D
class_name RaycastWheel2

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
@export var slip_exit := 0.02
@export var slip_enter := 0.33

@onready var wheel: MeshInstance3D = $Wheel
@onready var debug_label: Label3D = $DebugLabel
@onready var skid_marks: GPUParticles3D = $GPUParticles3D

var engine_force := 0.0
var grip_factor := 0.0
var is_braking := false

func _ready() -> void:
	target_position.y = -(rest_dist + wheel_radius + over_extend)

func get_grip_factor() -> float:
	return grip_factor

func apply_wheel_physics(car: RaycastCar) -> void:
	force_raycast_update()
	target_position.y = -(rest_dist + wheel_radius + over_extend)
	
	## Rotate wheel visuals
	var forward_dir := -global_basis.z
	var vel:= forward_dir.dot(car.linear_velocity)
	wheel.rotate_x((-vel * get_process_delta_time()) / wheel_radius)
	
	if not is_colliding(): return
	# anything past here, the raycast is colliding
	
	var contact_point := get_collision_point()
	var current_spring_len := maxf(0.0, global_position.distance_to(contact_point) - wheel_radius)
	var offset := rest_dist - current_spring_len
	
	wheel.position.y = move_toward(wheel.position.y, -current_spring_len, 5 * get_physics_process_delta_time()) # local y position of the wheel
	var wheel_center := wheel.global_position
	var force_pos := wheel_center - car.global_position
	
	## Spring forces
	var spring_force := spring_strength * offset
	var tire_vel := car._get_point_velocity(wheel_center)
	var spring_damp_f := spring_damping * global_basis.y.dot(tire_vel)
	
	var y_force := (spring_force - spring_damp_f) * get_collision_normal()
	
	## Acceleration
	if is_motor and car.motor_input:
		var speed_ratio := vel / car.max_speed
		var ac := car.accel_curve.sample_baked(speed_ratio)
		var accel_force := forward_dir * car.acceleration * car.motor_input * ac
		car.apply_force(accel_force, force_pos)
	
	## Tire X traction (Steering)
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
		z_friction = z_braking_traction * 0.6
	var z_force := global_basis.z * f_vel * z_friction * ((car.mass * gravity) / car.total_wheels)
	
	var total_force = y_force + x_force + z_force
	car.apply_force(total_force, force_pos)


func handle_slipping(car: RaycastCar) -> void:
	skid_marks.global_position = get_collision_point() + Vector3.UP * 0.01
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
