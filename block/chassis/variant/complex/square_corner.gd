extends "res://block/chassis/variant/variant.gd"


func _init():
	name = "square_corner"
	._set_generator()
	._set_indices_count(5)


func start(segments: int, scale: Vector3, offset: Vector3):
	.start(segments, scale, offset)
	step()


func step():
	.step()
		
	var x = Vector3(fractions[0], 0, 0)
	var y = Vector3(0, fractions[1], 0)
	var z = Vector3(0, 0, fractions[2])
	var u = Vector3(fractions[3], 0, fractions[4])
	
	result = [x, y, z, u]


func get_mesh(data: Array):
	assert(len(data) == 4)
	return mesh_generator.generate(Transform.IDENTITY, data[0], data[1], data[2],
			data[3])
