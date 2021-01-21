extends RayCast


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if event.button_mask & BUTTON_MASK_LEFT:
			_apply_damage()
	elif event is InputEventKey:
		if event.scancode == KEY_ENTER:
			_apply_damage()


func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_LEFT):
		translation -= Vector3.RIGHT * delta
	if Input.is_key_pressed(KEY_RIGHT):
		translation += Vector3.RIGHT * delta
	if Input.is_key_pressed(KEY_DOWN):
		translation -= Vector3.FORWARD * delta
	if Input.is_key_pressed(KEY_UP):
		translation += Vector3.FORWARD * delta


func _apply_damage() -> void:
	var damage := 1000
	if is_colliding():
		var collider := get_collider()
		if collider == null:
			# I don't get it but ok, probably a bug?
			return
		if collider.has_method("apply_damage"):
			collider.apply_damage(translation, cast_to, damage)
