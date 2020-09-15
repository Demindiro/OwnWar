class_name Global

extends Node

const LOADER_MAX_TIME = 1 / 30

var _loader


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
