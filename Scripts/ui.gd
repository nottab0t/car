extends Control

@onready var main := self.get_parent()
var car: RaycastCar
var show_help := false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("help"):
		if show_help: show_help = false
		else: show_help = true

func _physics_process(_delta: float) -> void:
	if car == null:
		car = main.get_car()
		return
	
	# fps display
	var fps = Engine.get_frames_per_second()
	$HBoxContainer/DebugOutput/Fps.text = str(fps) + " fps"
	
	# help display
	var car_speed = car.get_speed()
	$HBoxContainer/DebugOutput/SpeedBar.value = car_speed
	car_speed = int(car_speed)
	$HBoxContainer/DebugOutput/SpeedNumber.text = str(car_speed) + " speed"
	
	# show/hide help
	if show_help:
		$HBoxContainer/Help/Body.show()
		$HBoxContainer/Help/Title.hide()
	else:
		$HBoxContainer/Help/Body.hide()
		$HBoxContainer/Help/Title.show()
