extends OwnWar.Plugin.Interface


const PLUGIN_VERSION = Vector3(0, 0, 1)
const MIN_VERSION = Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {
		"chassis_blocks": Vector3(0, 0, 1),
		"basic_manufacturing": Vector3(0, 0, 1),
		"worker_drone": Vector3(0, 0, 1),
		"cannon": Vector3(0, 0, 1),
		"mainframe": Vector3(0, 0, 1),
		"wheel": Vector3(0, 0, 1),
		"engine": Vector3(0, 0, 1),
		"turret": Vector3(0, 0, 1),
	}


func pre_init():
	var dir = Util.get_script_dir(self)
	Maps.add_map("campaign_abcd", dir.plus_file("map.tscn"))
