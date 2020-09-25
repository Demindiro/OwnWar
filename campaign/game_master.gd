class_name GameMaster

extends Node


export(NodePath) var victory_screen
export var team_count := 2
export var start_material := 100

var teams := ["Player", "Evil AI"]
var teams_alive := team_count
var material_count := []
var units := []


func _enter_tree():
	for i in team_count:
		material_count.append(start_material)
		units.append([])


func add_material(team, count):
	material_count[team] += count
	

func take_material(team, count, exact = false):
	if count <= material_count[team]:
		material_count[team] -= count
		return count
	elif not exact:
		var remaining = material_count[team]
		material_count[team] = 0
		return remaining
	else:
		return 0


func add_unit(team, unit):
	units[team].append(unit)
	unit.team = team
	add_child(unit)


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
