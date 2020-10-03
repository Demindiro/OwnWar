extends "res://block/chassis/variant/complex/square_corner.gd"


func _init():
	name = "square_corner"
	._set_generator()
	._set_indices_count(5)


func start(segments: int, scale: Vector3, offset: Vector3):
	.start(segments, scale, offset)


func step():
	.step()
	while not _is_valid():
		if finished:
			return
		.step()


func get_mesh(data: Array):
	assert(len(data) == 4)
	return mesh_generator.generate(Transform.IDENTITY, data[0], data[1], data[2],
			data[3])


func _is_valid():
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
