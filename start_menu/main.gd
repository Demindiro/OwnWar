extends Control


signal refresh_vehicle_list()
signal vehicle_rename_failed()
signal vehicle_renamed(from, to)


var _selected_vehicle_path := ""


func goto_editor(vehicle_path := "") -> void:
	if vehicle_path == "":
		vehicle_path = _selected_vehicle_path
	if vehicle_path == "":
		assert(false, "No vehicle selected")
	if vehicle_path != "":
		var scene = load("res://editor/editor.tscn").instance()
		scene.vehicle_path = vehicle_path
		queue_free()
		var tree := get_tree()
		tree.root.remove_child(self)
		tree.root.add_child(scene)
		tree.current_scene = scene


func rename_vehicle(from: String, to: String) -> void:
	var dir := Directory.new()
	if dir.file_exists(to):
		print("Refusing to move %s to %s as the destination already exists" % [to, from])
		emit_signal("vehicle_rename_failed")
		return
	var e := Directory.new().rename(from, to)
	assert(e == OK)
	print("Renamed %s to %s" % [from, to])
	OwnWar_Thumbnail.move_vehicle_thumbnail(from, to)
	emit_signal("vehicle_renamed", from, to)


func exit_game() -> void:
	get_tree().quit()


func select_vehicle(path: String) -> void:
	OwnWar_Lobby.player_vehicle_path = path
	_selected_vehicle_path = path
