extends MeshInstance


onready var _origin: Spatial = $Origin


func set_grid_size(size: int) -> void:
	_origin.translation = -Vector3(1, 0, 1) * (size / 2.0 - 0.5) + Vector3.UP / 2
	translation = -_origin.translation + Vector3(0.5, 0.5, 0.5)
	# TODO set material params


func enable_mirror(enable: bool) -> void:
	material_override.set_shader_param("enable_mirror", enable)
