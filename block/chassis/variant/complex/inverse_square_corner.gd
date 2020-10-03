extends "res://block/chassis/variant/variant.gd"


func _init():
	name = "inverse_square_corner"
	._set_generator()
	._set_indices_count(9)


func start(segments: int, scale: Vector3, offset: Vector3):
	.start(segments, scale, offset)
	step()


func step():
	.step()
		
	var x = Vector3(fractions[0], 0, 0)
	var y = Vector3(0, fractions[1], 0)
	var z = Vector3(0, 0, fractions[2])
	var u = Vector3(0, fractions[3], fractions[4])
	var v = Vector3(fractions[5], 0, fractions[6])
	var w = Vector3(fractions[7], fractions[8], 0)
	
	result = [x, y, z, u, v, w]


func get_mesh(data: Array):
	assert(len(data) == 6)
	return mesh_generator.generate(Transform.IDENTITY, data[0], data[1], data[2],
			data[3], data[4], data[5])
