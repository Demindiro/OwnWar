extends PluginInterface


const PLUGIN_VERSION = Vector3(0, 0, 1)
const MIN_VERSION = Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {"basic_manufacturing": Vector3(0, 0, 1)}


func pre_init():
	Unit.add_unit("worker", preload("drone.tscn"))
