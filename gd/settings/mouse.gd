extends ScrollContainer


const CustomSlider := preload("slider.gd")

export var move_sensitivity_path := NodePath()
export var scroll_sensitivity_path := NodePath()

onready var move_sensitivity: CustomSlider = get_node(move_sensitivity_path)
onready var scroll_sensitivity: CustomSlider = get_node(scroll_sensitivity_path)


func _ready():
	move_sensitivity.value = OwnWar_Settings.mouse_move_sensitivity
	scroll_sensitivity.value = OwnWar_Settings.mouse_scroll_sensitivity
	var e := move_sensitivity.connect("value_changed", OwnWar_Settings, "set_mouse_move_sensitivity")
	assert(e == OK)
	e = scroll_sensitivity.connect("value_changed", OwnWar_Settings, "set_mouse_scroll_sensitivity")
	assert(e == OK)
