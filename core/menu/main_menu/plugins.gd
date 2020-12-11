extends "res://core/menu/dialog/independent_panel.gd"


export var button_template: PackedScene
onready var _info: Control = $Info
onready var _info_id: Label = $Info/VBoxContainer/ID
onready var _info_version: Label = $Info/VBoxContainer/Version
onready var _info_dependencies: Label = $Info/VBoxContainer/Dependencies
onready var _info_enabled: Button = $Info/VBoxContainer/Enabled
onready var _info_errors: Label = $Info/VBoxContainer/Errors



func _ready():
	var plugins = Plugin.get_all_plugins()
	for id in plugins:
		var plugin: PluginInterface = plugins[id].singleton
		var button: Button = button_template.instance()
		button.text = "%s (%d.%d.%d)" % [id,
				plugin.PLUGIN_VERSION.x, plugin.PLUGIN_VERSION.y, plugin.PLUGIN_VERSION.z
			]
		var e := button.connect("pressed", self, "_show_info", [plugin.PLUGIN_ID])
		assert(e == OK)
		match Plugin.get_disable_reason(plugin.PLUGIN_ID):
			Plugin.PluginState.NONE:
				pass
			Plugin.PluginState.MANUAL:
				button.modulate = Color.orange
			_:
				button.modulate = Color.red
		$ScrollContainer/VBoxContainer.add_child(button)


func _show_info(id: String) -> void:
	var plugin := Plugin.get_plugin(id)

	_info.visible = true
	_info_id.text = "ID: " + id
	# warning-ignore:unsafe_property_access
	var version: Vector3 = plugin.PLUGIN_VERSION
	_info_version.text = "Version: %s" % Util.version_vector_to_str(version)
	# warning-ignore:unsafe_property_access
	var deps: Dictionary = plugin.PLUGIN_DEPENDENCIES
	_info_dependencies.text = "Dependencies: " + PoolStringArray(deps.keys()) \
			.join(", ")
	_info_enabled.disconnect("toggled", self, "_enable_plugin")
	_info_enabled.pressed = Plugin.is_plugin_enabled(id)
	var e := _info_enabled.connect("toggled", self, "_enable_plugin", [id])
	assert(e == OK)

	var disable_reason = Plugin.get_disable_reason(id)
	match disable_reason:
		Plugin.PluginState.NONE:
			_info_enabled.visible = true
			_info_errors.visible = false
		Plugin.PluginState.MANUAL:
			_info_enabled.visible = true
			_info_errors.visible = false
		_:
			_info_enabled.visible = false
			_info_errors.visible = true
			var strs := PoolStringArray()
			var reason: int = Plugin.get_disable_reason(id)
			for i in range(64):
				var m := 1 << i
				if reason & m:
					strs.append(Plugin.PluginState.DISABLE_REASON_TO_STR[m])
			_info_errors.text = "Error: " + strs.join(", ")


func _enable_plugin(enable: bool, id: String):
	var success := Plugin.enable_plugin(id, enable)
	if not success:
		Global.error("Failed to toggle plugin")
