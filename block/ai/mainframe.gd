extends Node


var ai: AI
var vehicle
var aim_weapons := false
var weapons_aim_point := Vector3.ZERO
var _fire_weapons := false


func _process(_delta):
	debug_draw(get_tree().current_scene.find_node("Debug"))


func _physics_process(delta):
	ai.process(self, delta)
	for body in vehicle.voxel_bodies:
		for child in body.get_children():
			if child is Weapon:
				if aim_weapons:
					child.aim_at(weapons_aim_point)
				if _fire_weapons:
					child.fire()
			elif child is Cannon:
				if aim_weapons:
					child.aim_at(weapons_aim_point)
				else:
					child.set_angle(0)
				if _fire_weapons:
					child.fire()
			elif child.get_child_count() > 0 and child.get_child(0) is Connector:
				if aim_weapons:
					child.get_child(0).aim_at(weapons_aim_point)
				else:
					child.get_child(0).set_angle(0)
	_fire_weapons = false


func init(_coordinate, _block_data, _rotation, _voxel_body, p_vehicle):
	vehicle = p_vehicle
	vehicle.add_action(self, "Set waypoint", Unit.Action.INPUT_COORDINATE, "set_waypoint", [])
	vehicle.add_action(self, "Set targets", Unit.Action.INPUT_ENEMY_UNITS, "set_targets", [])
	ai = load("res://unit/vehicle/ai/brick.gd").new()
	ai.init(vehicle)


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
