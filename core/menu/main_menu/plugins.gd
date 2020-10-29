extends "res://core/menu/dialog/independent_panel.gd"


export var button_template: PackedScene


func _ready():
	for plugin in Plugin.get_all_plugins():
		var button: Button = button_template.instance()
		button.text = "%s (%d.%d.%d)" % [plugin.PLUGIN_ID,
				plugin.PLUGIN_VERSION.x, plugin.PLUGIN_VERSION.y, plugin.PLUGIN_VERSION.z
			]
		button.connect("pressed", self, "_show_info", [plugin.PLUGIN_ID])
		match Plugin.get_disable_reason(plugin.PLUGIN_ID):
			Plugin.DisableReason.NONE:
				pass
			Plugin.DisableReason.MANUAL:
				button.modulate = Color.orange
			_:
				button.modulate = Color.red
		$ScrollContainer/VBoxContainer.add_child(button)


func _show_info(id: String) -> void:
	var plugin := Plugin.get_plugin(id)

	$Info.visible = true
	$Info/VBoxContainer/ID.text = "ID: " + id
	$Info/VBoxContainer/Version.text = "Version: %d.%d.%d" % [plugin.PLUGIN_VERSION.x,
			plugin.PLUGIN_VERSION.y, plugin.PLUGIN_VERSION.z]
	$Info/VBoxContainer/Dependencies.text = "Dependencies: " + \
			PoolStringArray(plugin.PLUGIN_DEPENDENCIES.keys()).join(", ")
	$Info/VBoxContainer/Enabled.disconnect("toggled", self, "_enable_plugin")
	$Info/VBoxContainer/Enabled.pressed = Plugin.is_plugin_enabled(id)
	$Info/VBoxContainer/Enabled.connect("toggled", self, "_enable_plugin", [id])

	var disable_reason = Plugin.get_disable_reason(id)
	match disable_reason:
		Plugin.DisableReason.NONE:
			$Info/VBoxContainer/Enabled.visible = true
			$Info/VBoxContainer/Errors.visible = false
		Plugin.DisableReason.MANUAL:
			$Info/VBoxContainer/Enabled.visible = true
			$Info/VBoxContainer/Errors.visible = false
		_:
			$Info/VBoxContainer/Enabled.visible = false
			$Info/VBoxContainer/Errors.visible = true
			var reverse_map := {}
			for key in Plugin.DisableReason.keys():
				reverse_map[Plugin.DisableReason[key]] = key
			var reason: int = Plugin.get_disable_reason(id)
			$Info/VBoxContainer/Errors.text = "Error: " + reverse_map[reason]


func _enable_plugin(enable: bool, id: String):
	Plugin.enable_plugin(id, enable)
