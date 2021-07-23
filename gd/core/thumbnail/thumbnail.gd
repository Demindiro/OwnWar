extends Node


const _THUMBNAIL_DIRECTORY := "user://cache/thumbnails"
const _BLOCK_DIRECTORY := "blocks"
const _VEHICLE_DIRECTORY := "vehicles"
const _UNIT_DIRECTORY := "units"

# TODO
const BLOCK_SCALE := 0.25


static func get_block_thumbnail_async(id: int, callback: FuncRef, arguments := []) -> bool:
	if _try_get_thumbnail(_get_block_path(id), callback, arguments):
		return true
	else:
		OwnWar_Thumbnail._create_block_thumbnail(id, callback, arguments)
		return false


static func get_vehicle_thumbnail_async(path: String, callback: FuncRef,
	arguments := []) -> bool:
	var mod_time := File.new().get_modified_time(path)
	if _try_get_thumbnail(_get_vehicle_path(path), callback, arguments, mod_time):
		return true
	else:
		OwnWar_Thumbnail._create_vehicle_thumbnail(path, callback, arguments)
		return false


static func move_vehicle_thumbnail(from: String, to: String) -> void:
	from = _get_vehicle_path(from)
	to = _get_vehicle_path(to)
	var _e := Directory.new().rename(from, to)


static func _get_block_path(id: int) -> String:
	var blk = OwnWar_BlockManager.new().get_block(id)
	return _THUMBNAIL_DIRECTORY \
		.plus_file(_BLOCK_DIRECTORY) \
		.plus_file("%d-%d.png" % [id, blk.revision])


static func _get_vehicle_path(path: String) -> String:
	return _THUMBNAIL_DIRECTORY \
		.plus_file(_VEHICLE_DIRECTORY) \
		.plus_file(path.sha1_text() + ".png")


static func _try_get_thumbnail(path: String, callback: FuncRef, arguments: Array,
	created_after := 0) -> bool:
	if File.new().file_exists(path) and File.new().get_modified_time(path) >= created_after:
		var img := Image.new()
		var e := img.load(path)
		assert(e == OK)
		img.fix_alpha_edges()
		callback.call_funcv([img] + arguments)
		return true
	else:
		return false


func _create_block_thumbnail(id: int, callback: FuncRef, arguments: Array) -> void:
	while get_child_count() > 16:
		# Cap to 16 to prevent lag when loading a large amount of thumbnails
		yield(get_tree(), "idle_frame")
	var tn: Viewport = preload("thumbnail.tscn").instance()
	add_child(tn)
	var mi: MeshInstance = tn.get_child(0)
	var block: OwnWar_Block = OwnWar_BlockManager.new().get_block(id)
	print("Generating block thumbnail for ", id)
	var path := _get_block_path(id)
	mi.scale = Vector3.ONE / max(block.aabb.size.x, max(block.aabb.size.y, block.aabb.size.z))
	mi.translation = (-block.aabb.position - block.aabb.size / 2 + Vector3(0.5, 0.5, 0.5)) * mi.scale * BLOCK_SCALE
	mi.mesh = block.mesh
	if block.editor_node != null:
		var node: Spatial = block.editor_node.duplicate()
		node.transform = mi.transform
		node.set_color(Color.white)
		node.set("team_color", OwnWar.ALLY_COLOR)
		if node.has_method("set_preview_mode"):
			node.set_preview_mode(true)
		tn.add_child(node)
	yield(VisualServer, "frame_post_draw")
	yield(VisualServer, "frame_post_draw")
	var img := tn.get_texture().get_data()
	img.convert(Image.FORMAT_RGBA8)
	var e := Util.create_dirs(_THUMBNAIL_DIRECTORY.plus_file(_BLOCK_DIRECTORY))
	assert(e == OK)
	e = img.save_png(path)
	assert(e == OK)
	tn.queue_free()
	callback.call_funcv([img] + arguments)


func _create_vehicle_thumbnail(p_path: String, callback: FuncRef, arguments: Array
	) -> void:
	while get_child_count() > 4:
		# Cap to 4 to prevent lag when loading a large amount of thumbnails
		yield(get_tree(), "idle_frame")
	var tn: Viewport = preload("thumbnail.tscn").instance()
	add_child(tn)
	tn.get_child(0).free()
	print("Generating vehicle thumbnail for ", p_path)
	var path := _get_vehicle_path(p_path)
	var vehicle := OwnWar_VehiclePreview.new()
	var e := vehicle.load_from_file(p_path)
	assert(e == OK, "Failed to load vehicle")
	if e != OK:
		push_error("Failed to load vehicle from %s: %d" % [p_path, e])
		return
	var aabb := vehicle.aabb
	aabb.size *= BLOCK_SCALE
	aabb.position *= BLOCK_SCALE
	var camera: Camera = tn.get_node("Spatial/Camera")
	var size := max(aabb.size.x, max(aabb.size.y, aabb.size.z))
	var grid_center := Vector3(25, 25, 25) * BLOCK_SCALE / 2
	var aabb_center := aabb.size / 2 + aabb.position
	var offset_center := aabb_center - grid_center
	vehicle.translation -= offset_center
	# 1.5 has been derived by trial and error
	camera.translate(Vector3.BACK * size / 1.5 * 4)
	vehicle.propagate_call("set_process", [false], true)
	vehicle.propagate_call("set_process_internal", [false], true)
	vehicle.propagate_call("set_physics_process", [false], true)
	vehicle.propagate_call("set_physics_process_internal", [false], true)
	tn.add_child(vehicle)
	yield(VisualServer, "frame_post_draw")
	yield(VisualServer, "frame_post_draw")
	var img := tn.get_texture().get_data()
	img.convert(Image.FORMAT_RGBA8)
	img.fix_alpha_edges()
	e = Util.create_dirs(_THUMBNAIL_DIRECTORY.plus_file(_VEHICLE_DIRECTORY))
	assert(e == OK)
	e = img.save_png(path)
	assert(e == OK)
	tn.queue_free()
	callback.call_funcv([img] + arguments)
