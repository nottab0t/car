extends RigidBody3D
class_name RaycastCar

# based on www.youtube.com/watch?v=9MqmFSn1Rlw
# thanks Octodemy <3

var wheels : Array[RaycastWheel]
@export var acceleration := 950.0
@export var max_speed := 130.0
@export var accel_curve : Curve
@export var tire_turn_speed := 2.0
@export var tire_max_turn_degrees := 25
@export var handling_curve : Curve

@export var total_wheels := wheels.size()

@export var air_control := 0.4

# control
var motor_input := 0.0
var hand_break := false
var is_slipping := false
var headlights_on := false

# stats
var speed := 0.0
var grounded := false

# lights
var head_lights : Array[Light3D]
var tail_lights : Array[Light3D]
var running_lights : Array[Light3D]

# children
@onready var main : Main = self.get_parent()
@onready var cam := $CameraMount/CarCamera
@onready var cam_reset := $CameraMount/CameraReset
@onready var doors := $Doors
@onready var doorLabel := $Doors/DoorLabel

func get_speed() -> float:
	return speed

func get_cam() -> Camera3D:
	return cam

func _ready() -> void:
	# array setup
	for light in $Lights/Headlights.get_children():
		head_lights.append(light)
	for light in $Lights/Taillights.get_children():
		tail_lights.append(light)
	for light in $Lights/Running.get_children():
		running_lights.append(light)
	for wheel in $Wheels.get_children(): wheels.append(wheel)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use"):
		if main.control_mode == "player" and doors.overlaps_body(main.get_player()):
			main.control_mode = "car"
			cam.global_position = cam_reset.global_position
		elif main.control_mode == "car":
			main.control_mode = "player"
			main.get_player().position = self.position - Vector3(2, 0, 0)
			main.get_player().pivot.rotation.y = cam.rotation.y
	
	if not main.control_mode == "car": return
	
	if event.is_action_pressed("handbreak"):
		hand_break = true
		is_slipping = true
		for light in tail_lights: light.visible = true
	elif event.is_action_released("handbreak"):
		hand_break = false
		for light in tail_lights: light.visible = false
	
	if event.is_action_pressed("brake"):
		for light in tail_lights: light.visible = true
	elif event.is_action_released("brake"):
		for light in tail_lights: light.visible = false
	
	if event.is_action_pressed("toggle_headlights"):
		if headlights_on: for light in head_lights: 
			light.visible = false
			headlights_on = false
		elif not headlights_on: for light in head_lights: 
			light.visible = true
			headlights_on = true

func _basic_steering_rotation(wheel: RaycastWheel, delta: float) -> void:
	if not main.control_mode == "car": return
	if not wheel.is_steer: return
	
	# scale max_turn_degree by a factor of speed
	var handling := handling_curve.sample_baked(speed/60)
	var turn_input := Input.get_axis("turn_right", "turn_left") * tire_turn_speed
	var min_turn = deg_to_rad(-tire_max_turn_degrees * handling)
	var max_turn = deg_to_rad(tire_max_turn_degrees * handling)
	
	var tilt_input := Input.get_axis("reverse", "forward")
	
	if turn_input:
		wheel.rotation.y = clampf(wheel.rotation.y + turn_input * delta,
		min_turn, max_turn)
	else:
		wheel.rotation.y = move_toward(wheel.rotation.y, 0, tire_turn_speed * delta)
	
	if not grounded:
		var y_torque = transform.basis.y * (turn_input * air_control)
		var x_torque = transform.basis.x * (tilt_input * air_control)
		apply_torque(y_torque)
		apply_torque(-x_torque)

func _physics_process(delta: float) -> void:
	if not main.control_mode == "car" and doors.overlaps_body(main.get_player()): doorLabel.show()
	else: doorLabel.hide()
	
	if main.control_mode == "car":
		for light in running_lights: light.show()
		motor_input = clampf(Input.get_axis("decelerate", "accelerate"), -0.5, 1)
	else:
		for light in running_lights: light.hide()
		motor_input = 0
	grounded = false
	speed = linear_velocity.length()
	for wheel in wheels:
		wheel.apply_wheel_physics(self)
		wheel.handle_slipping(self)
		_basic_steering_rotation(wheel, delta)
		
		# brake check
		if Input.is_action_pressed("brake"):
			wheel.is_braking = true
		else:
			wheel.is_braking = false
		
		# grounded check
		if wheel.collision_check():
			grounded = true
	
	
	if grounded:
		center_of_mass = Vector3.ZERO
	else:
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = Vector3.DOWN

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)
