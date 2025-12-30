extends Node
class_name Main

@onready var car = $Car
@onready var player = $Player
@onready var pause_ui = $UI/HBoxContainer/DebugOutput/Paused

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
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			pause_ui.hide()
		else:
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			pause_ui.show()

func _process(_delta: float) -> void:
	if control_mode == "player":
		player.get_cam().make_current()
	elif control_mode == "car":
		car.get_cam().make_current()

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
