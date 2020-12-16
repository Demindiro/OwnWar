extends OwnWar_GameMaster


onready var _gui: Control = $GUI
onready var _hud: Control = $HUD


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_gui.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = true


func _on_GUI_restart() -> void:
	Global.goto_scene(filename)


func _on_GUI_exit() -> void:
	OwnWar.goto_main_menu(get_tree())


func _on_GUI_cancel() -> void:
	_gui.visible = false
	_hud.visible = true
	get_tree().paused = false
