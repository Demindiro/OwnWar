extends Reference


var _weapons := []


func aim_at(position: Vector3, velocity := Vector3.ZERO) -> void:
	for weapon in _weapons:
		weapon.aim_at(position, velocity)


func rest_aim():
	for weapon in _weapons:
		weapon.set_angle(0.0)


func fire_weapons(_max_error := 1e10) -> void:
	for weapon in _weapons:
		weapon.fire()


func add_weapon(weapon: Node) -> void:
	_weapons.append(weapon)
	var e := weapon.connect("tree_exited", self, "_weapon_destroyed", [weapon])
	assert(e == OK)


func _weapon_destroyed(weapon: Node) -> void:
	_weapons.erase(weapon)
