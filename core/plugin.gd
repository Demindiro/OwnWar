class_name Plugin


enum DisableReason {
		NONE = 0x0,
		MANUAL = 0x1,
		CONFLICT = 0x2,
		TOO_RECENT = 0x4,
		TOO_OLD = 0x8,
		DEPENDENCY = 0xf0,
		DEPENDENCY_MISSING = 0x10,
		DEPENDENCY_TOO_RECENT = 0x20,
		DEPENDENCY_TOO_OLD = 0x40,
	}
const _PLUGINS := {}


static func enable_plugin(name: String, enabled: bool) -> bool:
	var p = _PLUGINS.get(name)
	if p != null:
		if p[1] == DisableReason.NONE or p[1] == DisableReason.MANUAL:
			p[1] = DisableReason.NONE if enabled else DisableReason.MANUAL
			return true
		else:
			var s = PoolStringArray()
			for k in DisableReason:
				if DisableReason[k] & p[1]:
					s.append(k)
			print("Can't enable plugin %s : %s" % [name, s.join(", ")])
			return false
	else:
		print("Plugin %s not found" % name)
		return false


static func get_plugin(name: String) -> GDScript:
	assert(name in _PLUGINS)
	assert(_PLUGINS[name][0] is GDScript)
	return _PLUGINS[name][0]


static func get_all_plugins() -> Array:
	var a := []
	for id in _PLUGINS:
		a.append(_PLUGINS[id][0])
	return a


static func get_disable_reason(name: String) -> int:
	assert(name in _PLUGINS)
	assert(_PLUGINS[name][1] is int)
	return _PLUGINS[name][1]


static func is_plugin_enabled(name: String) -> int:
	return name in _PLUGINS and _PLUGINS[name][1] == DisableReason.NONE


static func load_plugins():
	_load_pcks()
	var scripts := _load_plugins_from_dir()

	var game_version: Vector3 = Compatibility.version_string_to_vector(Global.VERSION)

	print("Checking IDs and versions")
	for script in scripts:
		var id: String = script.PLUGIN_ID
		if id in _PLUGINS:
			print("Conflicting plugin id! %s", id)
			_PLUGINS[id][1] |= DisableReason.CONFLICT
		else:
			_PLUGINS[id] = [script, DisableReason.NONE]

		if game_version < script.MIN_VERSION:
			print("Plugin version is more recent than the game version! %s", id)
			print("Plugin version: %d.%d.%d" % [script.MIN_VERSION.x,
					script.MIN_VERSION.y, script.MIN_VERSION.z])
			_PLUGINS[id][1] |= DisableReason.TOO_RECENT

	print("Checking dependencies")
	var dependencies_satisfied := false
	while not dependencies_satisfied:
		dependencies_satisfied = true
		for id in _PLUGINS:
			var script = _PLUGINS[id][0]
			var flags := 0
			for dep_id in script.PLUGIN_DEPENDENCIES:
				var dep_req_ver: Vector3 = script.PLUGIN_DEPENDENCIES[dep_id]
				if not dep_id in _PLUGINS:
					print("%s misses dependency %s" % [id, dep_id])
					flags |= DisableReason.DEPENDENCY_MISSING
					dependencies_satisfied = false
					continue

				var dep_ver: Vector3 = _PLUGINS[dep_id][0].PLUGIN_VERSION
				if dep_ver < dep_req_ver:
					print("%s dependency %s too old %d.%d.%d > %d.%d.%d" % [
							script.PLUGIN_ID, dep_id,
							dep_req_ver.x, dep_req_ver.y, dep_req_ver.z,
							dep_ver.x, dep_ver.y, dep_ver.z,
						])
					flags |= DisableReason.DEPENDENCY_TOO_OLD
					dependencies_satisfied = false
					continue

			if not dependencies_satisfied:
				_PLUGINS[id][1] |= flags
				break

	print("Calling pre_init")
	for p in _PLUGINS.values():
		p[0].pre_init(p[0].resource_path.get_base_dir())

	print("Calling init")
	for p in _PLUGINS.values():
		p[0].init(p[0].resource_path.get_base_dir())

	print("Calling post_init")
	for p in _PLUGINS.values():
		p[0].post_init(p[0].resource_path.get_base_dir())


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
			var script_path := "res://plugins/".plus_file(plugin_path).plus_file("plugin.gd")
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

	for pck in _iterate_dir("user://plugins/", "pck"):
		if not ProjectSettings.load_resource_pack(pck, true):
			print("Failed to load %s" % pck)


static func _iterate_dir(path: String, extension: String) -> Array:
	var dir := Directory.new()
	var e := dir.open(path)
	if e != OK:
		print("Couldn't open %s : %d" % [path, e])
		return []

	e = dir.list_dir_begin(true)
	if e != OK:
		print("Couldn't iterate %s : %d" % [path, e])
		return []

	var file_paths := []
	while true:
		var file := dir.get_next()
		if file == "":
			break
		if dir.current_is_dir():
			file_paths += _iterate_dir(path.plus_file(file), extension)
		elif file.get_extension() == extension:
			file_paths.append(path.plus_file(file))

	return file_paths
