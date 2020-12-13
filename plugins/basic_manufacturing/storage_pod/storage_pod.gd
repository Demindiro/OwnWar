extends OwnWar.Structure


const _MAX_VOLUME := 1000_000_000
var _volume := 0
var _matter := {}
onready var _indicator: Spatial


func _ready():
	_update_indicator()


func get_info():
	var info = .get_info()
# warning-ignore:integer_division
# warning-ignore:integer_division
	info["Volume"] = "%d / %d" % [_volume / 1_000_000, _MAX_VOLUME / 1_000_000]
	for m in _matter:
		info[Matter.get_matter_name(m)] = str(_matter[m])
	return info


func get_matter_count(id: int) -> int:
	return _matter.get(id, 0)


func get_matter_space(id: int) -> int:
# warning-ignore:integer_division
	return (_MAX_VOLUME - _volume) / Matter.get_matter_volume(id)


func get_put_matter_list() -> PoolIntArray:
	return PoolIntArray(range(Matter.get_matter_types_count()))


func get_take_matter_list() -> PoolIntArray:
	return PoolIntArray(_matter.keys())


func provides_matter(id: int) -> int:
	return _matter.get(id, 0)


func takes_matter(id: int) -> int:
# warning-ignore:integer_division
	return (_MAX_VOLUME - _volume) / Matter.get_matter_volume(id)


func put_matter(id: int, amount: int) -> int:
	var max_put = get_matter_space(id)
	if max_put >= amount:
		_matter[id] = _matter.get(id, 0) + amount
		_volume += amount * Matter.get_matter_volume(id)
		_update_indicator()
		emit_signal("provide_matter", id, _matter[id])
		return 0
	else:
		_matter[id] = _matter.get(id, 0) + max_put
		_volume += max_put * Matter.get_matter_volume(id)
		_update_indicator()
		emit_signal("provide_matter", id, _matter[id])
		return amount - max_put


func take_matter(id: int, amount: int) -> int:
	if _matter.get(id, 0) > amount:
		_matter[id] -= amount
		_volume -= amount * Matter.get_matter_volume(id)
		_update_indicator()
		emit_signal("provide_matter", id, _matter[id])
		return amount
	else:
		var remainder: int = _matter.get(id, 0)
		_volume = 0
# warning-ignore:return_value_discarded
		_matter.erase(id)
		emit_signal("provide_matter", id, 0)
		return remainder


func serialize_json() -> Dictionary:
	var m_list := {}
	for id in _matter:
		m_list[Matter.get_matter_name(id)] = _matter[id]
	return {
			"matter": m_list
		}


func deserialize_json(data: Dictionary) -> void:
	_matter = {}
	_volume = 0
	for n in data["matter"]:
		var c: int = data["matter"][n]
		var id: int = Matter.get_matter_id(n)
		_matter[id] = c
		_volume += data["matter"][n] * Matter.get_matter_volume(id)


func _update_indicator() -> void:
	if _indicator == null:
		# _ready being called in "reverse" is quite annoying
		_indicator = $Indicator
	_indicator.scale.y = float(_volume) / _MAX_VOLUME
