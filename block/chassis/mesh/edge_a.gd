extends "res://block/chassis/mesh/mesh.gd"


func _init():
	name = "edge_a"


func generate(transform, x, y, z, u, v):
	var vertices = PoolVector3Array()
	var normals = PoolVector3Array()
	
	var normal_x = (x - u).cross(v - x).normalized()
	var normal_e0 = (z - y).cross(u - z).normalized()
	var normal_e1 = (v - y).cross(v - u).normalized()
	
	for vertex in [Vector3.ZERO, y, z]: # -X
		vertices.append(vertex)
		normals.append(Vector3.LEFT)
	for vertex in [x, u, v]: # +X
		vertices.append(vertex)
		normals.append(normal_x)
	for vertex in [Vector3.ZERO, z, x, x, z, u]: # -Y
		vertices.append(vertex)
		normals.append(Vector3.DOWN)
	for vertex in [Vector3.ZERO, x, y, y, x, v]: # -Z
		vertices.append(vertex)
		normals.append(Vector3.FORWARD)
	for vertex in [z, y, u]: # E (0)
		vertices.append(vertex)
		normals.append(normal_e0)
	for vertex in [v, u, y]: # E (1)
		vertices.append(vertex)
		normals.append(normal_e1)

	var array = []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = vertices
	array[Mesh.ARRAY_NORMAL] = normals
	var result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	return result
