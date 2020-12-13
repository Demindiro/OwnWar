extends Node


func _ready():
	var game_master = get_tree().current_scene
	game_master.units[0].append($"../Roboport")
	game_master.units[0].append($"../StoragePod")
	game_master.units[0].append($"../StoragePod2")
	game_master.units[0].append($"../StoragePod3")
	game_master.units[0].append($"../Refinery")
	game_master.units[0].append($"../MunitionsFactory")
	game_master.units[0].append($"../Drill")
	game_master.units[0].append($"../SpawnPlatform")
	game_master.ores.append($"../Ore")
	$"../Drill".init($"../Ore")
	$"../StoragePod3".put_matter(OwnWar.Matter.get_matter_id("material"), 5000)


func _physics_process(_delta):
	for child in get_parent().get_children():
		if child is Spatial and child.translation.y < -0.1:
			get_tree().paused = true
			push_error("Something fell off the edge!")
