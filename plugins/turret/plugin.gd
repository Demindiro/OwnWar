const PLUGIN_ID := "turret"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {
		"weapon_manager": Vector3(0, 0, 1),
	}


static func pre_init(_plugin_path: String):
	Block.add_block(preload("connector.tres"))


static func init(_plugin_path: String):
	pass


static func post_init(_plugin_path: String):
	pass


static func save_game(game_master: GameMaster) -> Dictionary:
	return {}


static func load_game(game_master: GameMaster, data: Dictionary) -> void:
	pass
