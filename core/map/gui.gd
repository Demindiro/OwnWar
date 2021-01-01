extends Control


signal cancel()
signal exit()
signal restart()


func _on_ExitMenu_cancel() -> void:
	emit_signal("cancel")


func _on_ExitMenu_exit() -> void:
	emit_signal("exit")


func _on_ExitMenu_restart() -> void:
	emit_signal("restart")


func _on_ExitMenu_settings() -> void:
	push_warning("TODO implement settings")
