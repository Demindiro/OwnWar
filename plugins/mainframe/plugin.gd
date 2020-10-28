const PLUGIN_ID := "mainframe"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)


static func pre_init(_plugin_path: String):
	Block.add_block(preload("mainframe.tres"))
	Vehicle.add_manager("mainframe", preload("mainframe_manager.gd"))


static func init(_plugin_path: String):
	pass


static func post_init(_plugin_path: String):
	pass
