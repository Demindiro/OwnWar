extends OwnWar.Plugin.Interface


const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {}


func pre_init():
	OwnWar.Block.add_block(preload("mainframe.tres"))
	OwnWar.Vehicle.add_manager("mainframe", preload("mainframe_manager.gd"))
