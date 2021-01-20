static func load_blocks() -> void:
	var file := File.new()
	var err := file.open("res://blocks/chassis/shapes.json", File.READ)
	if err != OK:
		print("Couldn't read shapes file: %d" % err)
		return
	var id_map_file := File.new()
	err = id_map_file.open("res://blocks/chassis/shapes_ids.json", File.READ)
	if err != OK:
		print("Couldn't read shapes IDs map: %d" % err)
		return
	var name2id: Dictionary = parse_json(id_map_file.get_as_text())
	var data = parse_json(file.get_as_text())
	for generator_name in data:
		var blocks = data[generator_name]
		# warning-ignore:unsafe_method_access
		var generator = load("res://blocks/chassis/variant/complex/%s.gd" % generator_name).new()
		for block_name in blocks:
			var block_data = blocks[block_name]
			var indices = PoolIntArray(block_data["indices"])
			var rotation = block_data["rotation"]
			var mirror = block_data["mirror"]
			var transform = Transform(
				OwnWar_Block.rotation_to_basis(rotation),
				Vector3.ZERO
			)
			transform = transform.scaled(Vector3.ONE * OwnWar_Block.BLOCK_SCALE)
			transform = transform.translated(-Vector3.ONE / 2)

			generator.start(2)
			generator.set_indices(indices)

			var block = OwnWar_Block.new()
			block.id = name2id[block_name]
			block.human_name = block_name
			block.category = "Structural"
			block.mesh = generator.get_mesh(generator.get_result(), transform)
			OwnWar_Block.add_block(block)
			if mirror < 0:
				var mirror_block = OwnWar_Block.new()
				var mirror_transform = Transform.FLIP_X * transform
				mirror_block.id = name2id[block_name + " (M)"]
				mirror_block.human_name = block.human_name + " (M)"
				mirror_block.category = "Structural"
				mirror_block.mesh = generator.get_mesh(generator.get_result(), mirror_transform, true)
				OwnWar_Block.add_block(mirror_block)
				mirror_block.mirror_block = block
				block.mirror_block = mirror_block
			else:
				block.set_mirror_rotation_offset(mirror)
