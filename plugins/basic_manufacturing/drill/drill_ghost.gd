extends Ghost


const Ore := preload("ore.gd")

var _ore: Ore


func _exit_tree():
	if _ore.drill == self:
		_ore.drill = null


func snap_transform(position: Vector3, scroll: int):
	var closest_ore: Ore
	var closest_distance2 := INF
	for ore in get_tree().get_nodes_in_group("ores"):
		var d2: float = ore.translation.distance_squared_to(position)
		if (ore.drill == null or ore.drill.team == "") and d2 < closest_distance2:
			closest_ore = ore
			closest_distance2 = d2
	if closest_ore != null:
		_ore = closest_ore
		position = _ore.translation
		_ore.drill = self
	self.global_transform = Transform(
		Basis.IDENTITY.rotated(Vector3.UP, scroll * PI / 8),
		position
	)
	OwnWar.snap_transform(self)


func finished_building() -> void:
	assert(_ore != null)
	var unit = structure.instance()
	unit.team = team
	unit.global_transform = global_transform
	unit.translate(spawn_offset)
	unit.ore = _ore
	_ore.drill = unit
	GameMaster.get_game_master(self).add_child(unit)
	destroy()
	emit_signal("built")
