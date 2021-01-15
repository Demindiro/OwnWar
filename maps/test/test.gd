tool
extends Node


var designer_scene_path: String
var vehicle_name := "tank"
var vehicle_path := ""
onready var _hud := get_node("HUD")
var _spawn_points := []
var _spawn_point_index := 0



func _get(name: String):
	var split = name.split("/")
	if len(split) == 2 and split[0] == "spawn_point":
		var i := int(split[1])
		if i < len(_spawn_points):
			return _spawn_points[i]
	elif name == "designer_scene":
		if designer_scene_path == "":
			return null
		# TODO the editor is crashing due to a cyclic reference most likely
		#elif _editor_done_instancing:
		#	return load(designer_scene_path)
		else:
			return null
	elif name == "designer_scene_path":
		return designer_scene_path


func _set(name: String, value) -> bool:
	var split = name.split("/")
	if len(split) == 2 and split[0] == "spawn_point":
		var i := int(split[1])
		if value is NodePath and value != NodePath():
			if i > len(_spawn_points):
				return false
			elif i <= len(_spawn_points):
				property_list_changed_notify()
				_spawn_points.resize(i + 1)
			_spawn_points[i] = value
			return true
		elif value == null or value == NodePath():
			if i < len(_spawn_points):
				_spawn_points.remove(i)
				property_list_changed_notify()
				return true
	elif name == "designer_scene":
		designer_scene_path = value.resource_path
	elif name == "designer_scene_path":
		designer_scene_path = value
	return false


func _get_property_list() -> Array:
	var props := [
		{
			"name": "designer_scene",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "PackedScene",
			"usage": PROPERTY_USAGE_EDITOR,
		},
		{
			"name": "designer_scene_path",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.tscn",
			# TODO temporary until the load(...) is fixed
			"usage": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
			#"usage": PROPERTY_USAGE_STORAGE,
		}
	]
	for i in len(_spawn_points):
		props.append({
			"name": "spawn_point/%d" % i,
			"type": TYPE_NODE_PATH,
		})
	props.append({
		"name": "spawn_point/%d" % len(_spawn_points),
		"type": TYPE_NODE_PATH,
		"usage": PROPERTY_USAGE_EDITOR,
	})
	return props


func _enter_tree() -> void:
	# Dummy network until I figure out how to do RPC in singleplayer properly
	# This is a security risk btw, we shouldn't listen on random ports, let alone
	# one that is bound to 0.0.0.0
	var n := NetworkedMultiplayerENet.new()
	n.create_server(59799)
	get_tree().network_peer = n


func _ready() -> void:
	if not Engine.editor_hint:
		if vehicle_path == "":
			assert(vehicle_name != "")
			vehicle_path = OwnWar.get_vehicle_path(vehicle_name)
		var vehicle := OwnWar_Vehicle.new()
		vehicle.team = 0
		var e := vehicle.load_from_file(vehicle_path)
		assert(e == OK)
		vehicle.transform = get_node(_spawn_points[_spawn_point_index]).transform
		add_child(vehicle)
		_hud.player_vehicle = vehicle
		_spawn_point_index += 1
		_spawn_point_index %= len(_spawn_points)
		spawn_vehicle(vehicle_path)
		spawn_vehicle(vehicle_path)
		spawn_vehicle(vehicle_path)


func _exit_tree() -> void:
	get_tree().network_peer = null


func spawn_vehicle(path: String) -> void:
	var vehicle := OwnWar_Vehicle.new()
	vehicle.team = 1
	var e := vehicle.load_from_file(path)
	assert(e == OK)
	vehicle.transform = get_node(_spawn_points[_spawn_point_index]).transform
	add_child(vehicle)
	_spawn_point_index += 1
	_spawn_point_index %= len(_spawn_points)


func exit() -> void:
	var scene = load(designer_scene_path).instance()
	scene.vehicle_path = vehicle_path
	queue_free()
	var tree := get_tree()
	tree.root.remove_child(self)
	tree.root.add_child(scene)
	tree.current_scene = scene


func restart() -> void:
	get_tree().reload_current_scene()
