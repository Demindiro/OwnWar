extends VehicleWheel
class_name Wheel


export var max_power := 300.0
var max_angle := 0.0


func supply_power(power):
	engine_force = power


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle):
	max_angle = asin(translation.dot(Vector3.FORWARD) / translation.length())
	var manager = vehicle.managers.get("movement")
	if manager == null:
		manager = preload("res://block/wheel/movement_manager.gd").new()
		vehicle.add_manager("movement", manager)
	manager.add_wheel(self)
