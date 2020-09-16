class_name Vehicle

extends Spatial

var start_position = Vector3.ONE * INF
var end_position = Vector3.ONE * -INF

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
	_set_collision_box(start_position, end_position)
	_correct_center_of_mass()


func _correct_center_of_mass() -> void:
	var total_mass = 0
	var position = Vector3.ZERO
	for cell in $GridMap.get_used_cells():
		var id = $GridMap.get_cell_item(cell.x, cell.y, cell.z)
		var mass = Global.blocks_by_id[id].mass
		position += cell * mass
		total_mass += mass
	position /= total_mass
	position += Vector3.ONE * 0.5
	for child in get_children():
		child.translate(-position)
	translate(position)



func _spawn_block(x: int, y: int, z: int, r: int, block: Block) -> void:
	$GridMap.set_cell_item(x, y, z, block.id)
	if block.scene != null:
		var node = block.scene.instance()
		assert(node is Spatial)
		node.translation = Vector3(x, y, z) + Vector3.ONE / 2
		add_child(node)
	start_position.x = x if start_position.x > x else start_position.x
	start_position.y = x if start_position.y > y else start_position.y
	start_position.z = x if start_position.z > z else start_position.z
	end_position.x = x if end_position.x < x else end_position.x
	end_position.y = x if end_position.y < y else end_position.y
	end_position.z = x if end_position.z < z else end_position.z


func _set_collision_box(start: Vector3, end: Vector3) -> void:
	end += Vector3.ONE
	var center = (start + end) / 2
	var extents = (end - start) / 2
	$CollisionShape.transform.origin = center
	$CollisionShape.shape.extents = extents
