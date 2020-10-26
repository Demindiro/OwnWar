const PLUGIN_ID := "mainframe"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)


func _init():
	var dir: String = get_script().get_path().get_base_dir()
	Block.add_block(preload("mainframe.tres"))
	Vehicle.add_manager("mainframe", preload("mainframe_manager.gd"))
