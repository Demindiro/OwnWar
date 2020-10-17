extends Unit


const _MAX_VOLUME := 10000_00
var _volume := 0
var _matter := {}


func _ready():
	_update_indicator()


func get_info():
	var info = .get_info()
	info["Volume"] = "%d / %d" % [_volume / 100, _MAX_VOLUME / 100]
	for m in _matter:
		info[Matter.matter_name[m]] = str(_matter[m])
	return info


func request_info(info: String):
	if info == "provide_matter":
		var dict := {}
		for id in range(len(Matter.matter_name)):
			dict[id] = _matter.get(id, 0)
		return dict
	if info == "take_matter":
		var dict := {}
		for id in range(len(Matter.matter_name)):
			dict[id] = (_MAX_VOLUME - _volume) / Matter.matter_volume[id]
		return get_take_matter_list()
	return .request_info(info)


func get_matter_count(id: int) -> int:
	return _matter.get(id, 0)


func get_matter_space(id: int) -> int:
	return (_MAX_VOLUME - _volume) / Matter.matter_volume[id]


func get_put_matter_list() -> PoolIntArray:
	return PoolIntArray(range(len(Matter.matter_name)))


func get_take_matter_list() -> PoolIntArray:
	return PoolIntArray(_matter.keys())


func put_matter(id: int, amount: int) -> int:
	var max_put = get_matter_space(id)
	if max_put >= amount:
		_matter[id] = _matter.get(id, 0) + amount
		_volume += amount * Matter.matter_volume[id]
		_update_indicator()
		return 0
	else:
		_matter[id] = _matter.get(id, 0) + max_put
		_volume += max_put * Matter.matter_volume[id]
		_update_indicator()
		return amount - max_put


func take_matter(id: int, amount: int) -> int:
	if _matter.get(id, 0) > amount:
		_matter[id] -= amount
		_volume -= amount * Matter.matter_volume[id]
		_update_indicator()
		return amount
	else:
		var remainder: int = _matter.get(id, 0)
		_matter.erase(id)
		return remainder


func _update_indicator() -> void:
	$Indicator.scale.y = float(_volume) / _MAX_VOLUME
