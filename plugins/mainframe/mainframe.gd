extends Node


const WeaponManager := preload("res://plugins/weapon_manager/weapon_manager.gd")
const MovementManager := preload("res://plugins/movement_manager/movement_manager.gd")
const AI := preload("ai/ai.gd")
const WAYPOINT_ICON := preload("res://addons/hud/obituary_triple_arrow_to_point.tres")
const ATTACK_ICON := preload("res://addons/hud/obituary_bullet.tres")
const WAYPOINT_CURSOR := preload("res://addons/hud/obituary_triple_arrow_to_point_16x16.tres")
const ATTACK_CURSOR := preload("res://addons/hud/obituary_bullet_16x16.tres")
const TARGET_ICON := preload("res://addons/crosshairs/image0025.png")

var ai: AI
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
	var waypoint_action := OwnWar.Action.new(
		"Set waypoint",
		WAYPOINT_ICON,
		OwnWar.Unit.Action.INPUT_COORDINATE,
		funcref(self, "set_waypoint"),
		[]
	)
	waypoint_action.cursor = WAYPOINT_CURSOR
	manager.add_action(waypoint_action)
	var attack_action := OwnWar.Action.new(
		"Attack targets",
		ATTACK_ICON,
		OwnWar.Unit.Action.INPUT_ENEMY_UNITS,
		funcref(self, "set_targets"),
		[]
	)
	attack_action.cursor = ATTACK_CURSOR
	manager.add_action(attack_action)

	vehicle.add_feedback_function(funcref(self, "_show_feedback"))

	_weapon_manager = vehicle.get_manager("weapon")
	_movement_manager = vehicle.get_manager("movement")


func set_waypoint(flags, waypoint):
	if flags & 0x1:
		ai.waypoints.append(waypoint)
	else:
		ai.waypoints = [waypoint]


func set_targets(flags, targets):
	if flags & 0x1:
		for target in targets:
			if not target in ai.targets:
				ai.targets.append(target)
	else:
		ai.targets = targets.duplicate()


func fire_weapons():
	_fire_weapons = true


func debug_draw():
	if ai != null:
		ai.debug_draw(self)


func serialize_json() -> Dictionary:
	return {
		"ai_state": ai.serialize_json(OwnWar.GameMaster.get_game_master(self))
	}


func deserialize_json(data: Dictionary) -> void:
	ai.deserialize_json(
		OwnWar.GameMaster.get_game_master(self),
		data["ai_state"]
	)


func _show_feedback(hud: Control) -> void:
	if ai != null:
		var cam := get_tree().root.get_camera()
		var font := hud.get_font("font")
		var index := 1
		var color := Color(1, 1, 1, 0.5)
		for wp in ai.waypoints:
			var rel_wp: Vector3 = wp - cam.translation
			if cam.transform.basis.z.dot(rel_wp) < 0:
				var pos := cam.unproject_position(wp)
				hud.draw_texture_rect(
					WAYPOINT_ICON,
					Rect2(pos - Vector2(32, 32 + 27), Vector2(64, 64)),
					false,
					color
				)
				hud.draw_string(font, pos + Vector2(20, 2), str(index), color)
			index += 1
		index = 1
		for target in ai.targets:
			var pos3: Vector3 = target.translation
			var rel_pos3 := pos3 - cam.translation
			if cam.transform.basis.z.dot(rel_pos3) < 0:
				var pos := cam.unproject_position(pos3)
				hud.draw_texture_rect(
					TARGET_ICON,
					Rect2(pos - Vector2(32, 32), Vector2(64, 64)),
					false,
					Color.white
				)
			index += 1
