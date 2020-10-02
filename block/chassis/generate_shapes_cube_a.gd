extends "res://block/chassis/generate_shapes.gd"


func _init():
	name = "cube_a"
	._set_indices_count(12)


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
	var u = Vector3(0, fractions[3], fractions[4])
	var v = Vector3(fractions[5], 0, fractions[6])
	var w = Vector3(fractions[7], fractions[8], 0)
	var a = Vector3(fractions[9], fractions[10], fractions[11])
	
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
	result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
