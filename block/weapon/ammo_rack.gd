extends Node


export var max_munitions := 4


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle):
	var manager = vehicle.managers.get("weapon")
	if manager == null:
		manager = preload("res://block/weapon/weapon_manager.gd").new()
		vehicle.add_manager("weapon", manager)
	manager.add_ammo_rack(self)
