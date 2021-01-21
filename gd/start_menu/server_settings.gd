extends VBoxContainer


export var username_path := NodePath()
onready var username: LineEdit = get_node(username_path)


func _ready() -> void:
	username.text = OwnWar_Lobby.player_name
	var e := username.connect("text_changed", OwnWar_Lobby, "set_player_name")
	assert(e == OK)
	e = username.connect("text_entered", self, "clear_focus")
	assert(e == OK)


func clear_focus(_zzz = null) -> void:
	username.release_focus()
