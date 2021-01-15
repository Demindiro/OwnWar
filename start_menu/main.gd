extends Control


signal refresh_vehicle_list()
signal vehicle_rename_failed()


var _selected_vehicle_path := ""


func goto_editor(vehicle_path := "") -> void:
	if vehicle_path == "":
		vehicle_path = _selected_vehicle_path
		assert(false, "No vehicle selected")
	if vehicle_path != "":
		var scene = load("res://editor/editor.tscn").instance()
		scene.vehicle_path = vehicle_path
		queue_free()
		var tree := get_tree()
		tree.root.remove_child(self)
		tree.root.add_child(scene)
		tree.current_scene = scene


func set_selected_vehicle(path: String) -> void:
	_selected_vehicle_path = path


func rename_vehicle(from: String, to: String) -> void:
	from = Util.filenamize_human_name(from) + ".json"
	to = Util.filenamize_human_name(to) + ".json"
	from = OwnWar.VEHICLE_DIRECTORY.plus_file(from)
	to = OwnWar.VEHICLE_DIRECTORY.plus_file(to)
	var dir := Directory.new()
	if dir.file_exists(to):
		print("Refusing to move %s to %s as the destination already exists" % [to, from])
		emit_signal("vehicle_rename_failed")
		return
	var e := Directory.new().rename(from, to)
	assert(e == OK)
	print("Renamed %s to %s" % [from, to])
	OwnWar_Thumbnail.move_vehicle_thumbnail(from, to)
	emit_signal("refresh_vehicle_list")


func exit_game() -> void:
	get_tree().quit()
