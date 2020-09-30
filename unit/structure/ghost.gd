class_name Ghost
extends Unit


signal built(structure)

export(PackedScene) var structure
export(Array) var init_arguments
export(Vector3) var spawn_offset = Vector3.ZERO
var build_progress = 0


func add_build_progress(material):
	build_progress += material
	if build_progress >= cost:
		var unit = structure.instance()
		unit.team = team
		unit.global_transform = global_transform
		unit.translate(spawn_offset)
		game_master.add_unit(team, unit)
		if unit.has_method("init") or init_arguments != []:
			unit.callv("init", init_arguments)
		destroy()
		return cost - build_progress
	return 0