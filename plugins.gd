extends Node


var plugins := {}


func _ready():
	call_deferred("_load_plugins")


func _load_plugins():
	var scripts := _load_plugins_from_dir("res://plugins/") + \
			_load_plugins_from_dir("user://plugins/")

	var game_version: Vector3 = Compatibility.version_string_to_vector(Global.VERSION)

	for script in scripts:
		var id: String = script.PLUGIN_ID
		print("Instantiating %s" % [id])
		if id in plugins:
			print("Conflicting plugin id!")
			continue
		if game_version < script.MIN_VERSION:
			print("Plugin version is more recent than the game version!")
			print("Plugin version: %s" % ["%d.%d.%d" % \
					[script.MIN_VERSION.x, script.MIN_VERSION.y, script.MIN_VERSION.z]])
			continue
		plugins[id] = script.new()

	for script in plugins.values():
		if script.has_method("pre_init"):
			print("Calling %s.pre_init()" % [script.PLUGIN_ID])
			script.pre_init()

	for script in plugins.values():
		if script.has_method("post_init"):
			print("Calling %s.post_init()" % [script.PLUGIN_ID])
			script.post_init()


func _load_plugins_from_dir(path: String) -> Array:
	print("Loading plugins from %s" % [path])

	var dir := Directory.new()
	var e := dir.open(path)
	if e != OK:
		print("Could not load plugins: %d" % [e])
		return []

	e = dir.list_dir_begin(true)
	if e != OK:
		print("Could not iterate plugins: %d" % [e])
		return []

	var scripts = []

	while true:
		var plugin_path = dir.get_next()
		if plugin_path == "":
			break
		if dir.current_is_dir():
			var script_path := path.plus_file(plugin_path).plus_file("plugin.gd")
			print("Loading %s" % [script_path])
			var script = load(script_path)
			if script == null:
				print("Couldn't load plugin - skipping")
				continue
			scripts.append(script)

	return scripts
