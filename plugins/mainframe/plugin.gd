const PLUGIN_ID := "mainframe"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {}


static func pre_init(_plugin_path: String):
	Block.add_block(preload("mainframe.tres"))
	Vehicle.add_manager("mainframe", preload("mainframe_manager.gd"))


static func init(_plugin_path: String):
	pass


static func post_init(_plugin_path: String):
	pass


static func save_game(_game_master: GameMaster) -> Dictionary:
	return {}


static func load_game(_game_master: GameMaster, _data: Dictionary) -> void:
	pass
