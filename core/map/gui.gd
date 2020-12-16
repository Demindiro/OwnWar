extends Control


signal save(path)
signal cancel()
signal exit()
signal restart()


onready var _exit_menu: Control = $ExitMenu
onready var _save_menu: Control = $SaveMenu


func _on_SaveMenu_save(path: String) -> void:
	emit_signal("save", path)
	_exit_menu.visible = true
	_save_menu.visible = false


func _on_SaveMenu_cancel():
	_exit_menu.visible = true
	_save_menu.visible = false


func _on_ExitMenu_cancel() -> void:
	emit_signal("cancel")


func _on_ExitMenu_exit() -> void:
	emit_signal("exit")


func _on_ExitMenu_restart() -> void:
	emit_signal("restart")


func _on_ExitMenu_save() -> void:
	_exit_menu.visible = false
	_save_menu.visible = true


func _on_ExitMenu_settings() -> void:
	push_warning("TODO implement settings")
