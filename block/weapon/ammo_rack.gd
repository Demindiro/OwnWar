extends Node


export var max_munitions := 4
var gauge := 0


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle, meta):
	var manager = vehicle.get_manager("weapon", preload("res://block/weapon/weapon_manager.gd"))
	manager.add_ammo_rack(self)
	if meta != null:
		gauge = meta["gauge_filter"]
