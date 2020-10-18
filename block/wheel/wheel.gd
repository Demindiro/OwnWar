extends VehicleWheel
class_name Wheel


# warning-ignore:unused_class_variable
export var max_power := 300.0
var max_angle := 0.0


func supply_power(power):
	engine_force = power


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle, _meta):
	max_angle = asin(translation.dot(Vector3.FORWARD) / translation.length())
	var manager = vehicle.get_manager("movement", preload("res://block/wheel/movement_manager.gd"))
	manager.add_wheel(self)
