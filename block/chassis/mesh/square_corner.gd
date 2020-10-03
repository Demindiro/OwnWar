extends "res://block/chassis/mesh/mesh.gd"


func _init():
	name = "square_corner"


func generate(transform, x, y, z, w):
	var vertices = PoolVector3Array()
	var normals = PoolVector3Array()
	
	for vertex in [y, x, w]: # Side (X)
		vertices.append(vertex)
		normals.append((x - w).cross(y - w).normalized())
	for vertex in [z, y, w]: # Side (Z)
		vertices.append(vertex)
		normals.append((z - w).cross(w - y).normalized())
	for vertex in [Vector3.ZERO, w, x]: # Y (X)
		vertices.append(vertex)
		normals.append(Vector3.DOWN)
	for vertex in [Vector3.ZERO, z, w]: # Y (Z)
		vertices.append(vertex)
		normals.append(Vector3.DOWN)
	for vertex in [Vector3.ZERO, y, z]: # X
		vertices.append(vertex)
		normals.append(Vector3.LEFT)
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
