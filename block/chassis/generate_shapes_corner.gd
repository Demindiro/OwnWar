extends "res://block/chassis/generate_shapes.gd"


var _index_x: int
var _index_y: int
var _index_z: int


func _init():
	name = "corner"
	._set_indices_count(3)


func start(segments: int, scale: Vector3, offset: Vector3):
	.start(segments, scale, offset)
	step()


func step():
	.step()
	
	var fractions = PoolRealArray()
	for index in indices:
		fractions.append(float(index) / float(segments))
		
	var x = Vector3(fractions[0], 0, 0)
	var y = Vector3(0, fractions[1], 0)
	var z = Vector3(0, 0, fractions[2])
	
	var vertices = PoolVector3Array()
	var normals = PoolVector3Array()
	
	for vertex in [z, y, x]: # Side
		vertices.append(vertex)
		normals.append(Vector3.ONE.normalized())
	for vertex in [Vector3.ZERO, y, z]: # X
		vertices.append(vertex)
		normals.append(Vector3.LEFT)
	for vertex in [Vector3.ZERO, z, x]: # Y
		vertices.append(vertex)
		normals.append(Vector3.DOWN)
	for vertex in [Vector3.ZERO, x, y]: # Z
		vertices.append(vertex)
		normals.append(Vector3.FORWARD)
	
	var array = []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = vertices
	array[Mesh.ARRAY_NORMAL] = normals
	result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)


func get_indices():
	return [_index_x, _index_y, _index_z]
