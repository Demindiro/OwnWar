extends "res://core/menu/dialog/independent_panel.gd"


signal pick_color(color)
const COLORS = [Color.white, Color.gray, Color.black, Color.red, Color.green,
		Color.blue, Color.yellow, Color.purple, Color.orange, Color.darkgreen,
		Color.beige, Color.brown]
var _template
var _escape_pressed = false


func _ready():
	_template = $GridContainer/Template
	$GridContainer.remove_child(_template)
	for color in COLORS:
		var button = _template.duplicate()
		button.get_node("ColorRect").color = color
		button.connect("pressed", self, "_button_pressed", [color])
		$GridContainer.add_child(button)
	_template.free()


func _unhandled_input(event):
	if not visible:
		return
	if event.is_action("ui_cancel") or event.is_action("editor_open_colorpicker"):
		if event.pressed:
			_escape_pressed = true
		elif _escape_pressed:
			visible = false
			_escape_pressed = false


func _button_pressed(color):
	visible = false
	emit_signal("pick_color", color)
