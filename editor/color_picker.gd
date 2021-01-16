extends ColorRect


signal pick_color(color)

const COLORS = [Color.white, Color.gray, Color.black, Color.red, Color.green,
		Color.blue, Color.yellow, Color.purple, Color.orange, Color.darkgreen,
		Color.beige, Color.brown]

export var button: PackedScene
export var _list := NodePath()

onready var list: Control = get_node(_list)


func _ready():
	for clr in COLORS:
		var btn := button.instance()
		btn.get_node("ColorRect").color = clr
		var e := btn.connect("pressed", self, "emit_signal", ["pick_color", clr])
		assert(e == OK)
		e = btn.connect("pressed", self, "set_visible", [false])
		assert(e == OK)
		list.add_child(btn)
