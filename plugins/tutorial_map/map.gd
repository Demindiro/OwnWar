extends Node


export(PackedScene) var drone_scene
onready var game_master = $".."
var _drone_spawn_transform


func _ready():
	$Player/Drill.init($Ores/Ore)
	for parent in get_children():
		for child in parent.get_children():
			if child is Unit:
				game_master.units[child.team].append(child)
				child.uid = game_master.uid_counter
				game_master.uid_counter += 241
	var material_id := Matter.get_matter_id("material")
	$Player/StoragePod.put_matter(material_id, 500)
	$Enemy/StoragePod.put_matter(material_id, 10000)
	$Enemy/StoragePod2.put_matter(material_id, 10000)
	_drone_spawn_transform = $Player/Drone.transform
	call_deferred("_set_terrain_collision_bit")


func _physics_process(_delta):
	if len(game_master.get_units(0, "worker")) == 0:
		var drone = drone_scene.instance()
		drone.transform = _drone_spawn_transform
		game_master.add_unit(0, drone)
