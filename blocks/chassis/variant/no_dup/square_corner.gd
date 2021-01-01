extends "../complex/square_corner.gd"


func _init():
	name = "square_corner"
	._set_generator()
	._set_indices_count(5)


func start(segments: int):
	.start(segments)


func step():
	.step()
	while not _is_valid():
		if finished:
			return
		.step()


func get_mesh(data: Array, transform := Transform.IDENTITY, flip_faces := false):
	assert(len(data) == 4)
	return mesh_generator.generate(transform, data[0], data[1], data[2],
			data[3], flip_faces)


func _is_valid():
	var result = get_result()
	var x = result[0]
	var y = result[1]
	var z = result[2]
	var u = result[3]
	if x.x < y.y or y.y < z.z:
		return false
	if x.x < u.x or z.z < u.z:
		return false
	if u.x < u.z:
		return false
	# No vertices on diagonal
	if (x - u).cross(x - z).length_squared() < 1e-5:
		return false
	return true
