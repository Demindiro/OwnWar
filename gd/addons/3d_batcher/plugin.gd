tool
extends EditorPlugin


const AUTOLOAD_SCRIPT := "batched_mesh_manager.gdns"

var autoload = null


func _enter_tree() -> void:
	autoload = preload(AUTOLOAD_SCRIPT).new()
	var e: int = autoload.connect("reload", self, "_reload")
	assert(e == OK)
	add_child(autoload)


func _exit_tree() -> void:
	autoload.queue_free()
	autoload = null


func _reload() -> void:
	# The library frees it already, so we don't have to
	# We just have to ensure we remove all references to the manager so
	# that the library can free it safely
	print("ok then 'non-existent' signal")
	remove_child(autoload)
	autoload = null
	# TODO is this reliable?
	#yield(get_tree(), "idle_frame")
	#_enter_tree()
