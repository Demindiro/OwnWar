const PLUGIN_ID := "designer_map"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {
		"basic_manufacturing": Vector3(0, 0, 1),
		"worker_drone": Vector3(0, 0, 1),
	}


static func pre_init(plugin_folder: String):
	Maps.add_map("designer", plugin_folder.plus_file("map.tscn"))


static func init(_plugin_path: String):
	pass


static func post_init(_plugin_path: String):
	pass
