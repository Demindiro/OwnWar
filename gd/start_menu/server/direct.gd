extends VBoxContainer


const Status := preload("status.gd")

export var no_connection_icon: Texture
export var empty_address_icon: Texture
export var connecting_icon: Texture
export var user_error_icon: Texture
export var _address := NodePath()
export var _port := NodePath()
export var _password := NodePath()
export var _status := NodePath()

onready var address: LineEdit = get_node(_address)
onready var port: Range = get_node(_port)
onready var password: LineEdit = get_node(_password)
onready var status: Status = get_node(_status)


func _ready() -> void:
	var e := get_tree().connect("connected_to_server", self, "connection_success")
	assert(e == OK)
	e = get_tree().connect("connection_failed", status, "set_status", [
		Status.STATUS_ERR, "Failed to connect to server", no_connection_icon])
	assert(e == OK)
	e = get_tree().connect("connection_failed", get_tree(), "set", ["network_peer", null])
	assert(e == OK)
	e = OwnWar_NetInfo.connect("received_server_map", self, "goto_map")
	assert(e == OK)


func _physics_process(_delta: float) -> void:
	get_tree().multiplayer.poll()


func _exit_tree() -> void:
	get_tree().disconnect("connected_to_server", self, "connection_success")
	get_tree().disconnect("connection_failed", status, "set_status")
	get_tree().disconnect("connection_failed", get_tree(), "set")
	OwnWar_NetInfo.disconnect("received_server_map", self, "goto_map")


func launch() -> void:
	if not OwnWar_Lobby.player_vehicle_valid:
		# Show this error first so the user doesn't waste time with an address or whatever
		status.set_status(Status.STATUS_ERR, "Vehicle isn't valid: %s" % OwnWar_Lobby.player_vehicle_invalid_reason, user_error_icon)
		return
	if address.text == "":
		status.set_status(Status.STATUS_ERR, "You need to fill in an address", empty_address_icon)
		return
	var network := NetworkedMultiplayerENet.new()
	network.compression_mode = OwnWar.NET_COMPRESSION
	var e := network.create_client(address.text, int(port.value))
	if e != OK:
		status.set_status(Status.STATUS_ERR,
			"Failed to create a connection: %s" % Global.ERROR_TO_STRING[e], no_connection_icon)
		return
	get_tree().network_peer = network
	get_tree().multiplayer_poll = false
	status.set_status(Status.STATUS_NONE, "Connecting...", connecting_icon, true)


func connection_success() -> void:
	status.set_status(Status.STATUS_OK, "Success! Waiting for map info...", connecting_icon, true)


func goto_map(path: String) -> void:
	OwnWar_Lobby.client_connected = true
	Global.goto_scene(path)
