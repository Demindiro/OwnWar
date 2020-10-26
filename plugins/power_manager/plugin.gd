const PLUGIN_ID := "power_manager"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)


func _init():
	Vehicle.add_manager("power", preload("power_manager.gd"))
