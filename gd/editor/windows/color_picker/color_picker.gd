extends "../window.gd"


# warning-ignore:unused_signal
signal pick_color(index)
signal request_hide
signal create_color(color)
signal change_color(index, color)
signal remove_color(index)

export var button: PackedScene
export var _list := NodePath()
export var picker := NodePath()

onready var list: Control = get_node(_list)

var index_to_button := []
var picker_index := -1

	
func add_color(color: Color) -> void:
	var btn := button.instance()
	var i := len(index_to_button)
	btn.get_node("ColorRect").color = color
	connect_button(btn, i)
	var e := btn.connect("pressed", self, "request_hide")
	assert(e == OK)
	index_to_button.push_back([btn, color])
	list.add_child(btn)
	# There's add_child_below but this is easier IMO
	list.move_child(btn, list.get_child_count() - 2)
	call_deferred("select_color", i)


func _ready() -> void:
	# Hey, as long as it works...
	call_deferred("call_deferred", "select_color", 0)


func select_color(index: int) -> void:
	picker_index = index
	emit_signal("pick_color", index)


func change_color(index: int, color: Color) -> void:
	index_to_button[index][0].get_node("ColorRect").color = color
	index_to_button[index][1] = color


func delete_color(index: int) -> void:
	index_to_button[index].queue_free()
	index_to_button.remove(index)
	for i in range(index, len(index_to_button)):
		disconnect_button(index_to_button[i][0])
		connect_button(index_to_button[i][0], i)


func create_color() -> void:
	emit_signal("create_color", index_to_button[picker_index][1])


func remove_color() -> void:
	emit_signal("remove_color", picker_index)


func set_picker_color(color: Color) -> void:
	emit_signal("change_color", picker_index, color)


func request_hide() -> void:
	emit_signal("request_hide")


func connect_button(button: Button, index: int) -> void:
	var e := button.connect("pressed", self, "select_color", [index])
	assert(e == OK)
	e = button.connect("alternate_pressed", self, "select_color", [index])
	assert(e == OK)


func disconnect_button(button: Button) -> void:
	button.disconnect("pressed", self, "select_color")
	button.disconnect("alternate_pressed", self, "select_picker")
