extends OwnWar_GameMaster


onready var _gui: Control = $GUI


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_gui.visible = true
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_GUI_cancel():
	_gui.visible = false
	get_tree().paused = false


func _on_GUI_restart():
	Global.goto_scene(filename)


func _on_GUI_exit():
	OwnWar.goto_main_menu(get_tree())
