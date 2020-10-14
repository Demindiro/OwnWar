extends Unit


var _radius2 := 100.0 * 100.0


func _physics_process(_delta):
	pass


func get_actions() -> Array:
	var actions := .get_actions()
	actions += [
			["Set Coverage", Action.INPUT_COORDINATE, "set_coverage_radius", []]
		]
	return actions


func set_coverage_radius(flags: int, coordinate: Vector3) -> void:
	_radius2 = translation.distance_squared_to(coordinate)
