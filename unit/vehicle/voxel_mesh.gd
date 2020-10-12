class_name VoxelMesh
extends ArrayMesh


func add_block(block: Block, color: Color, coordinate: Array, rotation: int) -> void:
	var mesh := block.mesh
	if mesh == null:
		return
	for i in range(mesh.get_surface_count()):
#		var material := mesh.surface_get_material(i)
		var material := MaterialCache.get_material(color)
		var index := _get_compatible_surface_index(material)
		var own_array
		if index < 0:
			own_array = _get_mesh_arrays(mesh, i, 0)
			_transform_array(own_array, coordinate, rotation)
		else:
			own_array = surface_get_arrays(index)
			var offset := len(own_array[Mesh.ARRAY_VERTEX])
			var array := _get_mesh_arrays(mesh, i, offset)
			_transform_array(array, coordinate, rotation)
			for j in range(Mesh.ARRAY_MAX):
				if array[j] != null:
					own_array[j] += array[j]
				else:
					assert(own_array[j] == null)
			surface_remove(index)
		var new_index := get_surface_count()
		add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, own_array)
		surface_set_material(new_index, material)


func _get_compatible_surface_index(p_material: Material) -> int:
	for i in range(get_surface_count()):
		var material := surface_get_material(i)
		if material != p_material:
			continue
		return i
#		var own_surface := surface_get_arrays(i)
	return -1


static func _get_mesh_arrays(mesh: Mesh, index: int, offset: int) -> Array:
	var mesh_array = mesh.surface_get_arrays(index)
	if mesh_array[Mesh.ARRAY_INDEX] == null:
		var length = len(mesh_array[Mesh.ARRAY_VERTEX])
		var indice_array = range(offset, length + offset, 1)
		mesh_array[Mesh.ARRAY_INDEX] = PoolIntArray(indice_array)
	return mesh_array


static func _transform_array(array: Array, coordinate: Array, rotation: int) -> void:
	var basis := Block.rotation_to_basis(rotation)
	var transform := Transform(basis,
			Vector3(coordinate[0], coordinate[1], coordinate[2]) * Global.BLOCK_SCALE)
	for i in range(len(array[Mesh.ARRAY_VERTEX])):
		array[Mesh.ARRAY_VERTEX][i] = transform * array[Mesh.ARRAY_VERTEX][i]
		array[Mesh.ARRAY_NORMAL][i] = basis * array[Mesh.ARRAY_NORMAL][i]
