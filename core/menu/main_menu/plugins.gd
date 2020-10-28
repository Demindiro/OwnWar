extends "res://core/menu/dialog/independent_panel.gd"


export var button_template: PackedScene


func _ready():
	for plugin in Plugins.plugins.values():
		var button: Button = button_template.instance()
		button.text = "%s (%d.%d.%d)" % [plugin.PLUGIN_ID,
				plugin.PLUGIN_VERSION.x, plugin.PLUGIN_VERSION.y, plugin.PLUGIN_VERSION.z
			]
		$ScrollContainer/VBoxContainer.add_child(button)
	var reverse_map := {}
	for key in Plugins.DisableReason.keys():
		reverse_map[Plugins.DisableReason[key]] = key
	for id in Plugins.disabled_plugins:
		var button: Button = button_template.instance()
		button.text = "%s (%s)" % [id, reverse_map[Plugins.disabled_plugins[id]]]
		button.modulate = Color.red;
		$ScrollContainer/VBoxContainer.add_child(button)
