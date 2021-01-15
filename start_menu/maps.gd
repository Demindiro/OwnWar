extends "../dialog/independent_panel.gd"


export var button_template: PackedScene


func _ready():
	for map in OwnWar.Maps.MAPS:
		var button: Button = button_template.instance()
		button.text = map
		var e := button.connect("pressed", Global, "goto_scene",
			[OwnWar.Maps.MAPS[map]])
		assert(e == OK)
		$VBoxContainer.add_child(button)
