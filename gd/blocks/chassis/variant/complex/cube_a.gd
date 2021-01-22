extends "../variant.gd"


func _init():
	name = "cube_a"
	._set_generator()
	._set_indices_count(12)


func start(segments: int):
	.start(segments)
	step()


func step():
	.step()


func get_result():
	var x = Vector3(fractions[0], 0, 0)
	var y = Vector3(0, fractions[1], 0)
	var z = Vector3(0, 0, fractions[2])
	var u = Vector3(0, fractions[3], fractions[4])
	var v = Vector3(fractions[5], 0, fractions[6])
	var w = Vector3(fractions[7], fractions[8], 0)
	var a = Vector3(fractions[9], fractions[10], fractions[11])
	return [x, y, z, u, v, w, a]


func get_mesh(data: Array, transform := Transform.IDENTITY, flip_faces := false):
	assert(len(data) == 7)
	return mesh_generator.generate(transform, data[0], data[1], data[2],
			data[3], data[4], data[5], data[6], flip_faces)
