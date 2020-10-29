extends "../dialog/independent_panel.gd"


export var button_template: PackedScene


func _ready():
	for map in Maps.MAPS:
		var button: Button = button_template.instance()
		button.text = map
		button.connect("pressed", Global, "goto_scene", [Maps.MAPS[map]])
		$VBoxContainer.add_child(button)
