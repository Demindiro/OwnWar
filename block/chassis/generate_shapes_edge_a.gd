extends "res://block/chassis/generate_shapes.gd"


func _init():
	name = "edge_a"
	._set_indices_count(7)


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
	var u = Vector3(fractions[3], 0, fractions[4])
	var v = Vector3(fractions[5], fractions[6], 0)
	
	var vertices = PoolVector3Array()
	var normals = PoolVector3Array()
	
	var normal_x = (x - u).cross(v - x).normalized()
	var normal_e0 = (z - y).cross(u - z).normalized()
	var normal_e1 = (v - y).cross(v - u).normalized()
	
	for vertex in [Vector3.ZERO, y, z]: # -X
		vertices.append(vertex)
		normals.append(Vector3.LEFT)
	for vertex in [x, u, v]: # +X
		vertices.append(vertex)
		normals.append(normal_x)
	for vertex in [Vector3.ZERO, z, x, x, z, u]: # -Y
		vertices.append(vertex)
		normals.append(Vector3.DOWN)
	for vertex in [Vector3.ZERO, x, y, y, x, v]: # -Z
		vertices.append(vertex)
		normals.append(Vector3.FORWARD)
	for vertex in [z, y, u]: # E (0)
		vertices.append(vertex)
		normals.append(normal_e0)
	for vertex in [v, u, y]: # E (1)
		vertices.append(vertex)
		normals.append(normal_e1)

	
	var array = []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = vertices
	array[Mesh.ARRAY_NORMAL] = normals
	result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
