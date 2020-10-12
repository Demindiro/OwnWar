extends Node


export var max_power := 16000.0


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle, _meta):
	var manager = vehicle.get_manager("power", preload("res://block/power/power_manager.gd"))
	manager.add_engine(self)
