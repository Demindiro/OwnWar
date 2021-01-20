extends PanelContainer


export var input_path := NodePath()
export var messages_path := NodePath()
export var font: Font
onready var input: LineEdit = get_node(input_path)
onready var messages: Control = get_node(messages_path)


func send_message(text: String) -> void:
	if text == "":
		return
	rpc("receive_message", "%s: %s" % [OwnWar_Lobby.player_name, text])
	input.text = ""
	input.release_focus()


remotesync func receive_message(text: String) -> void:
	var msg := Label.new()
	msg.text = text
	msg.set("custom_fonts/font", font)
	msg.autowrap = true
	if messages.get_child_count() > 8: # TODO find a proper solution
		var n := messages.get_child(0)
		messages.remove_child(n)
		n.queue_free()
	messages.add_child(msg)
