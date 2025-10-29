extends RigidBody3D
class_name Item

# children
@onready var label := $Label3D
@onready var main_grip := $MainGripPoint
@onready var collision := $CollisionShape3D
@onready var model := $model 

# related objects
var player : Player
var main : Main

var signal_connected := false
var near_player := false
var player_targeting := false
var equipped := false
var grip_offset : Vector3
var gripped_rotation := Vector3(deg_to_rad(-90), 0, deg_to_rad(180))

# properties
var holdable := true
var item_class := "gun"
var hold_anim_name := "Smg"
var item_name := "SMG"
var default_text := item_name + "\n<E to Take>\n|"
var pickup_text := item_name + "\n<E to Take>\n<F to Equip>\n|"


# called by player when they are nearby
func link_item(area: Area3D) -> void:
	label.visible = true
	near_player = true
	
	# connect signal if this is the first interaction with player
	if area.body_exited.is_connected(_left_player_area): return
	area.body_exited.connect(_left_player_area)
	player = area.get_parent()
	signal_connected = true

func _ready() -> void:
	grip_offset = main_grip.position
	main = get_parent()


func _match_position_to_hand() -> void:
	if equipped:
		transform = player.skeleton.get_bone_global_pose(player.main_hand_bone_id) * player.skeleton.transform
	

# called via signal when player is no longer nearby
func _left_player_area(_body: Node3D):
	label.visible = false
	near_player = false

func _physics_process(_delta: float) -> void:
	# keep label from rotating with item
	label.global_position = self.global_position + Vector3.UP * 0.75
	if player_targeting and not player.holding_item: label.text = pickup_text
	else: label.text = default_text
	
	if equipped:
		# match position and basis to player main hand
		#transform = player.main_hand_transform
		## new
		
		
		# drop item only if equipped
		if Input.is_action_pressed("drop_item"):
			equipped = false
			collision.disabled = false
			# adjust model back to normal
			global_position = model.global_position
			global_rotation = model.global_rotation
			model.rotation = Vector3.ZERO
			model.position = Vector3.ZERO
			self.linear_velocity = Vector3.ZERO
			player.drop_item_anim()
			player.holding_item = false
			player.equipped_item = null
			# reparent back to main
			self.reparent(main)
		
		# stop here if equipped to prevent ground checks
		return
	
	# prevent ground checks if not near player
	if not near_player: return
	# player picks up item into storage
	if Input.is_action_pressed("pickup_item"):
		## update player inventory somehow
		queue_free()
	
	# player equips item from ground
	if Input.is_action_pressed("equip_item") and not player.holding_item:
		equipped = true
		collision.disabled = true
		# adjust model to match hand
		model.position = grip_offset
		model.rotation = gripped_rotation
		# reparent to make position/rotation easy
		self.reparent(player.armature)
		player.hold_item_anim(self)
		player.holding_item = true
		player.equipped_item = self
		if player.skeleton.skeleton_updated.is_connected(_match_position_to_hand): return
		player.skeleton.skeleton_updated.connect(_match_position_to_hand)
		
