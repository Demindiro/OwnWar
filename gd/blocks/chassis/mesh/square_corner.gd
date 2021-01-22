extends "mesh.gd"


func _init():
	name = "square_corner"


func generate(transform, x, y, z, w, flip_faces = false):
	var vertices = PoolVector3Array()

	var o = transform * Vector3.ZERO
	x = transform * x
	y = transform * y
	z = transform * z
	w = transform * w

	for vertex in [y, x, w]: # Side (X)
		vertices.append(vertex)
	for vertex in [z, y, w]: # Side (Z)
		vertices.append(vertex)
	for vertex in [o, w, x]: # Y (X)
		vertices.append(vertex)
	for vertex in [o, z, w]: # Y (Z)
		vertices.append(vertex)
	for vertex in [o, y, z]: # X
		vertices.append(vertex)
	for vertex in [o, x, y]: # Z
		vertices.append(vertex)

	if flip_faces:
		vertices.invert()

	var array = []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = vertices
	array[Mesh.ARRAY_NORMAL] = get_normals(vertices)
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	return mesh
