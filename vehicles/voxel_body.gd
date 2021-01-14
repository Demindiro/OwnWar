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
signal destroyed()

const DESTROY_BLOCK_EFFECT_SCENE := preload("destroy_block_effect.tscn")
const DESTROY_BODY_EFFECT_SCENE := preload("destroy_body_effect.tscn")

var center_of_mass := Vector3.ZERO
var cost := 0
var max_cost := 0
var max_health := 0
var block_count := 0
var wheels := []
var weapons := []
var team := -1
var aabb := AABB() setget set_aabb
var last_hit_position := Vector3()
var id := -1
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
var _block_anchors := {}
var _block_has_mainframe := false

onready var server_mode := get_tree().multiplayer.is_network_server()
onready var headless := OS.has_feature("Server")

onready var _mainframe_id: int = OwnWar_Block.get_block("mainframe").id


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


func _exit_tree() -> void:
	if not headless:
		var node: CPUParticles = DESTROY_BODY_EFFECT_SCENE.instance()
		node.translation = translation
		# This is potentially a really bad idea and may need to be capped
		node.amount = 4 * block_count
		get_tree().current_scene.call_deferred("add_child", node)


func debug_draw():
	for hit in _debug_hits:
		var position = Vector3(hit[0][0], hit[0][1], hit[0][2]) + Vector3.ONE / 2
		Debug.draw_point(to_global(position * OwnWar_Block.BLOCK_SCALE - center_of_mass),
				hit[1], 0.55 * OwnWar_Block.BLOCK_SCALE)
	for ii in _block_anchors:
		var i:int = ii
		var sy := int(aabb.size.y)
		var sz := int(aabb.size.z)
		var x := i / sz / sy
		var y := i / sz % sy
		var z := i % sz
		Debug.draw_point(to_global(Vector3(x + 0.5, y + 0.5, z + 0.5) * OwnWar_Block.BLOCK_SCALE - center_of_mass),
			Color.green, 0.15)


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
	assert(is_network_master(), "This shouldn't be called on the client ever, use the local version")
	var local_origin := to_local(origin) + center_of_mass
	local_origin /= OwnWar_Block.BLOCK_SCALE
	var local_direction := to_local(origin + direction) - to_local(origin)
	return apply_damage_local(local_origin, local_direction, damage)


puppet func apply_damage_local(origin: Vector3, direction: Vector3, damage: int) -> int:
	if is_network_master():
		rpc_id(-OwnWar_NetInfo.disable_broadcast_id, "apply_damage_local", origin, direction, damage)
	var block_anchor_destroyed := false
	var sx := int(aabb.size.x)
	var sy := int(aabb.size.y)
	var sz := int(aabb.size.z)
	_raycast.start(origin, direction, sx, sy, sz)
	_debug_hits = []
	if _raycast.finished:
		return damage
	if _raycast.x >= sx or _raycast.y >= sy or _raycast.z >= sz or \
		_raycast.x < 0 or _raycast.y < 0 or _raycast.z < 0:
		# TODO fix the raycast algorithm
		_raycast.step()
	var destroyed_blocks := PoolIntArray()
	while not _raycast.finished:
		var key: Array = _raycast.voxel
		var pos := Vector3(_raycast.x, _raycast.y, _raycast.z)
		assert(_raycast.x < sx)
		assert(_raycast.y < sy)
		assert(_raycast.z < sz)
		assert(_raycast.x >= 0)
		assert(_raycast.y >= 0)
		assert(_raycast.z >= 0)
		var index := _raycast.x * sz * sy + _raycast.y * sz + _raycast.z
		assert(index >= 0)
		var val := _block_health[index]
		if val != 0:
			if not headless:
				_debug_hits.append([key, Color.orange])
				var node: Spatial = DESTROY_BLOCK_EFFECT_SCENE.instance()
				node.translation = to_global(pos * OwnWar_Block.BLOCK_SCALE - center_of_mass)
				get_tree().current_scene.add_child(node)
			if val & 0x8000:
				var alt_index := val & 0x7fff
				assert(alt_index >= 0)
				var hp := _block_health_alt[alt_index]
				assert(hp >= 0)
				if hp <= damage:
					damage -= hp
					for i in _block_reverse_index[alt_index]:
						_block_health[i] = 0
						block_count -= 1
						if i in _block_anchors:
							remove_all_anchors(index, _raycast.x, _raycast.y, _raycast.z)
							block_anchor_destroyed = true
					assert(_verify_block_count())
					_block_health_alt[alt_index] = 0
					var node: Spatial = _block_server_nodes[alt_index]
					if node != null:
						assert(not node.is_queued_for_deletion())
						node.queue_free()
						if node.has_method("destroy"):
							node.destroy()
						_block_server_nodes[alt_index] = null
					node = _block_client_nodes[alt_index]
					if node != null:
						node.queue_free()
						_block_client_nodes[alt_index] = null
					_voxel_mesh.remove_block(_raycast.voxel)
					cost -= OwnWar_Block.get_block_by_id(_block_ids[index]).cost
					destroyed_blocks.push_back(index)
					if _block_ids[index] == _mainframe_id:
						assert(_block_has_mainframe)
						get_parent().queue_free()
				else:
					_block_health_alt[alt_index] = hp - damage
					damage = 0
					break
			else:
				var hp := val
				if hp <= damage:
					damage -= hp
					_block_health[index] = 0
					block_count -= 1
					assert(_verify_block_count())
					if index in _block_anchors:
						remove_all_anchors(index, _raycast.x, _raycast.y, _raycast.z)
						block_anchor_destroyed = true
					_voxel_mesh.remove_block(_raycast.voxel)
					cost -= OwnWar_Block.get_block_by_id(_block_ids[index]).cost
					destroyed_blocks.push_back(index)
					# Don't do the check in release builds as a small optimization, but keep an
					# assert just in case things change (e.g. mainframe has no server_node anymore).
					assert(_block_ids[index] != _mainframe_id)
				else:
					_block_health[index] -= damage
					damage = 0
					break
		else:
			_debug_hits.append([key, Color.yellow])
		_raycast.step()
	last_hit_position = Vector3(_raycast.x, _raycast.y, _raycast.z)
	emit_signal("hit", self)
	_destroy_disconnected_blocks(destroyed_blocks, block_anchor_destroyed)
	return damage


func can_ray_pass_through(origin: Vector3, direction: Vector3) -> bool:
	var sx := int(aabb.size.x)
	var sy := int(aabb.size.y)
	var sz := int(aabb.size.z)
	var local_origin := to_local(origin) + center_of_mass
	local_origin /= OwnWar_Block.BLOCK_SCALE
	var local_direction := to_local(origin + direction) - to_local(origin)
	_raycast.start(local_origin, local_direction, sx, sy, sz)
	if _raycast.finished:
		return true
	if _raycast.x >= sx or _raycast.y >= sy or _raycast.z >= sz:
		# TODO fix the raycast algorithm
		_raycast.step()
	while not _raycast.finished:
		var index := _raycast.x * sy * sz + _raycast.y * sz + _raycast.z
		if _block_health[index] != 0:
			return false
		_raycast.step()
	return true


func spawn_block(position: Vector3, r: int, block: OwnWar_Block, color: Color, state := []) -> void:
	var sx := int(aabb.size.x)
	var sy := int(aabb.size.y)
	var sz := int(aabb.size.z)
	position -= aabb.position
	assert(position.x >= 0, "Position out of bounds (Corrupt data?)")
	assert(position.y >= 0, "Position out of bounds (Corrupt data?)")
	assert(position.z >= 0, "Position out of bounds (Corrupt data?)")
	assert(position.x < sx, "Position out of bounds (Corrupt data?)")
	assert(position.y < sy, "Position out of bounds (Corrupt data?)")
	assert(position.z < sz, "Position out of bounds (Corrupt data?)")
	var index := int(position.x * sy * sz + position.y * sz + position.z)
	_block_ids[index] = block.id
	if len(state) > 0 and state[0][index] == 0:
		# Include client node because of implicit spatial (may be removed in the future because of
		# this)
		if block.server_node != null or block.client_node != null:
			_block_health_alt.push_back(0)
			_block_server_nodes.push_back(null)
			_block_client_nodes.push_back(null)
			_block_reverse_index.push_back(PoolIntArray([index]))
		return
	_voxel_mesh.add_block(block, color, [int(position.x), int(position.y), int(position.z)], r)
	var basis := OwnWar_Block.rotation_to_basis(r)
	var pos := position + Vector3.ONE / 2
	var bb := InterpolationData.new(block)
	if bb.server_node != null:
		bb.server_node.name = "S %d" % index
		bb.server_node.transform = Transform(basis, pos * OwnWar_Block.BLOCK_SCALE)
		add_child(bb.server_node)
	if bb.client_node != null:
		bb.client_node.name = "C %d" % index
		bb.client_node.transform = Transform(basis, pos * OwnWar_Block.BLOCK_SCALE)
		bb.prev_transform = bb.client_node.transform
		bb.curr_transform = bb.client_node.transform
		add_child(bb.client_node)
		if bb.client_node.has_method("set_color"):
			bb.client_node.set_color(color)
		if bb.server_node == null:
			bb.server_node = Spatial.new()
			bb.server_node.name = "Sc %d" % index
			bb.server_node.transform = bb.client_node.transform
			add_child(bb.server_node)
		if "server_node" in bb.client_node:
			bb.client_node.server_node = bb.server_node
		bb.client_node.set_as_toplevel(true)
		_interpolate_blocks.push_back(bb)
		var e := bb.server_node.connect("tree_exiting", self, "_remove_interpolator", [bb])
		assert(e == OK)
	var index_alt := -1
	if bb.server_node == null:
		_block_health[index] = block.health
	else:
		index_alt = len(_block_health_alt)
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
	max_cost += block.cost
	if len(state) == 0:
		max_health += block.health
	else:
		if state[0][index] & 0x8000:
			var i: int = state[0][index] & 0x7fff
			assert(index_alt == i)
			_block_health_alt[i] = state[1][i]
		else:
			assert(index_alt < 0)
			_block_health[index] = state[0][index]
			max_cost += _block_health[index]
	block_count += 1
	assert(_verify_block_count())
	if block.name == "mainframe":
		assert(not _block_has_mainframe, "Body already has a mainframe!")
		_block_has_mainframe = true


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


func add_anchor(coordinate: Vector3, body: VehicleBody) -> void:
	assert(body != null)
	coordinate -= aabb.position
	assert(coordinate.x >= 0)
	assert(coordinate.y >= 0)
	assert(coordinate.z >= 0)
	assert(coordinate.x < aabb.size.x)
	assert(coordinate.y < aabb.size.y)
	assert(coordinate.z < aabb.size.z)
	var index := int(
		coordinate.x * aabb.size.z * aabb.size.y + \
		coordinate.y * aabb.size.z + \
		coordinate.z
	)
	var arr = _block_anchors.get(index)
	if arr == null:
		_block_anchors[index] = [body]
	else:
		arr.push_back(body)
	if not body.is_connected("destroyed", self, "_remove_anchored_body"):
		var e := body.connect("destroyed", self, "_remove_anchored_body", [body])
		assert(e == OK)


func remove_anchor(coordinate: Vector3, body: VehicleBody) -> void:
	assert(body != null)
	coordinate -= aabb.position
	var x := int(coordinate.x)
	var y := int(coordinate.y)
	var z := int(coordinate.z)
	var sx := int(aabb.size.x)
	var sy := int(aabb.size.y)
	var sz := int(aabb.size.z)
	assert(coordinate.x >= 0)
	assert(coordinate.y >= 0)
	assert(coordinate.z >= 0)
	assert(coordinate.x < aabb.size.x)
	assert(coordinate.y < aabb.size.y)
	assert(coordinate.z < aabb.size.z)
	var index := x * sz * sy + y * sz + z
	var arr = _block_anchors.get(index)
	if arr != null:
		arr.erase(body)
		if len(arr) == 0:
			var _e := _block_anchors.erase(index)
		else:
			# There are still anchors present, so it isn't disconnected
			return
	else:
		# The anchor was already removed, nothing to do here
		return
	var connect_count := 0
	if x < sx - 1 and _block_health[index + sy * sz] != 0:
		connect_count += 1
	if x > 0 and _block_health[index - sy * sz] != 0:
		connect_count += 1
	if y < sy - 1 and _block_health[index + sz] != 0:
		connect_count += 1
	if y > 0 and _block_health[index - sz] != 0:
		connect_count += 1
	if z < sz - 1 and _block_health[index + 1] != 0:
		connect_count += 1
	if z > 0 and _block_health[index - 1] != 0:
		connect_count += 1
	if connect_count == 0:
		_voxel_mesh.remove_block([x, y, z])
		var val := _block_health[index]
		if val != 0:
			_block_health[index] = 0
			block_count -= 1
			assert(_verify_block_count())
			if block_count == 0:
				queue_free()
				emit_signal("destroyed")
			elif val & 0x8000:
				var i := val & 0x7fff
				_block_health_alt[i] = 0
				var node = _block_server_nodes[i]
				if node != null:
					assert(not node.is_queued_for_deletion())
					node.queue_free()
					if node.has_method("destroy"):
						node.destroy()
					_block_server_nodes[i] = null
	else:
		_destroy_disconnected_blocks(PoolIntArray([index]), true, true)


func remove_all_anchors(index: int, x: int, y: int, z: int) -> void:
	var sx := int(aabb.size.x)
	var sy := int(aabb.size.y)
	var sz := int(aabb.size.z)
	var e := _block_anchors.erase(index)
	assert(e)
	var connect_count := 0
	if x < sx - 1 and _block_health[index + sy * sz] != 0:
		connect_count += 1
	if x > 0 and _block_health[index - sy * sz] != 0:
		connect_count += 1
	if y < sy - 1 and _block_health[index + sz] != 0:
		connect_count += 1
	if y > 0 and _block_health[index - sz] != 0:
		connect_count += 1
	if z < sz - 1 and _block_health[index + 1] != 0:
		connect_count += 1
	if z > 0 and _block_health[index - 1] != 0:
		connect_count += 1
	if connect_count > 0:
		_destroy_disconnected_blocks(PoolIntArray([index]), true, true)


func _remove_anchored_body(body) -> void:
	var indices := PoolIntArray()
	for index in _block_anchors:
		var arr: Array = _block_anchors[index]
		while true:
			var i := arr.find_last(body)
			if i < 0:
				break
			arr.remove(i)
		if len(arr) == 0:
			indices.push_back(index)
	for i in indices:
		var _e := _block_anchors.erase(i)
	_destroy_disconnected_blocks(PoolIntArray(), true)


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
	if interp.client_node != null:
		# queue_free is necessary to prevent the debug build from crashing.
		# I should report this as a bug but I don't have time to create a reproduction so... TODO
		interp.client_node.queue_free()
		interp.client_node = null
	_interpolate_blocks.erase(interp)


func _is_connected_to_mainframe(marks := []) -> bool:
	marks.push_back(self)
	for index in _block_anchors:
		for body in _block_anchors[index]:
			if body in marks:
				continue
			if body._block_has_mainframe or body._is_connected_to_mainframe(marks):
				return true
	return false


func _destroy_disconnected_blocks(destroyed_blocks: PoolIntArray, block_anchor_destroyed: bool,
	force_check := false) -> void:
	if get_parent().is_queued_for_deletion():
		return
	if is_queued_for_deletion():
		return
	if not _block_has_mainframe:
		if len(_block_anchors) == 0:
			queue_free()
			emit_signal("destroyed")
			return
		elif block_anchor_destroyed:
			var m := []
			if not _is_connected_to_mainframe(m):
				queue_free()
				emit_signal("destroyed")
				return
	var sx := int(aabb.size.x)
	var sy := int(aabb.size.y)
	var sz := int(aabb.size.z)
	for index_wtf in destroyed_blocks:
		assert(index_wtf >= 0)
		# wdym it has no set type???
		var index: int = index_wtf
		var x := index / sz / sy
		var y := index / sz % sy
		var z := index % sz
		var xpi := index + sy * sz
		var xni := index - sy * sz
		var ypi := index + sz
		var yni := index - sz
		var zpi := index + 1
		var zni := index - 1
		var connect_mask := 0
		var connect_count := 0
		if x < sx - 1 and _block_health[xpi] != 0:
			connect_mask |= 1
			connect_count += 1
		if x > 0 and _block_health[xni] != 0:
			connect_mask |= 2
			connect_count += 1
		if y < sy - 1 and _block_health[ypi] != 0:
			connect_mask |= 4
			connect_count += 1
		if y > 0 and _block_health[yni] != 0:
			connect_mask |= 8
			connect_count += 1
		if z < sz - 1 and _block_health[zpi] != 0:
			connect_mask |= 16
			connect_count += 1
		if z > 0 and _block_health[zni] != 0:
			connect_mask |= 32
			connect_count += 1
		# 0 = there is nothing anyways
		# 1 = there is only one connecting, which must have been connected to
		# the core, otherwise this block would already have been destroyed
		# >2 = we must check because any of the neighbours may have become
		# disconnected
		if force_check or connect_count > 1:
			var mi := 0
			while mi < 6:
				var m: int = connect_mask & (1 << mi)
				if m:
					var i: int
					var xi := x
					var yi := y
					var zi := z
					match m:
						1:
							i = xpi; xi += 1
						2:
							i = xni; xi -= 1
						4:
							i = ypi; yi += 1
						8:
							i = yni; yi -= 1
						16:
							i = zpi; zi += 1
						32:
							i = zni; zi -= 1
						_: assert(false)
					assert(xi >= 0)
					assert(yi >= 0)
					assert(zi >= 0)
					assert(xi < sx)
					assert(yi < sy)
					assert(zi < sz)
					var marks := BitMap.new()
					marks.create(Vector2(sx, sy * sz))
					var anchor_found := _mark_connected_blocks(i, xi, yi, zi, marks)
					if anchor_found:
						while mi < 5:
							mi += 1
							m = connect_mask & (1 << mi)
							if m:
								xi = x
								yi = y
								zi = z
								match m:
									1: xi += 1
									2: xi -= 1
									4: yi += 1
									8: yi -= 1
									16: zi += 1
									32: zi -= 1
									_: assert(false)
								if not marks.get_bit(Vector2(xi, yi * sz + zi)):
									# Substract because there is an addition later
									mi -= 1
									break
					else:
						_destroy_connected_blocks(i, xi, yi, zi)
				mi += 1
		if block_count == 0:
			emit_signal("destroyed")
			queue_free()


func _mark_connected_blocks(index: int, x: int, y: int, z: int, bitmap: BitMap, found := false) -> bool:
	var sx := int(aabb.size.x)
	var sy := int(aabb.size.y)
	var sz := int(aabb.size.z)
	bitmap.set_bit(Vector2(x, y * sz + z), 1)
	if not found:
		if _block_has_mainframe:
			found = _block_ids[index] == _mainframe_id
		else:
			found = index in _block_anchors
	if x < sx - 1:
		var i := index + sy * sz
		var xi := x + 1
		if not bitmap.get_bit(Vector2(xi, y * sz + z)) and _block_health[i]:
			found = _mark_connected_blocks(i, xi, y, z, bitmap, found)
	if x > 0:
		var i := index - sy * sz
		var xi := x - 1
		if not bitmap.get_bit(Vector2(xi, y * sz + z)) and _block_health[i]:
			found = _mark_connected_blocks(i, xi, y, z, bitmap, found)
	if y < sy - 1:
		var i := index + sz
		var yi := y + 1
		if not bitmap.get_bit(Vector2(x, yi * sz + z)) and _block_health[i]:
			found = _mark_connected_blocks(i, x, yi, z, bitmap, found)
	if y > 0:
		var i := index - sz
		var yi := y - 1
		if not bitmap.get_bit(Vector2(x, yi * sz + z)) and _block_health[i]:
			found = _mark_connected_blocks(i, x, yi, z, bitmap, found)
	if z < sz - 1:
		var i := index + 1
		var zi := z + 1
		if not bitmap.get_bit(Vector2(x, y * sz + zi)) and _block_health[i]:
			found = _mark_connected_blocks(i, x, y, zi, bitmap, found)
	if z > 0:
		var i := index - 1
		var zi := z - 1
		if not bitmap.get_bit(Vector2(x, y * sz + zi)) and _block_health[i]:
			found = _mark_connected_blocks(i, x, y, zi, bitmap, found)
	return found


func _destroy_connected_blocks(index: int, x: int, y: int, z: int) -> void:
	if not headless:
		var node: Spatial = DESTROY_BLOCK_EFFECT_SCENE.instance()
		var pos := Vector3(x, y, z)
		pos *= OwnWar_Block.BLOCK_SCALE
		pos -= center_of_mass
		node.translation = to_global(pos)
		get_tree().current_scene.add_child(node)
	_voxel_mesh.remove_block([x, y, z])
	var val := _block_health[index]
	if val != 0:
		_block_health[index] = 0
		block_count -= 1
		assert(_verify_block_count())
		if val & 0x8000:
			var i := val & 0x7fff
			_block_health_alt[i] = 0
			var node = _block_server_nodes[i]
			if node != null:
				assert(not node.is_queued_for_deletion())
				node.queue_free()
				if node.has_method("destroy"):
					node.destroy()
				_block_server_nodes[i] = null
	var sx := int(aabb.size.x)
	var sy := int(aabb.size.y)
	var sz := int(aabb.size.z)
	if x < sx - 1:
		var i := index + sy * sz
		if _block_health[i]:
			_destroy_connected_blocks(i, x + 1, y, z)
	if x > 0:
		var i := index - sy * sz
		if _block_health[i]:
			_destroy_connected_blocks(i, x - 1, y, z)
	if y < sy - 1:
		var i := index + sz
		if _block_health[i]:
			_destroy_connected_blocks(i, x, y + 1, z)
	if y > 0:
		var i := index - sz
		if _block_health[i]:
			_destroy_connected_blocks(i, x, y - 1, z)
	if z < sz - 1:
		var i := index + 1
		if _block_health[i]:
			_destroy_connected_blocks(i, x, y, z + 1)
	if z > 0:
		var i := index - 1
		if _block_health[i]:
			_destroy_connected_blocks(i, x, y, z - 1)


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


func _verify_block_count() -> bool:
	var c := 0
	for v in _block_health:
		if v != 0:
			c += 1
	if block_count != c:
		printt("Mismatch!", block_count, c)
	return block_count == c
