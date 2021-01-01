extends Node
const BM := preload("res://plugins/basic_manufacturing/plugin.gd")
const WorkerDrone := preload("res://plugins/worker_drone/drone.gd")

export(PackedScene) var drone_scene
onready var game_master := OwnWar.GameMaster.get_game_master(self)
var _drone_spawn_transform
onready var _player_drill: BM.Drill = $"../Player/Drill"
onready var _player_drone: WorkerDrone = $"../Player/Drone"
onready var _player_storage_pod: BM.StoragePod = $"../Player/StoragePod"
onready var _evilai_storage_pod_a: BM.StoragePod = $"../EvilAI/StoragePod"
onready var _player_storage_pod_b: BM.StoragePod = $"../EvilAI/StoragePod2"
onready var _ore: BM.Ore = $Ores/Ore


func _ready():
	var material_id := OwnWar.Matter.get_matter_id("material")
	_player_drill.init(_ore)
	var m := _player_storage_pod.put_matter(material_id, 500)
	assert(m == 0)
	m = _evilai_storage_pod_a.put_matter(material_id, 1000)
	assert(m == 0)
	m = _player_storage_pod_b.put_matter(material_id, 1000)
	assert(m == 0)
	_drone_spawn_transform = _player_drone.transform


func _physics_process(_delta):
	if len(game_master.get_units("Player", "worker")) == 0:
		# Make sure the player always has at least one worker drone
		# (the player may not lose)
		var drone = drone_scene.instance()
		drone.transform = _drone_spawn_transform
		drone.team = "Player"
		game_master.add_child(drone)
