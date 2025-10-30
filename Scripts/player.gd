extends CharacterBody3D
class_name Player

const JUMP_VELOCITY = 5.0
const LERP_VAL = .15

var speed := 5.0
@export var aim_speed := 2.5
@export var walk_speed := 5.0
@export var run_speed := 10.0

@export var sens := 0.005
@export var controller_sens := 1.5
@export var cam_zoom_speed := 20

# children
@onready var main : Main = self.get_parent()
@onready var cam := $CamOrigin/SpringArm3D/PlayerCamera
@onready var cam_arm := $CamOrigin/SpringArm3D
@onready var pivot := $CamOrigin
@onready var armature : Node3D = $man2/Armature
@onready var anim_tree : AnimationTree = $AnimationTree
@onready var debug_label : Label3D = $DebugLabel
@onready var interact_trigger : Area3D = $InteractTrigger
@onready var skeleton : Skeleton3D = $man2/Armature/Skeleton3D
@onready var aim_target : Marker3D = $CamOrigin/SpringArm3D/PlayerCamera/AimTarget
@onready var body_rotation_mod : SkeletonModifier3D = $man2/Armature/Skeleton3D/BodyRotation
@onready var reticle : Label3D = $CamOrigin/SpringArm3D/PlayerCamera/AimTarget/Reticle

# bone names/ids
var main_hand_bone := "hand.r"
@onready var main_hand_bone_id := skeleton.find_bone(main_hand_bone)
var off_hand_bone := "hand.l"
@onready var off_hand_bone_id := skeleton.find_bone(off_hand_bone)
var upperbody_bone := "body"
@onready var upperbody_bone_id := skeleton.find_bone(upperbody_bone)

# animations
var anim_arm_blend := "parameters/Arm Blend/blend_amount"
# static anims
var walk_anim := "parameters/Walk Blend/blend_amount"
var walk_anim_speed := "parameters/Walk Scale/scale"
var run_anim := "parameters/Run Blend/blend_amount"
# dynamic anims
var held_anim := "none"
var held_anim_run := "none"
var aim_anim := "none"

# items
var closest_item : Item = null
var equipped_item : Item = null

# states
var aiming := false
var running := false
var holding_item := false

func get_cam() -> Camera3D:
	return cam

func hold_item_anim(item: Item) -> void:
	anim_tree.set(anim_arm_blend, 1)
	held_anim = "parameters/" + item.hold_anim_name + " Hold Blend/blend_amount"
	held_anim_run = "parameters/" + item.hold_anim_name + " Hold Run Blend/blend_amount"
	anim_tree.set(held_anim, 1)
	if item.item_class == "gun":
		aim_anim = "parameters/" + item.hold_anim_name + " Aim Blend/blend_amount"

func drop_item_anim() -> void:
	anim_tree.set(held_anim, 0)
	anim_tree.set(held_anim_run, 0)
	anim_tree.set(aim_anim, 0)
	held_anim = "none"
	held_anim_run = "none"
	aim_anim = "none"

func _calc_global_bone_transform(bone_id: int) -> Transform3D:
	var bone_pos: Transform3D = skeleton.get_bone_global_pose(bone_id)
	var global_bone_pos: Transform3D = skeleton.global_transform * bone_pos
	return global_bone_pos

func _calc_local_bone_transform(bone_id: int) -> Transform3D:
	var bone_pos: Transform3D = skeleton.get_bone_global_pose(bone_id)
	var local_bone_pos: Transform3D = skeleton.transform * bone_pos
	return local_bone_pos

func _body_exited(body: Node3D):
	body.label.visible = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not main.control_mode == "player": return
	if event is InputEventMouseMotion:
		pivot.rotate_y(-event.relative.x * sens)
		cam_arm.rotate_x(-event.relative.y * sens)
		cam_arm.rotation.x = clamp(cam_arm.rotation.x, deg_to_rad(-75), deg_to_rad(30))

func _physics_process(delta: float) -> void:
	
	# reset facing_item
	if not closest_item == null: closest_item.player_targeting = false
	# get all nearby interactables
	for body in interact_trigger.get_overlapping_bodies():
		if body is Item:
			body.link_item(interact_trigger)
			# find closest equippable item
			var closest_item_dist := 1000.0
			if body.holdable:
				# check how close the item is
				var dist = global_position.distance_to(body.global_position)
				# remember to target the item if it is the closest
				if closest_item == null or dist < closest_item_dist: 
					closest_item = body
					closest_item_dist = dist
	# tell the item it is being targeted
	if not closest_item == null: closest_item.player_targeting = true
	
	# hide/show based on main control mode
	if main.control_mode == "car":
		self.hide()
		$CollisionShape3D.disabled = true
	elif main.control_mode == "player":
		self.show()
		$CollisionShape3D.disabled = false
	
	# gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# player control mode
	if not main.control_mode == "player": return
	
	# controller camera control
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
		running = true
		aiming = false
		anim_tree.set(aim_anim, 0)
		if not held_anim_run == "none": 
			anim_tree.set(held_anim, 0)
			anim_tree.set(held_anim_run, 1)
	else: 
		speed = 5.0
		running = false
		if not held_anim_run == "none": 
			anim_tree.set(held_anim, 1)
			anim_tree.set(held_anim_run, 0)
	
	# zoom
	if Input.is_action_pressed("zoom"): 
		cam_arm.spring_length = lerpf(cam_arm.spring_length, 1.5, delta * cam_zoom_speed)
		cam_arm.position.x = lerpf(cam_arm.position.x, 1, delta * cam_zoom_speed)
		if holding_item and equipped_item.item_class == "gun" and not running:
			aiming = true
			anim_tree.set(aim_anim, 1)
			speed = aim_speed
	else: 
		cam_arm.spring_length = lerpf(cam_arm.spring_length, 4.0, delta * cam_zoom_speed)
		cam_arm.position.x = lerpf(cam_arm.position.x, 0, delta * cam_zoom_speed)
		aiming = false
		anim_tree.set(aim_anim, 0)
	
	# walk & run animations
	if aiming:
		anim_tree.set(walk_anim, (velocity.length() / 5) * 0.7)
		anim_tree.set(walk_anim_speed, 1.2)
	else:
		anim_tree.set(walk_anim, velocity.length() / 5)
		anim_tree.set(walk_anim_speed, 0.9)
	
	anim_tree.set(run_anim, clampf((velocity.length() / 5) - 1, 0, 1))
	
	# jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# jump/fall animation
	if not is_on_floor():
		anim_tree.set(walk_anim, 0)
		anim_tree.set(run_anim, 0)
		# set held anims if needed
		if not held_anim_run == "none": 
			anim_tree.set(held_anim, 0)
			anim_tree.set(held_anim_run, 1)
		
		# rising
		if velocity.y > 0:
			anim_tree.set("parameters/Jump Scale/scale", 0.5)
			anim_tree.set("parameters/Jump Blend/blend_amount", 1)
			if aiming:
				anim_tree.set("parameters/Jump Blend/blend_amount", 0.5)
		# falling
		elif velocity.y < 0:
			anim_tree.set("parameters/Jump Scale/scale", -0.25)
			anim_tree.set("parameters/Jump Blend/blend_amount", clampf(-velocity.y * 0.2, 1, 0.8))
			if aiming:
				anim_tree.set("parameters/Jump Blend/blend_amount", clampf(0, 0.5, 0.8))
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
	
	# match rotation to camera if aiming and show reticle
	if aiming:
		armature.rotation.y = pivot.rotation.y - deg_to_rad(180)
		body_rotation_mod.target_coordinate = aim_target.global_position
		body_rotation_mod.influence = 1
		reticle.visible = true
	else:
		armature.rotation.x = 0
		body_rotation_mod.influence = 0
		reticle.visible = false
	
	move_and_slide()
