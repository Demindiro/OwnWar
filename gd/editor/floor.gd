extends MeshInstance


onready var _origin: Spatial = $Origin

var mesh_to_node := {}


func set_grid_size(size: int) -> void:
	_origin.translation = -Vector3(1, 0, 1) * (size / 2.0 - 0.5) + Vector3.UP / 2
	translation = -_origin.translation + Vector3(0.5, 0.5, 0.5)
	# TODO set material params


func enable_mirror(enable: bool) -> void:
	material_override.set_shader_param("enable_mirror", enable)


func add_voxel_mesh(mesh: Mesh) -> void:
	var n := MeshInstance.new();
	n.mesh = mesh
	n.name = "Voxel mesh"
	n.scale = Vector3(4, 4, 4)
	n.translation = Vector3(0.5, 0.5, 0.5)
	add_child(n)
	mesh_to_node[mesh] = n


func remove_voxel_mesh(mesh: Mesh) -> void:
	mesh_to_node[mesh].queue_free()
	mesh_to_node.erase(mesh)
