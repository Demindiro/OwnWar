tool

extends StaticBody


export(int) var rng_seed
export(int) var length = 10 setget set_length
export(int) var segment_scale = 1 setget set_segment_scale
export(bool) var regenerate = true


func f(x, z):
	var r = (x * x + z * z) / 2048
	r = clamp(r, 0, 1)
	return cos(PI * r) / (r * 0.02 + 0.2)
	

func df(x, z):
	var dx = f(x - 0.5, z) - f(x + 0.5, z)
	var dz = f(x, z - 0.5) - f(x, z + 0.5)
	return Vector3(dx, 1, dz).normalized()
	

func _process(_delta):
	if regenerate:
		_ready()

func _ready():
	if not regenerate:
		return
	regenerate = false
	var rng = RandomNumberGenerator.new()

	var vertices = []
	var uvs = []
	var normals = []
	var indices = []

	var a_offset = float(length) * cos(PI / 6)
	for a in range(length * 2 + 1):
		var b_len = length * 2 - abs(length - a) + 1
		var b_offset = float(b_len) / 2
		for b in range(b_len):
			var x = float(b) - b_offset
			var z = float(a) * cos(PI / 6) - a_offset
			var y = f(x, z)
			vertices.append(Vector3(x, y, z) * segment_scale)
			uvs.append(Vector2(x, z))
			normals.append(df(x, z))
	set_indices_bottom(indices)
	set_indices_top(indices)

	var array = []
	normals.resize(len(vertices))
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = PoolVector3Array(vertices)
	array[Mesh.ARRAY_TEX_UV] = PoolVector2Array(uvs)
	array[Mesh.ARRAY_NORMAL] = PoolVector3Array(normals)
	array[Mesh.ARRAY_INDEX] = PoolIntArray(indices)
	$MeshInstance.mesh = ArrayMesh.new()
	$MeshInstance.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)
	$MeshInstance.mesh.regen_normalmaps()
	
	var concave_triangles = PoolVector3Array()
	for i in indices:
		concave_triangles.append(vertices[i])
	print(len(concave_triangles))
	$CollisionShape.shape.set_faces(concave_triangles)
	print(len($CollisionShape.shape.get_faces()))


func set_indices_bottom(indices):
	var start = 0
	var segment_length = length + 1
	var end = start + segment_length
	for _n in range(length):
		for i in range(start, end - 1):
			indices.append(i)
			indices.append(i + 1)
			indices.append(i + segment_length + 1)
		for i in range(start, end):
			indices.append(i)
			indices.append(i + segment_length + 1)
			indices.append(i + segment_length)
		segment_length += 1
		start = end
		end = start + segment_length


func set_indices_top(indices):
	var start = (length + 1) * length + (length * (length - 1) / 2)
	var segment_length = length * 2 + 1
	var end = start + segment_length
	for _n in range(length):
		for i in range(start, end - 1):
			indices.append(i)
			indices.append(i + 1)
			indices.append(i + segment_length)
		for i in range(start + 1, end - 1):
			indices.append(i)
			indices.append(i + segment_length)
			indices.append(i + segment_length - 1)
		segment_length -= 1
		start = end
		end = start + segment_length
		

func set_length(p_length):
	if length != p_length:
		length = p_length


func set_segment_scale(p_scale):
	if segment_scale != p_scale:
		segment_scale = p_scale