extends "res://block/chassis/generate_shapes.gd"


var indices: PoolIntArray
var name = "square_corner"


func start(segments: int, scale: Vector3, offset: Vector3):
	.start(segments, scale, offset)
	indices = PoolIntArray()
	for i in range(5):
		indices.append(segments)
	indices[0] += 1
	finished = false
	step()


func step():
	for i in len(indices):
		indices[i] -= 1
		if indices[i] == 0:
			if i == len(indices) - 1:
				finished = true
				return
			indices[i] = segments
		else:
			break
	var fractions = PoolRealArray()
	for index in indices:
		fractions.append(float(index) / float(segments))
		
	var x = Vector3(fractions[0], 0, 0)
	var y = Vector3(0, fractions[1], 0)
	var z = Vector3(0, 0, fractions[2])
	var w = Vector3(fractions[3], 0, fractions[4])
	
	var vertices = PoolVector3Array()
	var normals = PoolVector3Array()
	
	for vertex in [y, x, w]: # Side (X)
		vertices.append(vertex)
		normals.append((x - w).cross(y - w).normalized())
	for vertex in [z, y, w]: # Side (Z)
		vertices.append(vertex)
		normals.append((z - w).cross(w - y).normalized())
	for vertex in [Vector3.ZERO, w, x]: # Y (X)
		vertices.append(vertex)
		normals.append(Vector3.DOWN)
	for vertex in [Vector3.ZERO, z, w]: # Y (Z)
		vertices.append(vertex)
		normals.append(Vector3.DOWN)
	for vertex in [Vector3.ZERO, y, z]: # X
		vertices.append(vertex)
		normals.append(Vector3.LEFT)
	for vertex in [Vector3.ZERO, x, y]: # Z
		vertices.append(vertex)
		normals.append(Vector3.FORWARD)
	
	var array = []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = vertices
	array[Mesh.ARRAY_NORMAL] = normals
	result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)



func get_name():
	var lowest_value = segments
	for value in indices:
		if value < lowest_value:
			lowest_value = value
	for divisor in range(lowest_value, 0, -1):
		var found = true
		if segments % divisor != 0:
			continue
		for value in indices:
			if value % lowest_value != 0:
				found = false
				break
		if found:
			var _name = name + "_" + str(segments / divisor)
			var pre = "_"
			for index in indices:
				_name += pre + str(index)
				pre = "-"
			return _name
