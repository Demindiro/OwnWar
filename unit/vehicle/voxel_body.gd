class_name VoxelBody
extends RigidBody


signal hit(voxel_body)
var start_position := Vector3.ONE * INF
var end_position := Vector3.ONE * -INF
var center_of_mass := Vector3.ZERO
var blocks := {}
var cost := 0
var max_cost := 0
var max_health := 0
var _debug_hits := []
var _raycast := preload("res://addons/voxel_raycast.gd").new()
var _collision_shape: CollisionShape


func _init():
	set_as_toplevel(true)
	_collision_shape = CollisionShape.new()
	_collision_shape.shape = BoxShape.new()
	add_child(_collision_shape)


func debug_draw(debug_node):
	for child in get_children():
		if child is Weapon:
			child.debug_draw(debug_node)
	for hit in _debug_hits:
		var position = Vector3(hit[0][0], hit[0][1], hit[0][2]) + Vector3.ONE / 2
		debug_node.draw_point(to_global(position * Global.BLOCK_SCALE - center_of_mass),
				hit[1], 0.55 * Global.BLOCK_SCALE)


func fix_physics(p_transform):
	cost = max_cost
	_set_collision_box(start_position, end_position)
	_correct_mass()
	global_transform = p_transform.translated(center_of_mass)


func projectile_hit(origin: Vector3, direction: Vector3, damage: int):
	var local_origin = to_local(origin) + center_of_mass
	local_origin /= Global.BLOCK_SCALE
	var local_direction = to_local(origin + direction) - to_local(origin)
	_raycast.start(local_origin, local_direction, 25, 25, 25)
	_debug_hits = []
	while not _raycast.finished:
		var key = [_raycast.x, _raycast.y, _raycast.z]
		var block = blocks.get(key)
		if block != null:
			_debug_hits.append([key, Color.orange])
			if block[1] < damage:
				damage -= block[1]
				block[2].queue_free()
				# warning-ignore:return_value_discarded
				blocks.erase(key)
				cost -= Global.blocks_by_id[block[0]].cost
			else:
				block[1] -= damage
				damage = 0
				break
		else:
			_debug_hits.append([key, Color.yellow])
		_raycast.step()
	emit_signal("hit", self)
	return damage


func spawn_block(x: int, y: int, z: int, r: int, block: Block, color: Color) -> void:
	var basis := Block.rotation_to_basis(r)
	var orthogonal_index := Block.rotation_to_orthogonal_index(r)
	var node: Spatial
	var material := SpatialMaterial.new()
	material.albedo_color = color
	if block.mesh != null:
		node = MeshInstance.new()
		node.mesh = block.mesh
		if block.scene != null:
			node.add_child(block.scene.instance())
	elif block.scene != null:
		node = block.scene.instance()
	else:
		assert(false)
	var position = Vector3(x, y, z) + Vector3.ONE / 2
	node.transform = Transform(basis, position * Global.BLOCK_SCALE)
	for child in get_children_recursive(node) + [node]:
		if child is GeometryInstance and not child is Sprite3D:
			child.material_override = material
	add_child(node)
	max_cost += block.cost
	max_health += block.health
	blocks[[x, y, z]] = [block.id, block.health, node]
	start_position.x = float(x) if start_position.x > x else start_position.x
	start_position.y = float(y) if start_position.y > y else start_position.y
	start_position.z = float(z) if start_position.z > z else start_position.z
	end_position.x = float(x) if end_position.x < x else end_position.x
	end_position.y = float(y) if end_position.y < y else end_position.y
	end_position.z = float(z) if end_position.z < z else end_position.z


func coordinate_to_vector(coordinate):
	var position = Vector3(coordinate[0], coordinate[1], coordinate[2])
	position *= Global.BLOCK_SCALE
	return position - center_of_mass


func _set_collision_box(start: Vector3, end: Vector3) -> void:
	end += Vector3.ONE
	var center = (start + end) / 2
	var extents = (end - start) / 2
	_collision_shape.transform.origin = center * Global.BLOCK_SCALE
	_collision_shape.shape.extents = extents * Global.BLOCK_SCALE


func _correct_mass() -> void:
	var total_mass = 0
	center_of_mass = Vector3.ZERO
	for coordinate in blocks:
		var block = blocks[coordinate]
		var block_mass = Global.blocks_by_id[block[0]].mass
		center_of_mass += Vector3(coordinate[0], coordinate[1], coordinate[2]) * block_mass
		total_mass += block_mass
	assert(total_mass > 0)
	center_of_mass /= total_mass
	center_of_mass += Vector3.ONE * 0.5
	center_of_mass *= Global.BLOCK_SCALE
	for child in get_children():
		child.transform.origin -= center_of_mass
		if child is VehicleWheel:
			remove_child(child) # Necessary to force VehicleWheel to move
			add_child(child)    # See VehicleWheel3D::_notification in vehicle_body_3d.cpp:81
#	mass = total_mass


# REEEEEEE https://github.com/godotengine/godot/issues/16105
func get_children_recursive(node = null, array = []):
	node = node if node != null else self
	for child in node.get_children():
		array.append(child)
		get_children_recursive(child, array)
	return array
