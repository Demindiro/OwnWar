extends "res://block/chassis/generate_shapes.gd"


func _init():
	name = "edge_a"
	._set_generator()
	._set_indices_count(7)


func start(segments: int, scale: Vector3, offset: Vector3):
	.start(segments, scale, offset)
	step()


func step():
	.step()
	
	var x = Vector3(fractions[0], 0, 0)
	var y = Vector3(0, fractions[1], 0)
	var z = Vector3(0, 0, fractions[2])
	var u = Vector3(fractions[3], 0, fractions[4])
	var v = Vector3(fractions[5], fractions[6], 0)
	
	result = mesh_generator.generate(Transform.IDENTITY, x, y, z, u, v)
