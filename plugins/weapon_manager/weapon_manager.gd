extends Reference


var _max_munitions_by_gauge := {}
var _munitions_count := {}
var _gauge_to_munitions := {}
var _weapons := []
var _vehicle
var Munition = Plugin.get_plugin("weapon_manager").Munition


#func init(vehicle: Vehicle) -> void:
func init(vehicle) -> void:
	_vehicle = vehicle
	vehicle.add_matter_count_handler(funcref(self, "get_matter_count"))
	vehicle.add_matter_space_handler(funcref(self, "get_matter_space"))
	vehicle.add_matter_put_handler(funcref(self, "put_matter"))
	vehicle.add_matter_take_handler(funcref(self, "take_matter"))
	vehicle.add_info(self, "get_info")


func get_matter_count(id: int) -> int:
	return _munitions_count.get(id, 0)


func get_matter_space(id: int) -> int:
	var munition = Munition.get_munition(id) if Munition.is_munition(id) else null
	return get_munition_space(munition.gauge) if munition != null else 0


func put_matter(id: int, amount: int) -> int:
	if not id in Munition.get_munition_ids():
		return amount
	return put_munition(id, amount)


func get_munition_count(gauge := 0) -> int:
	assert(gauge >= 0)
	var count := 0
	for id in _gauge_to_munitions.get(0, PoolIntArray()):
		count += _munitions_count[id]
	if gauge != 0:
		for id in _gauge_to_munitions.get(gauge, PoolIntArray()):
			count += _munitions_count[id]
	return count


func get_munition_space(gauge := 0) -> int:
	assert(gauge >= 0)
	var count: int = _max_munitions_by_gauge.get(0, 0)
	for id in _gauge_to_munitions.get(0, PoolIntArray()):
		count -= _munitions_count[id]
	if gauge != 0:
		count += _max_munitions_by_gauge.get(gauge, 0)
		for id in _gauge_to_munitions.get(gauge, PoolIntArray()):
			count -= _munitions_count[id]
	return count


func put_munition(id: int, amount: int) -> int:
	assert(id in Munition.get_munition_ids())
	var gauge: int = Munition.get_munition(id).gauge
	var space := get_munition_space(gauge)
	if space >= amount:
		_munitions_count[id] = _munitions_count.get(id, 0) + amount
		if not gauge in _gauge_to_munitions:
			_gauge_to_munitions[gauge] = PoolIntArray([id])
		elif not id in _gauge_to_munitions[gauge]:
			_gauge_to_munitions[gauge].append(id)
		amount = 0
	elif space > 0:
		_munitions_count[id] = _munitions_count.get(id, 0) + space
		if not gauge in _gauge_to_munitions:
			_gauge_to_munitions[gauge] = PoolIntArray([id])
		elif not id in _gauge_to_munitions[gauge]:
			_gauge_to_munitions[gauge].append(id)
		amount -= space
	return amount


func take_munition(gauge: int, amount: int) -> Dictionary:
	var dict := {}
	for id in _gauge_to_munitions.get(gauge, PoolIntArray()):
		var count = _munitions_count[id]
		if count >= amount:
			dict[id] = amount
			_munitions_count[id] -= amount
			return dict
		elif count > 0:
			dict[id] = count
			amount -= count
	if gauge != 0:
		for id in _gauge_to_munitions.get(gauge, PoolIntArray()):
			var count = _munitions_count[id]
			if count >= amount:
				dict[id] = dict.get(id, 0) + amount
				_munitions_count[id] -= amount
				return dict
			elif count > 0:
				dict[id] = dict.get(id, 0) + count
				amount -= count
	return dict


func aim_at(position: Vector3, velocity := Vector3.ZERO) -> void:
	for weapon in _weapons:
		weapon.aim_at(position, velocity)


func rest_aim():
	for weapon in _weapons:
		weapon.set_angle(0.0)


func fire_weapons(_max_error := 1e10) -> void:
	for weapon in _weapons:
		weapon.fire()


func add_ammo_rack(ammo_rack: Node) -> void:
	var gauge = ammo_rack.gauge
	if not gauge in _max_munitions_by_gauge:
		_max_munitions_by_gauge[gauge] = 0
		_gauge_to_munitions[gauge] = []
		if gauge != 0:
			for id in Munition.get_munition_ids():
				if Munition.get_munition(id).gauge == gauge:
					_vehicle.add_matter_put(id)
					_vehicle.add_matter_take(id)
	_max_munitions_by_gauge[gauge] += ammo_rack.max_munitions
	var e := ammo_rack.connect("tree_exited", self, "_ammo_rack_destroyed", [ammo_rack])
	assert(e == OK)


func add_weapon(weapon: Node) -> void:
	_weapons.append(weapon)
	var e := weapon.connect("tree_exited", self, "_weapon_destroyed", [weapon])
	assert(e == OK)


func _ammo_rack_destroyed(ammo_rack: Node) -> void:
	var gauge = ammo_rack.gauge
	_max_munitions_by_gauge[gauge] -= ammo_rack.max_munitions


func _weapon_destroyed(weapon: Node) -> void:
	_weapons.erase(weapon)


func get_info(info: Dictionary) -> void:
	for id in _munitions_count:
		info[Munition.get_munition(id).human_name] = str(_munitions_count[id])
