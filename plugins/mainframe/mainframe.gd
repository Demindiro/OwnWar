extends Node


var ai: AI
var aim_weapons := false
var weapons_aim_point := Vector3.ZERO
var drive_forward := 0.0
var drive_yaw := 0.0
var brake := 0.0
var vehicle: Vehicle
var _fire_weapons := false
var _weapon_manager: Reference
var _movement_manager: Reference


func _process(_delta):
	debug_draw(get_tree().current_scene.find_node("Debug"))


func process(delta):
	ai.process(self, delta)
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
	ai = preload("ai/brick.gd").new()
	ai.init(vehicle)

	var manager = vehicle.get_manager("mainframe")
	manager.add_mainframe(self)
	manager.add_action(self, "Set waypoint", Unit.Action.INPUT_COORDINATE, "set_waypoint", [])
	manager.add_action(self, "Set targets", Unit.Action.INPUT_ENEMY_UNITS, "set_targets", [])

	_weapon_manager = vehicle.get_manager("weapon")
	_movement_manager = vehicle.get_manager("movement")


func set_waypoint(flags, waypoint):
	if flags & 0x1:
		ai.waypoints.append(waypoint)
	else:
		ai.waypoints = [waypoint]


func set_targets(flags, targets):
	if flags & 0x1:
		ai.targets += targets
	else:
		ai.targets = targets.duplicate()


func fire_weapons():
	_fire_weapons = true


func debug_draw(debug):
	ai.debug_draw(self, debug)


func serialize_json() -> Dictionary:
	return {
			"ai_state": ai.serialize_json(GameMaster.get_game_master(self))
		}


func deserialize_json(data: Dictionary) -> void:
	ai.deserialize_json(GameMaster.get_game_master(self), data["ai_state"])
