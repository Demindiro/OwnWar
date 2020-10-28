const PLUGIN_ID = "tutorial_map"
const PLUGIN_VERSION = Vector3(0, 0, 1)
const MIN_VERSION = Vector3(0, 12, 0)


static func pre_init(_plugin_path: String):
	Maps.add_map("tutorial", _plugin_path.plus_file("hill.tscn"))


static func init(_plugin_path: String):
	pass


static func post_init(_plugin_path: String):
	pass
