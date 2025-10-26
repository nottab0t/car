extends Camera3D

@export var min_distance := 2.0
@export var max_distance := 3.0
@export var height := 1.7

@onready var target : Node3D = get_parent()

func _physics_process(delta: float) -> void:
	var from_target := global_position - target.global_position
	
	# check ranges
	if from_target.length() < min_distance:
		from_target = from_target.normalized() * min_distance
	elif from_target.length() > max_distance:
		from_target = from_target.normalized() * max_distance
	
	from_target.y = height
	global_position = lerp(global_position, target.global_position + from_target, delta * 10) 
	
	var look_dir := global_position.direction_to(target.global_position).abs() - Vector3.UP
	if not look_dir.is_zero_approx():
		look_at_from_position(global_position, target.global_position)
