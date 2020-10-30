const PLUGIN_ID = "chassis_blocks"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION = Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {}


static func pre_init(plugin_folder: String):
	var file := File.new()
	var err := file.open(plugin_folder.plus_file("shapes.json"), File.READ)
	if err != OK:
		print("Couldn't read shapes file: %d" % err)
		return
	var data = parse_json(file.get_as_text())
	for generator_name in data:
		var blocks = data[generator_name]
		var generator = load(plugin_folder.plus_file("variant/complex/%s.gd") % generator_name).new()
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


static func init(_plugin_path: String):
	pass


static func post_init(_plugin_path: String):
	pass


static func save_game(game_master: GameMaster) -> Dictionary:
	return {}


static func load_game(game_master: GameMaster, data: Dictionary) -> void:
	pass
