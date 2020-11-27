extends "mesh.gd"


func _init():
	name = "inverse_corner"


func generate(transform, x, y, z, u, v, w, flip_faces := false):
	var vertices = PoolVector3Array()

	var o = transform * Vector3.ZERO
	x = transform * x
	y = transform * y
	z = transform * z
	u = transform * u
	v = transform * v
	w = transform * w

	for vertex in [o, y, u, o, u, z]: # -X
		vertices.append(vertex)
	for vertex in [o, v, x, o, z, v]: # -Y
		vertices.append(vertex)
	for vertex in [o, x, w, o, w, y]: # -Z
		vertices.append(vertex)
	for vertex in [x, v, w]: # +X
		vertices.append(vertex)
	for vertex in [y, w, u]: # +Y
		vertices.append(vertex)
	for vertex in [z, u, v]: # +Z
		vertices.append(vertex)
	for vertex in [u, w, v]: # E
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
