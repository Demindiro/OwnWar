extends VehicleWheel
class_name Wheel


export var max_power := 300.0
var _max_angle := 0.0
var _drive_forward := 0.0
var _engines := []
var _vehicle: Vehicle


func _physics_process(_delta):
	if is_in_contact() and _vehicle.has_function("reserve_power"):
		_vehicle.call_function("reserve_power", [self, abs(_drive_forward * max_power)])


func supply_power(power):
	engine_force = power


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle):
	_max_angle = asin(translation.dot(Vector3.FORWARD) /
			translation.length())
	_vehicle = vehicle
	vehicle.add_block_function(self, "_static_set_drive_forward", "set_drive_forward")
	vehicle.add_block_function(self, "_static_set_drive_yaw", "set_drive_yaw")
	vehicle.add_block_function(self, "_static_set_brake", "set_brake")


static func _static_set_drive_forward(wheels, arguments):
	for wheel in wheels:
		wheel._drive_forward = clamp(arguments[0], -1, 1)


static func _static_set_drive_yaw(wheels, arguments):
	for wheel in wheels:
		wheel.steering = wheel._max_angle * clamp(arguments[0], -1, 1)


static func _static_set_brake(wheels, arguments):
	for wheel in wheels:
		wheel.brake = clamp(arguments[0], 0, 1)
