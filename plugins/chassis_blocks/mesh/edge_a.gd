extends "mesh.gd"


func _init():
	name = "edge_a"


func generate(transform, x, y, z, u, v, flip_faces := false):
	var vertices = PoolVector3Array()

	var o = transform * Vector3.ZERO
	x = transform * x
	y = transform * y
	z = transform * z
	u = transform * u
	v = transform * v

	for vertex in [o, y, z]: # -X
		vertices.append(vertex)
	for vertex in [x, u, v]: # +X
		vertices.append(vertex)
	for vertex in [o, z, x, x, z, u]: # -Y
		vertices.append(vertex)
	for vertex in [o, x, y, y, x, v]: # -Z
		vertices.append(vertex)
	for vertex in [z, y, u]: # E (0)
		vertices.append(vertex)
	for vertex in [v, u, y]: # E (1)
		vertices.append(vertex)

	if flip_faces:
		vertices = vertices.inverted()

	var array = []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = vertices
	array[Mesh.ARRAY_NORMAL] = get_normals(vertices)
	var result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	return result
