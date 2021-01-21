extends BaseButton


export var _icon := NodePath()
export var _name := NodePath()

onready var icon: TextureRect = get_node(_icon)
onready var name_s: Label = get_node(_name)
