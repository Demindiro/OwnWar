class_name Ghost
extends Unit


signal built(structure)

export(PackedScene) var structure
export(Array) var init_arguments
export(int) var build_cost = 0
var build_progress = 0


func add_build_progress(material):
	build_progress += material
	if build_progress >= build_cost:
		var unit = structure.instance()
		unit.team = team
		unit.global_transform = global_transform
		game_master.add_unit(team, unit)
		if unit.has_method("init") or init_arguments != []:
			unit.callv("init", init_arguments)
		destroy()
		return build_cost - build_progress
	return 0
