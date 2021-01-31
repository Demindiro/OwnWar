tool
extends HBoxContainer


signal toggled(value)

var pressed := false setget set_pressed

onready var _label: Label = get_node("Label")
onready var _value: BaseButton = get_node("Value")


func _ready() -> void:
	var e := connect("renamed", self, "on_renamed")
	assert(e == OK)
	_label.text = name
	pressed = _value.pressed


func on_renamed() -> void:
	_label.text = name


func set_pressed(v: bool) -> void:
	pressed = v
	_value.pressed = v
	emit_signal("toggled", v)
