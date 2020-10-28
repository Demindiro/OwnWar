extends "res://core/menu/dialog/independent_panel.gd"


export var button_template: PackedScene


func _ready():
	for plugin in Plugins.plugins.values():
		var button: Button = button_template.instance()
		button.text = "%s (%d.%d.%d)" % [plugin.PLUGIN_ID,
				plugin.PLUGIN_VERSION.x, plugin.PLUGIN_VERSION.y, plugin.PLUGIN_VERSION.z
			]
		button.connect("pressed", self, "_show_info", [plugin.PLUGIN_ID])
		$ScrollContainer/VBoxContainer.add_child(button)
	var reverse_map := {}
	for key in Plugins.DisableReason.keys():
		reverse_map[Plugins.DisableReason[key]] = key
	for id in Plugins.disabled_plugins:
		var button: Button = button_template.instance()
		button.text = "%s (%s)" % [id, reverse_map[Plugins.disabled_plugins[id]]]
		button.modulate = Color.red;
		button.connect("pressed", self, "_show_info", [id])
		$ScrollContainer/VBoxContainer.add_child(button)


func _show_info(plugin_id: String) -> void:
	$Info.visible = true
	$Info/VBoxContainer/ID.text = "ID: " + plugin_id
	if plugin_id in Plugins.plugins:
		var plugin = Plugins.plugins[plugin_id]
		$Info/VBoxContainer/Version.visible = true
		$Info/VBoxContainer/Version.text = "Version: %d.%d.%d" % [plugin.PLUGIN_VERSION.x,
				plugin.PLUGIN_VERSION.y, plugin.PLUGIN_VERSION.z]
		$Info/VBoxContainer/Dependencies.visible = true
		$Info/VBoxContainer/Dependencies.text = "Dependencies: " + \
				PoolStringArray(plugin.PLUGIN_DEPENDENCIES.keys()).join(", ")
		$Info/VBoxContainer/Enabled.pressed = true
		$Info/VBoxContainer/Errors.visible = false
	else:
		var reverse_map := {}
		for key in Plugins.DisableReason.keys():
			reverse_map[Plugins.DisableReason[key]] = key
		var reason: int = Plugins.disabled_plugins[plugin_id]
		$Info/VBoxContainer/Version.visible = false
		$Info/VBoxContainer/Dependencies.visible = false
		$Info/VBoxContainer/Enabled.pressed = false
		$Info/VBoxContainer/Errors.visible = true
		$Info/VBoxContainer/Errors.text = "Error: " + reverse_map[reason]
