extends Node


func _ready(deferred := false):
	if not deferred:
		call_deferred("_ready", true)
		return
	var vehicle: OwnWar.Vehicle = $"../A/Vehicle"
	vehicle.get_manager("mainframe")._mainframes[0].set_targets(0, [$"../B/Target"])
	$"../A/Drone".put_matter_in(0, [vehicle], false)
	var shell_35mm_id := OwnWar.Matter.get_matter_id("35mm AP")
	assert(shell_35mm_id >= 0)
	$"../A/StoragePod".put_matter(shell_35mm_id, 1000000)
