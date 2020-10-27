const PLUGIN_ID = "tutorial_map"
const PLUGIN_VERSION = Vector3(0, 0, 1)
const MIN_VERSION = Vector3(0, 12, 0)


func _init():
	var dir: String = get_script().get_path().get_base_dir()
	Maps.add_map("tutorial", dir.plus_file("hill.tscn"))
