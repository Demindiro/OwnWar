extends Node


signal shadows_toggled(enabled)
signal floor_mirror_toggled(enabled)

var enable_shadows := false setget set_enable_shadows
var enable_floor_mirror := true setget set_enable_floor_mirror
var master_volume := 0.0
var music_volume := 0.0
var effects_volume := 0.0
var ui_volume := 0.0
var username := ""


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
	cf.set_value("graphics", "vsync", OS.vsync_enabled)
	cf.set_value("graphics", "vsync_compositor", OS.vsync_via_compositor)
	cf.set_value("graphics", "window_fullscreen", OS.window_fullscreen)
	cf.set_value("graphics", "window_borderless", OS.window_borderless)
	cf.set_value("graphics", "fps", Engine.target_fps)

	cf.set_value("server", "username", OwnWar_Lobby.player_name)
	cf.set_value("server", "upnp", not OwnWar_Lobby.disable_upnp)
	cf.set_value("server", "lobby", not OwnWar_Lobby.disable_lobby)
	cf.set_value("server", "upnp_ttl", OwnWar_Lobby.upnp_ttl)
	cf.set_value("server", "name", OwnWar_Lobby.server_name)
	cf.set_value("server", "port", OwnWar_Lobby.server_port)
	cf.set_value("server", "max_players", OwnWar_Lobby.server_max_players)
	cf.set_value("server", "description", OwnWar_Lobby.server_description)

	cf.set_value("menu", "selected_vehicle", OwnWar_Lobby.player_vehicle_path)

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
			OS.set_use_vsync(cf.get_value("graphics", "vsync", true))
			OS.vsync_via_compositor = cf.get_value("graphics", "vsync_compositor", false)
			OS.window_fullscreen = cf.get_value("graphics", "window_fullscreen", true)
			OS.window_borderless = cf.get_value("graphics", "window_borderless", false)
			Engine.target_fps = cf.get_value("graphics", "fps", 0)

			OwnWar_Lobby.player_name = cf.get_value("server", "username", "")
			OwnWar_Lobby.disable_upnp = not cf.get_value("server", "upnp", true)
			OwnWar_Lobby.disable_lobby = not cf.get_value("server", "lobby", true)
			OwnWar_Lobby.upnp_ttl = cf.get_value("server", "upnp_ttl", 2)
			OwnWar_Lobby.server_name = cf.get_value("server", "name", "")
			OwnWar_Lobby.server_port = cf.get_value("server", "port", 39983)
			OwnWar_Lobby.server_max_players = cf.get_value("server", "max_players", 10)
			OwnWar_Lobby.server_description = cf.get_value("server", "description", "")

			OwnWar_Lobby.player_vehicle_path = cf.get_value("menu", "selected_vehicle", "")

			var root := get_tree().root
			root.msaa = ProjectSettings.get_setting("rendering/quality/filters/msaa")

			print("Loaded settings")
		ERR_FILE_NOT_FOUND:
			print("No custom configuration file found")
			OS.window_fullscreen = Engine.is_debug()
		_:
			print("Failed to load custom settings: %s" % Global.ERROR_TO_STRING[e])
			assert(false, "Failed to load custom settings")

