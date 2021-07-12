extends Node


const TRAILER_MODE := false
const AI_VEHICLES := [
	"res://default_user_dir/vehicles/skunk.owv",
	"res://default_user_dir/vehicles/tank.owv",
	"res://default_user_dir/vehicles/mini_tank.owv"
]

signal server_disconnected()

export var spawn_points := NodePath("Spawn Points")

var headless := OS.has_feature("Server")
onready var server_mode := get_tree().network_peer == null

var counter := 0
var clients := {}

var player_vehicle_data := PoolByteArray()
onready var hud = get_node("HUD")

var vehicles := []
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
		if not headless:
			clients[1] = null
			spawn_player_vehicle()

		# Spawn some AI to keep the map busy even when there are no players.
		if 1:
			for path in AI_VEHICLES:
				var vehicle_id = spawn_vehicle(path)
				var a = BrickAI.new()
				a.vehicle_id = vehicle_id
				ai.push_back(a)
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
				rpc_unreliable("sync_temporary_vehicle_data", i, pt[1]);

	# Process damage events
	if !server_mode:
		# Process permanent data (damage)
		for pkt in pending_permanent_data:
			if pkt[0] < len(vehicles):
				var v = vehicles[pkt[0]]
				if v != null:
					if v.process_permanent_packet(pkt[1]):
						cleanup_vehicle(pkt[0])
		pending_permanent_data.clear()
	else:
		# Apply damage
		for i in len(vehicles):
			var v = vehicles[i]
			if v != null:
				if v.apply_damage():
					cleanup_vehicle(i)

	# Step vehicles
	for i in len(vehicles):
		var v = vehicles[i]
		if v != null:
			v.step(delta)


func spawn_player_vehicle() -> void:
	print("Spawning vehicle")
	assert(not headless, "Can't spawn player vehicle in headless mode")
	var file := File.new()
	assert(OwnWar_Settings.selected_vehicle_path != "")
	var e := file.open_compressed(OwnWar_Settings.selected_vehicle_path, File.READ, File.COMPRESSION_GZIP)
	if e != OK:
		e = file.open(OwnWar_Settings.selected_vehicle_path, File.READ)
	assert(e == OK, "Failed to open file %s" % OwnWar_Settings.selected_vehicle_path)
	var data := file.get_buffer(file.get_len())
	if server_mode:
		hud.player_vehicle_id = request_vehicle(data, OwnWar.ALLY_COLOR)
	else:
		rpc("request_vehicle", data)
	player_vehicle_data = data


func new_client(id: int) -> void:
	clients[id] = null


master func request_sync_vehicles() -> void:
	print("Requested sync")
	var id := get_tree().get_rpc_sender_id()
	var data = []
	for i in len(vehicles):
		var v = vehicles[i]
		if v != null:
			print("Syncing vehicle ", i)
			rpc_id(id, "sync_vehicle", i, v.serialize())
	OwnWar_NetInfo.enable_broadcast(id)


func remove_client(id) -> void:
	var i = clients[id]
	var v = vehicles[i]
	if v != null:
		v.destroy()
		rpc_id(-OwnWar_NetInfo.disable_broadcast_id, "destroy_vehicle", i)
		free_vehicle_slot(i)
	var e := clients.erase(id)
	assert(e)


# Instantly destroy a vehicle.
puppet func destroy_vehicle(id) -> void:
	var v = vehicles[id]
	if v != null:
		v.destroy()
		vehicles[id] = null


puppet func sync_vehicle(id, data) -> void:
	print("Synced vehicle ", id)
	allocate_vehicle_slot(id)
	var v = OwnWar_Vehicle.new()
	var e = v.deserialize(data, id, OwnWar.ENEMY_COLOR, false, false, true)
	assert(e == OK)
	vehicles[id] = v
	v.spawn(self, false)


master func request_vehicle(data: PoolByteArray, color = OwnWar.ENEMY_COLOR):
	var id := get_tree().get_rpc_sender_id()
	if id == 0:
		# Server requested vehicle
		id = 1

	var vehicle := OwnWar_Vehicle.new()
	var index := counter % get_node(spawn_points).get_child_count()
	var team = counter
	var transform = get_node(spawn_points).get_child(index).transform
	var vehicle_id = reserve_vehicle_slot()
	var e = vehicle.load_from_data(
		data,
		team,
		color,
		transform,
		server_mode,
		id == 1,
		vehicle_id
	)
	assert(e == OK)
	vehicles[vehicle_id] = vehicle
	clients[id] = vehicle_id
	vehicle.spawn(self, true)
	counter += 1
	if id != 1:
		rpc_id(id, "accepted_vehicle", vehicle_id, team, transform)
		rpc_id(-id, "sync_vehicle", vehicle_id, vehicle.serialize())
	else:
		rpc("sync_vehicle", vehicle_id, vehicle.serialize())

	clients[id] = vehicle_id

	print("Respawned client ", id, ", vehicle ", vehicle_id)
	return vehicle_id


puppet func accepted_vehicle(id, team: int, transform: Transform) -> void:
	allocate_vehicle_slot(id)
	var v := OwnWar_Vehicle.new()
	var e = v.load_from_data(
		player_vehicle_data,
		team,
		OwnWar.ALLY_COLOR,
		transform,
		server_mode,
		true,
		id
	)
	assert(e == OK, "Failed to load vehicle")
	vehicles[id] = v
	hud.player_vehicle_id = id
	v.spawn(self, true)


func request_respawn() -> void:
	if is_inside_tree():
		yield(get_tree().create_timer(1.5), "timeout")
		if server_mode:
			hud.player_vehicle_id = request_vehicle(player_vehicle_data)
			var e: int = clients[1].connect("tree_exited", self, "request_respawn")
			assert(e == OK)
		else:
			rpc_id(1, "request_vehicle", player_vehicle_data)


# Spawn a locally controlled vehicle for AI.
func spawn_vehicle(path: String):
	var v = OwnWar_Vehicle.new()
	var team = counter
	var index := counter % get_node(spawn_points).get_child_count()
	var id = reserve_vehicle_slot()
	var e = v.load_from_file(
		path,
		team,
		OwnWar.ENEMY_COLOR,
		get_node(spawn_points).get_child(index).transform,
		server_mode,
		true,
		id
	)
	assert(e == OK)
	vehicles[id] = v
	v.spawn(self, true)
	rpc("sync_vehicle", id, v.serialize())
	counter += 1
	return id


func remove_client_vehicle(id: int) -> void:
	clients[id] = null


# Respawn the AI of a vehicle
func respawn_ai(a):
	var path = AI_VEHICLES[randi() % len(AI_VEHICLES)]
	a.vehicle_id = spawn_vehicle(path)


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
		inputs.push_back([0, Vector3()])
		return len(vehicles) - 1
	return e


# Allocate a specific slot in the vehicle list.
func allocate_vehicle_slot(id):
	if len(vehicles) <= id:
		vehicles.resize(id + 1)
		inputs.push_back([0, Vector3()])
	assert(vehicles[id] == null, "Vehicle slot already in use")


# Clear a slot in the vehicle list.
func free_vehicle_slot(id):
	vehicles[id] = null
	free_vehicle_slots.push_back(id)


# Sync client input with the server
master func sync_client_input(bitmap, aim_at):
	var id = get_tree().get_rpc_sender_id()
	id = clients[id]
	if id != null:
		var v = vehicles[id]
		if v != null:
			inputs[id] = [bitmap, aim_at]


# Cleanup vehicle & everything relying on it
func cleanup_vehicle(id):
	if id == hud.player_vehicle_id:
		hud.player_vehicle_id = -1
		# Respawn the player after some time
		get_tree() \
			.create_timer(1.5) \
			.connect("timeout", self, "spawn_player_vehicle")
	else:
		for a in ai:
			if a.vehicle_id == id:
				a.vehicle_id = -1
				# Respawn the AI after some time
				get_tree() \
					.create_timer(3.0) \
					.connect("timeout", self, "respawn_ai", [a])
				break
	free_vehicle_slot(id)
