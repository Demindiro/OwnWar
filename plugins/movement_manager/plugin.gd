const PLUGIN_ID := "movement_manager"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)


func _init():
	Vehicle.add_manager("movement", preload("movement_manager.gd"))
