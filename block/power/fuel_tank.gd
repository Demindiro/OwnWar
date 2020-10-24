extends Node


# warning-ignore:unused_class_variable
export var max_fuel := 1000


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle, _meta):
	var manager = vehicle.get_manager("power", preload("res://block/power/power_manager.gd"))
	manager.add_fuel_tank(self)
