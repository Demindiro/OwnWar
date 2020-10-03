extends "res://block/chassis/mesh/mesh.gd"


func generate(transform, x, y, z, u, v, w, a):
	var vertices = PoolVector3Array()
	var normals = PoolVector3Array()
	
	var normal_xl = (a - x).cross(v - a).normalized()
	var normal_xh = (a - x).cross(a - w).normalized()
	var normal_yl = (a - y).cross(a - u).normalized()
	var normal_yh = (a - y).cross(w - a).normalized()
	var normal_zl = (a - z).cross(u - a).normalized()
	var normal_zh = (a - z).cross(a - v).normalized()
	
	for vertex in [Vector3.ZERO, y, u, Vector3.ZERO, u, z]: # -X
		vertices.append(vertex)
		normals.append(Vector3.LEFT)
	for vertex in [Vector3.ZERO, v, x, Vector3.ZERO, z, v]: # -Y
		vertices.append(vertex)
		normals.append(Vector3.DOWN)
	for vertex in [Vector3.ZERO, x, w, Vector3.ZERO, w, y]: # -Z
		vertices.append(vertex)
		normals.append(Vector3.FORWARD)
	for vertex in [a, x, v]: # +X (L)
		vertices.append(vertex)
		normals.append(normal_xl)
	for vertex in [a, w, x]: # +X (H)
		vertices.append(vertex)
		normals.append(normal_xh)
	for vertex in [a, u, y]: # +Y (L)
		vertices.append(vertex)
		normals.append(normal_yl)
	for vertex in [a, y, w]: # +Y (H)
		vertices.append(vertex)
		normals.append(normal_yh)
	for vertex in [a, z, u]: # +Z (L)
		vertices.append(vertex)
		normals.append(normal_zl)
	for vertex in [a, v, z]: # +Z (H)
		vertices.append(vertex)
		normals.append(normal_zh)
		
	var array = []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = vertices
	array[Mesh.ARRAY_NORMAL] = normals
	var result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	return result
