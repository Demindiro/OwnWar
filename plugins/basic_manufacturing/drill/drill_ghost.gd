extends OwnWar_Ghost


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


func serialize_json() -> Dictionary:
	if _ore != null:
		return {"ore_translation": var2str(_ore.translation)}
	else:
		return {}


func deserialize_json(data: Dictionary) -> void:
	var ore_translation = data.get("ore_translation")
	if ore_translation != null:
		var ot: Vector3 = str2var(ore_translation)
		for o in get_tree().get_nodes_in_group("ores"):
			if o.translation == ot:
				_ore = o
				break
		assert(_ore != null)


func finished_building() -> void:
	assert(_ore != null)
	var unit = structure.instance()
	unit.team = team
	unit.global_transform = global_transform
	unit.translate(spawn_offset)
	unit.ore = _ore
	_ore.drill = unit
	OwnWar.GameMaster.get_game_master(self).add_child(unit)
	destroy()
	emit_signal("built")
