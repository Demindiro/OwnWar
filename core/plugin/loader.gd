class_name Plugin


class PluginState:
	enum {
		NONE = 0x0,
		MANUAL = 0x1,
		CONFLICT = 0x2,
		TOO_RECENT = 0x4,
		TOO_OLD = 0x8,
		DEPENDENCY_MISSING = 0x10,
		DEPENDENCY_TOO_RECENT = 0x20,
		DEPENDENCY_TOO_OLD = 0x40,
		DEPENDENCY_DISABLED = 0x80,
	}
	const DISABLE_REASON_TO_STR := {
			NONE: "None",
			MANUAL: "Manual",
			CONFLICT: "Conflict",
			TOO_RECENT: "Too recent",
			TOO_OLD: "Too old",
			DEPENDENCY_MISSING: "Dependency missing",
			DEPENDENCY_TOO_RECENT: "Dependency too recent",
			DEPENDENCY_TOO_OLD: "Dependency too old",
			DEPENDENCY_DISABLED: "Dependency disabled",
		}
	var singleton: PluginInterface
	var disable_reason := NONE

	func _init(p_script):
		singleton = p_script.new()


const _PLUGINS := {}


static func enable_plugin(id: String, enable: bool) -> bool:
	var p: PluginState = _PLUGINS.get(id)
	if p != null:
		if p.disable_reason == PluginState.NONE or \
				p.disable_reason == PluginState.MANUAL:
			var text := Util.read_file_text("user://plugins/disabled.txt")
			var list := Array(text.split("\n")) if text != null else []

			if enable and id in list:
				list.erase(id)
			elif not enable and not id in list:
				list.append(id)

			return Util.write_file_text("user://plugins/disabled.txt",
					PoolStringArray(list).join("\n"))
		else:
			var s := PoolStringArray()
			for i in range(len(PluginState.DISABLE_REASON_TO_STR)):
				if p.disable_reason & (1 << i):
					s.append(PluginState.DISABLE_REASON_TO_STR[(1 << i)])
			print("Can't enable plugin %s : %s" % [id, s.join(", ")])
			return false
	else:
		print("Plugin %s not found" % id)
		return false


static func get_plugin(name: String) -> PluginState:
	assert(name in _PLUGINS)
	assert(_PLUGINS[name].singleton is PluginInterface)
	return _PLUGINS[name].singleton


static func get_all_plugins() -> Dictionary:
	return _PLUGINS


static func get_disable_reason(name: String) -> int:
	assert(name in _PLUGINS)
	assert(_PLUGINS[name].disable_reason is int)
	return _PLUGINS[name].disable_reason


static func is_plugin_enabled(name: String) -> bool:
	var text := Util.read_file_text("user://plugins/disabled.txt")
	return text == null or not name in text.split("\n")


static func load_plugins():
	_load_pcks()
	var scripts := _load_plugins_from_dir()

	print("Checking IDs and versions")
	for script in scripts:
		var id: String = script.PLUGIN_ID
		if id in _PLUGINS:
			print("Conflicting plugin id! %s", id)
			_PLUGINS[id].disable_reason |= PluginState.CONFLICT
		else:
			_PLUGINS[id] = PluginState.new(script)

		if Constants.VERSION < script.MIN_VERSION:
			print("Plugin version is more recent than the game version! %s", id)
			print("Plugin version: %d.%d.%d" % [script.MIN_VERSION.x,
					script.MIN_VERSION.y, script.MIN_VERSION.z])
			_PLUGINS[id].disable_reason |= PluginState.TOO_RECENT

	print("Checking if enabled")
	var file := File.new()
	var e := file.open("user://plugins/disabled.txt", File.READ)
	var list := PoolStringArray() if e != OK else file.get_as_text().split("\n")
	for id in _PLUGINS:
		if id in list:
			_PLUGINS[id].disable_reason |= PluginState.MANUAL
			print("%s is disabled" % id)

	print("Checking dependencies")
	var dependencies_satisfied := false
	while not dependencies_satisfied:
		dependencies_satisfied = true
		for id in _PLUGINS:
			if _PLUGINS[id].disable_reason != PluginState.NONE:
				continue
			var script = _PLUGINS[id].singleton
			var flags := 0
			for dep_id in script.PLUGIN_DEPENDENCIES:
				var dep_req_ver: Vector3 = script.PLUGIN_DEPENDENCIES[dep_id]
				if not dep_id in _PLUGINS:
					print("%s misses dependency %s" % [id, dep_id])
					flags |= PluginState.DEPENDENCY_MISSING
					dependencies_satisfied = false
					continue

				var dep_ver: Vector3 = _PLUGINS[dep_id].singleton.PLUGIN_VERSION
				if dep_ver < dep_req_ver:
					print("%s dependency %s too old %s > %s" % [id, dep_id,
							Util.version_vector_to_str(dep_req_ver),
							Util.version_vector_to_str(dep_ver)
						])
					flags |= PluginState.DEPENDENCY_TOO_OLD
					dependencies_satisfied = false
					continue

				if _PLUGINS[dep_id].disable_reason != PluginState.NONE:
					print("%s dependency %s not enabled" % [id, dep_id])
					flags |= PluginState.DEPENDENCY_DISABLED
					dependencies_satisfied = false
					continue

			if not dependencies_satisfied:
				_PLUGINS[id].disable_reason |= flags
				break

	print("Calling pre_init")
	for p in _PLUGINS.values():
		if p.disable_reason == PluginState.NONE:
			var s = p.singleton
			if s.has_method("pre_init"):
				s.pre_init()

	print("Calling init")
	for p in _PLUGINS.values():
		if p.disable_reason == PluginState.NONE:
			var s = p.singleton
			if s.has_method("init"):
				s.init()

	print("Calling post_init")
	for p in _PLUGINS.values():
		if p.disable_reason == PluginState.NONE:
			var s = p.singleton
			if s.has_method("post_init"):
				s.post_init()


static func _load_plugins_from_dir() -> Array:
	var dir := Directory.new()
	var e := dir.open("res://plugins/")
	assert(e == OK)
	e = dir.list_dir_begin(true)
	assert(e == OK)

	var scripts = []

	while true:
		var plugin_path = dir.get_next()
		if plugin_path == "":
			break
		if dir.current_is_dir():
			var script_path := "res://plugins/" \
				.plus_file(plugin_path) \
				.plus_file("plugin.gd")
			print("Loading %s" % [script_path])
			var script = load(script_path)
			if script == null:
				print("Couldn't load plugin - skipping")
				continue
			scripts.append(script)

	return scripts


static func _load_pcks() -> void:
	if not OS.has_feature("standalone"):
		print("Plugins cannot be loaded in the editor due to a bug with Godot")
		print("Ref: https://github.com/godotengine/godot/issues/16798")
		return
	print("Loading plugin PCKs")
	for pck in Util.iterate_dir_recursive("user://plugins/", "pck"):
		if not ProjectSettings.load_resource_pack(pck):
			print("Failed to load %s" % pck)
