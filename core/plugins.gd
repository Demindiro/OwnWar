extends Node


var plugins := {}


func _enter_tree():
	_load_plugins()


func _load_plugins():
	var scripts := _load_plugins_from_dir()

	var game_version: Vector3 = Compatibility.version_string_to_vector(Global.VERSION)

	print("Checking plugins")
	for script in scripts:
		var id: String = script.PLUGIN_ID
		if id in plugins:
			print("Conflicting plugin id! %d", id)
			continue
		if game_version < script.MIN_VERSION:
			print("Plugin version is more recent than the game version! %d", id)
			print("Plugin version: %s" % ["%d.%d.%d" % \
					[script.MIN_VERSION.x, script.MIN_VERSION.y, script.MIN_VERSION.z]])
			continue
		plugins[id] = script

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
