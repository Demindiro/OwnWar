extends "res://block/chassis/mesh/mesh.gd"


func _init():
	name = "cube_b"


func generate(transform, x, y, z, u, v, w, a):
	var vertices = PoolVector3Array()
	var normals = PoolVector3Array()
	
	var normal_xl = (x - v).cross(w - x).normalized()
	var normal_yl = (y - u).cross(y - w).normalized()
	var normal_zl = (z - u).cross(v - z).normalized()
	var normal_xh = (a - v).cross(a - x).normalized()
	var normal_yh = (a - u).cross(w - a).normalized()
	var normal_zh = (a - u).cross(a - z).normalized()
	
	for vertex in [Vector3.ZERO, y, u, Vector3.ZERO, u, z]: # -X
		vertices.append(vertex)
		normals.append(Vector3.LEFT)
	for vertex in [Vector3.ZERO, v, x, Vector3.ZERO, z, v]: # -Y
		vertices.append(vertex)
		normals.append(Vector3.DOWN)
	for vertex in [Vector3.ZERO, x, w, Vector3.ZERO, w, y]: # -Z
		vertices.append(vertex)
		normals.append(Vector3.FORWARD)
	for vertex in [x, v, w]: # +X (L)
		vertices.append(vertex)
		normals.append(normal_xl)
	for vertex in [y, w, u]: # +Y (L)
		vertices.append(vertex)
		normals.append(normal_yl)
	for vertex in [z, u, v]: # +Z (L)
		vertices.append(vertex)
		normals.append(normal_zl)
	for vertex in [a, w, v]: # +X (L)
		vertices.append(vertex)
		normals.append(normal_xh)
	for vertex in [a, u, w]: # +Y (L)
		vertices.append(vertex)
		normals.append(normal_yh)
	for vertex in [a, v, u]: # +Z (L)
		vertices.append(vertex)
		normals.append(normal_zh)
		
	var array = []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = vertices
	array[Mesh.ARRAY_NORMAL] = normals
	var result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	return result
