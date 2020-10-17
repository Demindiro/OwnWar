extends Unit


const MAX_VOLUME := 10000_00
var _volume := 0
var _matter := {}


func _ready():
	_update_indicator()


func get_info():
	var info = .get_info()
	info["Volume"] = "%d / %d" % [_volume / 100, MAX_VOLUME / 100]
	for m in _matter:
		info[Matter.matter_name[m]] = str(_matter[m])
	return info


func request_info(info: String):
	if info == "provide_material":
		return get_matter_count(Matter.name_to_id["material"])
	if info == "take_material":
		return get_matter_space(Matter.name_to_id["material"])
	return .request_info(info)


func get_matter_count(id: int) -> int:
	return _matter.get(id, 0)


func get_matter_space(id: int) -> int:
	return (MAX_VOLUME - _volume) / Matter.matter_volume[id]


func get_put_matter_list(id: int) -> PoolIntArray:
	return PoolIntArray(range(len(Matter.matter_name)))


func get_take_matter_list(id: int) -> PoolIntArray:
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


func put_material(p_material):
	var r := put_matter(Matter.name_to_id["material"], p_material)
	send_message("provide_material", get_matter_count(Matter.name_to_id["material"]))
	send_message("take_material", get_material_space())
	return r


func take_material(p_material):
	var r := take_matter(Matter.name_to_id["material"], p_material)
	send_message("provide_material", get_matter_count(Matter.name_to_id["material"]))
	send_message("take_material", get_material_space())
	return r


func get_material_space() -> int:
	return get_matter_space(Matter.name_to_id["material"])


func _update_indicator() -> void:
	$Indicator.scale.y = float(_volume) / MAX_VOLUME
