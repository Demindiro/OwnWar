tool
extends Node


var vehicle_path := "user://vehicles/crane.json"
onready var _hud := get_node("HUD")
var _spawn_points := []
var _spawn_point_index := 0



func _get(name: String):
	var split = name.split("/")
	if len(split) == 2 and split[0] == "spawn_point":
		var i := int(split[1])
		if i < len(_spawn_points):
			return _spawn_points[i]


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
	return false


func _get_property_list() -> Array:
	var props := []
	for i in len(_spawn_points):
		props.append({
			"name": "spawn_point/%d" % i,
			"type": TYPE_NODE_PATH,
		})
	props.append({
		"name": "spawn_point/%d" % len(_spawn_points),
		"type": TYPE_NODE_PATH,
	})
	return props


func _ready() -> void:
	if not Engine.editor_hint:
		var vehicle := OwnWar_Vehicle.new()
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


func spawn_vehicle(path: String) -> void:
	var vehicle := OwnWar_Vehicle.new()
	var e := vehicle.load_from_file(path)
	assert(e == OK)
	vehicle.transform = get_node(_spawn_points[_spawn_point_index]).transform
	add_child(vehicle)
	_spawn_point_index += 1
	_spawn_point_index %= len(_spawn_points)

