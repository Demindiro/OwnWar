extends Reference


var _wheels := []
var _power_manager: Reference


func init(vehicle: Vehicle) -> void:
	_power_manager = vehicle.get_manager("power", preload("res://block/power/power_manager.gd"))


func set_drive_forward(drive):
	drive = clamp(drive, -1, 1)
	for wheel in _wheels:
		_power_manager.reserve_power(wheel, abs(wheel.max_power * drive))


func set_drive_yaw(drive):
	drive = clamp(drive, -1, 1)
	for wheel in _wheels:
		wheel.steering = wheel.max_angle * drive


func set_brake(brake):
	brake = clamp(brake, 0, 1)
	for wheel in _wheels:
		wheel.brake = brake


func add_wheel(wheel):
	_wheels.append(wheel)
	wheel.connect("tree_exited", self, "_wheel_destroyed", [wheel])
	wheel.connect("tree_entered", self, "_wheel_readded", [wheel])


func _wheel_destroyed(wheel):
	_wheels.erase(wheel)


func _wheel_readded(wheel):
	if not wheel in _wheels:
		_wheels.append(wheel)
