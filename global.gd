extends Node

const LOADER_MAX_TIME = 1 / 30

export var blocks: Dictionary = { }

var _loader

onready var _blocks_mesh_library: MeshLibrary = MeshLibrary.new()


func _ready():
	Block.add_block(preload("res://blocks/cube.tres"))
	for name in blocks:
		var id = _blocks_mesh_library.get_last_unused_item_id()
		var block = blocks[name]
		_blocks_mesh_library.create_item(id)
		_blocks_mesh_library.set_item_mesh(id, block.mesh)
		_blocks_mesh_library.set_item_name(id, block.name)
		block.id = id


func _process(_delta):
	if _loader != null:
		_load_scene()
	else:
		set_process(false)


func goto_scene(path):
	call_deferred("_goto_scene", path)


func _goto_scene(path):
	_loader = ResourceLoader.load_interactive(path)
	if _loader == null:
		print_debug("Error creating loader")
		return
	set_process(true)
	get_tree().get_root().queue_free()
	print_debug("TODO: implement loading animation")


func _load_scene():
	var t = OS.get_ticks_sec()
	while OS.get_ticks_sec() < t + LOADER_MAX_TIME:
		var err = _loader.poll()
		if err == ERR_FILE_EOF:
			var scene = _loader.get_resource().instance()
			get_node("/root").add_child(scene)
			_loader = null
			break
		elif err == OK:
			_show_loading_progress()
		else:
			print_debug("Error loading scene")
			_loader = null
			break


func _show_loading_progress():
	print_debug("Progress: %d/%d" % [_loader.get_stage(), _loader.get_stage_count()])
