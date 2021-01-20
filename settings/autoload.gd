extends Node


signal shadows_toggled(enabled)
signal floor_mirror_toggled(enabled)

var enable_shadows := false setget set_enable_shadows
var enable_floor_mirror := true setget set_enable_floor_mirror
var master_volume := 0.0
var music_volume := 0.0
var effects_volume := 0.0
var ui_volume := 0.0


func _enter_tree() -> void:
	load_settings()


func set_msaa(value: int) -> void:
	assert(0 <= value)
	assert(value <= Viewport.MSAA_16X)
	var root := get_tree().root
	root.msaa = value
	ProjectSettings.set_setting("rendering/quality/filters/msaa", value)


func get_msaa() -> int:
	return ProjectSettings.get_setting("rendering/quality/filters/msaa")


func enable_shadows(enabled: bool) -> void:
	enable_shadows = enabled


func set_shadow_filter_mode(value: int) -> void:
	assert(0 <= value)
	assert(value <= 2)
	ProjectSettings.set_setting("rendering/quality/shadows/filter_mode", value)


func get_shadow_filter_mode() -> int:
	return ProjectSettings.get_setting("rendering/quality/shadows/filter_mode")


func enable_floor_mirror(enabled: bool) -> void:
	enable_floor_mirror = enabled


func set_enable_shadows(value: bool) -> void:
	enable_shadows = value
	emit_signal("shadows_toggled", value)


func set_enable_floor_mirror(value: bool) -> void:
	enable_floor_mirror = value
	emit_signal("floor_mirror_toggled", value)


func save_settings() -> void:
	var cf := ConfigFile.new()

	var actions := Array(InputMap.get_actions())
	actions.sort() # Sort to make the config file a little user-friendlier
	for a in actions:
		if a.begins_with("ui_"):
			continue # Don't save ui_* bindings to prevent disaster
		for e in InputMap.get_action_list(a):
			if e is InputEventKey:
				cf.set_value("input_map", a, e.as_text())
			elif e is InputEventMouseButton:
				cf.set_value("input_map", a, "MOUSE_BUTTON_%d" % e.button_index)
			else:
				assert(false, "Invalid event type")
			break # Only save one event
	
	for bus in ["Master", "Music", "Effects", "UI"]:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			print("Audio bus not found: %s" % bus)
			assert(false, "Audio bus not found")
			continue
		var vol: float
		if AudioServer.is_bus_mute(index):
			vol = 0.0
		else:
			var db := AudioServer.get_bus_volume_db(index)
			vol = db2linear(db)
		cf.set_value("audio_buses", bus, vol)

	cf.set_value("graphics", "msaa", ProjectSettings.get_setting("rendering/quality/filters/msaa"))
	cf.set_value("graphics", "shadows", enable_shadows)
	cf.set_value("graphics", "shadows_filter_mode",
		ProjectSettings.get_setting("rendering/quality/shadows/filter_mode"))
	cf.set_value("graphics", "floor_mirror", enable_floor_mirror)

	var e := cf.save(OwnWar.SETTINGS_FILE)
	if e != OK:
		print("Failed to save custom settings: %s" % Global.ERROR_TO_STRING[e])
		assert(false, "Failed to save custom settings")
	else:
		print("Saved settings")


func load_settings() -> void:
	var cf := ConfigFile.new()
	var e := cf.load(OwnWar.SETTINGS_FILE)
	match e:
		OK:
			for a in cf.get_section_keys("input_map"):
				var v: String = cf.get_value("input_map", a, "")
				if v == "":
					continue
				if v.begins_with("MOUSE_BUTTON_"):
					v = v.substr(len("MOUSE_BUTTON_"))
					if not v.is_valid_integer():
						print("Invalid mouse button: %s" % v)
						assert(false, "Invalid mouse button")
						continue
					var ev := InputEventMouseButton.new()
					ev.button_index = int(v)
					InputMap.action_erase_events(a)
					InputMap.action_add_event(a, ev)
				else:
					var ev := InputEventKey.new()
					ev.scancode = OS.find_scancode_from_string(v)
					if ev.scancode == 0:
						print("Invalid key: %s" % v)
						assert(false, "Invalid key")
						continue
					InputMap.action_erase_events(a)
					InputMap.action_add_event(a, ev)
			
			for bus in cf.get_section_keys("audio_buses"):
				var index := AudioServer.get_bus_index(bus)
				if index < 0:
					print("Audio bus not found: %s" % bus)
					assert(false, "Audio bus not found")
					continue
				var vol: float = cf.get_value("audio_buses", bus)
				AudioServer.set_bus_mute(index, vol == 0)
				if vol > 0:
					AudioServer.set_bus_volume_db(index, linear2db(vol))

			ProjectSettings.set_setting("rendering/quality/filters/msaa",
				cf.get_value("graphics", "msaa"))
			enable_shadows = cf.get_value("graphics", "shadows")
			ProjectSettings.set_setting("rendering/quality/shadows/filter_mode",
				cf.get_value("graphics", "shadows_filter_mode"))
			enable_floor_mirror = cf.get_value("graphics", "floor_mirror")

			var root := get_tree().root
			root.msaa = ProjectSettings.get_setting("rendering/quality/filters/msaa")

			print("Loaded settings")
		ERR_FILE_NOT_FOUND:
			print("No custom configuration file found")
		_:
			print("Failed to load custom settings: %s" % Global.ERROR_TO_STRING[e])
			assert(false, "Failed to load custom settings")

