extends PluginInterface


const PLUGIN_ID := "basic_manufacturing"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {"worker_drone": Vector3(0, 0, 1)}

const MunitionsFactory := preload("munitions_factory/munitions_factory.gd")
const Ore := preload("drill/ore.gd")
const Drill := preload("drill/drill.gd")
const StoragePod := preload("storage_pod/storage_pod.gd")
const SpawnPlatform := preload("spawn_platform/spawn_platform.gd")
const Refinery := preload("refinery/refinery.gd")
const Roboport := preload("roboport/roboport.gd")


func pre_init():
	Unit.add_unit("drill", preload("drill/drill.tscn"))
	Unit.add_unit("munitions_factory", preload("munitions_factory/munitions_factory.tscn"))
	Unit.add_unit("storage_pod", preload("storage_pod/storage_pod.tscn"))
	Unit.add_unit("spawn_platform", preload("spawn_platform/spawn_platform.tscn"))
	Unit.add_unit("refinery", preload("refinery/refinery.tscn"))
	Unit.add_unit("roboport", preload("roboport/roboport.tscn"))
	Unit.add_unit("drill_ghost", preload("drill/drill_ghost.tscn"))
	Unit.add_unit("storage_pod_ghost", preload("storage_pod/storage_pod_ghost.tscn"))
	Unit.add_unit("munitions_factory_ghost", preload("munitions_factory/munitions_factory_ghost.tscn"))
	Unit.add_unit("spawn_platform_ghost", preload("spawn_platform/spawn_platform_ghost.tscn"))
	Unit.add_unit("refinery_ghost", preload("refinery/refinery_ghost.tscn"))
	Unit.add_unit("roboport_ghost", preload("roboport/roboport_ghost.tscn"))
	Unit.add_unit("roboport_drone", preload("roboport/roboport_drone.tscn"))


func save_game(game_master: GameMaster) -> Dictionary:
	var s_ores := []
	for ore in game_master.get_tree().get_nodes_in_group("ores"):
		s_ores.append([var2str(ore.transform), ore.material])
	return {"ores": s_ores}


func load_game(game_master: GameMaster, data: Dictionary) -> void:
	for s in data["ores"]:
		var found := false
		var transform: Transform = str2var(s[0])
		var org := transform.origin
		for ore in game_master.get_tree().get_nodes_in_group("ores"):
			# High leeway because old saves
			if Util.is_vec3_approx_eq(ore.translation, org, 0.25):
				ore.material = s[1]
				found = true
				break
		assert(found)
