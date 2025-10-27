extends CharacterBody3D
class_name Player

const JUMP_VELOCITY = 5.0
const LERP_VAL = .15

@export var speed := 5.0
@export var run_speed := 10.0

@export var sens := 0.005
@export var controller_sens := 1.5

# children
@onready var main : Main = self.get_parent()
@onready var cam := $CamOrigin/SpringArm3D/PlayerCamera
@onready var cam_arm := $CamOrigin/SpringArm3D
@onready var pivot := $CamOrigin
@onready var armature : Node3D = $Armature
@onready var anim_tree : AnimationTree = $AnimationTree
@onready var debug_label : Label3D = $DebugLabel
@onready var item_trigger : Area3D = $ItemTrigger
@onready var skeleton : Skeleton3D = $Armature/Skeleton3D

var main_hand_pos : Vector3
var main_hand_rot : Basis
var main_hand_offset : float
var off_hand_pos : Vector3
var off_hand_rot : Basis

var held_anim := "none"
var held_anim_run := "none"

func get_cam() -> Camera3D:
	return cam

func hold_item_anim(item: String) -> void:
	anim_tree.set("parameters/Arm Blend/blend_amount", 1)
	held_anim = "parameters/" + item + " Hold Blend/blend_amount"
	held_anim_run = "parameters/" + item + " Hold Run Blend/blend_amount"
	anim_tree.set(held_anim, 1)

func drop_item_anim() -> void:
	anim_tree.set(held_anim, 0)
	anim_tree.set(held_anim_run, 0)
	held_anim = "none"
	held_anim_run = "none"
	

func _body_exited(body: Node3D):
	body.label.visible = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not main.control_mode == "player": return
	if event is InputEventMouseMotion:
		pivot.rotate_y(-event.relative.x * sens)
		cam_arm.rotate_x(-event.relative.y * sens)
		cam_arm.rotation.x = clamp(cam_arm.rotation.x, deg_to_rad(-75), deg_to_rad(20))

func _physics_process(delta: float) -> void:
	for body in item_trigger.get_overlapping_bodies():
		if body is Item:
			body.link_item(item_trigger)
	
	# hide/show based on control mode
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
		pivot.rotation.y -= controller_sens * delta
	if Input.is_action_pressed("look_left"):
		pivot.rotation.y += controller_sens * delta
	if Input.is_action_pressed("look_up"):
		cam_arm.rotation.x += controller_sens * delta
		cam_arm.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-90), deg_to_rad(10))
	if Input.is_action_pressed("look_down"):
		cam_arm.rotation.x -= controller_sens * delta
		cam_arm.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-90), deg_to_rad(10))
	
	# sprint
	if Input.is_action_pressed("run"): 
		speed = run_speed
		if not held_anim_run == "none": 
			anim_tree.set(held_anim, 0)
			anim_tree.set(held_anim_run, 1)
	else: 
		speed = 5.0
		if not held_anim_run == "none": 
			anim_tree.set(held_anim, 1)
			anim_tree.set(held_anim_run, 0)
	
	# walk & run animations
	anim_tree.set("parameters/Walk Blend/blend_amount", velocity.length() / 5)
	anim_tree.set("parameters/Run Blend/blend_amount", clampf((velocity.length() / 5) - 1, 0, 1))
	
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

	# jump/fall animation
	if not is_on_floor():
		anim_tree.set("parameters/Walk Blend/blend_amount", 0)
		anim_tree.set("parameters/Run Blend/blend_amount", 0)
		if not held_anim_run == "none": 
			anim_tree.set(held_anim, 0)
			anim_tree.set(held_anim_run, 1)
		
		if velocity.y > 0:
			anim_tree.set("parameters/Jump Scale/scale", 0.5)
			anim_tree.set("parameters/Jump Blend/blend_amount", 1)
		elif velocity.y < 0:
			anim_tree.set("parameters/Jump Scale/scale", -0.25)
			anim_tree.set("parameters/Jump Blend/blend_amount", clampf(-velocity.y * 0.2, 1, 0.8))
	else:
		anim_tree.set("parameters/Jump Blend/blend_amount", 0)

	# Get the input direction and handle the movement/deceleration
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
	
	# update hand positions
	main_hand_pos = skeleton.get_bone_global_pose(10).origin
	main_hand_rot = skeleton.get_bone_global_pose(10).basis
	main_hand_offset = skeleton.get_bone_global_pose(10).origin.x
	#off_hand_pos = global_position + skeleton.get_bone_global_pose(4).origin
	#off_hand_rot = basis.z + skeleton.get_bone_global_pose(4).basis.z
	

	move_and_slide()
