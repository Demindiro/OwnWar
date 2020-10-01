tool
extends Control


signal pressed(button_name)

export(String) var title = "Title" setget set_title
export(Array, Array, String) var buttons = [] setget set_buttons
var ready = false

func _ready():
	ready = true
	set_title(title)
	set_buttons(buttons)


func set_buttons(p_buttons):
	if not ready:
		return # Not _ready() yet
	buttons = p_buttons
	for child in $Panel/VBoxContainer.get_children():
		child.queue_free()
	for button in buttons:
		var node = $MenuButton.duplicate()
		node.name = button[1]
		node.text = button[0]
		node.visible = true
		node.connect("pressed", self, "pressed", [button[1]])
		$Panel/VBoxContainer.add_child(node)


func set_title(p_title):
	title = p_title
	$Title.text = title


func pressed(button_name):
	emit_signal("pressed", button_name)
