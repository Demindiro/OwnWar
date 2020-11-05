const PLUGIN_ID := "basic_manufacturing"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {"worker_drone": Vector3(0, 0, 1)}


static func pre_init(_plugin_path: String):
	Unit.add_unit("storage_pod", preload("storage_pod.tscn"))
	Unit.add_unit("munitions_factory", preload("munitions_factory.tscn"))
	Unit.add_unit("spawn_platform", preload("spawn_platform/spawn_platform.tscn"))
	Unit.add_unit("refinery", preload("refinery.tscn"))
	Unit.add_unit("roboport", preload("roboport.tscn"))
	Unit.add_unit("storage_pod_ghost", preload("storage_pod_ghost.tscn"))
	Unit.add_unit("munitions_factory_ghost", preload("munitions_factory_ghost.tscn"))
	Unit.add_unit("spawn_platform_ghost", preload("spawn_platform/spawn_platform_ghost.tscn"))
	Unit.add_unit("refinery_ghost", preload("refinery_ghost.tscn"))
	Unit.add_unit("roboport_ghost", preload("roboport_ghost.tscn"))
	Unit.add_unit("roboport_drone", preload("roboport_drone.tscn"))


static func init(_plugin_path: String):
	pass


static func post_init(_plugin_path: String):
	pass


static func save_game(game_master: GameMaster) -> Dictionary:
	var s_ores := []
	for ore in game_master.get_tree().get_nodes_in_group("ores"):
		s_ores.append([var2str(ore.transform), ore.material])
	return {"ores": s_ores}


static func load_game(game_master: GameMaster, data: Dictionary) -> void:
	for s in data["ores"]:
		var found := false
		var transform: Transform = str2var(s[0])
		for ore in game_master.get_tree().get_nodes_in_group("ores"):
			if ore.transform == transform:
				ore.material = s[1]
				found = true
				break
		assert(found)
