extends Node


export(PackedScene) var drone_scene
onready var game_master := GameMaster.get_game_master(self)
var _drone_spawn_transform


func _ready():
	var material_id := Matter.get_matter_id("material")
	$"../Player/Drill".init($Ores/Ore)
	$"../Player/StoragePod".put_matter(material_id, 500)
	$"../EvilAI/StoragePod".put_matter(material_id, 10000)
	$"../EvilAI/StoragePod2".put_matter(material_id, 10000)
	_drone_spawn_transform = $"../Player/Drone".transform


func _physics_process(_delta):
	if len(game_master.get_units("Player", "worker")) == 0:
		var drone = drone_scene.instance()
		drone.transform = _drone_spawn_transform
		game_master.add_unit(0, drone)
