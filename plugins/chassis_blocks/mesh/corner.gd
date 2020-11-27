extends "mesh.gd"


func _init():
	name = "corner"


func generate(transform, x, y, z, flip_faces = false):
	var vertices = PoolVector3Array()
#	var normals = PoolVector3Array()

	var o = transform * Vector3.ZERO
	x = transform * x
	y = transform * y
	z = transform * z

	for vertex in [z, y, x]: # E
		vertices.append(vertex)
	for vertex in [o, y, z]: # X
		vertices.append(vertex)
	for vertex in [o, z, x]: # Y
		vertices.append(vertex)
	for vertex in [o, x, y]: # Z
		vertices.append(vertex)

	if flip_faces:
		vertices.invert()

	var array = []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = vertices
	array[Mesh.ARRAY_NORMAL] = get_normals(vertices) #normals
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	return mesh
