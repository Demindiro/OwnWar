extends Node


export var max_fuel := 1000


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle):
	var manager = vehicle.managers.get("power")
	if manager == null:
		manager = preload("res://block/power/power_manager.gd").new()
		vehicle.add_manager("power", manager)
	manager.add_fuel_tank(self)
