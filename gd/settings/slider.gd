tool
extends HBoxContainer


signal value_changed(value)

export var value := 0.0 setget set_value
export var min_value := 0.0 setget set_min_value
export var max_value := 100.0 setget set_max_value
export var step := 1.0 setget set_step
export var exp_edit := false setget set_exp_edit

onready var _name: Label = get_node("Name")
onready var _slider: HSlider = get_node("Slider")
onready var _value: Label = get_node("Value")


func _ready() -> void:
	var e := connect("renamed", self, "on_renamed")
	assert(e == OK)
	e = _slider.connect("value_changed", self, "set_value")
	assert(e == OK)
	_name.text = name
	_slider.value = value
	_slider.max_value = max_value
	_slider.min_value = min_value
	_slider.step = step
	_slider.exp_edit = exp_edit
	_value.text = str(value)


func on_renamed() -> void:
	_name.text = name


func set_value(v: float) -> void:
	value = v
	if _slider != null:
		_slider.value = v
	if _value != null:
		_value.text = str(v)
	emit_signal("value_changed", v)


func set_max_value(v: float) -> void:
	max_value = v
	if _slider != null:
		_slider.max_value = v


func set_min_value(v: float) -> void:
	min_value = v
	if _slider != null:
		_slider.min_value = v


func set_step(v: float) -> void:
	step = v
	if _slider != null:
		_slider.step = v


func set_exp_edit(v: bool) -> void:
	exp_edit = v
	if _slider != null:
		_slider.exp_edit = v
