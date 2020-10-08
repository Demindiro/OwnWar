extends Node


var ai: AI
var vehicle


func _process(_delta):
	debug_draw(get_tree().current_scene.find_node("Debug"))


func _physics_process(delta):
	ai.process(delta)


func init(_coordinate, _block_data, _rotation, _voxel_body, p_vehicle):
	vehicle = p_vehicle
	vehicle.add_action(self, "Set waypoint", Unit.Action.INPUT_COORDINATE, "set_waypoint", [])
	vehicle.add_action(self, "Set targets", Unit.Action.INPUT_ENEMY_UNITS, "set_targets", [])
	ai = load("res://unit/vehicle/ai/brick.gd").new()
	ai.init(vehicle)


func set_waypoint(_flags, waypoint):
	ai.waypoint = waypoint


func set_targets(_flags, targets):
	ai.target = targets[0] if len(targets) > 0 else null


func debug_draw(debug):
	ai.debug_draw(debug)
