class_name Ghost
extends Spatial


signal built(structure)

export(PackedScene) var structure
export(Array) var init_arguments
export(int) var build_cost = 0
export(int) var team = 0
var build_progress = 0
onready var game_master = get_tree().get_current_scene()


func add_build_progress(material):
	build_progress += material
	if build_progress >= build_cost:
		var unit = structure.instance()
		unit.team = team
		unit.global_transform = global_transform
		game_master.add_unit(team, unit)
		unit.callv("init", init_arguments)
		emit_signal("built", unit)
		queue_free()
		return build_cost - build_progress
	return 0
