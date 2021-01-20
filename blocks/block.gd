extends Resource
class_name OwnWar_Block


const ROTATION_TO_ORTHOGONAL_INDEX = [0, 16, 10, 22, 2, 18, 8, 20, 3, 19, 9, 21,
		1, 17, 11, 23, 4, 5, 6, 7, 14, 13, 12, 15]
const BLOCK_SCALE := 0.25
const _ID_TO_BLOCK = []

export var id := 0
export var human_name: String
export var revision := 0 # Used for things like e.g. thumbnail generation
export var category := "other"
export var mesh: Mesh
export var instance: PackedScene setget set_instance
export var health := 100
export var mass := 1.0
export var cost := 1
export var aabb := AABB(Vector3(), Vector3.ONE)
export var mirror_rotation_offset := 0 setget set_mirror_rotation_offset
export var __mirror_block_id := 0

var server_node: Spatial
var client_node: Spatial
var editor_node: Spatial
var mirror_block: Resource setget __set_mirror_block, __get_mirror_block
var mirror_rotation_map: PoolIntArray


func _init():
	set_mirror_rotation_offset(0)


func set_mirror_rotation_offset(rotation: int) -> void:
	mirror_rotation_offset = rotation
	assert(0 <= rotation and rotation < 4)
	for i in range(24):
		var offset_basis = rotation_to_basis(rotation)
		mirror_rotation_map = PoolIntArray()
		mirror_rotation_map.resize(24)
		mirror_rotation_map[i] = basis_to_rotation(get_basis(i) * offset_basis)
		var angle = i & 0b11
		var direction = (i & 0b11100) >> 2
		if rotation % 2 == 0:
			match angle:
				3: angle = 1
				1: angle = 3
		else:
			match angle:
				0: angle = 3
				1: angle = 2
				2: angle = 1
				3: angle = 0
		match direction:
			2: direction = 3
			3: direction = 2
		mirror_rotation_map[i] = (direction << 2) | angle


func get_basis(rotation: int) -> Basis:
	return rotation_to_basis(rotation)


func get_mirror_rotation(rotation: int) -> int:
	return mirror_rotation_map[rotation]


func set_instance(p_instance: PackedScene) -> void:
	var node: OwnWar_BlockInstance = p_instance.instance()
	if node.server_node != NodePath():
		server_node = node.get_node(node.server_node)
		assert(server_node != null)
	if node.client_node != NodePath():
		client_node = node.get_node(node.client_node)
		assert(client_node != null)
	if node.editor_node != NodePath():
		editor_node = node.get_node(node.editor_node)
		assert(editor_node != null)
	if server_node != null:
		node.remove_child(server_node)
	if client_node != null and node.has_node(node.client_node):
		node.remove_child(client_node)
	if editor_node != null and node.has_node(node.editor_node):
		node.remove_child(editor_node)
	node.free()
	instance = p_instance


static func add_block(block):
	_ID_TO_BLOCK.resize(65536)
	assert(block.id > 0, "Block ID is not set")
	assert(block.id < 65536, "Block ID is out of range")
	assert(_ID_TO_BLOCK[block.id] == null, "Block ID conflicts")
	_ID_TO_BLOCK[block.id] = block


static func get_block(p_id: int):# -> Block:
	assert(p_id > 0 and p_id < 65536, "Block ID out of range")
	if _ID_TO_BLOCK[p_id] == null:
		return _ID_TO_BLOCK[13] # Cube (L)
	#assert(_ID_TO_BLOCK[p_id] != null, "Invalid block ID")
	return _ID_TO_BLOCK[p_id]


static func get_all_blocks() -> Array:
	var arr := []
	for blk in _ID_TO_BLOCK:
		if blk != null:
			arr.push_back(blk)
	return arr


static func rotation_to_basis(rotation: int) -> Basis:
	assert(0 <= rotation and rotation < 24)
	var angle = rotation & 0b11
	var direction = (rotation & 0b11100) >> 2
	var basis := Basis.IDENTITY
	basis = Basis(Vector3.UP, PI / 2 * angle) * basis
	match direction:
		1:
			basis = Basis(Vector3.FORWARD, PI) * basis
		2:
			basis = Basis(Vector3.FORWARD, PI / 2) * basis
		3:
			basis = Basis(Vector3.FORWARD, PI) * Basis(Vector3.FORWARD, PI / 2) * basis
		4:
			basis = Basis(Vector3.RIGHT, PI / 2) * basis
		5:
			basis = Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, PI / 2) * basis
	return basis


static func basis_to_rotation(basis: Basis) -> int:
	return orthogonal_index_to_rotation(basis.get_orthogonal_index())


static func rotation_to_orthogonal_index(rotation: int) -> int:
	return ROTATION_TO_ORTHOGONAL_INDEX[rotation]


static func orthogonal_index_to_rotation(index: int) -> int:
	for i in range(24):
		if ROTATION_TO_ORTHOGONAL_INDEX[i] == index:
			return i
	assert(false)
	return -1


static func axis_to_direction(axis: Vector3) -> int:
	# Matching is fine, because round() rounds to whole integers, which can be
	# represented in memory without any loss of precisision
	axis = axis.round()
	var d := -1
	match axis:
		Vector3.UP: d = 0
		Vector3.DOWN: d = 1
		Vector3.RIGHT: d = 2
		Vector3.LEFT: d = 3
		Vector3.BACK: d = 4
		Vector3.FORWARD: d = 5
		_: assert(false)
	return d << 2


func __set_mirror_block(block: Resource):
	# warning-ignore:unsafe_property_access
	assert(block.id > 0, "oh no - invalid mirror block id")
	__mirror_block_id = block.id


func __get_mirror_block():
	if len(get_stack()) == 0 or get_stack()[2]["function"] != "__get_mirror_block":
		return get_block(__mirror_block_id) if __mirror_block_id != 0 else self
