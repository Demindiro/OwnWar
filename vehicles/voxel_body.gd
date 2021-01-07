extends VehicleBody


const VoxelMesh := preload("voxel_mesh.gd")


class InterpolationData:
	var server_node: Spatial
	var client_node: Spatial
	var prev_transform: Transform
	var curr_transform: Transform
	var interpolate_dirty := false

	func _init(block: OwnWar_Block) -> void:
		if block.server_node != null:
			server_node = block.server_node.duplicate()
		if block.client_node != null:
			client_node = block.client_node.duplicate()


signal hit(voxel_body)
var center_of_mass := Vector3.ZERO
var cost := 0
var max_cost := 0
var max_health := 0
var wheels := []
var weapons := []
var team := -1
var last_hit_position := Vector3()
var _debug_hits := []
var _raycast := preload("res://addons/voxel_raycast.gd").new()
var _collision_shape: CollisionShape
var _voxel_mesh := VoxelMesh.new()
var _voxel_mesh_instance := MeshInstance.new()
var _interpolation_dirty := true
var _curr_transform := transform
var _prev_transform := transform
var _interpolate_blocks := []

var _block_ids := PoolIntArray()
var _block_health := PoolIntArray()
var _block_health_alt := PoolIntArray()
var _block_server_nodes := []
var _block_client_nodes := []
var _block_reverse_index := []

var aabb := AABB() setget set_aabb


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
	if _interpolation_dirty:
		_prev_transform = _curr_transform
		_curr_transform = transform
		_interpolation_dirty = false
	var frac := Engine.get_physics_interpolation_fraction()
	var trf := _prev_transform.interpolate_with(transform, frac)
	_voxel_mesh_instance.transform = trf
	_voxel_mesh_instance.translation -= trf.basis * center_of_mass
	for block in _interpolate_blocks:
		var bb: InterpolationData = block
		if bb.interpolate_dirty:
			bb.prev_transform = bb.curr_transform
			bb.curr_transform = bb.server_node.global_transform
			bb.interpolate_dirty = false
		bb.client_node.global_transform = bb.prev_transform.interpolate_with(
			bb.curr_transform,
			Engine.get_physics_interpolation_fraction()
		)


func _physics_process(_delta: float) -> void:
	if _interpolation_dirty:
		_prev_transform = _curr_transform
		_curr_transform = transform
	_interpolation_dirty = true
	for block in _interpolate_blocks:
		var bb: InterpolationData = block
		if bb.interpolate_dirty:
			bb.prev_transform = bb.curr_transform
			bb.curr_transform = bb.server_node.global_transform
			bb.interpolate_dirty = false
		bb.interpolate_dirty = true


func debug_draw():
	for hit in _debug_hits:
		var position = Vector3(hit[0][0], hit[0][1], hit[0][2]) + Vector3.ONE / 2
		Debug.draw_point(to_global(position * OwnWar_Block.BLOCK_SCALE - center_of_mass),
				hit[1], 0.55 * OwnWar_Block.BLOCK_SCALE)


func get_visual_transform() -> Transform:
	return _voxel_mesh_instance.transform.translated(center_of_mass)


func fix_physics():
	cost = max_cost
	var middle := aabb.size / 2 * OwnWar_Block.BLOCK_SCALE
	_collision_shape.transform.origin = middle
	_collision_shape.shape.extents = middle
	_correct_mass()
	global_transform = Transform(Basis(), center_of_mass + aabb.position * OwnWar_Block.BLOCK_SCALE)


func apply_damage(origin: Vector3, direction: Vector3, damage: int) -> int:
	var local_origin := to_local(origin) + center_of_mass
	local_origin /= OwnWar_Block.BLOCK_SCALE
	var local_direction := to_local(origin + direction) - to_local(origin)
	_raycast.start(local_origin, local_direction, aabb.size.x, aabb.size.y, aabb.size.z)
	_debug_hits = []
	if _raycast.finished:
		return damage
	if _raycast.x >= aabb.size.x or _raycast.y >= aabb.size.y or _raycast.z >= aabb.size.z:
		# TODO fix the raycast algorithm
		_raycast.step()
	while not _raycast.finished:
		var key := [_raycast.x, _raycast.y, _raycast.z]
		assert(_raycast.x < aabb.size.x)
		assert(_raycast.y < aabb.size.y)
		assert(_raycast.z < aabb.size.z)
		var index := int(
			_raycast.x * aabb.size.y * aabb.size.z + \
			_raycast.y * aabb.size.z + \
			_raycast.z
		)
		var val := _block_health[index]
		if val != 0:
			_debug_hits.append([key, Color.orange])
			if val & 0x8000:
				var alt_index := val & 0x7fff
				var hp := _block_health_alt[alt_index]
				assert(hp >= 0)
				if hp <= damage:
					damage -= hp
					_block_health_alt[alt_index] = 0
					var node: Spatial = _block_server_nodes[alt_index]
					if node != null:
						node.queue_free()
						_block_server_nodes[alt_index] = null
					node = _block_client_nodes[alt_index]
					if node != null:
						node.queue_free()
						_block_client_nodes[alt_index] = null
					_voxel_mesh.remove_block(_raycast.voxel)
					cost -= OwnWar_Block.get_block_by_id(_block_ids[index]).cost
					for i in _block_reverse_index[alt_index]:
						_block_health[i] = 0
				else:
					_block_health_alt[alt_index] = hp - damage
					damage = 0
					break
			else:
				var hp := val
				if hp <= damage:
					damage -= hp
					_voxel_mesh.remove_block(_raycast.voxel)
					cost -= OwnWar_Block.get_block_by_id(_block_ids[index]).cost
					_block_health[index] = 0
				else:
					_block_health[index] -= damage
					damage = 0
					break
		else:
			_debug_hits.append([key, Color.yellow])
		_raycast.step()
	last_hit_position = Vector3(_raycast.x, _raycast.y, _raycast.z)
	emit_signal("hit", self)
	return damage


func can_ray_pass_through(origin: Vector3, direction: Vector3) -> bool:
	var local_origin := to_local(origin) + center_of_mass
	local_origin /= OwnWar_Block.BLOCK_SCALE
	var local_direction := to_local(origin + direction) - to_local(origin)
	_raycast.start(local_origin, local_direction, aabb.size.x, aabb.size.y, aabb.size.z)
	if _raycast.finished:
		return true
	if _raycast.x >= aabb.size.x or _raycast.y >= aabb.size.y or _raycast.z >= aabb.size.z:
		# TODO fix the raycast algorithm
		_raycast.step()
	while not _raycast.finished:
		var index := int(
			_raycast.x * aabb.size.y * aabb.size.z + \
			_raycast.y * aabb.size.z + \
			_raycast.z
		)
		if _block_health[index] != 0:
			return false
		_raycast.step()
	return true


func spawn_block(position: Vector3, r: int, block: OwnWar_Block, color: Color) -> void:
	position -= aabb.position
	assert(position.x >= 0, "Position out of bounds (Corrupt data?)")
	assert(position.y >= 0, "Position out of bounds (Corrupt data?)")
	assert(position.z >= 0, "Position out of bounds (Corrupt data?)")
	assert(position.x < aabb.size.x, "Position out of bounds (Corrupt data?)")
	assert(position.y < aabb.size.y, "Position out of bounds (Corrupt data?)")
	assert(position.z < aabb.size.z, "Position out of bounds (Corrupt data?)")
	var basis := OwnWar_Block.rotation_to_basis(r)
	var pos := position + Vector3.ONE / 2
	_voxel_mesh.add_block(block, color, [int(position.x), int(position.y), int(position.z)], r)
	var bb := InterpolationData.new(block)
	if bb.server_node != null:
		bb.server_node.transform = Transform(basis, pos * OwnWar_Block.BLOCK_SCALE)
		add_child(bb.server_node)
	if bb.client_node != null:
		bb.client_node.transform = Transform(basis, pos * OwnWar_Block.BLOCK_SCALE)
		bb.prev_transform = bb.client_node.transform
		bb.curr_transform = bb.client_node.transform
		add_child(bb.client_node)
		if bb.client_node.has_method("set_color"):
			bb.client_node.set_color(color)
		if bb.server_node == null:
			bb.server_node = Spatial.new()
			bb.server_node.transform = bb.client_node.transform
			add_child(bb.server_node)
		if "server_node" in bb.client_node:
			bb.client_node.server_node = bb.server_node
		bb.client_node.set_as_toplevel(true)
		_interpolate_blocks.push_back(bb)
		var e := bb.client_node.connect("tree_exiting", self, "_remove_interpolator", [bb])
		assert(e == OK)
		e = bb.server_node.connect("tree_exiting", self, "_remove_interpolator", [bb])
		assert(e == OK)
	var index := int(position.x * aabb.size.y * aabb.size.z + position.y * aabb.size.z + position.z)
	if bb.server_node == null:
		_block_health[index] = block.health
	else:
		var index_alt := len(_block_health_alt)
		assert(index_alt < (1 << 16), "Alt index out of bounds")
		_block_health_alt.push_back(block.health)
		_block_server_nodes.push_back(bb.server_node)
		_block_client_nodes.push_back(bb.client_node)
		_block_reverse_index.push_back(PoolIntArray([index]))
		_block_health[index] = index_alt | 0x8000
		if bb.server_node is VehicleWheel:
			wheels.append(bb.server_node)
		elif bb.server_node is OwnWar_Weapon:
			weapons.append(bb.server_node)
	_block_ids[index] = block.id
	max_cost += block.cost
	max_health += block.health


func coordinate_to_vector(coordinate):
	var position = Vector3(coordinate[0], coordinate[1], coordinate[2])
	position *= OwnWar_Block.BLOCK_SCALE
	return position - center_of_mass


func init_blocks(vehicle) -> void:
	var sx := int(aabb.size.x)
	var sy := int(aabb.size.y)
	var sz := int(aabb.size.z)
	for index_alt in len(_block_server_nodes):
		# TODO what about multi-voxel blocks?
		var index: int = _block_reverse_index[index_alt][0]
		var node = _block_server_nodes[index_alt]
		if node != null:
			if "team" in node:
				node.team = team
			if node.has_method("init"):
				var z := index % sz
				var y := (index / sz) % sy
				var x := index / sz / sy
				assert(x < sx and y < sy and z < sz)
				node.init(Vector3(x, y, z) + aabb.position, self, vehicle)


func _correct_mass() -> void:
	var total_mass := 0.0
	center_of_mass = Vector3.ZERO
	var sx := int(aabb.size.x)
	var sy := int(aabb.size.y)
	var sz := int(aabb.size.z)
	for x in sx:
		for y in sy:
			for z in sz:
				var id := _block_ids[x * sy * sz + y * sz + z]
				var block_mass: float = OwnWar_Block.get_block_by_id(id).mass
				center_of_mass += Vector3(x, y, z) * block_mass
				total_mass += block_mass
	assert(total_mass > 0)
	center_of_mass /= total_mass
	center_of_mass += Vector3.ONE * 0.5
	center_of_mass *= OwnWar_Block.BLOCK_SCALE
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


func _remove_interpolator(interp: InterpolationData) -> void:
	assert(interp != null)
	_interpolate_blocks.erase(interp)


# REEEEEEE https://github.com/godotengine/godot/issues/16105
func get_children_recursive(node = null, array = []):
	node = node if node != null else self
	for child in node.get_children():
		array.append(child)
		get_children_recursive(child, array)
	return array


func get_block_id(position: Vector3) -> int:
	position -= aabb.position
	if position.x < 0 or position.y < 0 or position.z < 0 or \
		position.x >= aabb.size.x or position.y >= aabb.size.y or position.z >= aabb.size.z:
		return -1
	var index := int(position.x * aabb.size.y * aabb.size.z + position.y * aabb.size.z + position.z)
	return _block_ids[index]


func set_aabb(value: AABB) -> void:
	assert(aabb == AABB(), "AABB already set")
	aabb = value
	var size := int(aabb.size.x * aabb.size.y * aabb.size.z)
	_block_health.resize(size)
	_block_ids.resize(size)
	# Slooooow
	for i in size:
		_block_health[i] = 0
		_block_ids[i] = 0
