extends Node


const TRAILER_MODE := false
const TRAILER_FREE_CAM := false

const AI_VEHICLES := [
	"res://default_user_dir/vehicles/skunk.owv",
	"res://default_user_dir/vehicles/tank.owv",
	"res://default_user_dir/vehicles/mini_tank.owv",
]

signal server_disconnected()
signal vehicle_rejected(reason)

export var spawn_points := NodePath("Spawn Points")

var headless := OS.has_feature("Server")
onready var server_mode := get_tree().network_peer == null

var counter := 0
var clients := {}

var player_vehicle_data := PoolByteArray()
onready var hud = get_node("HUD")

var vehicles := []
var vehicle_data := []
var vehicle_is_local := []
var inputs := []
var free_vehicle_slots := []
var ai := []

# Temporary vehicle data to be applied
var pending_temporary_data := []
# Permanent vehicle data to be applied
var pending_permanent_data := []

# Counter to reduce the amount of temporary packets send
var temp_packet_counter = 0


func _ready() -> void:
	get_tree().multiplayer_poll = false
	hud.vehicles = vehicles
	if server_mode:
		print("Server mode")
		print("  port: ", OwnWar_Lobby.server_port)
		print("  max players: ", OwnWar_Lobby.server_max_players)
		var network := NetworkedMultiplayerENet.new()
		network.compression_mode = OwnWar.NET_COMPRESSION
		var e := network.create_server(OwnWar_Lobby.server_port, OwnWar_Lobby.server_max_players)
		assert(e == OK)
		get_tree().network_peer = network
		e = get_tree().connect("network_peer_connected", self, "new_client")
		assert(e == OK)
		e = get_tree().connect("network_peer_disconnected", self, "remove_client")
		assert(e == OK)
		OwnWar_Lobby.register_server(self)

		if TRAILER_FREE_CAM:
			var cam = FreeCamera.new()
			cam.actions = PoolStringArray([
				"editor_move_left",
				"editor_move_right",
				"editor_move_forward",
				"editor_move_back",
				"editor_move_up",
				"editor_move_down"
			])
			add_child(cam)
			cam.current = true
			cam.far = 2000
		elif not headless:
			clients[1] = null
			spawn_player_vehicle()

		# Spawn some AI to keep the map busy even when there are no players.
		if 1:
			for path in AI_VEHICLES:
				spawn_ai(path)
	else:
		assert(not headless, "Can't create client in headless mode")
		# Sync vehicles on the server side
		print("Request sync")
		rpc("request_sync_vehicles")
		# Spawn our vehicle
		spawn_player_vehicle()
		var e := get_tree().multiplayer.connect(
			"server_disconnected", self, "emit_signal", ["server_disconnected"])
		assert(e == OK)
	if TRAILER_MODE:
		get_node("Chat").visible = false


func _exit_tree() -> void:
	get_tree().network_peer = null
	get_tree().multiplayer_poll = true


func _input(e):
	if e is InputEventKey and e.pressed and e.scancode == KEY_CAPSLOCK:
		set_physics_process(not is_physics_processing())
		PhysicsServer.set_active(is_physics_processing())


func _process(delta: float) -> void:
	for v in vehicles:
		if v != null:
			v.visual_step(delta)


func _physics_process(delta: float) -> void:
	# Send current client input
	if !server_mode:
		if hud.player_vehicle_id >= 0:
			var v = vehicles[hud.player_vehicle_id]
			if v != null:
				rpc_unreliable("sync_client_input", v.get_controller_bitmap(), v.aim_at)

	# Receive client inputs _or_ receive server data
	get_tree().multiplayer.poll()

	# Apply client inputs
	if server_mode:
		# Apply client inputs. If this is the client, any inputs from remote vehicles
		# will be overridden anyways, so no worries.
		for i in len(vehicles):
			var v = vehicles[i]
			if v != null:
				v.apply_input(inputs[i][0], inputs[i][1])

	# Process physics & server inputs
	if !server_mode:
		# Process temporary data (physics, inputs)
		for pkt in pending_temporary_data:
			if pkt[0] < len(vehicles):
				var v = vehicles[pkt[0]]
				if v != null:
					v.process_temporary_packet(pkt[1])
		pending_temporary_data.clear()

	# Apply inputs
	for a in ai:
		a.step(vehicles, delta)
	for v in vehicles:
		if v != null:
			v.process_input(delta)

	# Send packets including physics, inputs & damage events
	if server_mode:
		# Create packets with state to be applied to the vehicles & send it to the clients.
		for i in len(vehicles):
			var v = vehicles[i]
			if v != null:
				var pt = v.create_packet()
				rpc("sync_permanent_vehicle_data", i, pt[0]);
				# Send a packet every 3 frames (20 packets/sec)
				temp_packet_counter += 1
				if temp_packet_counter >= 3:
					rpc_unreliable("sync_temporary_vehicle_data", i, pt[1]);
					temp_packet_counter = 0

	# Process damage events
	if !server_mode:
		# Process permanent data (damage)
		for pkt in pending_permanent_data:
			if pkt[0] < len(vehicles):
				var v = vehicles[pkt[0]]
				if v != null:
					if v.process_permanent_packet(pkt[1]):
						vehicles[pkt[0]] = null
		pending_permanent_data.clear()
	else:
		# Apply damage
		for i in len(vehicles):
			var v = vehicles[i]
			if v != null:
				if v.apply_damage():
					start_respawn(i)


	# Step vehicles
	for i in len(vehicles):
		var v = vehicles[i]
		if v != null:
			v.step(delta)


# Load vehicle data from a file
func load_vehicle_data(path):
	var file := File.new()
	var e := file.open_compressed(path, File.READ, File.COMPRESSION_GZIP)
	if e != OK:
		e = file.open(path, File.READ)
	assert(e == OK, "Failed to open file %s" % path)
	return file.get_buffer(file.get_len())


func spawn_player_vehicle() -> void:
	print("Spawning vehicle")
	assert(not headless, "Can't spawn player vehicle in headless mode")
	assert(OwnWar_Settings.selected_vehicle_path != "")
	var data = load_vehicle_data(OwnWar_Settings.selected_vehicle_path)
	if server_mode:
		hud.player_vehicle_id = request_vehicle(data, OwnWar.ALLY_COLOR)
	else:
		rpc("request_vehicle", data)
	player_vehicle_data = data


# Spawn an AI vehicle
func spawn_ai(path):
	var transform = get_next_spawn_point()
	var id = reserve_vehicle_slot()
	var v = OwnWar_Vehicle.new()
	var data = load_vehicle_data(path)
	var team = id
	var e = v.load_from_data(
		data,
		team,
		OwnWar.ENEMY_COLOR,
		transform,
		server_mode,
		true,
		id
	)
	assert(e == null)

	vehicles[id] = v
	vehicle_data[id] = data
	vehicle_is_local[id] = true
	v.spawn(self, true)

	var a = BrickAI.new()
	a.vehicle_id = id
	ai.push_back(a)


func new_client(id: int) -> void:
	print("New client ", id)
	clients[id] = null


master func request_sync_vehicles() -> void:
	print("Requested sync")
	var id := get_tree().get_rpc_sender_id()
	var data = []
	for i in len(vehicles):
		var v = vehicles[i]
		if v != null:
			print("Syncing vehicle ", i)
			rpc_id(id, "sync_vehicle", i, v.serialize(), vehicle_data[i])
	OwnWar_NetInfo.enable_broadcast(id)


func remove_client(id) -> void:
	print("Removing client ", id)
	var i = clients[id]
	if i != null:
		var v = vehicles[i]
		if v != null:
			rpc("free_vehicle_slot", i)
	var e := clients.erase(id)
	assert(e)


# Sync a full vehicle's state, including destroyed blocks, on the client side
#
# `serialized` is the current vehicle's state
# `data` is the "fresh" vehicle state, i.e. file data.
puppet func sync_vehicle(id, serialized, data) -> void:
	print("Synced vehicle ", id)
	allocate_vehicle_slot(id)
	var v = OwnWar_Vehicle.new()
	var e = v.deserialize(serialized, id, OwnWar.ENEMY_COLOR, false, false)
	assert(e == OK)
	vehicles[id] = v
	vehicle_data[id] = data
	vehicle_is_local[id] = false
	v.spawn(self, false)


master func request_vehicle(data: PoolByteArray, color = OwnWar.ENEMY_COLOR):
	var id := get_tree().get_rpc_sender_id()
	if id == 0:
		# Server requested vehicle
		id = 1

	var vehicle := OwnWar_Vehicle.new()
	var transform = get_next_spawn_point()
	var vehicle_id = reserve_vehicle_slot()
	var team = vehicle_id
	var e = vehicle.load_from_data(
		data,
		team,
		color,
		transform,
		server_mode,
		id == 1,
		vehicle_id
	)
	if e != null:
		rpc_id(id, "rejected_vehicle", e)
		return -1
	else:
		vehicles[vehicle_id] = vehicle
		vehicle_data[vehicle_id] = data
		vehicle_is_local[vehicle_id] = id == 1
		clients[id] = vehicle_id
		vehicle.spawn(self, true)
		if id != 1:
			rpc_id(id, "accepted_vehicle", vehicle_id, transform)
			rpc_id(-id, "sync_vehicle", vehicle_id, vehicle.serialize(), data)
		else:
			rpc("sync_vehicle", vehicle_id, vehicle.serialize(), data)

		clients[id] = vehicle_id

		print("Respawned client ", id, ", vehicle ", vehicle_id)
		return vehicle_id


# Callback executed when a client's vehicle is rejected.
puppet func rejected_vehicle(reason):
	emit_signal("vehicle_rejected", reason)


# Callback executed when a client's vehicle is accepted.
puppet func accepted_vehicle(id, transform: Transform) -> void:
	print("Vehicle accepted, controlling ", id)
	allocate_vehicle_slot(id)
	var v := OwnWar_Vehicle.new()
	var team = id
	var e = v.load_from_data(
		player_vehicle_data,
		team,
		OwnWar.ALLY_COLOR,
		transform,
		server_mode,
		true,
		id
	)
	assert(e == null, "Failed to load vehicle")
	vehicles[id] = v
	vehicle_data[id] = player_vehicle_data
	vehicle_is_local[id] = true
	hud.player_vehicle_id = id
	v.spawn(self, true)


# Respawn a vehicle by recreating it from file data
puppetsync func respawn_vehicle(id, transform):
	print("Respawning ", id)
	var v = OwnWar_Vehicle.new()
	var team = id
	var e = v.load_from_data(
		vehicle_data[id],
		team,
		OwnWar.ENEMY_COLOR if hud.player_vehicle_id != id else OwnWar.ALLY_COLOR,
		transform,
		server_mode,
		vehicle_is_local[id],
		id
	)
	assert(e == null)
	vehicles[id] = v
	v.spawn(self, true)


# Receive temporary from the server for a specific vehicle
puppet func sync_temporary_vehicle_data(id, data):
	pending_temporary_data.push_back([id, data])


# Receive permanent from the server for a specific vehicle
puppet func sync_permanent_vehicle_data(id, data):
	pending_permanent_data.push_back([id, data])


# Return a valid slot in the vehicle list.
func reserve_vehicle_slot():
	var e = free_vehicle_slots.pop_back()
	if e == null:
		vehicles.push_back(null)
		vehicle_data.push_back(null)
		vehicle_is_local.push_back(null)
		inputs.push_back([0, Vector3()])
		return len(vehicles) - 1
	return e


# Allocate a specific slot in the vehicle list.
func allocate_vehicle_slot(id):
	if len(vehicles) <= id:
		vehicles.resize(id + 1)
		vehicle_data.resize(id + 1)
		vehicle_is_local.resize(id + 1)
		inputs.push_back([0, Vector3()])
	assert(vehicles[id] == null, "Vehicle slot already in use")


# Clear a slot in the vehicle list.
puppetsync func free_vehicle_slot(id):
	var v = vehicles[id]
	if v != null:
		v.destroy()
	vehicles[id] = null
	vehicle_data[id] = null
	vehicle_is_local[id] = null
	free_vehicle_slots.push_back(id)


# Sync client input with the server
master func sync_client_input(bitmap, aim_at):
	var id = get_tree().get_rpc_sender_id()
	id = clients[id]
	if id != null:
		var v = vehicles[id]
		if v != null:
			inputs[id] = [bitmap, aim_at]

# Request the server to destroy the player's vehicle
func request_destroy_player_vehicle():
	request_destroy_vehicle(hud.player_vehicle_id)

# Request the server for a vehicle to be destroyed
#
# Does nothing if the requester does not own the vehicle
master func request_destroy_vehicle(vehicle_id):
	if server_mode:
		print("Request destroy ", vehicle_id)
		var id = get_tree().get_rpc_sender_id()
		if id == 0 or id == 1 or clients[id] == vehicle_id:
			destroy_vehicle(vehicle_id)
	else:
		rpc("request_destroy_vehicle", vehicle_id)


# Instantly destroy a vehicle. The vehicle will be respawned.
puppet func destroy_vehicle(id) -> void:
	print("Destroying ", id)
	var v = vehicles[id]
	if v != null:
		vehicles[id] = null
		v.destroy()
		if server_mode:
			rpc("destroy_vehicle", id)
			start_respawn(id)


# Respawn a vehicle with a delay
func start_respawn(id):
	vehicles[id] = null
	print("Will respawn ", id)
	yield(get_tree().create_timer(1.5), "timeout")
	rpc("respawn_vehicle", id, get_next_spawn_point())


# Get the next spawn point
func get_next_spawn_point():
	var c = get_node(spawn_points)
	var trf = c.get_child(counter % c.get_child_count()).transform
	counter += 1
	return trf
