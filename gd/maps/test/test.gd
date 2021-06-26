tool
extends Node


var editor_scene_path: String
var vehicle_name := "skunk"
var vehicle_path := ""
onready var _hud := get_node("HUD")
export var spawn_points := NodePath("SpawnPoints")
var _spawn_point_index := 0



func _get(name: String):
	if name == "editor_scene":
		if editor_scene_path == "":
			return null
		# TODO the editor is crashing due to a cyclic reference most likely
		#elif _editor_done_instancing:
		#	return load(editor_scene_path)
		else:
			return null
	elif name == "editor_scene_path":
		return editor_scene_path


func _set(name: String, value) -> bool:
	if name == "editor_scene":
		editor_scene_path = value.resource_path
	elif name == "editor_scene_path":
		editor_scene_path = value
	return false


func _get_property_list() -> Array:
	var props := [
		{
			"name": "editor_scene",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "PackedScene",
			"usage": PROPERTY_USAGE_EDITOR,
		},
		{
			"name": "editor_scene_path",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.tscn",
			# TODO temporary until the load(...) is fixed
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
			#"usage": PROPERTY_USAGE_STORAGE,
		}
	]
	return props


func _enter_tree() -> void:
	# Dummy network until I figure out how to do RPC in singleplayer properly
	# This is a security risk btw, we shouldn't listen on random ports, let alone
	# one that is bound to 0.0.0.0
	# Try some random ports until one works
	for i in 1000:
		var n := NetworkedMultiplayerENet.new()
		var e := n.create_server(randi() % (65536 - 10000) + 10000)
		if e == OK:
			get_tree().network_peer = n
			break


func _ready() -> void:
	if not Engine.editor_hint:
		if vehicle_path == "":
			assert(vehicle_name != "")
			vehicle_path = OwnWar.get_vehicle_path(vehicle_name)
		var vehicle := OwnWar_Vehicle.new()
		vehicle.team = 0
		vehicle.is_ally = true
		var e := vehicle.load_from_file(vehicle_path)
		assert(e == OK)
		vehicle.transform = get_node(spawn_points).get_child(_spawn_point_index).transform
		add_child(vehicle)
		_hud.player_vehicle = vehicle
		_spawn_point_index += 1
		_spawn_point_index %= get_node(spawn_points).get_child_count()
		if true:
			for _i in 12:
				spawn_vehicle(vehicle_path)


func _exit_tree() -> void:
	get_tree().network_peer.close_connection()
	get_tree().network_peer = null


func spawn_vehicle(path: String) -> void:
	var vehicle := OwnWar_Vehicle.new()
	vehicle.team = 1
	var e := vehicle.load_from_file(path)
	assert(e == OK)
	vehicle.transform = get_node(spawn_points).get_child(_spawn_point_index).transform
	add_child(vehicle)
	_spawn_point_index += 1
	_spawn_point_index %= get_node(spawn_points).get_child_count()
	for n in Util.get_children_recursive(vehicle):
		if n is MeshInstance and not n.has_meta("no_outline"):
			get_node("Outline").add_outline(n)


func exit() -> void:
	var scene = load(editor_scene_path).instance()
	scene.data_path = vehicle_path
	queue_free()
	var tree := get_tree()
	tree.root.remove_child(self)
	tree.root.add_child(scene)
	tree.current_scene = scene


func restart() -> void:
	var s = load(filename).instance()
	s.vehicle_path = vehicle_path
	var tree := get_tree()
	tree.root.remove_child(self)
	tree.root.add_child(s)
	tree.current_scene = s
	queue_free()
