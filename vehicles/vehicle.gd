class_name Vehicle

extends Spatial


func _ready():
	$GridMap.mesh_library = Global._blocks_mesh_library
	var cube = Global.blocks["cube"]
	var wheel = Global.blocks["wheel"]
	# Chassis
	for x in range(3):
		for y in range(3):
			for z in range(6):
				var c = 0
				c += 1 if (x != 0 and x != 2) else 0
				c += 1 if (y != 0 and y != 2) else 0
				c += 1 if (z != 0 and z != 5) else 0
				if c > 1:
					continue
				_spawn_block(x, y, z, 0, cube)
	# Wheels
	_spawn_block(-1, 0, 0, 0, wheel)
	_spawn_block(-1, 0, 5, 0, wheel)
	_spawn_block(3, 0, 0, 0, wheel)
	_spawn_block(3, 0, 5, 0, wheel)
	_set_collision_box(Vector3(0, 0, 0), Vector3(2, 2, 0))


func _spawn_block(x: int, y: int, z: int, r: int, block: Block) -> void:
	$GridMap.set_cell_item(x, y, z, block.id)
	if block.scene != null:
		var node = block.scene.instance()
		assert(node is Spatial)
		node.translation = Vector3(x, y, z) + Vector3.ONE / 2
		add_child(node)


func _set_collision_box(start: Vector3, end: Vector3) -> void:
	start -= Vector3.ONE / 2
	end += Vector3.ONE / 2
	var center = (start + end) / 2
	var extents = (end - start) / 2
	$CollisionShape.transform.origin = center
	$CollisionShape.shape.extents = extents
