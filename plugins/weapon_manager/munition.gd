extends Resource


const _ID_TO_MUNITION := {}


export var human_name := ""
# warning-ignore:unused_class_variable
export var shell: PackedScene
# warning-ignore:unused_class_variable
export var mesh: Mesh
# warning-ignore:unused_class_variable
export var cost := 1
# warning-ignore:unused_class_variable
export var shells_per_batch := 1
# warning-ignore:unused_class_variable
export var gauge := -1
# warning-ignore:unused_class_variable
export var id := -1


func _to_string():
	return human_name


static func is_munition(p_id: int) -> bool:
	return p_id in _ID_TO_MUNITION


static func get_munition_ids() -> PoolIntArray:
	return PoolIntArray(_ID_TO_MUNITION.keys())


static func get_munition(p_id: int) -> Resource:
	return _ID_TO_MUNITION[p_id]


static func add_munition(m) -> int:
	# Ammo containers generally pack munition in a square pattern
	var volume: int = get_volume_by_gauge(m.gauge)
	var m_id := Matter.add_matter(m.human_name, volume)
	_ID_TO_MUNITION[m_id] = m
	m.id = m_id
	return m_id


static func get_volume_by_gauge(p_gauge: int) -> int:
	# Pretend that length = gauge * 3
	return p_gauge * p_gauge * (p_gauge * 3)
