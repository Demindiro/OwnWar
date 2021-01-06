extends ArrayMesh


class SubMesh:
	var array: Array
	var coordinate: Array

	func _init(p_array: Array, p_coordinate: Array):
		array = p_array
		coordinate = p_coordinate


var dirty := false
var _material_to_meshes_map := {}
var _material_to_dirty_map := {}
var _remove_list_positions := []


func add_block(block: OwnWar_Block, color: Color, coordinate: Array, rotation: int) -> void:
	assert(coordinate[0] is int)
	assert(coordinate[1] is int)
	assert(coordinate[2] is int)
	var mesh := block.mesh
	if mesh == null:
		return
	add_mesh(mesh, color, coordinate, rotation)


func add_mesh(mesh: Mesh, color: Color, coordinate: Array, rotation: int) -> void:
	assert(coordinate[0] is int)
	assert(coordinate[1] is int)
	assert(coordinate[2] is int)
	for i in range(mesh.get_surface_count()):
#		var material := mesh.surface_get_material(i)
#		var material := MaterialCache.get_material(color)
		var material := MaterialCache.get_material(color)
		var array := _get_mesh_arrays(mesh, i)
		_transform_array(array, coordinate, rotation)
		_dedup_array(array)
		var sm := SubMesh.new(array, coordinate)
		var sm_array: Array = _material_to_meshes_map.get(material, [])
		if len(sm_array) > 0:
			sm_array.append(sm)
		else:
			_material_to_meshes_map[material] = [sm]
		_material_to_dirty_map[material] = true
		dirty = true


func remove_block(coordinate: Array) -> void:
	assert(coordinate[0] is int)
	assert(coordinate[1] is int)
	assert(coordinate[2] is int)
	_remove_list_positions.append(coordinate)
	dirty = true


func generate() -> void:
	var remove_materials := []
	for material in _material_to_meshes_map:
		var list: Array = _material_to_meshes_map[material]
		# warning-ignore:unsafe_cast
		var array_dirty: bool = _material_to_dirty_map[material]
		var i := 0
		while i < len(list):
			var sm: SubMesh = list[i]
			var coordinate := sm.coordinate
			if coordinate in _remove_list_positions:
				list.remove(i)
				i -= 1
				array_dirty = true
			i += 1
		if len(list) == 0:
			remove_materials.append(material)
		elif array_dirty:
			_remove_surface_array(material)
			var array := []
			array.resize(ARRAY_MAX)
			array[ARRAY_VERTEX] = PoolVector3Array()
			array[ARRAY_NORMAL] = PoolVector3Array()
			array[ARRAY_INDEX] = PoolIntArray()
			i = 0
			while i < len(list):
				var sm: SubMesh = list[i]
				var offset = len(array[ARRAY_VERTEX])
				var index_array = sm.array[ARRAY_INDEX]
				for j in range(len(index_array)):
					index_array[j] += offset
				array[ARRAY_VERTEX] += sm.array[ARRAY_VERTEX]
				array[ARRAY_NORMAL] += sm.array[ARRAY_NORMAL]
				array[ARRAY_INDEX] += index_array
				i += 1
			if len(array[ARRAY_VERTEX]) > 0:
				var index := get_surface_count()
				add_surface_from_arrays(PRIMITIVE_TRIANGLES, array)
				surface_set_material(index, material)
			else:
				remove_materials.append(material)
	for material in remove_materials:
# warning-ignore:return_value_discarded
		_material_to_meshes_map.erase(material)
# warning-ignore:return_value_discarded
		_material_to_dirty_map.erase(material)
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


func _remove_surface_array(p_material: Material):
	for i in range(get_surface_count()):
		var material := surface_get_material(i)
		if material == p_material:
			surface_remove(i)
			break


static func _get_mesh_arrays(mesh: Mesh, index: int) -> Array:
	var mesh_array = mesh.surface_get_arrays(index)
	if mesh_array[Mesh.ARRAY_INDEX] == null:
		var length = len(mesh_array[Mesh.ARRAY_VERTEX])
		mesh_array[Mesh.ARRAY_INDEX] = PoolIntArray(range(length))
	return mesh_array


static func _transform_array(array: Array, coordinate: Array, rotation: int) -> void:
	var basis := OwnWar_Block.rotation_to_basis(rotation)
	var position := Vector3(coordinate[0], coordinate[1], coordinate[2]) + Vector3.ONE / 2
	var transform := Transform(basis, position * OwnWar_Block.BLOCK_SCALE)
	for i in range(len(array[Mesh.ARRAY_VERTEX])):
		array[Mesh.ARRAY_VERTEX][i] = transform * array[Mesh.ARRAY_VERTEX][i]
		array[Mesh.ARRAY_NORMAL][i] = basis * array[Mesh.ARRAY_NORMAL][i]


static func _dedup_array(array: Array):
	array[Mesh.ARRAY_VERTEX] = ObjectCache.dedup_immutable(array[Mesh.ARRAY_VERTEX])
	array[Mesh.ARRAY_NORMAL] = ObjectCache.dedup_immutable(array[Mesh.ARRAY_NORMAL])
	array[Mesh.ARRAY_INDEX] = ObjectCache.dedup_immutable(array[Mesh.ARRAY_INDEX])
