class_name GameMaster
extends Node


signal unit_added(unit)
export(NodePath) var victory_screen
export var team_count := 2
export var map_name: String
# warning-ignore:unused_class_variable
var teams := ["Player", "Evil AI"]
var teams_alive := team_count
var units := []
# warning-ignore:unused_class_variable
var ores := []
var uid_counter := 0


func _enter_tree():
	assert(map_name != "")
	for i in team_count:
		units.append([])


func add_unit(team, unit):
	units[team].append(unit)
	unit.team = team
	unit.uid = uid_counter
	uid_counter += 241
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


func get_unit_by_uid(uid: int):# -> Unit:
	for l in units:
		for u in l:
			if u.uid == uid:
				return u
	assert(false)
	return null


func game_end():
	get_tree().paused = true
	get_node(victory_screen).visible = true
	get_node(victory_screen).pause_mode = PAUSE_MODE_PROCESS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func save_game(p_name: String) -> int:
	print("Saving game as %s" % p_name)
	var start_time := OS.get_ticks_msec()
	var s_units := {}
	for i in range(len(teams)):
		var list := []
		for u in units[i]:
			list.append({
					"name": u.unit_name,
					"transform": var2str(u.transform),
					"health": u.health,
					"uid": u.uid,
					"data": u.serialize_json(),
				})
		s_units[teams[i]] = list

	var s_plugins := {}
	for plugin in Plugin.get_all_plugins():
		if Plugin.get_disable_reason(plugin.PLUGIN_ID) == Plugin.DisableReason.NONE:
			s_plugins[plugin.PLUGIN_ID] = plugin.save_game(self)
			assert(s_plugins[plugin.PLUGIN_ID] is Dictionary)
	print("Serializing time %d msec" % (OS.get_ticks_msec() - start_time))

	start_time = OS.get_ticks_msec()
	var json := to_json({
			"map_name": map_name,
			"units": s_units,
			"plugin_data": s_plugins,
			"uid_counter": uid_counter,
		})
	print("to_json time %d msec" % (OS.get_ticks_msec() - start_time))

	Util.create_dirs("user://game_saves")
	var e := OK if Util.write_file_text("user://game_saves".plus_file(p_name) + \
			".json", json, true) else FAILED
	if e == OK:
		print("Saved game")
	else:
		print("Error saving game %d" % e)
	return e


static func get_game_master(node: Node) -> Node:# -> GameMaster:
#	while not node is GameMaster:
	# REEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
	while not node.has_method("get_game_master"): # Don't judge me
		assert(node.get_parent() != null)
		node = node.get_parent()
	return node
#	return node as GameMaster
