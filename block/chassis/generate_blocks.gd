extends Node


func _enter_tree():
	var file := File.new()
	var err := file.open("res://block/chassis/shapes.json", File.READ)
	if err != OK:
		Global.error("Couldn't read shapes file", err)
		return
	var data = parse_json(file.get_as_text())
	for generator_name in data:
		var blocks = data[generator_name]
		var generator = load("res://block/chassis/variant/complex/%s.gd" % generator_name).new()
		for block_name in blocks:
			var block_data = blocks[block_name]
			var indices = PoolIntArray(block_data["indices"])
			var rotation = block_data["rotation"]
			var mirror = block_data["mirror"]
			var transform = Transform(Block.rotation_to_basis(rotation), Vector3.ZERO)
			transform = transform.scaled(Vector3.ONE * Global.BLOCK_SCALE)
			transform = transform.translated(-Vector3.ONE / 2)

			generator.start(2)
			generator.set_indices(indices)
			var result = generator.get_result()
			var mesh = generator.get_mesh(result, transform)
			var block_full_name = generator.get_name()

			var block = Block.new()
			block.name = generator.get_name()
			block.human_name = block_name
			block.category = "generated"
			block.mesh = generator.get_mesh(generator.get_result(), transform)
			Block.add_block(block)
			if mirror < 0:
				var mirror_transform = Transform.FLIP_X * transform
				var mirror_block = Block.new()
				mirror_block.name = generator.get_name() + "_m"
				mirror_block.human_name = block_name + " (M)"
				mirror_block.category = "generated"
				mirror_block.mesh = generator.get_mesh(generator.get_result(), transform, true)
				Block.add_block(mirror_block)
			else:
				var mirror_transform = Transform(Block.rotation_to_basis(mirror), Vector3.ZERO) * transform
				# TODO
