extends Node


export var max_power := 16000.0


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle):
	var manager = vehicle.managers.get("power")
	if manager == null:
		manager = preload("res://block/power/power_manager.gd").new()
		vehicle.add_manager("power", manager)
	manager.add_engine(self)
