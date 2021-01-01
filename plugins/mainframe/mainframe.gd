extends Node


const WeaponManager := preload("res://plugins/weapon_manager/weapon_manager.gd")
const MovementManager := preload("res://plugins/movement_manager/movement_manager.gd")

var aim_weapons := false
var weapons_aim_point := Vector3.ZERO
var drive_forward := 0.0
var drive_yaw := 0.0
var brake := 0.0
var vehicle: OwnWar.Vehicle
var _fire_weapons := false
var _weapon_manager: WeaponManager
var _movement_manager: MovementManager


func process(delta):
	_movement_manager.set_drive_forward(drive_forward)
	_movement_manager.set_drive_yaw(drive_yaw)
	_movement_manager.set_brake(brake)
	if aim_weapons:
		_weapon_manager.aim_at(weapons_aim_point)
	else:
		_weapon_manager.rest_aim()
	if _fire_weapons:
		_weapon_manager.fire_weapons()
		_fire_weapons = false


func init(_coordinate, _block_data, _rotation, _voxel_body, p_vehicle, _meta):
	vehicle = p_vehicle


func fire_weapons():
	_fire_weapons = true
