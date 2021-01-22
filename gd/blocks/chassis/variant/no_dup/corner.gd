extends "../variant.gd"


func _init():
	name = "corner"
	._set_generator()
	._set_indices_count(3)


func start(segments: int):
	.start(segments)
	step()


func step():
	.step()
	while fractions[0] < fractions[1] or fractions[1] < fractions[2]:
		if finished:
			return
		.step()



func get_result():
	var x = Vector3(fractions[0], 0, 0)
	var y = Vector3(0, fractions[1], 0)
	var z = Vector3(0, 0, fractions[2])
	return [x, y, z]


func get_mesh(data: Array, transform := Transform.IDENTITY, flip_faces := false):
	assert(len(data) == 3)
	return mesh_generator.generate(transform, data[0], data[1], data[2], flip_faces)
