tool
extends Spatial
class_name OwnWar_Vehicle


# TODO
const BLOCK_SCALE := 0.25


var team := -1
var is_ally := false

var max_cost: int
var voxel_bodies := []
var wheels := []
var weapons := []
var thrusters := []
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

# A ring buffer holding the bodies' previous physics state as well as player
# inputs
var past_state := []
var past_state_index := 0
const PAST_STATE_SIZE := 64

class PastBodyState:
	var transform := Transform()
	var linear_velocity := Vector3()
	var angular_velocity := Vector3()

class PastState:
	var body_states := []
	var inputs := 0
	var aiming_at := Vector3()


func _init() -> void:
	set_process(not server_mode)
	add_to_group("vehicles")
	for _i in PAST_STATE_SIZE:
		past_state.push_back(PastState.new())


func _ready() -> void:
	set_physics_process(get_tree().network_peer != null)
	add_child(controller)


func _physics_process(delta: float) -> void:
	if not Engine.editor_hint:
		# Set transform to "main" body transform
		for vb in voxel_bodies:
			if vb != null:
				transform = vb.transform
				break
		if controller.is_network_master():
			# Save current state to ring buffer.
			var ps = past_state[past_state_index % PAST_STATE_SIZE]
			for i in len(voxel_bodies):
				var psb = ps.body_states[i]
				var vb = voxel_bodies[i]
				psb.transform = vb.transform
				psb.linear_velocity = vb.linear_velocity
				psb.angular_velocity = vb.angular_velocity
			ps.inputs = controller.bitmask
			ps.aiming_at = controller.aim_at
			past_state_index += 1

		process_controller_input(delta, controller.bitmask, controller.aim_at)

		if is_network_master() and len(fireable_weapons) > 0:
			if controller.fire:
				if delay_until_next_fire <= 0:
					if fireable_weapons[0].volley:
						var delay := PoolRealArray([INF, 1.0, 2.0, 3.0, 4.0])[min(len(fireable_weapons), 4)]
						for i in min(len(fireable_weapons), 4):
							var weapon = fireable_weapons[(fired_shots_count + i) % len(fireable_weapons)]
							var fired = weapon.fire()
							assert(fired, "Weapon did not fire!")
						delay_until_next_fire += delay
					else:
						var avg_delay_between_shots := PoolRealArray(
							[INF, 1.0, 1.0 / 2, 1.0 / 3, 1.0 / 4])[min(len(fireable_weapons), 4)]
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
			# Tell the client the actual state
			#rpc_unreliable_id(-OwnWar_NetInfo.disable_broadcast_id, "sync_physics",
			rpc_unreliable_id(0, "sync_physics",
				past_state_index, state)
		elif controller.is_network_master():
			# Send the server a new sequence ID, which is used by the client which
			# physics frame a "sync_physics" response applies to.
			rpc_unreliable_id(0, "send_sequence_id", past_state_index)


func process_controller_input(delta: float, inputs: int, aim_at: Vector3) -> void:

	var orig_inputs = controller.bitmask
	var orig_aim_at = controller.aim_at
	controller.set_inputs(inputs, aim_at)

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
				if b != null:
					b.custom_integrator = false
		controller.set_inputs(orig_inputs, orig_aim_at)
		return

	var drive_yaw := 0.0
	var drive_forward := 0.0
	var drive_brake := 0.0
	if controller.turn_left:
		drive_yaw += 1.0
	if controller.turn_right:
		drive_yaw -= 1.0
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
		wheel.steering = drive_yaw * wheel.max_angle * 0.3
		wheel.brake = drive_brake * wheel.max_brake
		var fraction := 1 - clamp(ease(abs(wheel.get_rpm()) / wheel.max_rpm, 1), 0, 1)
		wheel.engine_force = wheel.max_power * drive_forward * fraction

	for thruster in thrusters:
		thruster.apply_drive(drive_forward, drive_yaw, 0.0)

	for weapon in weapons:
		weapon.aim_at(controller.aim_at)
		if weapon.has_method("process_tick"):
			weapon.process_tick(delta)

	controller.set_inputs(orig_inputs, orig_aim_at)


puppet func sync_physics(seq_id: int, state: PoolVector3Array) -> void:
	if seq_id <= _last_seq_id:
		return
	_last_seq_id = seq_id
	assert(len(voxel_bodies) * 4 == len(state))

	var ps = past_state[seq_id % PAST_STATE_SIZE]

	var rollback := false

	for i in len(voxel_bodies):
		var body: OwnWar_VoxelBody = voxel_bodies[i]
		if body == null:
			# Can happen due to packets being late / out of order
			continue
		i *= 4
		var q := state[i]
		# q.length_squared() is sometimes slightly larger than 1, hence max(0, ...)
		var trf := Transform(Quat(q.x, q.y, q.z, sqrt(max(0, 1 - q.length_squared()))))
		trf.origin = state[i + 1]
		var lv = state[i + 2]
		var av = state[i + 3]

		var psb = ps.body_states[i / 4]

		if controller.is_network_master():
			# This client is in control, hence prediction is active

			assert(seq_id <= past_state_index, "The server is ahead of us!")

			var divergence = trf.origin.distance_to(psb.transform.origin)
			#rollback = rollback or divergence > 0.01
			rollback = true
		else:
			# This client is _not_ in control, so just set the state directly
			psb.transform = trf
			psb.linear_velocity = lv
			psb.angular_velocity = av
			body.transform = trf
			body.linear_velocity = lv
			body.angular_velocity = av
	
	if rollback:
		# Fix the old state and all states after it
		for i in len(voxel_bodies):
			var body: OwnWar_VoxelBody = voxel_bodies[i]
			if body == null:
				# Can happen due to packets being late / out of order
				continue
			var psb = ps.body_states[i]
			i *= 4
			var q := state[i]
			# q.length_squared() is sometimes slightly larger than 1, hence max(0, ...)
			var trf := Transform(Quat(q.x, q.y, q.z, sqrt(max(0, 1 - q.length_squared()))))
			trf.origin = state[i + 1]
			var lv = state[i + 2]
			var av = state[i + 3]
			body.transform = trf
			body.linear_velocity = lv
			body.angular_velocity = av
			# NOTIFICATION_TRANSFORM_CHANGED isn't triggered because idk godot
			# never supported manual stepping.
			# Godot claims that "_notification" doesn't exist so communication
			# with the PhysicsServer it is!
			PhysicsServer.body_set_state(
				body.get_rid(),
				PhysicsServer.BODY_STATE_TRANSFORM,
				trf
			)
			PhysicsServer.body_set_state(
				body.get_rid(),
				PhysicsServer.BODY_STATE_LINEAR_VELOCITY,
				lv
			)
			PhysicsServer.body_set_state(
				body.get_rid(),
				PhysicsServer.BODY_STATE_ANGULAR_VELOCITY,
				av
			)
		get_parent().rollback(self, past_state_index - seq_id)


remote func send_sequence_id(index: int) -> void:
	# TODO ensure no clients are trying to spoof us
	past_state_index = index


func rollback_steps(delta: float, steps: int) -> void:
	var ps = past_state[posmod(past_state_index - steps, PAST_STATE_SIZE)]
	for i in len(voxel_bodies):
		var psb = ps.body_states[i]
		var body = voxel_bodies[i]
		body.transform = psb.transform
		body.linear_velocity = psb.linear_velocity
		body.angular_velocity = psb.angular_velocity
		PhysicsServer.body_set_state(
			body.get_rid(),
			PhysicsServer.BODY_STATE_TRANSFORM,
			body.transform
		)
		PhysicsServer.body_set_state(
			body.get_rid(),
			PhysicsServer.BODY_STATE_LINEAR_VELOCITY,
			body.linear_velocity
		)
		PhysicsServer.body_set_state(
			body.get_rid(),
			PhysicsServer.BODY_STATE_ANGULAR_VELOCITY,
			body.angular_velocity
		)
	process_controller_input(delta, ps.inputs, ps.aiming_at)


func rollback_copy_current(delta: float, steps: int) -> void:
	var ps = past_state[posmod(past_state_index - steps, PAST_STATE_SIZE)]
	for i in len(voxel_bodies):
		var psb = ps.body_states[i]
		var body = voxel_bodies[i]
		psb.transform = body.transform
		psb.linear_velocity = body.linear_velocity
		psb.angular_velocity = body.angular_velocity
	process_controller_input(delta, ps.inputs, ps.aiming_at)


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
		err = file.open(path, File.READ)
	if err != OK:
		return err

	return load_from_data(file.get_buffer(file.get_len()))


func load_from_data(p_data: PoolByteArray, state := []) -> int:

	if len(data) > 0:
		print("Vehicle is already loaded!")
		return ERR_ALREADY_IN_USE

	var loader := OwnWar_VehicleLoader.new()
	var err := loader.load_from_data(p_data)
	if err != OK:
		print("Failed to load vehicle: ", Global.ERROR_TO_STRING[err])
		return err
	if not loader.valid:
		print("Vehicle isn't valid")
		return ERR_INVALID_DATA

	data = p_data

	voxel_bodies = []

	for layer in loader.bodies:
		if layer >= len(voxel_bodies):
			voxel_bodies.resize(layer + 1)
		if len(state) > 0 and (len(state) <= layer or state[layer] == null):
			continue
		var vb := OwnWar_VoxelBody.new()
		vb.team = team
		vb.id = layer
		vb.is_ally = is_ally
		add_child(vb)
		var e: int = vb.connect("destroyed", self, "_remove_voxel_body", [layer])
		assert(e == OK)
		vb.transform = Transform()
		var body: OwnWar_VehicleLoader.Body = loader.bodies[layer]
		vb.create_body(body.aabb)
		for bd in body.blocks:
			if len(state) > 0:
				vb.spawn_block(bd.position, bd.rotation, bd.block, bd.color, state[layer])
			else:
				vb.spawn_block(bd.position, bd.rotation, bd.block, bd.color, null)
			vb.name = "VoxelBody %d" % layer
		voxel_bodies[layer] = vb

	for body in voxel_bodies:
		if body != null:
			body.init(self)
			max_cost += body.max_cost
		for ps in past_state:
			ps.body_states.push_back(PastBodyState.new())

	for vb in voxel_bodies:
		if vb == null:
			continue
		var center_of_mass_0: Vector3 = vb.center_of_mass
		var position_0: Vector3 = vb.aabb.position
		for body in voxel_bodies:
			if body != null:
				body.translate(-center_of_mass_0 - position_0 * BLOCK_SCALE)
		break

	for body in voxel_bodies:
		if body != null:
			wheels += body.wheels
			weapons += body.weapons
			thrusters += body.thrusters
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
	for t in thrusters:
		var e: int = t.connect("tree_exited", self, "_remove_thruster", [t])
		assert(e == OK)

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
			vb_data[vb.id] = vb.serialize_state()
	return vb_data


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
	for b in voxel_bodies:
		if b != null:
			Debug.draw_point(b.translation, Color.purple, 0.2)


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


func _remove_thruster(thruster) -> void:# OwnWar_Thruster_Server) -> void:
	assert(thruster != null)
	thrusters.erase(thruster)
