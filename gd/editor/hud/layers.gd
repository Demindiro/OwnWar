extends Control


signal add_layer
signal select_layer(index)
signal remove_layer(index)
signal rename_layer(index, name)


export var list_path := NodePath()
export var name_path := NodePath()
onready var list_node: Control = get_node(list_path)
onready var name_node: LineEdit = get_node(name_path)
var layer_to_buttons := []
var button_group := ButtonGroup.new()
var selected_index := -1


func add_layer(p_name: String) -> void:
	var box := HBoxContainer.new()
	var btn := Button.new()
	var i := len(layer_to_buttons)
	btn.group = button_group
	btn.text = p_name
	btn.focus_mode = FOCUS_NONE
	btn.size_flags_horizontal = SIZE_EXPAND_FILL
	btn.toggle_mode = true
	var rem_btn := Button.new()
	rem_btn.text = "x"
	rem_btn.focus_mode = FOCUS_NONE
	rem_btn.size_flags_horizontal = 0
	box.add_child(rem_btn)
	box.add_child(btn)
	rem_btn.rect_min_size = Vector2(32, 32)
	layer_to_buttons.push_back([btn, rem_btn])
	list_node.add_child(box)
	connect_buttons([btn, rem_btn], i)
	call_deferred("user_select_layer", i)


func _ready() -> void:
	call_deferred("call_deferred", "user_select_layer", 0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# godot pls
		name_node.release_focus()


func remove_layer(index: int) -> void:
	layer_to_buttons[index][0].queue_free()
	layer_to_buttons[index][1].queue_free()
	layer_to_buttons.remove(index)
	for i in range(index, len(layer_to_buttons)):
		disconnect_buttons(layer_to_buttons[i])
		connect_buttons(layer_to_buttons[i], i)


func select_layer(index: int) -> void:
	selected_index = index
	name_node.text = layer_to_buttons[index][0].text
	layer_to_buttons[index][0].pressed = true
	layer_to_buttons[index][0].grab_focus()
	layer_to_buttons[index][0].release_focus()


func rename_layer(index: int, p_name: String) -> void:
	layer_to_buttons[index][0].text = p_name


func user_add_layer() -> void:
	emit_signal("add_layer")


func user_select_layer(index: int) -> void:
	emit_signal("select_layer", index)


func user_remove_layer(index: int) -> void:
	emit_signal("remove_layer", index)


func user_rename_layer(p_name: String) -> void:
	assert(selected_index >= 0, "No selected layer!")
	emit_signal("rename_layer", selected_index, p_name)


func connect_buttons(buttons: Array, index: int) -> void:
	var e: int = buttons[0].connect("pressed", self, "user_select_layer", [index])
	assert(e == OK)
	e = buttons[1].connect("pressed", self, "user_remove_layer", [index])
	assert(e == OK)


func disconnect_buttons(buttons: Array) -> void:
	buttons[0].disconnect("pressed", self, "user_select_layer")
	buttons[1].disconnect("pressed", self, "user_remove_layer")
