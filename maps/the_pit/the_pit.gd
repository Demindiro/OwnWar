extends Node


export var spawn_points := NodePath("Spawn Points")
export var port := 39983
export var password := ""
export var max_players := 10

var counter := 0
var clients := {}

var player_vehicle_data := PoolByteArray()

onready var hud: Control = get_node("HUD")
onready var hud_cam: Camera = get_node("HUDCamera")
onready var free_cam: Camera = get_node("FreeCamera")


func _ready() -> void:
	if get_tree().network_peer == null:
		print("Server mode")
		hud.free()
		hud_cam.free()
		var network := NetworkedMultiplayerENet.new()
		network.compression_mode = OwnWar.NET_COMPRESSION
		var e := network.create_server(port, max_players)
		assert(e == OK)
		get_tree().network_peer = network
		e = get_tree().connect("network_peer_connected", self, "new_client")
		assert(e == OK)
		e = get_tree().connect("network_peer_disconnected", self, "remove_client")
		assert(e == OK)
		get_tree().multiplayer_poll = false
		if true:
			spawn_vehicle("tank")
			spawn_vehicle("tank")
			spawn_vehicle("tank")
		OwnWar_Lobby.register_server(self)
	else:
		print("Client mode")
		free_cam.free()
		var file := File.new()
		var e := file.open_compressed(OwnWar.get_vehicle_path("tank"), File.READ, File.COMPRESSION_GZIP)
		assert(e == OK)
		var data := file.get_buffer(file.get_len())
		rpc("request_sync_vehicles")
		rpc("request_vehicle", data)
		player_vehicle_data = data
		get_tree().multiplayer_poll = false


func _exit_tree() -> void:
	get_tree().network_peer = null
	get_tree().multiplayer_poll = true


func _physics_process(_delta: float) -> void:
	get_tree().multiplayer.poll()


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
	var id := get_tree().get_rpc_sender_id()
	if clients[id] == null:
		var vehicle := OwnWar_Vehicle.new()
		vehicle.team = counter
		var e := vehicle.load_from_data(data)
		assert(e == OK)
		var index := counter % get_node(spawn_points).get_child_count()
		vehicle.transform = get_node(spawn_points).get_child(index).transform
		vehicle.add_to_group("vehicles")
		vehicle.name = "Vehicle %d" % counter
		vehicle.controller.set_network_master(id)
		add_child(vehicle)
		counter += 1
		rpc_id(id, "accepted_vehicle", vehicle.name, vehicle.team, vehicle.transform)
		rpc_id(-id, "sync_vehicle", data, vehicle.name, vehicle.team,
			vehicle.transform, vehicle.controller.get_network_master())
		clients[id] = vehicle
		e = vehicle.connect("tree_exiting", self, "remove_client_vehicle", [id])
		assert(e == OK)


puppet func accepted_vehicle(name: String, team: int, transform: Transform) -> void:
	var vehicle := OwnWar_Vehicle.new()
	vehicle.name = name
	vehicle.team = team
	vehicle.transform = transform
	vehicle.load_from_data(player_vehicle_data)
	add_child(vehicle)
	#player_vehicle_data = PoolByteArray()
	hud.player_vehicle = vehicle
	vehicle.controller.set_network_master(get_tree().get_network_unique_id())
	vehicle.connect("tree_exited", self, "request_respawn")


func request_respawn() -> void:
	if is_inside_tree():
		yield(get_tree().create_timer(1.5), "timeout")
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
