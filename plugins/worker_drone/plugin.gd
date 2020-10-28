const PLUGIN_ID = "worker_drone"
const PLUGIN_VERSION = Vector3(0, 0, 1)
const MIN_VERSION = Vector3(0, 12, 0)


func _init():
	Unit.add_unit("drone", preload("drone.tscn"))
