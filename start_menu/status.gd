extends VBoxContainer


enum {
	STATUS_NONE,
	STATUS_OK,
	STATUS_WARN,
	STATUS_ERR,
}

export(float, 0, 1800) var spin_speed := 60.0
export var spin := false
export var _error := NodePath()
export var _icon := NodePath()

onready var error: Label = get_node(_error)
onready var icon: TextureRect = get_node(_icon)


func _process(delta: float) -> void:
	if spin:
		icon.rect_rotation += delta * spin_speed
	else:
		icon.rect_rotation = 0.0


func set_status(type: int, message: String, p_icon: Texture, p_spin := false) -> void:
	match type:
		STATUS_NONE: error.modulate = Color.white
		STATUS_OK: error.modulate = Color.green
		STATUS_WARN: error.modulate = Color.yellow
		STATUS_ERR: error.modulate = Color.red
		_: assert(false, "Unknown status type")
	error.text = message
	icon.texture = p_icon
	spin = p_spin
