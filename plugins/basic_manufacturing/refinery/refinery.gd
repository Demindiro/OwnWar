extends OwnWar.Structure


const _MAX_MATERIAL := 50
const _MAX_FUEL := 1000
var _time_until_fuel_produced := 0.0
var _producing := false
var _material := 0
var _fuel := 0
var _material_id: int = Matter.get_matter_id("material")
var _fuel_id: int = Matter.get_matter_id("fuel")


func _physics_process(delta):
	if _producing:
		_time_until_fuel_produced += delta
		if _time_until_fuel_produced >= 1.0 and _fuel < _MAX_FUEL:
			_fuel += 10
			emit_signal("dump_matter", _fuel_id, _fuel)
			emit_signal("provide_matter", _fuel_id, _fuel)
			_time_until_fuel_produced = 0.0
			_producing = false
	if not _producing:
		if _material >= 2:
			_material -= 2
			emit_signal("need_matter", _material_id, _MAX_MATERIAL - _material)
			_producing = true


func get_info():
	var info = .get_info()
	info["Material"] = "%d / %d" % [_material, _MAX_MATERIAL]
	info["Fuel"] = "%d / %d" % [_fuel, _MAX_FUEL]
	return info


func needs_matter(id: int) -> int:
	if _material_id == id:
		return _MAX_MATERIAL - _material
	return 0


func dumps_matter(id: int) -> int:
	return _fuel if _fuel_id == id else 0


func provides_matter(id: int) -> int:
	return _fuel if _fuel_id == id else 0


func get_matter_count(id: int):
	if id == _material_id:
		return _material
	elif id == _fuel_id:
		return _fuel
	return 0


func get_matter_space(id: int) -> int:
	if id == _material_id:
		return _MAX_MATERIAL - _material
	return 0


func get_put_matter_list() -> PoolIntArray:
	return PoolIntArray([_material_id])


func get_take_matter_list() -> PoolIntArray:
	return PoolIntArray([_fuel_id])


func put_matter(id: int, amount: int) -> int:
	if id == _material_id:
		_material += amount
		if _material > _MAX_MATERIAL:
			var remainder = _material - _MAX_MATERIAL
			_material = _MAX_MATERIAL
			emit_signal("need_matter", _material_id, _MAX_MATERIAL - _material)
			return remainder
		emit_signal("need_matter", _material_id, _MAX_MATERIAL - _material)
		return 0
	return amount


func take_matter(id: int, amount: int) -> int:
	if id == _material_id:
		_material -= amount
		if _material < 0:
			amount += _material
			_material = 0
			emit_signal("need_matter", _material_id, _MAX_MATERIAL - _material)
		return amount
	elif id == _fuel_id:
		_fuel -= amount
		if _fuel < 0:
			amount += _fuel
			_fuel = 0
			emit_signal("dump_matter", _fuel_id, _MAX_FUEL - _fuel)
			emit_signal("provide_matter", _fuel_id, _fuel)
		return amount
	return 0


func serialize_json() -> Dictionary:
	return {
			"material": _material,
			"fuel": _fuel,
		}


func deserialize_json(data: Dictionary) -> void:
	_material = data["material"]
	_fuel = data["fuel"]
