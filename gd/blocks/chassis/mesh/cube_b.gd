extends "mesh.gd"


func _init():
	name = "cube_b"


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
	for vertex in [x, v, w]: # +X (L)
		vertices.append(vertex)
	for vertex in [y, w, u]: # +Y (L)
		vertices.append(vertex)
	for vertex in [z, u, v]: # +Z (L)
		vertices.append(vertex)
	for vertex in [a, w, v]: # +X (L)
		vertices.append(vertex)
	for vertex in [a, u, w]: # +Y (L)
		vertices.append(vertex)
	for vertex in [a, v, u]: # +Z (L)
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
