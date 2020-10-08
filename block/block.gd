class_name Block

extends Resource


const ROTATION_TO_ORTHOGONAL_INDEX = [0, 16, 10, 22, 2, 18, 8, 20, 3, 19, 9, 21,
		1, 17, 11, 23, 4, 5, 6, 7, 14, 13, 12, 15]
export(String) var name: String
# warning-ignore:unused_class_variable
export(String) var human_name: String
# warning-ignore:unused_class_variable
export(String) var category: String = "other"
# warning-ignore:unused_class_variable
export(Mesh) var mesh: Mesh
# warning-ignore:unused_class_variable
export(Material) var material: Material
# warning-ignore:unused_class_variable
export(PackedScene) var scene: PackedScene
# warning-ignore:unused_class_variable
export(int) var mass: int = 1
# warning-ignore:unused_class_variable
export(int) var health: int = 100
# warning-ignore:unused_class_variable
export(int) var cost: int = 1
# warning-ignore:unused_class_variable
export(Vector3) var size: Vector3 = Vector3.ONE
export(int) var mirror_rotation_offset := 0 setget set_mirror_rotation_offset
#export(Block) var mirror_block: Block
#export(Resource) var mirror_block
export var __mirror_block_name: String
var mirror_block: Resource setget __set_mirror_block, __get_mirror_block
# warning-ignore:unused_class_variable
var id: int
var mirror_rotation_map: PoolIntArray


func _init():
	set_mirror_rotation_offset(0)
	mirror_block = self


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


static func add_block(block: Block):
	if block.name in Global.blocks:
		push_error("Block name is already registered: '%s'" % block.name)
		return
	Global.blocks[block.name] = block


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


#static func mirror_rotation(rotation: int) -> int:
#	assert(0 <= rotation and rotation < 24)
#	var angle = rotation & 0b11
#	var direction = (rotation & 0b11100) >> 2
#	match direction:
#		0, 1:
#			match angle:
#				3: angle = 1
#				1: angle = 3
#		2, 3:
#			match angle:
#				_: pass
#		4, 5:
#			match angle:
#				3: angle = 1
#				1: angle = 3
#	match direction:
#		2: direction = 3
#		3: direction = 2
#	return (direction << 2) | angle
#

static func rotation_to_orthogonal_index(rotation: int) -> int:
	return ROTATION_TO_ORTHOGONAL_INDEX[rotation]


static func orthogonal_index_to_rotation(index: int) -> int:
	for i in range(24):
		if ROTATION_TO_ORTHOGONAL_INDEX[i] == index:
			return i
	assert(false)
	return -1


func __set_mirror_block(block: Resource):
	__mirror_block_name = block.name


func __get_mirror_block():
	var caller = get_stack()[1]
	if caller["function"] != "__get_mirror_block":
		return Global.blocks[__mirror_block_name]
