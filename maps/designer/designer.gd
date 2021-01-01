extends Node


var _vehicle_path := "user://vehicles/tank.json"
onready var _hud := get_node("HUD")
onready var _spawn_point: Spatial = get_node("SpawnPoint")


func _ready() -> void:
	var vehicle := OwnWar_Vehicle.new()
	var e := vehicle.load_from_file(_vehicle_path)
	assert(e == OK)
	vehicle.transform = _spawn_point.transform
	add_child(vehicle)
	_hud.player_vehicle = vehicle
