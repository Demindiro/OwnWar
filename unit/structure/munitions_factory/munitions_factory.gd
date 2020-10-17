extends Unit


#export(Array, Munition) var munition_types := []
export(Array, Resource) var munition_types := []
const _MAX_MATERIAL := 30
const _MAX_MUNITION_VOLUME := 3000
var _material := 0
var _munition := {}
var _munition_volume := 0
var _current_munition_type: Munition
var _producing_munition := false
var _time_between_munitions := 1.0
var _time_until_munition_produced := 0.0
onready var _material_id = Matter.name_to_id["material"]


func _ready():
	_current_munition_type = munition_types[0]


func _physics_process(delta):
	if _producing_munition:
		if _time_until_munition_produced >= _time_between_munitions:
			var id = Matter.name_to_id[_current_munition_type.human_name]
			var volume = Matter.matter_volume[id]
			if _munition_volume + volume < _MAX_MUNITION_VOLUME:
				_munition[id] = _munition.get(id, 0) + 1
				_munition_volume += volume
				_visualize_munitions()
				_producing_munition = false
				_time_until_munition_produced -= _time_between_munitions
		else:
			_time_until_munition_produced += delta
	else:
		if _current_munition_type.cost <= _material:
			_material -= _current_munition_type.cost
			send_message("need_material", _MAX_MATERIAL - _material)
			_producing_munition = true


func get_actions():
	var actions = []
	for munition_type in munition_types:
		actions.append([
				"Produce %s" % str(munition_type),
				Action.INPUT_NONE,
				"set_munition_type",
				[munition_type],
			])
	return actions


func get_info():
	var info = .get_info()
	info["Material"] = "%d / %d" % [_material, _MAX_MATERIAL]
	info["Producing"] = str(_current_munition_type)
	info["Volume"] = "%d / %d" % [_munition_volume, _MAX_MUNITION_VOLUME]
	for m in _munition:
		info[Matter.matter_name[m]] = _munition[m]
	return info


func request_info(info: String):
	if info == "need_material":
		return get_matter_space(_material_id)
	return .request_info(info)


func get_matter_count(id: int) -> int:
	if id == _material_id:
		return _material
	return _munition.get(id, 0)


func get_matter_space(id: int) -> int:
	if id == _material_id:
		return _MAX_MATERIAL - _material
	elif Munition.is_munition(id):
		var v := Matter.matter_volume[id]
		return (_MAX_MUNITION_VOLUME - _munition_volume) / v
	return 0


func put_matter(id: int, amount: int) -> int:
	if id == _material_id:
		var remainder = 0
		_material += amount
		if _material > _MAX_MATERIAL:
			remainder = _material - _MAX_MATERIAL
			_material = _MAX_MATERIAL
		send_message("need_material", _MAX_MATERIAL - _material)
		return remainder
	return amount


func take_matter(id: int, amount: int) -> int:
	if id in _munition:
		if _munition[id] >= amount:
			_munition[id] -= amount
		else:
			amount = _munition[id]
			_munition.erase(id)
		_munition_volume -= amount * Matter.matter_volume[id]
		_visualize_munitions()
		return amount
	return 0


func put_material(p_material: int) -> int:
	return put_matter(_material_id, p_material)


func take_munition():
	for id in _munition:
		var amount = take_matter(id, 1)
		if amount > 0:
			_visualize_munitions()
			return RegisterMunition.id_to_munitions[id].duplicate()
	return null


func get_munition_count():
	var count := 0
	for c in _munition.values():
		count += c
	return count


#func get_munition_space():
#	return max_munition - len(munition)


func get_material_space():
	return get_matter_space(_material_id)


func set_munition_type(flags, munition_type):
	_current_munition_type = munition_type


func _visualize_munitions():
	var id = Matter.name_to_id[_current_munition_type.human_name]
	$MultiMeshInstance.multimesh.mesh = _current_munition_type.mesh
	$MultiMeshInstance.multimesh.instance_count = _munition[id]
	for i in range(_munition[id]):
		var munition_transform := Transform2D(Vector2.UP, Vector2.RIGHT,
			Vector2(i % 5, i / 5) / 3)
		$MultiMeshInstance.multimesh.set_instance_transform_2d(i, munition_transform)
