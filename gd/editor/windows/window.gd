extends Control

func open_window(window_name: String) -> void:
	visible = window_name == name
