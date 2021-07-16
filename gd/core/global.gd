extends Node

const LOADER_MAX_TIME := 1000.0 / 60.0
const DIRECTORY_USER_VEHICLES = "user://vehicles"
const ERROR_TO_STRING = [
		"No errors",
		"Generic",
		"Unavailable",
		"Unconfigured",
		"Unauthorized",
		"Parameter range",
		"Out of memory (OOM)",
		"Not found",
		"Bad drive",
		"Bad path",
		"No permission",
		"Already in use",
		"Can't open",
		"Can't write",
		"Can't read",
		"Unrecognized",
		"Corrupt",
		"Missing dependencies",
		"End of file (EOF)",
		"Can't open",
		"Can't create",
		"Query failed",
		"Already in use",
		"Locked",
		"Timeout",
		"Can't connect",
		"Can't resolve",
		"Connection",
		"Can't acquire resource",
		"Can't fork process",
		"Invalid data",
		"Invalid parameter",
		"Already exists",
		"Does not exist",
		"Database: Read",
		"Database: Write",
		"Compilation failed",
		"Method not found",
		"Linking failed",
		"Script failed",
		"Cycling link (import cycle)",
		"Invalid declaration",
		"Duplicate symbol",
		"Parse",
		"Busy",
		"Skip",
		"Help",
		"Bug",
		"Printer on fire",
	]
const COLLISION_MASK_TERRAIN = 1 << (8 - 1) # Christ's sake, Godot pls

var _loader
var _loader_callback
var _loader_callback_arguments: Array


func _init():
	print("Game version %s" % [OwnWar.VERSION])
	preload("res://blocks/chassis/chassis.gd").load_blocks()
	var BM := preload("res://blocks/block_manager.gdns").new()
	BM.add_block(preload("res://blocks/wheels/big-wheel/wheel_left.tres"))
	BM.add_block(preload("res://blocks/wheels/big-wheel/wheel_right.tres"))
	BM.add_block(preload("res://blocks/mainframe/mainframe.tres"))
	BM.add_block(preload("res://blocks/turrets/turret_1x1.tres"))
	BM.add_block(preload("res://blocks/turrets/turret_2x2.tres"))
	BM.add_block(preload("res://blocks/turrets/turret_3x3.tres"))
	BM.add_block(preload("res://blocks/weapons/lasers/fixed_laser.tres"))
	BM.add_block(preload("res://blocks/thrusters/thruster.tres"))
	BM.add_block(preload("res://blocks/weapons/plasma/cannon.tres"))
	BM.add_block(preload("res://blocks/wings/rudder.tres"))


func _ready():
	BatchedMeshManager.enable_culling = false


func _process(_delta):
	if _loader != null:
		_load_scene()
	else:
		set_process(false)


func recurse_directory(path: String, ends_with: String = "", _arr := []) -> Array:
	var directory = Directory.new()
	var err = directory.open(path)
	if err != OK:
		error("Could not open directory '%s'", err)
		return []
	directory.list_dir_begin(true)
	if err != OK:
		error("Could not iterate directory '%s'", err)
		return []
	var file = directory.get_next()
	while file != "":
		if directory.current_is_dir():
			# warning-ignore:return_value_discarded
			recurse_directory(path.plus_file(file), ends_with, _arr)
		elif file.ends_with(ends_with):
			_arr.append(path.plus_file(file))
		file = directory.get_next()
	directory.list_dir_end()
	return _arr


func goto_scene(path, callback = null, arguments := []) -> void:
	assert(path is String or path is PackedScene)
	assert(callback == null or callback is FuncRef or callback is String)
	_loader_callback = callback
	_loader_callback_arguments = arguments.duplicate()
	call_deferred("_goto_scene", path)


func error(string, code := -1):
	if code != -1:
		push_error("%s: %s (%d)" % [string, ERROR_TO_STRING[code], code])
	else:
		push_error(string)


func _goto_scene(path) -> void:
	assert(path is String or path is PackedScene)
	if path is PackedScene:
		var err = get_tree().change_scene_to(path)
		if err != OK:
			error("Failed to change scene '%s'" % path, err)
			return
		if _loader_callback != null:
			_loader_callback_arguments.push_front(get_tree().current_scene)
			_loader_callback.call_funcv(_loader_callback_arguments)
	else:
		_loader = ResourceLoader.load_interactive(path)
		if _loader == null:
			error("Error creating loader")
			return
		set_process(true)
		var err = get_tree().change_scene("res://ui/loading_screen.tscn")
		if err != OK:
			error("Failed to change scene '%s'" % path, err)
		call_deferred("_load_scene")
	get_tree().paused = false


func _load_scene():
	var t = OS.get_ticks_msec()
	while OS.get_ticks_msec() < t + LOADER_MAX_TIME:
		var err = _loader.poll()
		var tree := get_tree()
		if err == ERR_FILE_EOF:
			var scene = _loader.get_resource()
			_loader = null
			if scene is PackedScene:
				var instance = scene.instance()
				tree.root.add_child(instance)
				tree.root.move_child(instance, 0)
				if _loader_callback != null:
					var fr = _loader_callback
					if fr is String:
						fr = funcref(instance, fr)
					else:
						_loader_callback_arguments.push_front(instance)
					fr.call_funcv(_loader_callback_arguments)
				# Allow any heavy scene stuff to load first (Heightmap terrain)
				var was_paused := get_tree().paused
				if not was_paused:
					get_tree().paused = true
				yield(get_tree(), "idle_frame")
				if not was_paused:
					get_tree().paused = false
				tree.current_scene.queue_free()
				tree.current_scene = instance
			else:
				error("Loaded resource is not a scene! ('%s')" % str(scene))
			return
		elif err == OK:
			_show_loading_progress()
		else:
			error("Error loading scene", err)
			var cr: ColorRect = tree.current_scene.get_node("ColorRect")
			cr.color = Color.red
			_show_loading_progress()
			_loader = null
			return


func _show_loading_progress():
	var stage = _loader.get_stage()
	var count = _loader.get_stage_count()
	var bar = get_tree().current_scene.get_node("ProgressBar")
	bar.max_value = count
	bar.value = stage
