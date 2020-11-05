extends Control


signal load_vehicle(path)
var enabled = false setget set_enabled
onready var mouse_mode = Input.get_mouse_mode()


func _ready():
	set_enabled(enabled)


func set_enabled(p_enabled):
	enabled = p_enabled
	visible = enabled
	get_tree().paused = enabled
	if enabled:
		mouse_mode = Input.get_mouse_mode()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(mouse_mode)
		for child in get_children():
			child.visible = false


func _on_LoadVehicle_load_vehicle(path):
	emit_signal("load_vehicle", path)
