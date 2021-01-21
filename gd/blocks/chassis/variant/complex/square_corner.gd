extends "../variant.gd"


func _init():
	name = "square_corner"
	._set_generator()
	._set_indices_count(5)


func start(segments: int):
	.start(segments)
	step()


func step():
	.step()


func get_result():
	var x = Vector3(fractions[0], 0, 0)
	var y = Vector3(0, fractions[1], 0)
	var z = Vector3(0, 0, fractions[2])
	var u = Vector3(fractions[3], 0, fractions[4])
	return [x, y, z, u]


func get_mesh(data: Array, transform := Transform.IDENTITY, flip_faces := false):
	assert(len(data) == 4)
	return mesh_generator.generate(transform, data[0], data[1], data[2],
			data[3], flip_faces)
