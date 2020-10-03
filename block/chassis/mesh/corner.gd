extends "res://block/chassis/mesh/mesh.gd"


func _init():
	name = "corner"


func generate(transform, x, y, z):
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
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	return mesh
