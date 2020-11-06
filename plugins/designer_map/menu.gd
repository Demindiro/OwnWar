extends "res://core/menu/dialog/independent_panel.gd"


onready var parent = get_parent()


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		visible = !parent.enabled
		parent.set_enabled(!parent.enabled)


func _on_Continue_pressed():
	visible = !parent.enabled
	parent.set_enabled(!parent.enabled)


func _on_Restart_pressed():
	var err = get_tree().reload_current_scene()
	if err != OK:
		Global.error("Failed to reload scene", err)


func _on_Designer_pressed():
	Global.goto_scene(Global.SCENE_DESIGNER)


func _on_Exit_pressed():
	Global.goto_scene(Global.SCENE_MENU_MAIN)

