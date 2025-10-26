extends CharacterBody3D

const JUMP_VELOCITY = 5.0
const LERP_VAL = .15

@export var speed := 5.0
@export var run_speed := 10.0

@export var sens := 0.005
@export var controller_sens := 1.5

@onready var main : Main = self.get_parent()
@onready var cam := $CamOrigin/SpringArm3D/PlayerCamera
@onready var cam_arm := $CamOrigin/SpringArm3D
@onready var pivot := $CamOrigin
@onready var armature := $Armature
@onready var anim_tree := $AnimationTree

func get_cam() -> Camera3D:
	return cam

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not main.control_mode == "player": return
	if event is InputEventMouseMotion:
		pivot.rotate_y(-event.relative.x * sens)
		cam_arm.rotate_x(-event.relative.y * sens)
		cam_arm.rotation.x = clamp(cam_arm.rotation.x, deg_to_rad(-75), deg_to_rad(20))

func _physics_process(delta: float) -> void:
	if main.control_mode == "car":
		self.hide()
		$CollisionShape3D.disabled = true
	elif main.control_mode == "player":
		self.show()
		$CollisionShape3D.disabled = false
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if not main.control_mode == "player": return
	# camera control
	if Input.is_action_pressed("look_right"):
		rotation.y -= controller_sens * delta
	if Input.is_action_pressed("look_left"):
		rotation.y += controller_sens * delta
	if Input.is_action_pressed("look_up"):
		pivot.rotation.x += controller_sens * delta
		pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-90), deg_to_rad(10))
	if Input.is_action_pressed("look_down"):
		pivot.rotation.x -= controller_sens * delta
		pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-90), deg_to_rad(10))
	
	# sprint
	if Input.is_action_pressed("run"): 
		speed = run_speed
		anim_tree.set("parameters/Run Blend/blend_amount", velocity.length() / run_speed)
		anim_tree.set("parameters/Walk Blend/blend_amount", 0)
	else: 
		speed = 5.0
		anim_tree.set("parameters/Walk Blend/blend_amount", velocity.length() / run_speed)
		anim_tree.set("parameters/Run Blend/blend_amount", 0)
		
	
	# zoom
	if Input.is_action_pressed("zoom"): 
		cam_arm.spring_length = 1.5
		cam_arm.position.x = 1
	else: 
		cam_arm.spring_length = 4.0
		cam_arm.position.x = 0
	
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("walk_left", "walk_right", "walk_forward", "walk_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction = direction.rotated(Vector3.UP, pivot.rotation.y)
	if direction:
		velocity.x = lerp(velocity.x, direction.x * speed, LERP_VAL)
		velocity.z = lerp(velocity.z, direction.z * speed, LERP_VAL)
		armature.rotation.y = lerp_angle(armature.rotation.y, atan2(velocity.x, velocity.z), LERP_VAL)
	else:
		velocity.x = lerp(velocity.x, 0.0, LERP_VAL)
		velocity.z = lerp(velocity.z, 0.0, LERP_VAL)

	anim_tree.set("parameters/Run Blend/blend_amount", velocity.length() / run_speed)

	move_and_slide()
