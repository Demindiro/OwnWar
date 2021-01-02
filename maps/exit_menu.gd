tool
extends "res://core/menu/dialog/independent_panel.gd"


signal cancel()
signal settings()
signal restart()
signal exit()


func _on_Continue_pressed():
	emit_signal("cancel")


func _on_Settings_pressed():
	emit_signal("settings")


func _on_Restart_pressed():
	emit_signal("restart")


func _on_Exit_pressed():
	emit_signal("exit")
