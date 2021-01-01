extends Reference


var _wheels := []


func set_drive_forward(drive):
	drive = clamp(drive, -1, 1)
	for wheel in _wheels:
		wheel.set_drive(drive)


func set_drive_yaw(drive):
	drive = clamp(drive, -1, 1)
	for wheel in _wheels:
		wheel.steering = wheel.max_angle * drive


func set_brake(brake):
	brake = clamp(brake, 0, 1)
	for wheel in _wheels:
		wheel.brake = brake * 2.0


func add_wheel(wheel):
	_wheels.append(wheel)
	wheel.connect("tree_exited", self, "_wheel_destroyed", [wheel])
	wheel.connect("tree_entered", self, "_wheel_readded", [wheel])


func serialize_json() -> Dictionary:
	return {}


func deserialize_json(_data: Dictionary) -> void:
	pass


func _wheel_destroyed(wheel):
	_wheels.erase(wheel)


func _wheel_readded(wheel):
	if not wheel in _wheels:
		_wheels.append(wheel)
