extends Reference


var _wheels := []
var _power_manager: Reference


func init(vehicle: Vehicle) -> void:
	vehicle.add_function(self, "set_drive_forward")
	vehicle.add_function(self, "set_drive_yaw")
	vehicle.add_function(self, "set_brake")
	_power_manager = vehicle.managers.get("power")
	if _power_manager == null:
		_power_manager = preload("res://block/power/power_manager.gd").new()
		vehicle.add_manager("power", _power_manager)


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
#	wheel.connect("tree_exited", self, "_wheel_destroyed", [wheel])


func _wheel_destroyed(wheel):
	_wheels.erase(wheel)
