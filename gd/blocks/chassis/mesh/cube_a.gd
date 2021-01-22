extends "mesh.gd"


func _init():
	name = "cube_a"


func generate(transform, x, y, z, u, v, w, a, flip_faces := false):
	var vertices = PoolVector3Array()

	var o = transform * Vector3.ZERO
	x = transform * x
	y = transform * y
	z = transform * z
	u = transform * u
	v = transform * v
	w = transform * w
	a = transform * a

	for vertex in [o, y, u, o, u, z]: # -X
		vertices.append(vertex)
	for vertex in [o, v, x, o, z, v]: # -Y
		vertices.append(vertex)
	for vertex in [o, x, w, o, w, y]: # -Z
		vertices.append(vertex)
	for vertex in [a, x, v]: # +X (L)
		vertices.append(vertex)
	for vertex in [a, w, x]: # +X (H)
		vertices.append(vertex)
	for vertex in [a, u, y]: # +Y (L)
		vertices.append(vertex)
	for vertex in [a, y, w]: # +Y (H)
		vertices.append(vertex)
	for vertex in [a, z, u]: # +Z (L)
		vertices.append(vertex)
	for vertex in [a, v, z]: # +Z (H)
		vertices.append(vertex)

	if flip_faces:
		vertices.invert()

	var array = []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = vertices
	array[Mesh.ARRAY_NORMAL] = get_normals(vertices)
	var result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	return result
