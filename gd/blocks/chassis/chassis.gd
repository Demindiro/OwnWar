# TODO consts in NativeScript pls
const BLOCK_SCALE := 0.25


static func load_blocks() -> void:
	var BlockManager := preload("../block_manager.gdns").new()
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
				BlockManager.rotation_to_basis(int(rotation)),
				Vector3.ZERO
			)
			transform = transform.scaled(Vector3.ONE * BLOCK_SCALE)
			transform = transform.translated(-Vector3.ONE / 2)

			generator.start(2)
			generator.set_indices(indices)

			var mesh = generator.get_mesh(generator.get_result(), transform)

			var block = OwnWar_Block.new()
			# TODO this is a bug in GDScript, report it
			block.id = int(name2id[block_name])
			block.human_name = block_name
			block.human_category = "Structural"
			block.mesh = mesh
			block.mass = 1.0
			block.mount_sides = find_connectable_sides(mesh)
			BlockManager.add_block(block)
			if mirror < 0:
				var mirror_block = OwnWar_Block.new()
				var mirror_transform = Transform.FLIP_X * transform
				mesh = generator.get_mesh(generator.get_result(), mirror_transform, true)
				# TODO ditto
				mirror_block.id = int(name2id[block_name + " (M)"])
				mirror_block.human_name = block.human_name + " (M)"
				mirror_block.human_category = "Structural"
				mirror_block.mesh = mesh
				mirror_block.mass = 1.0
				mirror_block.mount_sides = find_connectable_sides(mesh)
				BlockManager.add_block(mirror_block)
				mirror_block.mirror_block = block
				block.mirror_block = mirror_block
			else:
				block.mirror_rotation_offset = int(mirror)


# Figure out which sides would look connectable visually and create an appropriate bitmask
static func find_connectable_sides(mesh):
	var mask = 0
	var arrays = mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var indices = arrays[Mesh.ARRAY_INDEX]
	assert(indices == null)
	assert(len(vertices) % 3 == 0)

	for i in len(vertices) / 3:
		var a = vertices[i * 3 + 0]
		var b = vertices[i * 3 + 1]
		var c = vertices[i * 3 + 2]
		var cross = (b - a).cross(c - a)
		if cross.length_squared() > 1e-4:
			var norm = cross.normalized()
			# TODO why the hell are the normals reversed? And how is this correct?
			if norm == Vector3(0, 1, 0) && in_cube_plane(a, b, c, 1):
				mask |= 2
			if norm == Vector3(0, -1, 0) && in_cube_plane(a, b, c, 1):
				mask |= 1
			if norm == Vector3(1, 0, 0) && in_cube_plane(a, b, c, 0):
				mask |= 8
			if norm == Vector3(-1, 0, 0) && in_cube_plane(a, b, c, 0):
				mask |= 4
			if norm == Vector3(0, 0, 1) && in_cube_plane(a, b, c, 2):
				mask |= 32
			if norm == Vector3(0, 0, -1) && in_cube_plane(a, b, c, 2):
				mask |= 16

	return mask

# Check if the vertices are all in a cube plane of the given axis
#
# - 0 is X
# - 1 is Y
# - 2 is Z
static func in_cube_plane(a, b, c, i):
	match i:
		0:
			a = a.x
			b = b.x
			c = c.x
		1:
			a = a.y
			b = b.y
			c = c.y
		2:
			a = a.z
			b = b.z
			c = c.z
		_:
			assert(false)
			return false
	var s = BLOCK_SCALE / 2.0
	return (abs(a - s) < 1e-4 || abs(a + s) < 1e-4) && abs(a - b) < 1e-4 && abs(a - c) < 1e-4
