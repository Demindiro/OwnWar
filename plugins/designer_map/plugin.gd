extends OwnWar.Plugin.Interface


const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {
		"basic_manufacturing": Vector3(0, 0, 1),
		"worker_drone": Vector3(0, 0, 1),
	}


func pre_init():
	var dir: String = Util.get_script_dir(self)
	OwnWar.Maps.add_map("designer", dir.plus_file("map.tscn"))
