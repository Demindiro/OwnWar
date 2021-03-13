extends Button


signal alternate_pressed


var alt_pressed := false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_RIGHT:
			if event.pressed:
				alt_pressed = true
			elif alt_pressed:
				emit_signal("alternate_pressed")
				alt_pressed = false
			else:
				alt_pressed = false


func mouse_exited() -> void:
	alt_pressed = false
