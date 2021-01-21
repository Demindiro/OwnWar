extends Node


signal received_server_map(path)


# TODO find a way to use multiple IDs somehow
var disable_broadcast_id := 0


func _ready() -> void:
	var e := get_tree().connect("network_peer_connected", self, "on_client_connect")
	assert(e == OK)
	e = get_tree().connect("network_peer_disconnected", self, "on_client_disconnect")
	assert(e == OK)


func on_client_connect(id: int) -> void:
	if get_tree().is_network_server():
		disable_broadcast_id = id
		rpc_id(id, "send_current_map", get_tree().current_scene.filename)


func on_client_disconnect(id: int) -> void:
	if disable_broadcast_id == id:
		disable_broadcast_id = 0


func enable_broadcast(id: int) -> void:
	if disable_broadcast_id == id:
		disable_broadcast_id = 0


puppet func send_current_map(path: String) -> void:
	emit_signal("received_server_map", path)
