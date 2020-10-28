const PLUGIN_ID := "basic_manufacturing"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {}


static func pre_init(_plugin_path: String):
	Unit.add_unit("storage_pod", preload("storage_pod.tscn"))
	Unit.add_unit("munitions_factory", preload("munitions_factory.tscn"))
	Unit.add_unit("spawn_platform", preload("spawn_platform.tscn"))
	Unit.add_unit("refinery", preload("refinery.tscn"))
	Unit.add_unit("roboport", preload("roboport.tscn"))
	Unit.add_unit("storage_pod_ghost", preload("storage_pod_ghost.tscn"))
	Unit.add_unit("munitions_factory_ghost", preload("munitions_factory_ghost.tscn"))
	Unit.add_unit("spawn_platform_ghost", preload("spawn_platform_ghost.tscn"))
	Unit.add_unit("refinery_ghost", preload("refinery_ghost.tscn"))
	Unit.add_unit("roboport_ghost", preload("roboport_ghost.tscn"))
	Unit.add_unit("roboport_drone", preload("roboport_drone.tscn"))


static func init(_plugin_path: String):
	pass


static func post_init(_plugin_path: String):
	pass
