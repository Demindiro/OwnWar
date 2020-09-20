class_name Block

extends Resource


export(String) var name: String
export(String) var category: String = "other"
export(Mesh) var mesh: Mesh
export(PackedScene) var scene: PackedScene
export(int) var mass: int = 1
export(Vector3) var size: Vector3 = Vector3.ONE

var id


func _init(p_mesh: Mesh = null):
	mesh = p_mesh


static func add_block(block: Block):
	if block.name in Global.blocks:
		push_error("Block name is already registered: '%s'" % block.name)
		return
	Global.blocks[block.name] = block


static func rotation_to_basis(var rotation: int) -> Basis:
	assert(0 <= rotation and rotation < 24)
	var angle = rotation & 0b11
	var direction = (rotation & 0b11100) >> 2
	var basis := Basis.IDENTITY
	basis = Basis(Vector3.UP, PI / 2 * angle) * basis
	match direction:
		1:
			basis = Basis.FLIP_Y * basis
		2:
			basis = Basis(Vector3.FORWARD, PI / 2) * basis
		3:
			basis = Basis.FLIP_X * Basis(Vector3.FORWARD, PI / 2) * basis
		4:
			basis = Basis(Vector3.RIGHT, PI / 2) * basis
		5:
			basis = Basis.FLIP_Z * Basis(Vector3.RIGHT, PI / 2) * basis
	return basis


static func mirror_rotation(var rotation: int) -> int:
	assert(0 <= rotation and rotation < 24)
	var angle = rotation & 0b11
	var direction = (rotation & 0b11100) >> 2
	match direction:
		0, 1:
			match angle:
				3: angle = 1
				1: angle = 3
		2, 3:
			match angle:
				_: pass
		4, 5:
			match angle:
				3: angle = 1
				1: angle = 3
	match direction:
		2: direction = 3
		3: direction = 2
	return (direction << 2) | angle


static func rotation_to_orthogonal_index(rotation: int) -> int:
	assert(0 <= rotation and rotation < 24)
	# For some reason the orientation still isn't correct
	var basis := rotation_to_basis(rotation)
	#basis *= Basis(Vector3.BACK, Vector3.UP, Vector3.RIGHT)
	return basis.get_orthogonal_index()
