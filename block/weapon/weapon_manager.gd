extends Reference


var _max_munitions := {0: 0}
var _munitions := {0: []}
var _cannons := []
var _weapons := []
var _turrets := []


#func init(vehicle: Vehicle) -> void:
func init(vehicle) -> void:
	vehicle.add_function(self, "get_munition_count")
	vehicle.add_function(self, "get_munition_space")
	vehicle.add_function(self, "put_munition")
	vehicle.add_function(self, "take_munition")
	vehicle.add_info(self, "get_info")


func get_munition_count(gauge := 0) -> int:
	return len(_munitions[gauge]) if gauge in _munitions else 0


func get_munition_space(gauge := 0) -> int:
	if gauge in _munitions:
		return _max_munitions[gauge] - len(_munitions[gauge])
	else:
		return 0


func put_munition(munition: Munition) -> Munition:
	var gauge = munition.gauge
	if gauge in _munitions and len(_munitions[gauge]) < _max_munitions[gauge]:
		_munitions[gauge].append(munition)
		if gauge != 0:
			_munitions[0].append(munition)
		return null
	return munition


func take_munition(gauge := 0) -> Munition:
	if gauge in _munitions and len(_munitions[gauge]) > 0:
		var munition = _munitions[gauge].pop_back()
		if gauge != 0:
			_munitions[0].erase(munition)
		return munition
	return null


func aim_at(position: Vector3, velocity := Vector3.ZERO) -> void:
	for weapon in _weapons:
		weapon.aim_at(position, velocity)
	for cannon in _cannons:
		cannon.aim_at(position, velocity)
	for turret in _turrets:
		turret.aim_at(position, velocity)


func rest_aim():
	for cannon in _cannons:
		cannon.set_angle(0.0)
	for turret in _turrets:
		turret.set_angle(0.0)


func fire_weapons(max_error := 1e10) -> void:
	for weapon in _weapons:
		weapon.fire()
	for cannon in _cannons:
		cannon.fire()


func add_ammo_rack(ammo_rack: Node) -> void:
	var gauge = ammo_rack.gauge
	if not gauge in _max_munitions:
		_max_munitions[gauge] = 0
		_munitions[gauge] = []
	_max_munitions[gauge] += ammo_rack.max_munitions
	if gauge != 0:
		_max_munitions[0] += ammo_rack.max_munitions
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
	var gauge = ammo_rack.gauge
	_max_munitions[gauge] -= ammo_rack.max_munitions
	if gauge != 0:
		_max_munitions[0] -= ammo_rack.max_munitions


func _cannon_destroyed(cannon: Node) -> void:
	_cannons.erase(cannon)


func _weapon_destroyed(weapon: Node) -> void:
	_weapons.erase(weapon)


func _turret_destroyed(turret: Node) -> void:
	_turrets.erase(turret)


func get_info(info: Dictionary) -> void:
	for gauge in _munitions:
		var info_name = "Munition (" + ("all" if gauge == 0 else str(gauge) + "mm") + ")"
		info[info_name] = "%d / %d" % [len(_munitions[gauge]), _max_munitions[gauge]]
