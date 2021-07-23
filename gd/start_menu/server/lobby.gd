extends VBoxContainer


const Status = preload("status.gd")

export var failed_connect_icon: Texture
export var loading_icon: Texture
export var connecting_icon: Texture
export var user_error_icon: Texture
export var _filter := NodePath()
export var _list := NodePath()
export var _map := NodePath()
export var _max_players := NodePath()
export var _description := NodePath()
export var _status := NodePath()

var selected_entry: OwnWar_Lobby.Entry

var _list_button_group := ButtonGroup.new()
var _timer: SceneTreeTimer = null

onready var filter: LineEdit = get_node(_filter)
onready var list: Control = get_node(_list)
onready var map: Label = get_node(_map)
onready var max_players: Label = get_node(_max_players)
onready var description: Label = get_node(_description)
onready var status: Status = get_node(_status)


func _ready() -> void:
	var e := OwnWar_Lobby.connect("server_list", self, "generate_list")
	assert(e == OK)
	e = OwnWar_Lobby.connect("server_info", self, "set_info")
	assert(e == OK)

	while true:
		if OwnWar_Lobby.got_server_list:
			OwnWar_Lobby.get_server_list()
			status.set_status(Status.STATUS_NONE, "Getting server list...", loading_icon, true)
		_timer = get_tree().create_timer(10.0)
		yield(_timer, "timeout")


func _exit_tree() -> void:
	OwnWar_Lobby.disconnect("server_list", self, "generate_list")
	OwnWar_Lobby.disconnect("server_info", self, "set_info")
	for sig in _timer.get_signal_connection_list("timeout"):
		_timer.disconnect(sig["signal"], sig["target"], sig["method"])


func launch() -> void:
	if not OwnWar_Lobby.player_vehicle_valid:
		# Show this error first so the user doesn't waste time with an address or whatever
		status.set_status(Status.STATUS_ERR, "Vehicle isn't valid: %s" % OwnWar_Lobby.player_vehicle_invalid_reason, user_error_icon)
		return
	if selected_entry == null:
		status.set_status(Status.STATUS_ERR, "No server selected", failed_connect_icon)
		return
	var network := NetworkedMultiplayerENet.new()
	network.compression_mode = OwnWar.NET_COMPRESSION
	var e := network.create_client(selected_entry.get_ip(), selected_entry.port)
	if e != OK:
		status.set_status(Status.STATUS_ERR,
			"Failed to create a connection: %s" % Global.ERROR_TO_STRING[e], failed_connect_icon)
		return
	OwnWar_Lobby.punch_hole(selected_entry)
	get_tree().network_peer = network
	get_tree().multiplayer_poll = false
	print("Attempting to connect to %s:%d" % [selected_entry.get_ip(), selected_entry.port])
	status.set_status(Status.STATUS_NONE, "Connecting...", connecting_icon, true)


func sort_list(a, b) -> bool:
	return a.name < b.name


func generate_list(entries: Array) -> void:
	Util.free_children(list, true)
	entries.sort_custom(self, "sort_list")
	for entry in entries:
		var btn := Button.new()
		btn.text = entry.name
		btn.group = _list_button_group
		btn.toggle_mode = true
		var e := btn.connect("pressed", OwnWar_Lobby, "get_server_info", [entry])
		assert(e == OK)
		e = btn.connect("pressed", self, "set", ["selected_entry", entry])
		assert(e == OK)
		e = btn.connect("pressed", status, "set_status", [
			Status.STATUS_NONE,
			"Getting server info...",
			loading_icon,
			true,
		])
		list.add_child(btn)
	status.set_status(Status.STATUS_OK, "Received server list", null)


func set_info(info: OwnWar_Lobby.ServerInfo) -> void:
	map.text = info.map.get_file().get_basename()
	description.text = info.description
	max_players.text = str(info.max_players)
	status.set_status(Status.STATUS_OK, "Received server info", null)
