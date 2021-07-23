extends Control

signal set_message(msg)

func set_message(msg):
	emit_signal("set_message", msg)
	set_visible(true)
