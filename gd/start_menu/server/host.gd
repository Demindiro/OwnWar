extends Control


const Status := preload("status.gd")

export var user_error_icon: Texture
export var _map_selection := NodePath()
export var _thumbnail := NodePath()
export var _list_lobby := NodePath()
export var _use_upnp := NodePath()
export var _name := NodePath()
export var _description := NodePath()
export var _port := NodePath()
export var _max_players := NodePath()
export var _password := NodePath()
export var _status := NodePath()

export var maps := PoolStringArray()

var _button_group_map := ButtonGroup.new()

onready var map_selection: Control = get_node(_map_selection)
onready var thumbnail: TextureRect = get_node(_thumbnail)
onready var list_lobby: BaseButton = get_node(_list_lobby)
onready var use_upnp: BaseButton = get_node(_use_upnp)
onready var name_s: LineEdit = get_node(_name)
onready var description: TextEdit = get_node(_description)
onready var port: Range = get_node(_port)
onready var max_players: Range = get_node(_max_players)
onready var password: LineEdit = get_node(_password)
onready var status: Status = get_node(_status)


func _ready() -> void:
	for map in maps:
		var btn := Button.new()
		btn.text = Util.humanize_file_name(map.get_file())
		btn.clip_text = true
		btn.group = _button_group_map
		btn.toggle_mode = true
		btn.set_meta("map_path", map)
		map_selection.add_child(btn)
	list_lobby.pressed = not OwnWar_Lobby.disable_lobby
	use_upnp.pressed = not OwnWar_Lobby.disable_upnp
	port.value = OwnWar_Lobby.server_port
	name_s.text = OwnWar_Lobby.server_name
	description.text = OwnWar_Lobby.server_description
	max_players.value = OwnWar_Lobby.server_max_players


func launch() -> void:
	if not OwnWar_Lobby.player_vehicle_valid:
		# Show this error first so the user doesn't waste time with an address or whatever
		status.set_status(Status.STATUS_ERR, "Vehicle isn't valid: %s" % OwnWar_Lobby.player_vehicle_invalid_reason, user_error_icon)
		return
	var btn := _button_group_map.get_pressed_button()
	if btn == null:
		status.set_status(Status.STATUS_ERR, "You need to select a map", user_error_icon)
		return
	if list_lobby.pressed and name_s.text == "":
		status.set_status(Status.STATUS_ERR, "Name may not be empty", user_error_icon)
		return
	var map: String = btn.get_meta("map_path")
	OwnWar_Lobby.disable_upnp = not use_upnp.pressed
	OwnWar_Lobby.disable_lobby = not list_lobby.pressed
	OwnWar_Lobby.server_port = int(port.value)
	OwnWar_Lobby.server_name = name_s.text
	OwnWar_Lobby.server_description = description.text
	OwnWar_Lobby.server_max_players = int(max_players.value)
	OwnWar_Settings.save_settings()
	Global.goto_scene(map)
