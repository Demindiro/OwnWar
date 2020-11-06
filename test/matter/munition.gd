extends Node


func _ready(deferred := false):
	if not deferred:
		call_deferred("_ready", true)
		return
	var game_master: GameMaster = $".."
	game_master.units[0].append($Drone)
	game_master.units[0].append($StoragePod)
	game_master.units[1].append($Target)
	var vehicle := Vehicle.new()
	vehicle.translation += Vector3.UP * 1
	vehicle.load_from_file("user://vehicles/spaag.json")
	game_master.add_unit(0, vehicle)
	vehicle.get_manager("mainframe")._mainframes[0].set_targets(0, [$Target])
	$Drone.put_matter_in(0, [vehicle], false)
	var shell_35mm_id := Matter.get_matter_id("35mm AP")
	assert(shell_35mm_id >= 0)
	$StoragePod.put_matter(shell_35mm_id, 1000000)
