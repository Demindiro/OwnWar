extends PanelContainer


func exit() -> void:
	get_tree().change_scene(OwnWar.MAIN_MENU)
	get_tree().paused = false


func on_visibility_changed() -> void:
	if visible or Input.is_action_pressed("combat_release_cursor"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = true # Prevent RPC error spam
