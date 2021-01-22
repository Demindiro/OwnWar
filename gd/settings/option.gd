tool
extends HBoxContainer


signal item_selected(index)

export var options := PoolStringArray() setget set_options

var selected := 0 setget set_selected

onready var _label: Label = get_node("Label")
onready var _options: OptionButton = get_node("Options")


func _ready() -> void:
	var e := _options.connect("item_selected", self, "on_item_selected")
	assert(e == OK)
	e = connect("renamed", self, "on_renamed")
	assert(e == OK)
	set_options(options)
	_label.text = name


func set_options(value: PoolStringArray) -> void:
	options = value
	if not is_inside_tree():
		return
	_options.clear()
	for v in value:
		_options.add_item(v)


func set_selected(value: int) -> void:
	selected = value
	_options.selected = value


func on_item_selected(index: int) -> void:
	emit_signal("item_selected", index)


func on_renamed() -> void:
	_label.text = name
