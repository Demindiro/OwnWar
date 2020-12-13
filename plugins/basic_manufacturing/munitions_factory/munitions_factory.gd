extends OwnWar.Structure


const Munition := preload("res://plugins/weapon_manager/munition.gd")

#export(Array, Munition) var munition_types := []
export(Array, Resource) var munition_types := []
const _MAX_MATERIAL := 30
const _MAX_MUNITION_VOLUME := 125_000_000
var _material := 0
var _munition := {}
var _munition_volume := 0
var _current_munition_type
var _current_producing_munition
var _time_until_munition_produced := 0.0
onready var _material_id = Matter.get_matter_id("material")


func _physics_process(delta):
	if _current_producing_munition != null:
		var id = Matter.get_matter_id(_current_producing_munition.human_name)
		var volume = Matter.get_matter_volume(id) * _current_producing_munition.shells_per_batch
		var time_between_munitions = float(volume) / 10_000_000.0
		if _time_until_munition_produced >= time_between_munitions:
			if _munition_volume + volume < _MAX_MUNITION_VOLUME:
				_munition[id] = _munition.get(id, 0) + _current_producing_munition.shells_per_batch
				_munition_volume += volume
				_current_producing_munition = null
				_time_until_munition_produced -= time_between_munitions
				emit_signal("dump_matter", id, _munition[id])
				emit_signal("provide_matter", id, _munition[id])
		else:
			_time_until_munition_produced += delta
	elif _current_munition_type != null and _current_munition_type.cost <= _material:
			_material -= _current_munition_type.cost
			emit_signal("need_matter", _material_id, _MAX_MATERIAL - _material)
			_current_producing_munition = _current_munition_type


func get_actions():
	var actions = [
		OwnWar.Action.new(
			"Turn off",
			Action.INPUT_NONE,
			funcref(self, "set_munition_type"),
			[null]
		)
	]
	for munition_type in munition_types:
		actions.append(OwnWar.Action.new(
			"Produce %s" % str(munition_type),
			Action.INPUT_NONE,
			funcref(self, "set_munition_type"),
			[munition_type]
		))
	return actions


func get_info():
	var info = .get_info()
	info["Material"] = "%d / %d" % [_material, _MAX_MATERIAL]
	if _current_munition_type != null:
		info["Producing"] = str(_current_munition_type)
	else:
		info["Producing"] = "None"
	info["Volume"] = "%d / %d" % [
			# warning-ignore:integer_division
			_munition_volume / 1_000_000,
			# warning-ignore:integer_division
			_MAX_MUNITION_VOLUME / 1_000_000
		]
	for m in _munition:
		info[Matter.get_matter_name(m)] = _munition[m]
	return info


func needs_matter(id: int) -> int:
	if _current_munition_type != null:
		return _MAX_MATERIAL - _material if _material_id == id else 0
	return 0


func dumps_matter(id: int) -> int:
	return _munition.get(id, 0)


func provides_matter(id: int) -> int:
	return _munition.get(id, 0)


func get_matter_count(id: int) -> int:
	if id == _material_id:
		return _material
	return _munition.get(id, 0)


func get_matter_space(id: int) -> int:
	if id == _material_id:
		return _MAX_MATERIAL - _material
	elif Munition.is_munition(id):
		var v := Matter.get_matter_volume(id)
# warning-ignore:integer_division
		return (_MAX_MUNITION_VOLUME - _munition_volume) / v
	return 0


func get_put_matter_list() -> PoolIntArray:
	return PoolIntArray([_material_id])


func get_take_matter_list() -> PoolIntArray:
	return PoolIntArray(Munition.get_munition_ids())


func put_matter(id: int, amount: int) -> int:
	if id == _material_id:
		var remainder = 0
		_material += amount
		if _material > _MAX_MATERIAL:
			remainder = _material - _MAX_MATERIAL
			_material = _MAX_MATERIAL
			if _current_munition_type != null:
				emit_signal("need_matter", _material_id, _MAX_MATERIAL - _material)
			else:
				emit_signal("need_matter", _material_id, 0)
		return remainder
	return amount


func take_matter(id: int, amount: int) -> int:
	if id in _munition:
		if _munition[id] >= amount:
			_munition[id] -= amount
		else:
			amount = _munition[id]
# warning-ignore:return_value_discarded
			_munition.erase(id)
		_munition_volume -= amount * Matter.get_matter_volume(id)
		emit_signal("dump_matter", id, _munition.get(id, 0))
		emit_signal("provide_matter", id, _munition.get(id, 0))
		return amount
	return 0


func get_current_munition_type():
	return _current_munition_type


func set_munition_type(_flags, munition_type):
	_current_munition_type = munition_type
	if _current_munition_type != null:
		emit_signal("need_matter", _material_id, _MAX_MATERIAL - _material)
	else:
		emit_signal("need_matter", _material_id, 0)


func serialize_json() -> Dictionary:
	var m_list := {}
	for id in _munition:
		m_list[Matter.get_matter_name(id)] = _munition[id]
	var data = {
			"material": _material,
			"munition": m_list,
			"time_until_produced": _time_until_munition_produced,
		}
	if _current_munition_type != null:
		data["current_munition"] = Matter.get_matter_name(
				_current_munition_type.id)
	if _current_munition_type != null:
		data["current_producing"] = Matter.get_matter_name(
				_current_producing_munition.id)
	return data


func deserialize_json(data: Dictionary) -> void:
	_material = data["material"]

	if "current_munition" in data:
		var cur_mun_id: int = Matter.get_matter_id(data["current_munition"])
		_current_munition_type = Munition.get_munition(cur_mun_id)
		assert(Munition.is_munition(cur_mun_id))

	if "current_producing" in data:
		var cur_prod_id: int = Matter.get_matter_id(data["current_producing"])
		assert(Munition.is_munition(cur_prod_id))
		_current_producing_munition = Munition.get_munition(cur_prod_id)

	_time_until_munition_produced = data["time_until_produced"]
	_munition = {}
	_munition_volume = 0
	for n in data["munition"]:
		var c: int = data["munition"][n]
		var id: int = Matter.get_matter_id(n)
		_munition[id] = c
		_munition_volume += c * Matter.get_matter_volume(id)
