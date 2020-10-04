extends "res://block/chassis/mesh/mesh.gd"


func _init():
	name = "inverse_corner"


func generate(transform, x, y, z, u, v, w):
	var vertices = PoolVector3Array()
	var normals = PoolVector3Array()
	
	x = transform * x
	y = transform * y
	z = transform * z
	u = transform * u
	v = transform * v
	w = transform * w
	
	var normal_x = (v - x).cross(x - w).normalized()
	var normal_y = (u - y).cross(w - y).normalized()
	var normal_z = (u - z).cross(z - v).normalized()
	var normal_e = (u - v).cross(u - w).normalized()
	
	for vertex in [Vector3.ZERO, y, u, Vector3.ZERO, u, z]: # -X
		vertices.append(vertex)
		normals.append(Vector3.LEFT)
	for vertex in [Vector3.ZERO, v, x, Vector3.ZERO, z, v]: # -Y
		vertices.append(vertex)
		normals.append(Vector3.DOWN)
	for vertex in [Vector3.ZERO, x, w, Vector3.ZERO, w, y]: # -Z
		vertices.append(vertex)
		normals.append(Vector3.FORWARD)
	for vertex in [x, v, w]: # +X 
		vertices.append(vertex)
		normals.append(normal_x)
	for vertex in [y, w, u]: # +Y
		vertices.append(vertex)
		normals.append(normal_y)
	for vertex in [z, u, v]: # +Z
		vertices.append(vertex)
		normals.append(normal_z)
	for vertex in [u, w, v]: # E
		vertices.append(vertex)
		normals.append(normal_e)
	
	var array = []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = vertices
	array[Mesh.ARRAY_NORMAL] = normals
	var result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	return result
