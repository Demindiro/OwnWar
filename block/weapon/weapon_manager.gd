extends Reference


var _max_munitions := 0
var _munitions := []
var _cannons := []
var _weapons := []
var _turrets := []


#func init(vehicle: Vehicle) -> void:
func init(vehicle) -> void:
	vehicle.add_function(self, "get_munition_count")
	vehicle.add_function(self, "get_munition_space")
	vehicle.add_function(self, "put_munition")
	vehicle.add_function(self, "take_munition")
	vehicle.add_function(self, "aim_at")
	vehicle.add_info(self, "get_info")


func get_munition_count() -> int:
	return len(_munitions)


func get_munition_space() -> int:
	return _max_munitions - len(_munitions)


func put_munition(munition: Munition) -> Munition:
	if len(_munitions) < _max_munitions:
		_munitions.append(munition)
		return null
	return munition


func take_munition() -> Munition:
	if len(_munitions) > 0:
		return _munitions.pop_back()
	return null


func aim_at(position: Vector3, velocity := Vector3.ZERO) -> void:
	for weapon in _weapons:
		weapon.aim_at(position, velocity)
	for cannon in _cannons:
		cannon.aim_at(position, velocity)
	for turret in _turrets:
		turret.aim_at(position, velocity)


func fire_weapons(max_error := 1e10) -> void:
	for weapon in _weapons:
		weapon.fire()
	for cannon in _cannons:
		cannon.fire()


func add_ammo_rack(ammo_rack: Node) -> void:
	_max_munitions += ammo_rack.max_munitions
	ammo_rack.connect("tree_exited", self, "_ammo_rack_destroyed", [ammo_rack])


func add_cannon(cannon: Node) -> void:
	_cannons.append(cannon)
	cannon.connect("tree_exited", self, "_cannon_destroyed", [cannon])


func add_weapon(weapon: Node) -> void:
	_weapons.append(weapon)
	weapon.connect("tree_exited", self, "_weapon_destroyed", [weapon])


func add_turret(turret: Node) -> void:
	_turrets.append(turret)
	turret.connect("tree_exited", self, "_turret_destroyed", [turret])


func _ammo_rack_destroyed(ammo_rack: Node) -> void:
	_max_munitions -= ammo_rack.max_munitions


func _cannon_destroyed(cannon: Node) -> void:
	_cannons.erase(cannon)


func _weapon_destroyed(weapon: Node) -> void:
	_weapons.erase(weapon)


func _turret_destroyed(turret: Node) -> void:
	_turrets.erase(turret)


func get_info(info: Dictionary) -> void:
	info["Munition"] = "%d / %d" % [len(_munitions), _max_munitions]
