tool
extends Spatial
class_name OwnWar_Vehicle


const Compatibility := preload("res://core/compatibility.gd")
const VoxelBody := preload("voxel_body.gd")
const VoxelMesh := preload("voxel_mesh.gd")


const MANAGERS := {}

var team := -1
var is_ally := false

var max_cost: int
var voxel_bodies := []
var wheels := []
var weapons := []
var fireable_weapons := []

var fireable_weapon_count := 0
var delay_until_next_fire := 0.0
var fired_shots_count := 0
var data: PoolByteArray
var _last_seq_id := 0

var controller := OwnWar_VehicleController.new()
var collisions_with_player := 0
var accept_server_physics := true
var accept_server_physics_timer: SceneTreeTimer = null

var flipping_timeout := 0.0

onready var server_mode := get_tree().is_network_server()
onready var headless := OS.has_feature("Server")


func _init() -> void:
	set_process(not server_mode)


func _ready() -> void:
	set_physics_process(get_tree().network_peer != null)
	add_child(controller)


func _physics_process(delta: float) -> void:
	if not Engine.editor_hint:
		if not server_mode:
			for vb in voxel_bodies:
				if vb != null:
					transform = vb.transform
					break

		if controller.flip:
			var space := get_world().direct_space_state
			for b in voxel_bodies:
				if b == null:
					continue
				var result := space.intersect_ray(
					b.global_transform.origin,
					b.global_transform.origin - Vector3(0, 2, 0),
					voxel_bodies
				)
				if len(result) > 0:
					flipping_timeout = 1.0
					break

		if flipping_timeout > 0:
			var space := get_world().direct_space_state
			var vel_up := 0.0
			for b in voxel_bodies:
				if b == null:
					continue
				b.custom_integrator = true
				var result := space.intersect_ray(
					b.global_transform.origin,
					b.global_transform.origin - Vector3(0, 2, 0),
					voxel_bodies
				)
				if len(result) > 0:
					vel_up = 2
					break
			for b in voxel_bodies:
				if b == null:
					continue
				var vel := Vector3(0, vel_up, 0)
				var xz: Vector3 = b.global_transform.basis.z
				xz = Vector3(xz.x, 0, xz.z).normalized() * 2
				if controller.move_forward:
					vel += xz
				if controller.move_back:
					vel -= xz
				b.linear_velocity = vel
				var rot_diff: Vector3 = b.global_transform.basis.inverse().get_euler() * PI
				rot_diff.y = 0
				if controller.turn_left:
					rot_diff.y += 1.0
				if controller.turn_right:
					rot_diff.y -= 1.0
				b.angular_velocity = rot_diff
			flipping_timeout -= delta
			if flipping_timeout <= 0.0:
				for b in voxel_bodies:
					b.custom_integrator = false
			return

		var drive_yaw := 0.0
		var drive_forward := 0.0
		var drive_brake := 0.0
		if controller.turn_left:
			drive_yaw += 0.3
		if controller.turn_right:
			drive_yaw -= 0.3
		if controller.move_forward:
			drive_forward += 1.0
		if controller.move_back:
			drive_forward -= 1.0
		if not controller.move_forward and not controller.move_back:
			drive_brake = 1.0
			# Reduce brake to prevent jitter
			for b in voxel_bodies:
				if b != null and b.linear_velocity.length_squared() < 1.0:
					drive_brake = 0.2
					break
		for wheel in wheels:
			wheel.steering = drive_yaw * wheel.max_angle
			wheel.brake = drive_brake * wheel.max_brake
			var fraction := 1 - clamp(ease(abs(wheel.get_rpm()) / wheel.max_rpm, 1), 0, 1)
			wheel.engine_force = wheel.max_power * drive_forward * fraction

		for weapon in weapons:
			weapon.aim_at(controller.aim_at)
		if len(fireable_weapons) > 0:
			var avg_delay_between_shots := PoolRealArray(
				[INF, 1.0, 1.0 / 2, 1.0 / 3, 1.0 / 4])[min(len(fireable_weapons), 4)]
			if controller.fire:
				if delay_until_next_fire <= 0:
					var weapon = fireable_weapons[fired_shots_count % len(fireable_weapons)]
					if weapon.fire():
						delay_until_next_fire += avg_delay_between_shots
						fired_shots_count += 1
				delay_until_next_fire -= delta
			elif delay_until_next_fire > 0:
				delay_until_next_fire -= delta
				if delay_until_next_fire < 0:
					delay_until_next_fire = 0

		var state := PoolVector3Array()
		for body in voxel_bodies:
			if body == null:
				state.push_back(Vector3())
				state.push_back(Vector3())
				state.push_back(Vector3())
				state.push_back(Vector3())
				continue
			var trf: Transform = body.transform
			var q := trf.basis.get_rotation_quat()
			if q.w < 0:
				q = -q
			assert(q.w >= 0)
			state.push_back(Vector3(q.x, q.y, q.z))
			state.push_back(trf.origin)
			state.push_back(body.linear_velocity)
			state.push_back(body.angular_velocity)
		if server_mode:
			rpc_unreliable_id(-OwnWar_NetInfo.disable_broadcast_id, "sync_physics",
				Engine.get_physics_frames(), state)
		elif controller.is_network_master():
			rpc_unreliable_id(1, "apply_client_physics", Engine.get_physics_frames(), state)


puppet func sync_physics(seq_id: int, state: PoolVector3Array) -> void:
	if controller.is_network_master():
		return
	if seq_id <= _last_seq_id:
		return
	_last_seq_id = seq_id
	assert(len(voxel_bodies) * 4 == len(state))
	for i in len(voxel_bodies):
		var body: OwnWar.VoxelBody = voxel_bodies[i]
		if body == null:
			# Can happen due to packets being late / out of order
			continue
		i *= 4
		var q := state[i]
		# q.length_squared() is sometimes slightly larger than 1, hence max(0, ...)
		var trf := Transform(Quat(q.x, q.y, q.z, sqrt(max(0, 1 - q.length_squared()))))
		trf.origin = state[i + 1]
		body.transform = trf
		body.linear_velocity = state[i + 2]
		body.angular_velocity = state[i + 3]


# TODO verify client input
master func apply_client_physics(seq_id: int, state: PoolVector3Array) -> void:
	if get_tree().get_rpc_sender_id() != controller.get_network_master():
		assert(false, "A client tried to override another client's input")
		return
	if seq_id <= _last_seq_id:
		return
	_last_seq_id = seq_id
	assert(len(voxel_bodies) * 4 == len(state))
	for i in len(voxel_bodies):
		var body: OwnWar.VoxelBody = voxel_bodies[i]
		if body == null:
			continue
		i *= 4
		var q := state[i]
		# q.length_squared() is sometimes slightly larger than 1, hence max(0, ...)
		var trf := Transform(Quat(q.x, q.y, q.z, sqrt(max(0, 1 - q.length_squared()))))
		trf.origin = state[i + 1]
		body.transform = trf
		body.linear_velocity = state[i + 2]
		body.angular_velocity = state[i + 3]


# TODO apply server correction
puppet func override_physics(state: PoolVector3Array) -> void:
	pass


func get_visual_origin() -> Vector3:
	for vb in voxel_bodies:
		if vb != null:
			return vb.get_visual_transform().origin
	return translation


func load_from_file(path: String) -> int:
	#assert(team >= 0)
	var file := File.new()
	var err := file.open_compressed(path, File.READ, File.COMPRESSION_GZIP)
	if err != OK:
		return err

	return load_from_data(file.get_buffer(file.get_len()))


func load_from_data(data: PoolByteArray, state := []) -> int:
	for body in voxel_bodies:
		if body != null:
			body.queue_free()

	var has_mainframe := false
	var mainframe_id: int = OwnWar_Block.get_block("mainframe").id

	var spb := StreamPeerBuffer.new()
	spb.data_array = data
	self.data = data

	var vb_data_blocks := {}
	var vb_aabbs := {}
	var MAGIC := 493279249 # Totally random, not derived from a name
	var REVISION := 0
	var magic := spb.get_u32()
	if magic != MAGIC:
		print("Magic is wrong! ", magic)
		assert(false)
		return ERR_INVALID_DATA
	var revision := spb.get_u16()
	if revision != REVISION:
		print("Revision doesn't match!")
		assert(false)
		return ERR_INVALID_DATA
	var layer_count := spb.get_u8()
	for _i in layer_count:
		var layer := spb.get_u8()
		if layer in vb_data_blocks:
			print("File data corrupt: double layer %d" % layer)
			assert(false, "File data corrupt: double layer %d" % layer)
			return ERR_INVALID_DATA
		var aabb := AABB()
		aabb.position.x = spb.get_u8()
		aabb.position.y = spb.get_u8()
		aabb.position.z = spb.get_u8()
		aabb.size.x = spb.get_u8()
		aabb.size.y = spb.get_u8()
		aabb.size.z = spb.get_u8()
		vb_aabbs[layer] = aabb
		var vb := []
		vb_data_blocks[layer] = vb
		var size := spb.get_32()
		for _j in size:
			var color := Color()
			var x := spb.get_u8()
			var y := spb.get_u8()
			var z := spb.get_u8()
			var id := spb.get_u16()
			var rot := spb.get_u8()
			color.r8 = spb.get_u8()
			color.g8 = spb.get_u8()
			color.b8 = spb.get_u8()
			var arr := [Vector3(x, y, z), OwnWar_Block.get_block_by_id(id), rot, color]
			vb.push_back(arr)
			if id == mainframe_id:
				if has_mainframe:
					print("Refusing to load vehicle with more than one mainframe")
					return ERR_INVALID_DATA
				has_mainframe = true

	if not has_mainframe:
		print("Refusing to load vehicle with no mainframes")
		return ERR_INVALID_DATA

	voxel_bodies = []

	for layer in vb_data_blocks:
		if layer >= len(voxel_bodies):
			voxel_bodies.resize(layer + 1)
		if len(state) > 0 and (len(state) <= layer or state[layer] == null):
			continue
		var vb := VoxelBody.new()
		vb.team = team
		vb.id = layer
		vb.is_ally = is_ally
		add_child(vb)
		var e := vb.connect("destroyed", self, "_remove_voxel_body", [layer])
		assert(e == OK)
		vb.transform = Transform()
		vb.aabb = vb_aabbs[layer]
		for bd in vb_data_blocks[layer]:
			var pos: Vector3 = bd[0]
			var blk: OwnWar_Block = bd[1]
			var rot: int = bd[2]
			var clr: Color = bd[3]
			if len(state) > 0:
				vb.spawn_block(pos, rot, blk, clr, state[layer])
			else:
				vb.spawn_block(pos, rot, blk, clr)
			vb.name = "VoxelBody %d" % layer
		voxel_bodies[layer] = vb

	for body in voxel_bodies:
		if body != null:
			body.fix_physics()
			body.init_blocks(self)
			max_cost += body.max_cost
	for vb in voxel_bodies:
		var center_of_mass_0: Vector3 = vb.center_of_mass
		var position_0: Vector3 = vb.aabb.position
		for body in voxel_bodies:
			if body != null:
				body.translate(-center_of_mass_0 - position_0 * OwnWar_Block.BLOCK_SCALE)
		break

	for body in voxel_bodies:
		if body != null:
			wheels += body.wheels
			weapons += body.weapons
	if len(wheels) > 0:
		var wheel_susp_force := get_mass() / len(wheels) * 9.81 * 3
		for w in wheels:
			var e: int = w.connect("tree_exited", self, "_erase_from", [wheels, w])
			assert(e == OK)
			w.suspension_max_force = wheel_susp_force
	for w in weapons:
		var e: int = w.connect("tree_exited", self, "_remove_weapon", [w])
		assert(e == OK)
		if not "_joint" in w:
			fireable_weapons.push_back(w)

	var physics_bodies := []
	for child in Util.get_children_recursive(self):
		if child is PhysicsBody:
			physics_bodies.append(child)
	for a in physics_bodies:
		for b in physics_bodies:
			a.add_collision_exception_with(b)

	return OK


func serialize_state() -> Array:
	var vb_data := []
	for vb in voxel_bodies:
		if vb != null:
			if vb.id >= len(vb_data):
				vb_data.resize(vb.id + 1)
			vb_data[vb.id] = [vb._block_health, vb._block_health_alt]
	return vb_data


func get_blocks(block_name):
	var id = OwnWar_Block.get_block(block_name).id
	return get_blocks_by_id(id)


func get_blocks_by_id(id):
	var filtered_blocks = []
	for body in voxel_bodies:
		if body != null:
			for block in body.blocks.values():
				if block.id == id:
					filtered_blocks.append(block)
	return filtered_blocks


func get_cost():
	var cost = 0
	for body in voxel_bodies:
		if body != null:
			cost += body.cost
	return cost


func get_linear_velocity():
	for vb in voxel_bodies:
		if vb != null:
			return vb.linear_velocity
	return Vector3()


func get_aabb() -> AABB:
	var aabb := AABB()
	for vb in voxel_bodies:
		if vb != null:
			aabb = vb.aabb
			break
	for vb in voxel_bodies:
		if vb != null:
			aabb = aabb.merge(vb.aabb)
	return aabb


func get_block_count() -> int:
	var c := 0
	for b in voxel_bodies:
		if b != null:
			c += b.block_count
	return c


func get_mass() -> float:
	var c := 0.0
	for b in voxel_bodies:
		if b != null:
			c += b.mass
	return c


func debug_draw() -> void:
	var text := "Actions: "
	if controller.turn_left:
		text += "left, "
	if controller.turn_right:
		text += "right, "
	if controller.pitch_up:
		text += "up, "
	if controller.pitch_down:
		text += "down, "
	if controller.move_forward:
		text += "forward, "
	if controller.move_back:
		text += "back, "
	if controller.fire:
		text += "fire, "
	if controller.flip:
		text += "flip, "
	Debug.draw_text(get_visual_origin(), text, Color.cyan)
	for b in voxel_bodies:
		if b != null:
			Debug.draw_point(b.translation, Color.purple, 0.2)


static func add_manager(p_name: String, script: GDScript):
	assert(not p_name in MANAGERS)
	MANAGERS[p_name] = script


func _erase_from(array: Array, item) -> void:
	array.erase(item)


func _remove_voxel_body(index: int) -> void:
	voxel_bodies[index] = null


func _remove_weapon(weapon: OwnWar_Weapon) -> void:
	assert(weapon != null)
	weapons.erase(weapon)
	fireable_weapons.erase(weapon)


func _remove_wheel(wheel: OwnWar_Wheel) -> void:
	assert(wheel != null)
	wheels.erase(wheel)
	if len(wheels) > 0:
		var susp_force := get_mass() / len(wheels) * 9.81 * 3
		for wheel in wheels:
			wheel.suspension_max_force = susp_force
