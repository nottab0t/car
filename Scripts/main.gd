extends Node
class_name Main

@onready var car = $Car
@onready var player = $Player

var control_mode := "player"

func get_car() -> Node:
	return car

func get_player() -> Node:
	return player

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	if event.is_action_pressed("quit"):
		get_tree().quit()

func _process(_delta: float) -> void:
	if control_mode == "player":
		player.get_cam().make_current()
	elif control_mode == "car":
		car.get_cam().make_current()
