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

			var block = Block.new()
			block.name = generator.get_name()
			block.human_name = block_name
			block.category = "generated"
			block.mesh = generator.get_mesh(generator.get_result(), transform)
			Block.add_block(block)
			if mirror < 0:
				var mirror_block = Block.new()
				var mirror_transform = Transform.FLIP_X * transform
				mirror_block.name = block.name + "_m"
				mirror_block.human_name = block.human_name + " (M)"
				mirror_block.category = "generated"
				mirror_block.mesh = generator.get_mesh(generator.get_result(), mirror_transform, true)
				Block.add_block(mirror_block)
				mirror_block.mirror_block = block
				block.mirror_block = mirror_block
			else:
				block.set_mirror_rotation_offset(mirror)
