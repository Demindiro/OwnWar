extends VehicleBody


const Block := preload("res://core/block/block.gd")
const VoxelMesh := preload("voxel_mesh.gd")


class BodyBlock:
	const Block := preload("res://core/block/block.gd")

	var id: int
	var health: int
	var node: Spatial
	var rotation: int
	var color: Color

	func _init(block: Block, p_node: Spatial, p_rotation: int, p_color: Color) \
			-> void:
		id = block.id
		health = block.health
		node = p_node
		rotation = p_rotation
		color = p_color


signal hit(voxel_body)
var start_position := Vector3.ONE * INF
var end_position := Vector3.ONE * -INF
var center_of_mass := Vector3.ZERO
var blocks := {}
var cost := 0
var max_cost := 0
var max_health := 0
var wheels := []
var weapons := []
var _debug_hits := []
var _raycast := preload("res://addons/voxel_raycast.gd").new()
var _collision_shape: CollisionShape
var _voxel_mesh := VoxelMesh.new()
var _voxel_mesh_instance := MeshInstance.new()
onready var visual_translation := translation
onready var _prev_transform := transform
onready var _next_transform := transform


func _init():
	set_as_toplevel(true)
	_collision_shape = CollisionShape.new()
	_collision_shape.shape = BoxShape.new()
	add_child(_collision_shape)
	_voxel_mesh_instance.mesh = _voxel_mesh
	_voxel_mesh_instance.set_as_toplevel(true)
	add_child(_voxel_mesh_instance)
	if OS.has_feature("Server"):
		set_process(false)
		set_physics_process(false)


func _process(_delta: float) -> void:
	if _voxel_mesh.dirty:
		_voxel_mesh.generate()
	var frac := Engine.get_physics_interpolation_fraction()
	var trf := _prev_transform.interpolate_with(_next_transform, frac)
	_voxel_mesh_instance.transform = trf
	_voxel_mesh_instance.translation -= trf.basis * center_of_mass
	visual_translation = trf.origin


func _physics_process(_delta: float) -> void:
	_prev_transform = _next_transform
	_next_transform = transform


func debug_draw():
	for hit in _debug_hits:
		var position = Vector3(hit[0][0], hit[0][1], hit[0][2]) + Vector3.ONE / 2
		Debug.draw_point(to_global(position * Block.BLOCK_SCALE - center_of_mass),
				hit[1], 0.55 * Block.BLOCK_SCALE)


func fix_physics():
	cost = max_cost
	_set_collision_box(start_position, end_position)
	_correct_mass()
	global_transform = Transform(Basis.IDENTITY, center_of_mass)


func projectile_hit(origin: Vector3, direction: Vector3, damage: int) -> int:
	var local_origin := to_local(origin) + center_of_mass
	local_origin /= Block.BLOCK_SCALE
	var local_direction := to_local(origin + direction) - to_local(origin)
	_raycast.start(local_origin, local_direction, 25, 25, 25)
	_debug_hits = []
	while not _raycast.finished:
		var key := [_raycast.x, _raycast.y, _raycast.z]
		var block: BodyBlock = blocks.get(key)
		if block != null:
			_debug_hits.append([key, Color.orange])
			if block.health < damage:
				damage -= block.health
				if block.node != null:
					block.node.queue_free()
				_voxel_mesh.remove_block(_raycast.voxel)
				# warning-ignore:return_value_discarded
				blocks.erase(key)
				cost -= Block.get_block_by_id(block.id).cost
			else:
				block.health -= damage
				damage = 0
				break
		else:
			_debug_hits.append([key, Color.yellow])
		_raycast.step()
	emit_signal("hit", self)
	return damage


func spawn_block(x: int, y: int, z: int, r: int, block: Block, color: Color) -> void:
	var basis := Block.rotation_to_basis(r)
	var node: Spatial = null
	var position = Vector3(x, y, z) + Vector3.ONE / 2
	_voxel_mesh.add_block(block, color, [x, y, z], r)
	if block.scene != null:
		node = block.scene.instance()
		node.transform = Transform(basis, position * Block.BLOCK_SCALE)
		add_child(node)
		var material = MaterialCache.get_material(color)
		for child in get_children_recursive(node) + [node]:
			if child is GeometryInstance and not child is Sprite3D:
				var set_override := true
				if child is MeshInstance:
					for i in range(child.get_surface_material_count()):
						if child.get_surface_material(i) != null:
							set_override = false
							break
				if set_override:
					child.material_override = material
	max_cost += block.cost
	max_health += block.health
	blocks[[x, y, z]] = BodyBlock.new(block, node, r, color)
	start_position.x = float(x) if start_position.x > x else start_position.x
	start_position.y = float(y) if start_position.y > y else start_position.y
	start_position.z = float(z) if start_position.z > z else start_position.z
	end_position.x = float(x) if end_position.x < x else end_position.x
	end_position.y = float(y) if end_position.y < y else end_position.y
	end_position.z = float(z) if end_position.z < z else end_position.z
	if node is VehicleWheel:
		wheels.append(node)
	elif node is OwnWar_Weapon:
		weapons.append(node)


func coordinate_to_vector(coordinate):
	var position = Vector3(coordinate[0], coordinate[1], coordinate[2])
	position *= Block.BLOCK_SCALE
	return position - center_of_mass


func init_blocks(vehicle, meta):
	for coordinate in blocks:
		var block: BodyBlock = blocks[coordinate]
		if block.node == null:
			continue
		var meta_data = meta.get(coordinate)
		if block.node.has_method("init"):
			# warning-ignore:unsafe_method_access
			block.node.init(coordinate, block, -1, self, vehicle, meta_data)
		else:
			for child in block.node.get_children():
				if child.has_method("init"):
					child.init(coordinate, block, -1, self, vehicle, meta_data)


func _set_collision_box(start: Vector3, end: Vector3) -> void:
	end += Vector3.ONE
	var center := (start + end) / 2
	var extents := (end - start) / 2
	_collision_shape.transform.origin = center * Block.BLOCK_SCALE
	var shape: BoxShape = _collision_shape.shape
	shape.extents = extents * Block.BLOCK_SCALE


func _correct_mass() -> void:
	var total_mass := 0.0
	center_of_mass = Vector3.ZERO
	for coordinate in blocks:
		var block: BodyBlock = blocks[coordinate]
		var block_mass: float = Block.get_block_by_id(block.id).mass
		center_of_mass += Vector3(coordinate[0], coordinate[1], coordinate[2]) * block_mass
		total_mass += block_mass
	assert(total_mass > 0)
	center_of_mass /= total_mass
	center_of_mass += Vector3.ONE * 0.5
	center_of_mass *= Block.BLOCK_SCALE
	for child in get_children():
		child.translation -= center_of_mass
		if child is VehicleWheel:
			remove_child(child) # Necessary to force VehicleWheel to move
			add_child(child)    # See VehicleWheel3D::_notification in vehicle_body_3d.cpp:81
			var angle := atan2(child.translation.z, child.translation.x)
			if angle > PI / 2:
				angle = PI - angle
			elif angle < -PI / 2:
				angle = -PI - angle
			child.max_angle = angle
	mass = total_mass


# REEEEEEE https://github.com/godotengine/godot/issues/16105
func get_children_recursive(node = null, array = []):
	node = node if node != null else self
	for child in node.get_children():
		array.append(child)
		get_children_recursive(child, array)
	return array