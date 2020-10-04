extends Reference


var name := "mesh"


static func get_normals(vertices):
	assert(len(vertices) % 3 == 0)
	var normals = PoolVector3Array()
	normals.resize(len(vertices))
	for i in range(0, len(vertices), 3):
		var x = vertices[i]
		var y = vertices[i + 1]
		var z = vertices[i + 2]
		var normal = (x - z).cross(z - y).normalized()
		normals[i] = normal
		normals[i + 1] = normal
		normals[i + 2] = normal
	return normals
