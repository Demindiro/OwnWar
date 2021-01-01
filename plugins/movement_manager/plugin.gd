extends OwnWar.Plugin.Interface


const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {}


func pre_init():
	OwnWar.Vehicle.add_manager("movement", preload("movement_manager.gd"))
