@tool

class_name BodyRotation
extends SkeletonModifier3D

@export var target_coordinate: Vector3 = Vector3.ZERO
@export_enum(" ") var bone: String

func _validate_property(property: Dictionary) -> void:
	if property.name == "bone":
		var skeleton: Skeleton3D = get_skeleton()
		if skeleton:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = skeleton.get_concatenated_bone_names()

func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	if !skeleton: return # Never happen, but for the safety :)
	var bone_idx: int = skeleton.find_bone(bone)
	var bone_pose: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)
	var look_position: Transform3D = bone_pose.looking_at(target_coordinate)
	skeleton.set_bone_global_pose(bone_idx, skeleton.global_transform.affine_inverse() * look_position)
