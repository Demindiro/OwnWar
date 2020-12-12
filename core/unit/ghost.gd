class_name Ghost
extends Structure


signal built()
export(PackedScene) var structure
export(Array) var init_arguments
export(Vector3) var spawn_offset = Vector3.ZERO
export(int) var cost = 10
var build_progress = 0


func get_info():
	var info = .get_info()
	info["Progress"] = "%d / %d" % [build_progress, cost]
	return info


func enable_preview_mode():
	remove_from_group("units")
	remove_from_group("units_" + team)
	propagate_call("set_physics_process", [false])
	for c in Util.get_children_recursive(self):
		if c is RigidBody:
			c.collision_layer = 0
			c.collision_mask = 0


func snap_transform(position: Vector3, scroll: int):
	self.global_transform = Transform(
		Basis.IDENTITY.rotated(Vector3.UP, scroll * PI / 8),
		position
	)
	OwnWar.snap_transform(self)


func add_build_progress(material):
	build_progress += material
	if build_progress >= cost:
		finished_building()
		return cost - build_progress
	return 0


func finished_building():
	var unit = structure.instance()
	unit.team = team
	unit.global_transform = global_transform
	unit.translate(spawn_offset)
	GameMaster.get_game_master(self).add_child(unit)
	if unit.has_method("init") or init_arguments != []:
		unit.callv("init", init_arguments)
	destroy()
	emit_signal("built")



func serialize_json() -> Dictionary:
	return { "progress": build_progress }


func deserialize_json(data: Dictionary) -> void:
	build_progress = data["progress"]
