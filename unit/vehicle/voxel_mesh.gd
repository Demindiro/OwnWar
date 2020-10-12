class_name VoxelMesh
extends ArrayMesh


var dirty := false
var _material_to_meshes_map := {}
var _remove_list_positions := []


func add_block(block: Block, color: Color, coordinate: Array, rotation: int) -> void:
	var mesh := block.mesh
	if mesh == null:
		return
	for i in range(mesh.get_surface_count()):
#		var material := mesh.surface_get_material(i)
		var material := MaterialCache.get_material(color)
		var array = _get_mesh_arrays(mesh, i)
		_transform_array(array, coordinate, rotation)
		_dedup_array(array)
		if material in _material_to_meshes_map:
			_material_to_meshes_map[material].append([array, coordinate])
		else:
			_material_to_meshes_map[material] = [[array, coordinate]]
		dirty = true


func remove_block(coordinate: Array) -> void:
	_remove_list_positions.append(coordinate)
	dirty = true


func generate() -> void:
	var remove_materials := []
	for material in _material_to_meshes_map:
		var list := _material_to_meshes_map[material] as Array
		var array := []
		array.resize(ARRAY_MAX)
		array[ARRAY_VERTEX] = PoolVector3Array()
		array[ARRAY_NORMAL] = PoolVector3Array()
		array[ARRAY_INDEX] = PoolIntArray()
		for i in range(len(list)):
			var coordinate := list[i][1] as Array
			if coordinate in _remove_list_positions:
				list.remove(i)
				continue
			var block_array := list[i][0] as Array
			var offset = len(array[ARRAY_VERTEX])
			var index_array = block_array[ARRAY_INDEX]
			for j in range(len(index_array)):
				index_array[j] += offset
			array[ARRAY_VERTEX] += block_array[ARRAY_VERTEX]
			array[ARRAY_NORMAL] += block_array[ARRAY_NORMAL]
			array[ARRAY_INDEX] += index_array
		if len(array[ARRAY_VERTEX]) > 0:
			var index := get_surface_count()
			add_surface_from_arrays(PRIMITIVE_TRIANGLES, array)
			surface_set_material(index, material)
		else:
			remove_materials.append(material)
	for material in remove_materials:
		_material_to_meshes_map.erase(material)
	_remove_list_positions = []
	dirty = false


func _get_compatible_surface_index(p_material: Material) -> int:
	for i in range(get_surface_count()):
		var material := surface_get_material(i)
		if material != p_material:
			continue
		return i
#		var own_surface := surface_get_arrays(i)
	return -1


static func _get_mesh_arrays(mesh: Mesh, index: int) -> Array:
	var mesh_array = mesh.surface_get_arrays(index)
	if mesh_array[Mesh.ARRAY_INDEX] == null:
		var length = len(mesh_array[Mesh.ARRAY_VERTEX])
		mesh_array[Mesh.ARRAY_INDEX] = PoolIntArray(range(length))
	return mesh_array


static func _transform_array(array: Array, coordinate: Array, rotation: int) -> void:
	var basis := Block.rotation_to_basis(rotation)
	var position := Vector3(coordinate[0], coordinate[1], coordinate[2]) + Vector3.ONE / 2
	var transform := Transform(basis, position * Global.BLOCK_SCALE)
	for i in range(len(array[Mesh.ARRAY_VERTEX])):
		array[Mesh.ARRAY_VERTEX][i] = transform * array[Mesh.ARRAY_VERTEX][i]
		array[Mesh.ARRAY_NORMAL][i] = basis * array[Mesh.ARRAY_NORMAL][i]


static func _dedup_array(array: Array):
	array[Mesh.ARRAY_VERTEX] = ObjectCache.dedup_immutable(array[Mesh.ARRAY_VERTEX])
	array[Mesh.ARRAY_NORMAL] = ObjectCache.dedup_immutable(array[Mesh.ARRAY_NORMAL])
	array[Mesh.ARRAY_INDEX] = ObjectCache.dedup_immutable(array[Mesh.ARRAY_INDEX])
