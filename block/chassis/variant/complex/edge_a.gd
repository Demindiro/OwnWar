extends "res://block/chassis/variant/variant.gd"


func _init():
	name = "edge_a"
	._set_generator()
	._set_indices_count(7)


func start(segments: int):
	.start(segments)
	step()


func step():
	.step()
	
	var x = Vector3(fractions[0], 0, 0)
	var y = Vector3(0, fractions[1], 0)
	var z = Vector3(0, 0, fractions[2])
	var u = Vector3(fractions[3], 0, fractions[4])
	var v = Vector3(fractions[5], fractions[6], 0)
	
	result = [x, y, z, u, v]


func get_mesh(data: Array, transform := Transform.IDENTITY):
	assert(len(data) == 5)
	return mesh_generator.generate(transform, data[0], data[1], data[2],
			data[3], data[4])
