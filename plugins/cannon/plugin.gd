extends OwnWar.Plugin.Interface


const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {"weapon_manager": Vector3(0, 0, 1)}


func pre_init():
	OwnWar.Block.add_block(preload("160mm/80mm_cannon.tres"))
	OwnWar.Block.add_block(preload("35mm/35mm_cannon.tres"))
	var Munition := preload("res://plugins/weapon_manager/plugin.gd").Munition
# warning-ignore:return_value_discarded
	Munition.add_munition(preload("160mm/shell_160mm.tres"))
# warning-ignore:return_value_discarded
	Munition.add_munition(preload("35mm/shell_35mm.tres"))
