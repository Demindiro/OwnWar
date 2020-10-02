extends "res://block/chassis/generate_shapes.gd"


var _index_x: int
var _index_y: int
var _index_z: int


func _init():
	._set_indices_count(3)


func start(segments: int, scale: Vector3, offset: Vector3):
	.start(segments, scale, offset)
	_index_x = segments
	_index_y = segments
	_index_z = segments + 1
	finished = false
	step()


func step():
	_index_z -= 1
	if _index_z == 0:
		_index_z = segments
		_index_y -= 1
		if _index_y == 0:
			_index_y = segments
			_index_x -= 1
			if _index_x == 0:
				finished = true
				return
			
	var x  = 1.0 * _index_x / segments
	var y = 1.0 * _index_y / segments
	var z = 1.0 * _index_z / segments
	
	var vertices = PoolVector3Array()
	var normals = PoolVector3Array()
	
	for vertex in [Vector3(0, 0, z), Vector3(0, y, 0), Vector3(x, 0, 0)]: # Side
		vertices.append(vertex)
		normals.append(Vector3(x, y, z).normalized())
	for vertex in [Vector3.ZERO, Vector3(0, y, 0), Vector3(0, 0, z)]: # X
		vertices.append(vertex)
		normals.append(Vector3.LEFT)
	for vertex in [Vector3.ZERO, Vector3(0, 0, z), Vector3(x, 0, 0)]: # Y
		vertices.append(vertex)
		normals.append(Vector3.DOWN)
	for vertex in [Vector3.ZERO, Vector3(x, 0, 0), Vector3(0, y, 0)]: # Z
		vertices.append(vertex)
		normals.append(Vector3.FORWARD)
	
	var array = []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = vertices
	array[Mesh.ARRAY_NORMAL] = normals
	result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)



func get_name():
	var array = [segments, _index_x, _index_y, _index_z]
	var lowest_value = min(min(array[0], array[1]), min(array[2], array[3]))
	for divisor in range(lowest_value, 0, -1):
		var found = true
		for value in array:
			if value % lowest_value != 0:
				found = false
				break
		if found:
			for i in len(array):
				array[i] /= divisor
	return "corner_%d_%d-%d-%d" % array


func get_indices():
	return [_index_x, _index_y, _index_z]
