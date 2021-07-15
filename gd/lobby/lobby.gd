extends Node


class Entry:
	var ip: PoolIntArray
	var port: int
	var name: String

	func get_ip() -> String:
		match len(ip):
			4: return "%d.%d.%d.%d" % Array(ip)
			8: return "%x:%x:%x:%x:%x:%x:%x:%x" % Array(ip)
			_: assert(false, "Invalid IP")
		return ""


class ServerInfo:
	var description: String
	var map: String
	var max_players: int

enum {
	MSG_TYPE_LIST = 0,
	MSG_TYPE_REGISTER_SERVER = 1,
	MSG_TYPE_REMOVE_SERVER = 2,
	MSG_TYPE_PING = 3,
	MSG_TYPE_INFO = 4,
	MSG_TYPE_PUNCH_HOLE = 5,
}

signal server_list(entries)
signal server_info(info)

var lobby_address := "107.189.30.116"
var lobby_port := 39984
var lobby_peer := PacketPeerUDP.new()

var registered := false
var got_server_list := true # TODO name isn't quite correct
var got_server_info := true

var disable_lobby := false
var disable_upnp := false
var upnp_ttl := 2

var server_name := ""
var server_port := 39983
var server_max_players := 32
var server_description := ""
var server_scene: Node
var server_ping_timer := Timer.new()

var client_connected := false
var player_vehicle_valid := false
var player_vehicle_invalid_reason = null
var player_name := "" setget set_player_name

var _retry_timer: SceneTreeTimer = null


func _ready() -> void:
	var e := lobby_peer.connect_to_host(lobby_address, lobby_port)
	assert(e == OK)
	e = server_ping_timer.connect("timeout", self, "ping")
	server_ping_timer.wait_time = 10
	add_child(server_ping_timer)


func _process(_delta: float) -> void:
	for _i in lobby_peer.get_available_packet_count():
		var spb := StreamPeerBuffer.new()
		spb.data_array = lobby_peer.get_packet()
		var msg_type := spb.get_u8()
		match msg_type:
			MSG_TYPE_LIST:
				var entries := []
				while spb.get_available_bytes() > 0:
					var entry := Entry.new()
					var is_ipv6 := spb.get_u8()
					if is_ipv6:
						var a := spb.get_u16()
						var b := spb.get_u16()
						var c := spb.get_u16()
						var d := spb.get_u16()
						var e := spb.get_u16()
						var f := spb.get_u16()
						var g := spb.get_u16()
						var h := spb.get_u16()
						entry.ip = PoolIntArray([a, b, c, d, e, f, g, h])
					else:
						var a := spb.get_u8()
						var b := spb.get_u8()
						var c := spb.get_u8()
						var d := spb.get_u8()
						entry.ip = PoolIntArray([a, b, c, d])
					entry.port = spb.get_u16()
					var l := spb.get_u8()
					entry.name = spb.get_data(l)[1].get_string_from_utf8()
					entries.push_back(entry)
				emit_signal("server_list", entries)
				got_server_list = true
			MSG_TYPE_REGISTER_SERVER:
				var status := spb.get_u8()
				match status:
					OK:
						if not server_scene.is_connected("tree_exiting", self, "remove_server"):
							var e := server_scene.connect("tree_exiting", self, "remove_server")
							assert(e == OK)
						registered = true
						print("Registered server")
						server_ping_timer.start()
					_:
						print("Failed to register server: %s" % Global.ERROR_TO_STRING[status])
						assert(false, "Failed to register server")
			MSG_TYPE_INFO:
				if spb.get_available_bytes() == 0:
					print("Failed to get info") # Can happen due to unfortunate timing
				else:
					var info := ServerInfo.new()
					info.max_players = spb.get_u8()
					var l := spb.get_u8()
					info.map = spb.get_data(l)[1].get_string_from_utf8()
					l = spb.get_u16()
					info.description = spb.get_data(l)[1].get_string_from_utf8()
					emit_signal("server_info", info)
					got_server_info = true
			MSG_TYPE_PUNCH_HOLE:
				var port := spb.get_u16()
				if port != server_port:
					print("Received punch request for unbound port")
					assert(false, "Received punch request for unbound port")
				var is_ipv6 := spb.get_u8()
				var addr: String
				if is_ipv6:
					var a := spb.get_u16()
					var b := spb.get_u16()
					var c := spb.get_u16()
					var d := spb.get_u16()
					var e := spb.get_u16()
					var f := spb.get_u16()
					var g := spb.get_u16()
					var h := spb.get_u16()
					addr = "%x:%x:%x:%x:%x:%x:%x:%x" % [a, b, c, d, e, f, g, h]
				else:
					var a := spb.get_u8()
					var b := spb.get_u8()
					var c := spb.get_u8()
					var d := spb.get_u8()
					addr = "%d.%d.%d.%d" % [a, b, c, d]
				port = spb.get_u16()
				var ppu := PacketPeerUDP.new()
				var e := ppu.set_dest_address(addr, port)
				assert(e == OK)
				print(("I got a request to punch a hole for %s:%d but I can't use"
					+ " the ENet socket yet :(") % [addr, port])
			MSG_TYPE_REMOVE_SERVER, MSG_TYPE_PING:
				assert(false, "Recieved response for no-response packet")
			_:
				assert(false, "Invalid message type")


func register_server(scene: Node) -> void:
	if not disable_upnp:
		var upnp := UPNP.new()
		var e := upnp.discover(100, upnp_ttl)
		match e:
			UPNP.UPNP_RESULT_SUCCESS:
				e = upnp.add_port_mapping(server_port)
				assert(e == UPNP.UPNP_RESULT_SUCCESS)
				match e:
					UPNP.UPNP_RESULT_SUCCESS:
						print("Added UPNP port mapping")
					UPNP.UPNP_RESULT_NO_GATEWAY:
						print("No gateway found")
					_:
						print("Faield to add UPNP port mapping")
						assert(false, "TODO proper error handling")
			UPNP.UPNP_RESULT_NO_DEVICES:
				print("No UPNP devices found")
			_:
				assert(false, "TODO handle this error code")
	else:
		print("UPNP disabled")

	if disable_lobby:
		print("Lobby disabled, ignoring register request")
		return
	assert(scene.multiplayer.network_peer != null, "No network peer active")
	assert(not registered, "Server already registered")
	assert(len(name) < 256, "Name too long")
	assert(len(scene.filename) < 256, "File path too long")
	assert(len(server_description) < 65536, "Description too long")

	server_scene = scene
	var spb := StreamPeerBuffer.new()
	spb.put_u8(MSG_TYPE_REGISTER_SERVER)
	spb.put_u16(server_port)
	spb.put_u8(len(server_name))
	var e := spb.put_data(server_name.to_utf8())
	assert(e == OK)
	spb.put_u8(len(server_scene.filename))
	e = spb.put_data(server_scene.filename.to_utf8())
	assert(e == OK)
	spb.put_u8(server_max_players)
	spb.put_u16(len(server_description))
	e = spb.put_data(server_description.to_utf8())
	assert(e == OK)

	while not registered:
		print("Attempting to register server")
		e = lobby_peer.put_packet(spb.data_array)
		assert(e == OK)
		yield(get_tree().create_timer(1.0), "timeout")

	# Reregister periodically in case the lobby stopped (and thus lost the entry)
	while true:
		yield(get_tree().create_timer(100), "timeout")
		if server_scene == null:
			break
		e = lobby_peer.put_packet(spb.data_array)
		assert(e == OK)


func remove_server() -> void:
	var spb := StreamPeerBuffer.new()
	spb.put_u8(MSG_TYPE_REGISTER_SERVER)
	spb.put_u16(server_port)
	registered = false
	server_scene = null
	server_ping_timer.stop()


func ping() -> void:
	assert(registered)
	var spb := StreamPeerBuffer.new()
	spb.put_u8(MSG_TYPE_PING)
	spb.put_u16(server_port)
	var e := lobby_peer.put_packet(spb.data_array)
	assert(e == OK)


func get_server_list(filter := "") -> void:
	var pkt := PoolByteArray()
	pkt.push_back(MSG_TYPE_LIST)
	pkt.append_array(filter.to_utf8())

	got_server_list = false
	while not got_server_list:
		var e := lobby_peer.put_packet(pkt)
		assert(e == OK)
		yield(get_tree().create_timer(1.0), "timeout")


func get_server_info(entry: Entry) -> void:
	var spb := StreamPeerBuffer.new()
	spb.put_u8(MSG_TYPE_INFO)
	match len(entry.ip):
		4:
			spb.put_u8(0)
			for n in entry.ip:
				spb.put_u8(n)
		8:
			spb.put_u8(1)
			for n in entry.ip:
				spb.put_u16(n)
		_:
			assert(false, "Invalid IP address")
	spb.put_u16(entry.port)

	got_server_info = false
	while not got_server_info:
		var e := lobby_peer.put_packet(spb.data_array)
		assert(e == OK)
		yield(get_tree().create_timer(1), "timeout")


func punch_hole(entry: Entry) -> void:
	var spb := StreamPeerBuffer.new()
	spb.put_u8(MSG_TYPE_PUNCH_HOLE)
	match len(entry.ip):
		4:
			spb.put_u8(0)
			for n in entry.ip:
				spb.put_u8(n)
		8:
			spb.put_u8(1)
			for n in entry.ip:
				spb.put_u16(n)
		_:
			assert(false, "Invalid IP address")
	spb.put_u16(entry.port)

	client_connected = false
	# If the connection fails after 5 tries, the server is likely unreachable anyways
	for _i in 5:
		var e := lobby_peer.put_packet(spb.data_array)
		assert(e == OK)
		yield(get_tree().create_timer(1.0), "timeout")
		if client_connected:
			break


func set_player_name(value: String) -> void:
	player_name = value
	OwnWar_Settings.dirty = true
