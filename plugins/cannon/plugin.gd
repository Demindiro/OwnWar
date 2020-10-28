const PLUGIN_ID := "cannon"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {"weapon_manager": Vector3(0, 0, 1)}


static func pre_init(_plugin_path: String):
	Block.add_block(preload("160mm/80mm_cannon.tres"))
	Block.add_block(preload("35mm/35mm_cannon.tres"))


static func init(_plugin_path: String):
	var Munition = Plugins.plugins["weapon_manager"].Munition
	var material_id: int = Matter.name_to_id.get("material", -1)
	if material_id < 0:
		print("Matter 'material' not found!")
		return
	Munition.add_munition(preload("160mm/shell_160mm.tres"))
	Munition.add_munition(preload("35mm/shell_35mm.tres"))


static func post_init(_plugin_path: String):
	pass
