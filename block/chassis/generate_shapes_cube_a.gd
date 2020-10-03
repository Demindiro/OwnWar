extends "res://block/chassis/generate_shapes.gd"


func _init():
	name = "cube_a"
	._set_generator()
	._set_indices_count(12)


func start(segments: int, scale: Vector3, offset: Vector3):
	.start(segments, scale, offset)
	step()


func step():
	.step()
	var fractions = PoolRealArray()
	for index in indices:
		fractions.append(float(index) / float(segments))
		
	var x = Vector3(fractions[0], 0, 0)
	var y = Vector3(0, fractions[1], 0)
	var z = Vector3(0, 0, fractions[2])
	var u = Vector3(0, fractions[3], fractions[4])
	var v = Vector3(fractions[5], 0, fractions[6])
	var w = Vector3(fractions[7], fractions[8], 0)
	var a = Vector3(fractions[9], fractions[10], fractions[11])
	
	result = mesh_generator.generate(Transform.IDENTITY, x, y, z, u, v, w, a)
