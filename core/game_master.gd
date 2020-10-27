class_name GameMaster
extends Node


signal unit_added(unit)
export(NodePath) var victory_screen
export var team_count := 2
# warning-ignore:unused_class_variable
var teams := ["Player", "Evil AI"]
var teams_alive := team_count
var units := []
# warning-ignore:unused_class_variable
var ores := []


func _enter_tree():
	for i in team_count:
		units.append([])


func add_unit(team, unit):
	units[team].append(unit)
	unit.team = team
	add_child(unit)
	emit_signal("unit_added", unit)


func remove_unit(team, unit):
	var index = units[team].find(unit)
	if index == -1:
		push_error("Unit '%s' not found in units[%d]" % [unit, team])
		return
	units[team].remove(index)
	unit.queue_free()
	if len(units[team]) == 0:
		teams_alive -= 1
		if teams_alive == 1:
			game_end()
			

func get_units(team, unit_name = null):
	if unit_name == null:
		return units[team].duplicate()
	else:
		var units_by_name = []
		for unit in units[team]:
			if unit.unit_name == unit_name:
				units_by_name.append(unit)
		return units_by_name
	
	
func game_end():
	get_tree().paused = true
	get_node(victory_screen).visible = true
	get_node(victory_screen).pause_mode = PAUSE_MODE_PROCESS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


static func get_game_master(node: Node) -> Node:# -> GameMaster:
#	while not node is GameMaster:
	# REEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
	while not node.has_method("get_game_master"): # Don't judge me
		assert(node.get_parent() != null)
		node = node.get_parent()
	return node
#	return node as GameMaster
