extends Node


func _enter_tree():
	var generators = [
			preload("res://block/chassis/variant/no_dup/corner.gd").new(),
			preload("res://block/chassis/variant/no_dup/cube.gd").new(),
			preload("res://block/chassis/variant/no_dup/edge.gd").new(),
			preload("res://block/chassis/variant/no_dup/inverse_corner.gd").new(),
			preload("res://block/chassis/variant/no_dup/inverse_square_corner.gd").new(),
			preload("res://block/chassis/variant/no_dup/square_corner.gd").new(),
		]
	var transform = Transform.IDENTITY
	transform.origin -= Vector3(1, 1, 1) / 2 * Global.BLOCK_SCALE
	transform = transform.scaled(Vector3.ONE * Global.BLOCK_SCALE)
	for generator in generators:
		generator.start(2)
		while not generator.finished:
			var block = Block.new()
			block.name = generator.get_name()
			block.category = "generated"
			block.mesh = generator.get_mesh(generator.result, transform)
			Block.add_block(block)
			generator.step()
