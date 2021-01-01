extends OwnWar.Plugin.Interface


const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION = Vector3(0, 12, 0)
const PLUGIN_DEPENDENCIES := {}


func pre_init():
	var plugin_folder: String = Util.get_script_dir(self)
	var file := File.new()
	var err := file.open(plugin_folder.plus_file("shapes.json"), File.READ)
	if err != OK:
		print("Couldn't read shapes file: %d" % err)
		return
	var data = parse_json(file.get_as_text())
	for generator_name in data:
		var blocks = data[generator_name]
		# warning-ignore:unsafe_method_access
		var generator = load(plugin_folder.plus_file("variant/complex/%s.gd") % generator_name).new()
		for block_name in blocks:
			var block_data = blocks[block_name]
			var indices = PoolIntArray(block_data["indices"])
			var rotation = block_data["rotation"]
			var mirror = block_data["mirror"]
			var transform = Transform(
				OwnWar.Block.rotation_to_basis(rotation),
				Vector3.ZERO
			)
			transform = transform.scaled(Vector3.ONE * OwnWar.Block.BLOCK_SCALE)
			transform = transform.translated(-Vector3.ONE / 2)

			generator.start(2)
			generator.set_indices(indices)

			var block = OwnWar.Block.new()
			block.name = generator.get_name()
			block.human_name = block_name
			block.category = "generated"
			block.mesh = generator.get_mesh(generator.get_result(), transform)
			OwnWar.Block.add_block(block)
			if mirror < 0:
				var mirror_block = OwnWar.Block.new()
				var mirror_transform = Transform.FLIP_X * transform
				mirror_block.name = block.name + "_m"
				mirror_block.human_name = block.human_name + " (M)"
				mirror_block.category = "generated"
				mirror_block.mesh = generator.get_mesh(generator.get_result(), mirror_transform, true)
				OwnWar.Block.add_block(mirror_block)
				mirror_block.mirror_block = block
				block.mirror_block = mirror_block
			else:
				block.set_mirror_rotation_offset(mirror)
