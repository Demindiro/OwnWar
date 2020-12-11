extends PluginInterface


const PLUGIN_ID := "engine"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {"power_manager": Vector3(0, 0, 1)}


func pre_init():
	Block.add_block(preload("engine.tres"))
	Block.add_block(preload("fuel_tank.tres"))
