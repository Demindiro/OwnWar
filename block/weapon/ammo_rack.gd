extends Node


export var max_munitions := 4


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle):
	var manager = vehicle.get_manager("weapon", preload("res://block/weapon/weapon_manager.gd"))
	manager.add_ammo_rack(self)
