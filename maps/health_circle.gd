tool
extends ColorRect


export(float, 0.0, 1.0) var value := 1.0 setget set_value

var _label := Label.new()


func _ready() -> void:
	_label.text = str(int(value * 100)) + "%"
	_label.anchor_right = 1
	_label.anchor_bottom = 1
	_label.align = Label.ALIGN_CENTER
	_label.valign = Label.VALIGN_CENTER
	add_child(_label)
	material.set_shader_param("fill_ratio", value)


func set_value(v: float) -> void:
	value = v
	if _label == null:
		return
	_label.text = str(int(v * 100)) + "%"
	material.set_shader_param("fill_ratio", v)
	update()
