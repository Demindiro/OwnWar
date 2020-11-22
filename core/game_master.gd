class_name GameMaster
extends Node


signal unit_added(unit)
# "unused" (see line 177)
# warning-ignore:unused_signal
signal load_game(data)
signal save_game(data)
export(NodePath) var victory_screen
export var team_count := 2
export var map_name: String
# warning-ignore:unused_class_variable
var teams := PoolStringArray([])
# warning-ignore:unused_class_variable
var ores := []
var uid_counter := 0
var _loading_game := false


func _enter_tree() -> void:
	assert(map_name != "")
	get_tree().connect("node_added", self, "_node_added")


func get_units(team: String, unit_name = null) -> Array:
	assert(team in teams)
	var team_name := "units_" + team
	if unit_name == null:
		return get_tree().get_nodes_in_group(team_name)
	else:
		var units_by_name = []
		for unit in get_tree().get_nodes_in_group(team_name):
			if unit.unit_name == unit_name:
				units_by_name.append(unit)
		return units_by_name


func get_unit_by_uid(uid: int):# -> Unit:
	for u in get_tree().get_nodes_in_group("units"):
		if u.uid == uid:
			return u
	assert(false)
	return null


func get_teams():
	return teams


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
		var team := teams[i]
		for u in get_tree().get_nodes_in_group("units_" + team):
			var u_data := {
					"name": u.unit_name,
					"transform": var2str(u.transform),
					"health": u.health,
					"uid": u.uid,
					"data": u.serialize_json(),
				}
			if u is RigidBody:
				u_data["linear_velocity"] = var2str(u.linear_velocity)
				u_data["angular_velocity"] = var2str(u.angular_velocity)
			list.append(u_data)
		s_units[team] = list

	var s_plugins := {}
	for plugin in Plugin.get_all_plugins():
		if Plugin.get_disable_reason(plugin.PLUGIN_ID) == Plugin.DisableReason.NONE:
			s_plugins[plugin.PLUGIN_ID] = plugin.save_game(self)
			assert(s_plugins[plugin.PLUGIN_ID] is Dictionary)

	var data := {
			"map_name": map_name,
			"units": s_units,
			"plugin_data": s_plugins,
			"uid_counter": uid_counter,
			"game_version": Util.version_vector_to_str(Game.VERSION),
		}
	emit_signal("save_game", data)
	print("Serializing time %d msec" % (OS.get_ticks_msec() - start_time))

	start_time = OS.get_ticks_msec()
	var json := to_json(data)
	print("to_json time %d msec" % (OS.get_ticks_msec() - start_time))

	var e := Util.create_dirs("user://game_saves")
	if e == OK:
		e = OK if Util.write_file_text("user://game_saves".plus_file(p_name) + \
				".json", json, true) else FAILED
		if e == OK:
			print("Saved game")
		else:
			print("Error saving game %d" % e)
	else:
		print("Error creating directory %d" %e)
	return e


static func _load_game(game_master: GameMaster, data: Dictionary) -> void:
	var start_time := OS.get_ticks_msec()

	for m_units in game_master.units:
		for u in m_units:
			u.free()
	game_master.teams = []
	game_master.units = []

	print("Free time %d msec" % (OS.get_ticks_msec() - start_time))
	start_time = OS.get_ticks_msec()

	game_master.uid_counter = data["uid_counter"]
	var _Vehicle := load("res://core/vehicle.gd")
	var _Unit := load("res://core/unit.gd")

	for team in data["units"]:
		var u_list := []
		for u_d in data["units"][team]:
			var u_name: String = u_d["name"]
			var u = _Vehicle.new() if \
					u_name.begins_with("vehicle_") else \
					_Unit.get_unit(u_d["name"]).instance()
			if u_name.begins_with("vehicle_"):
				u.unit_name = u_name
			u.game_master = game_master
			u.transform = str2var(u_d["transform"])
			u.uid = u_d["uid"]
			u.health = u_d["health"]
			if u is RigidBody:
				u.linear_velocity = str2var(u_d["linear_velocity"])
				u.angular_velocity = str2var(u_d["angular_velocity"])
			game_master.add_child(u)
			u_list.append(u)
		game_master.teams.push_front(team)
		game_master.units.push_front(u_list)

	for plugin_name in data["plugin_data"]:
		var plugin = Plugin.get_plugin(plugin_name)
		plugin.load_game(game_master, data["plugin_data"][plugin_name])

	for team in data["units"]:
		for u_d in data["units"][team]:
			game_master.get_unit_by_uid(u_d["uid"]).deserialize_json(u_d["data"])

	game_master.emit_signal("load_game", data)

	print("Deserialize time %d msec" % (OS.get_ticks_msec() - start_time))


static func load_game(path: String) -> int:
	print("Loading game from %s" % path)
	var start_time := OS.get_ticks_msec()
	var text := Util.read_file_text(path)
	if text == null:
		print("Failed to load game %d" % FAILED)
		return FAILED
	print("File read time %d msec" % (OS.get_ticks_msec() - start_time))
	start_time = OS.get_ticks_msec()
	var data: Dictionary = parse_json(text)
	print("parse_json time %d msec" % (OS.get_ticks_msec() - start_time))
	var map := Maps.get_map(data["map_name"])
	# Christ's sake
	var totallynotselfandstatic = load("res://core/game_master.gd")
	Global.goto_scene(map, funcref(totallynotselfandstatic.new(), "_load_game"), [data])
	return OK


static func get_game_master(node: Node) -> Node:# -> GameMaster:
	for child in node.get_tree().root.get_children():
		if child.has_method("get_game_master"):
			return child
	assert(false)
	return null


func _node_added(node: Node) -> void:
	#if node is Unit:
	if not _loading_game and node.get("unit_name") != null:
		assert(node.uid == -1)
		node.uid = uid_counter
		uid_counter += 7
		if not node.team in teams:
			print("Adding team %s" % node.team)
			teams.append(node.team)
		emit_signal("unit_added", node)
