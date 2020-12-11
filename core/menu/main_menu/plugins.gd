extends "res://core/menu/dialog/independent_panel.gd"


onready var _info: Control = $Info
onready var _info_id: Label = $Info/Box/Attributes/ID
onready var _info_version: Label = $Info/Box/Attributes/Version
onready var _info_dependencies_box: VBoxContainer = \
	$Info/Box/Dependencies/Box/Box/Box
onready var _info_enabled: Button = $Info/Box/Attributes/Enabled
onready var _info_errors: Label = $Info/Box/Attributes/Errors
onready var _list: BoxContainer = $List/Box


func _ready():
	var plugins = Plugin.get_all_plugins()
	for id in plugins:
		var plugin: Plugin.PluginState = plugins[id]
		var button := Button.new()
		button.text = id
		button.align = Button.ALIGN_LEFT
		var e := button.connect("pressed", self, "_show_info", [id])
		assert(e == OK)
		match plugin.disable_reason:
			Plugin.PluginState.NONE:
				pass
			Plugin.PluginState.MANUAL:
				button.modulate = Color.orange
			_:
				button.modulate = Color.red
		_list.add_child(button)


func _show_info(id: String) -> void:
	var plugin := Plugin.get_plugin(id)

	_info.visible = true
	_info_id.text = id
	_info_version.text = Util.version_vector_to_str(plugin.get_version())
	Util.free_children(_info_dependencies_box)
	var dependencies := plugin.get_dependencies()
	for id in dependencies:
		var label := Label.new()
		label.text = id
		_info_dependencies_box.add_child(label)
	if _info_enabled.is_connected("toggled", self, "_enable_plugin"):
		_info_enabled.disconnect("toggled", self, "_enable_plugin")
	_info_enabled.pressed = Plugin.is_plugin_enabled(id)
	var e := _info_enabled.connect("toggled", self, "_enable_plugin", [id])
	assert(e == OK)

	var disable_reason = Plugin.get_disable_reason(id)
	match disable_reason:
		Plugin.PluginState.NONE:
			_info_enabled.visible = true
			_info_errors.text = ""
		Plugin.PluginState.MANUAL:
			_info_enabled.visible = true
			_info_errors.text = ""
		_:
			_info_enabled.visible = false
			var strs := PoolStringArray()
			var reason: int = Plugin.get_disable_reason(id)
			for i in range(64):
				var m := 1 << i
				if reason & m:
					strs.append(Plugin.PluginState.DISABLE_REASON_TO_STR[m])
			_info_errors.text = strs.join(", ")


func _enable_plugin(enable: bool, id: String):
	var success := Plugin.enable_plugin(id, enable)
	if not success:
		Global.error("Failed to toggle plugin")
