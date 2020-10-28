extends Node


enum DisableReason {
		MANUAL = 0x1,
		CONFLICT = 0x2,
		TOO_RECENT = 0x4,
		TOO_OLD = 0x8,
		DEPENDENCY = 0xf0,
		DEPENDENCY_MISSING = 0x10,
		DEPENDENCY_TOO_RECENT = 0x20,
		DEPENDENCY_TOO_OLD = 0x40,
	}
var disabled_plugins := {}
var plugins := {}


func _enter_tree():
	_load_plugins()


func _load_plugins():
	var scripts := _load_plugins_from_dir()

	var game_version: Vector3 = Compatibility.version_string_to_vector(Global.VERSION)

	print("Checking IDs and versions")
	for script in scripts:
		var id: String = script.PLUGIN_ID
		if id in plugins or disabled_plugins.get(id, -1) == DisableReason.CONFLICT:
			print("Conflicting plugin id! %s", id)
			plugins.erase(id)
			disabled_plugins[id] = DisableReason.CONFLICT
			continue
		if game_version < script.MIN_VERSION:
			print("Plugin version is more recent than the game version! %s", id)
			print("Plugin version: %s" % ["%d.%d.%d" % \
					[script.MIN_VERSION.x, script.MIN_VERSION.y, script.MIN_VERSION.z]])
			disabled_plugins[id] = DisableReason.TOO_RECENT
			continue
		plugins[id] = script

	print("Checking dependencies")
	var dependencies_satisfied := false
	while not dependencies_satisfied:
		dependencies_satisfied = true
		for script in plugins.values():
			var flags := 0
			for dep_id in script.PLUGIN_DEPENDENCIES:
				var dep_req_ver: Vector3 = script.PLUGIN_DEPENDENCIES[dep_id]
				var dep_ver: Vector3 = plugins[dep_id].PLUGIN_VERSION
				if not dep_id in plugins:
					print("%s misses dependency %s" % [script.PLUGIN_ID, dep_id])
					flags |= DisableReason.DEPENDENCY_MISSING
					dependencies_satisfied = false
				elif dep_ver < dep_req_ver:
					print("%s dependency %s too old %d.%d.%d > %d.%d.%d" % [
							script.PLUGIN_ID, dep_id,
							dep_req_ver.x, dep_req_ver.y, dep_req_ver.z,
							dep_ver.x, dep_ver.y, dep_ver.z,
						])
					flags |= DisableReason.DEPENDENCY_TOO_OLD
					dependencies_satisfied = false
			if not dependencies_satisfied:
				plugins.erase(script.PLUGIN_ID)
				disabled_plugins[script.PLUGIN_ID] = flags
				break

	print("Calling pre_init")
	for script in plugins.values():
		script.pre_init(script.resource_path.get_base_dir())

	print("Calling init")
	for script in plugins.values():
		script.init(script.resource_path.get_base_dir())

	print("Calling post_init")
	for script in plugins.values():
		script.post_init(script.resource_path.get_base_dir())


func _load_plugins_from_dir() -> Array:
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
