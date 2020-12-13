extends PluginInterface


const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {
		"movement_manager": Vector3(0, 0, 1),
		"power_manager": Vector3(0, 0, 1),
	}


func pre_init():
	OwnWar.Block.add_block(preload("wheel.tres"))
