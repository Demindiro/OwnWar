extends Node

const LOADER_MAX_TIME := 1000.0 / 60.0
const VERSION = "0.12.1"
# Because Godot does not allow cyclic references and is apparently not capable
# of updating file paths automatically, this shall be the solution
const SCENE_MENU_MAIN = "res://core/menu/main.tscn"
const SCENE_DESIGNER = "res://core/designer/designer.tscn"
const SCENE_DESIGNER_MAP = "res://core/designer/map.tscn"
const SCENE_LOADING = "res://core/menu/loading_screen.tscn"
const SCENE_VEHICLE = "res://unit/vehicle/vehicle.tscn"
const BLOCK_DIR = "res://block"
const DIRECTORY_USER_VEHICLES = "user://vehicles"
const FILE_EXTENSION = ".json"
const DEFAULT_AI_SCRIPT = "res://unit/vehicle/ai/brick.gd"
const BLOCK_SCALE = 0.25
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


export var blocks: Dictionary = {}

var blocks_by_id: Array = [null]

var _loader


func _init():
	print("Game version %s" % [VERSION])


func _ready():
	for file in recurse_directory(BLOCK_DIR, ".tres"):
		Block.add_block(load(file))
	var id = 1
	for name in blocks:
		var block = blocks[name]
		blocks_by_id.append(block)
		block.id = id
		id += 1
# warning-ignore:return_value_discarded
	Matter.add_matter("material", 1_000_000)
# warning-ignore:return_value_discarded
	Matter.add_matter("fuel", 1_000_000)


func _process(_delta):
	if _loader != null:
		_load_scene()
	else:
		set_process(false)
		
		
func _notification(notification):
	match notification:
		MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
#			get_tree().root.print_stray_nodes()
			pass


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


func get_block(name: String): #-> Block:
	return blocks[name]


func goto_scene(path):
	call_deferred("_goto_scene", path)
	

func error(string, code := -1):
	if code != -1:
		push_error("%s: %s (%d)" % [string, ERROR_TO_STRING[code], code])
	else:
		push_error(string)


func _goto_scene(path):
	if path is PackedScene:
		var err = get_tree().change_scene_to(path)
		if err != OK:
			error("Failed to change scene '%s'" % path, err)
	else:
		_loader = ResourceLoader.load_interactive(path)
		if _loader == null:
			error("Error creating loader")
			return
		set_process(true)
		var err = get_tree().change_scene(SCENE_LOADING)
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
				# Allow any heavy scene stuff to load first (Heightmap terrain)
				yield(get_tree(), "idle_frame")
				tree.current_scene.queue_free()
				tree.current_scene = instance
			else:
				error("Loaded resource is not a scene! ('%s')" % str(scene))
			return
		elif err == OK:
			_show_loading_progress()
		else:
			error("Error loading scene", err)
			tree.current_scene.get_node("ColorRect").color = Color.red
			_show_loading_progress()
			_loader = null
			return


func _show_loading_progress():
	var stage = _loader.get_stage()
	var count = _loader.get_stage_count()
	var bar = get_tree().current_scene.get_node("ProgressBar")
	bar.max_value = count
	bar.value = stage
