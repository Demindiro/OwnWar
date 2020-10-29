extends Spatial


# warning-ignore:unused_class_variable
var Munition = Plugin.get_plugin("weapon_manager").Munition setget _assert_noset
var weapon_manager setget _assert_noset


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle, _meta) -> void:
	weapon_manager = vehicle.get_manager("weapon")
	weapon_manager.add_weapon(self)


func fire() -> bool:
	return false


func aim_at(_position: Vector3) -> void:
	pass


func set_angle(_angle: float) -> void:
	pass


func _assert_noset(_v) -> void:
	assert(false)
