extends Node
class_name OwnWar_GameMaster


const Unit := preload("../unit/unit.gd")
const Vehicle := preload("../unit/vehicle.gd")
const Compatibility := preload("../compatibility.gd")
const Maps := preload("../maps.gd")


signal unit_added(unit)
# "unused" (see line 177)
# warning-ignore:unused_signal
signal load_game(data)
signal save_game(data)
export(NodePath) var victory_screen
export var map_name: String
# warning-ignore:unused_class_variable
var teams := PoolStringArray([])
# warning-ignore:unused_class_variable
var ores := []
var uid_counter := 0
var _loading_game := false


func _enter_tree() -> void:
	assert(map_name != "")
	var e := get_tree().connect("node_added", self, "_node_added")
	assert(e == OK)


func get_units(team: String, unit_filter = null) -> Array:
	assert(team in teams)
	var team_name := "units_" + team
	var units := get_tree().get_nodes_in_group(team_name)
	if unit_filter == null:
		return units
	elif unit_filter is String:
		var units_by_name = []
		for unit in units:
			if unit.unit_name == unit_filter:
				units_by_name.append(unit)
		return units_by_name
	elif unit_filter is GDScript:
		var units_by_type = []
		for unit in units:
			if unit is unit_filter:
				units_by_type.append(unit)
		return units_by_type
	else:
		assert(false)
		return []


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
	var node: Control = get_node(victory_screen)
	assert(node != null)
	node.visible = true
	node.pause_mode = PAUSE_MODE_PROCESS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func save_game(path: String) -> int:
	print("Saving game as %s" % path)
	var start_time := OS.get_ticks_msec()
	var s_units := {}
	for u in get_tree().get_nodes_in_group("units"):
		var u_data := {
				"name": u.unit_name,
				"transform": var2str(u.transform),
				"health": u.health,
				"team": u.team,
				"data": u.serialize_json(),
			}
		if u is RigidBody:
			u_data["linear_velocity"] = var2str(u.linear_velocity)
			u_data["angular_velocity"] = var2str(u.angular_velocity)
		s_units[var2str(u.uid)] = u_data

	var s_plugins := {}

	var game_version: Vector3 = load("res://core/ownwar.gd").VERSION
	var data := {
			"map_name": map_name,
			"units": s_units,
			"plugin_data": s_plugins,
			"uid_counter": uid_counter,
			"game_version": Util.version_vector_to_str(game_version),
		}
	emit_signal("save_game", data)
	print("Serializing time %d msec" % (OS.get_ticks_msec() - start_time))

	start_time = OS.get_ticks_msec()
	var json := to_json(data)
	print("to_json time %d msec" % (OS.get_ticks_msec() - start_time))

	var e := Util.create_dirs("user://game_saves")
	if e == OK:
		e = OK if Util.write_file_text(path, json, true) else FAILED
		if e == OK:
			print("Saved game")
		else:
			assert(false)
			push_error("Error saving game %d" % e)
	else:
		print("Error creating directory %d" %e)
	return e


func _load_game(data: Dictionary) -> void:
	_loading_game = true
	var start_time := OS.get_ticks_msec()

	for unit in get_tree().get_nodes_in_group("units"):
		unit.free()
	teams = []

	print("Free time %d msec" % (OS.get_ticks_msec() - start_time))
	start_time = OS.get_ticks_msec()

	uid_counter = data["uid_counter"]

	teams = []
	var units_data: Dictionary = data["units"]
	for uid in units_data:
		var u_d: Dictionary = units_data[uid]
		var u_name: String = u_d["name"]
		var u: Unit
		if u_name.begins_with("vehicle_"):
			u = Vehicle.new()
		else:
			u = Unit.get_unit(u_d["name"]).instance()
		if u_name.begins_with("vehicle_"):
			u.unit_name = u_name
		u.game_master = self
		u.transform = str2var(u_d["transform"])
		u.uid = str2var(uid)
		u.health = u_d["health"]
		if (u as Spatial) is RigidBody:
			var s: RigidBody
			s = u as Spatial
			s.linear_velocity = str2var(u_d["linear_velocity"])
			s.angular_velocity = str2var(u_d["angular_velocity"])
		u.team = u_d["team"]
		u.add_to_group("units_" + u.team)
		u.add_to_group("units")
		add_child(u)
		if not u.team in teams:
			teams.append(u.team)

	for unit in get_tree().get_nodes_in_group("units"):
		unit.deserialize_json(units_data[var2str(unit.uid)]["data"])

	emit_signal("load_game", data)

	print("Deserialize time %d msec" % (OS.get_ticks_msec() - start_time))
	_loading_game = false


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

	start_time = OS.get_ticks_msec()
	data = Compatibility.convert_game_data(data)
	print("convert_game_data %d msec" % (OS.get_ticks_msec() - start_time))

	var map := Maps.get_map(data["map_name"])
	# Christ's sake
	Global.goto_scene(map, "_load_game", [data])
	return OK


static func get_game_master(node: Node) -> Node:# -> GameMaster:
	if Engine.editor_hint:
		return null
	assert(node.get_tree() != null)
	for child in node.get_tree().root.get_children():
		if child.has_method("get_game_master"):
			return child
	assert(false)
	return null


func _node_added(node: Node) -> void:
	#if node is Unit:
	var unit := node as Unit
	if not _loading_game and unit != null:
		assert(unit.uid == -1)
		unit.uid = uid_counter
		uid_counter += 7
		if not unit.team in teams:
			print("Adding team %s" % unit.team)
			teams.append(unit.team)
		unit.game_master = self
		emit_signal("unit_added", unit)
