extends Node


export var spawn_points := NodePath("Spawn Points")

var headless := OS.has_feature("Server")
onready var server_mode := get_tree().network_peer == null

var counter := 0
var clients := {}

var player_vehicle_data := PoolByteArray()
onready var hud = get_node("HUD")


func _ready() -> void:
	get_tree().multiplayer_poll = false
	if server_mode:
		print("Server mode")
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
	else:
		assert(not headless, "Can't create client in headless mode")
		spawn_player_vehicle()


func _exit_tree() -> void:
	get_tree().network_peer = null
	get_tree().multiplayer_poll = true


func _physics_process(_delta: float) -> void:
	get_tree().multiplayer.poll()


func spawn_player_vehicle() -> void:
	print("Spawning vehicle")
	assert(not headless, "Can't spawn player vehicle in headless mode")
	var file := File.new()
	assert(OwnWar_Settings.selected_vehicle_path != "")
	var e := file.open_compressed(OwnWar_Settings.selected_vehicle_path, File.READ, File.COMPRESSION_GZIP)
	assert(e == OK)
	var data := file.get_buffer(file.get_len())
	if server_mode:
		request_vehicle(data)
		hud.player_vehicle = clients[1]
		e = clients[1].connect("tree_exited", self, "request_respawn")
		assert(e == OK)
	else:
		rpc("request_sync_vehicles")
		rpc("request_vehicle", data)
	player_vehicle_data = data


func new_client(id: int) -> void:
	clients[id] = null


master func request_sync_vehicles() -> void:
	var id := get_tree().get_rpc_sender_id()
	for vehicle in get_tree().get_nodes_in_group("vehicles"):
		rpc_id(id, "sync_vehicle", vehicle.data, vehicle.name, vehicle.team, vehicle.transform,
			vehicle.controller.get_network_master(), vehicle.serialize_state())
	OwnWar_NetInfo.enable_broadcast(id)


func remove_client(id: int) -> void:
	var vehicle: OwnWar_Vehicle = clients[id]
	if vehicle != null:
		vehicle.queue_free()
		rpc_id(-OwnWar_NetInfo.disable_broadcast_id, "destroy_vehicle", vehicle.get_path())
	var e := clients.erase(id)
	assert(e)


puppet func destroy_vehicle(path: NodePath) -> void:
	var vehicle: OwnWar_Vehicle = get_node_or_null(path)
	if vehicle != null:
		vehicle.queue_free()


puppet func sync_vehicle(data: PoolByteArray, name: String, team: int, \
	transform: Transform, master_id: int, state := []) -> void:
	var vehicle := OwnWar_Vehicle.new()
	vehicle.team = team
	vehicle.name = name
	vehicle.transform = transform
	var e := vehicle.load_from_data(data, state)
	assert(e == OK)
	vehicle.add_to_group("vehicles")
	vehicle.controller.set_network_master(master_id)
	add_child(vehicle)


master func request_vehicle(data: PoolByteArray) -> void:
	var is_ally := false
	var id := get_tree().get_rpc_sender_id()
	if id == 0:
		# Server requested vehicle
		id = 1
		is_ally = true
	if clients[id] == null:
		var vehicle := OwnWar_Vehicle.new()
		vehicle.team = counter
		vehicle.is_ally = is_ally
		var e := vehicle.load_from_data(data)
		assert(e == OK)
		var index := counter % get_node(spawn_points).get_child_count()
		vehicle.transform = get_node(spawn_points).get_child(index).transform
		vehicle.add_to_group("vehicles")
		vehicle.name = "Vehicle %d" % counter
		vehicle.controller.set_network_master(id)
		add_child(vehicle)
		counter += 1
		if id != 1:
			rpc_id(id, "accepted_vehicle", vehicle.name, vehicle.team, vehicle.transform)
			rpc_id(-id, "sync_vehicle", data, vehicle.name, vehicle.team,
				vehicle.transform, vehicle.controller.get_network_master())
		else:
			rpc("sync_vehicle", data, vehicle.name, vehicle.team,
				vehicle.transform, vehicle.controller.get_network_master())
		clients[id] = vehicle
		e = vehicle.connect("tree_exiting", self, "remove_client_vehicle", [id])
		assert(e == OK)


puppet func accepted_vehicle(name: String, team: int, transform: Transform) -> void:
	var vehicle := OwnWar_Vehicle.new()
	vehicle.name = name
	vehicle.team = team
	vehicle.transform = transform
	vehicle.is_ally = true
	vehicle.load_from_data(player_vehicle_data)
	add_child(vehicle)
	#player_vehicle_data = PoolByteArray()
	hud.player_vehicle = vehicle
	vehicle.controller.set_network_master(get_tree().get_network_unique_id())
	vehicle.connect("tree_exited", self, "request_respawn")


func request_respawn() -> void:
	if is_inside_tree():
		yield(get_tree().create_timer(1.5), "timeout")
		if server_mode:
			request_vehicle(player_vehicle_data)
			hud.player_vehicle = clients[1]
			var e: int = clients[1].connect("tree_exited", self, "request_respawn")
			assert(e == OK)
		else:
			rpc_id(1, "request_vehicle", player_vehicle_data)


func spawn_vehicle(name: String) -> void:
	var vehicle := OwnWar_Vehicle.new()
	vehicle.team = counter
	vehicle.load_from_file(OwnWar.get_vehicle_path(name))
	var index := counter % get_node(spawn_points).get_child_count()
	vehicle.transform = get_node(spawn_points).get_child(index).transform
	vehicle.add_to_group("vehicles")
	vehicle.name = "Vehicle %d" % counter
	add_child(vehicle)
	counter += 1


func remove_client_vehicle(id: int) -> void:
	clients[id] = null
