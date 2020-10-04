extends Reference


static func get_meshes():
	var generators = [
			preload("res://block/chassis/variant/no_dup/corner.gd").new(),
			preload("res://block/chassis/variant/no_dup/cube.gd").new(),
			preload("res://block/chassis/variant/no_dup/edge.gd").new(),
			preload("res://block/chassis/variant/no_dup/inverse_corner.gd").new(),
			preload("res://block/chassis/variant/no_dup/inverse_square_corner.gd").new(),
			preload("res://block/chassis/variant/no_dup/square_corner.gd").new(),
		]
	var meshes = []
	for generator in generators:
		generator.start()
