extends Timer


const _ORE_MAX_DISTANCE_2 := 100.0 * 100.0
const _DRONE := preload("res://plugins/worker_drone/drone.gd")
const _ORE := preload("res://plugins/basic_manufacturing/drill/ore.gd")
var _units := []


func _ready() -> void:
	process_mode = Timer.TIMER_PROCESS_PHYSICS
	wait_time = 0.1
	autostart = true
	var e := connect("timeout", self, "_ai_process")
	assert(e == OK)


func _ai_process() -> void:
	_units = get_tree().get_nodes_in_group("units_" + name)
	_build_mining_post()


func _build_mining_post() -> void:
	var ore := _get_closest_ore()
	if ore != null:
		var ore_pos := ore.global_transform.origin
		var worker := _get_idle_worker(ore_pos)
		if worker != null:
			worker.build_drill(0, ore_pos)


# Get any worker without any tasks
func _get_idle_worker(closest_to: Vector3) -> _DRONE:
	var closest: _DRONE = null
	var closest_distance2 := INF
	for u in _units:
		if u is _DRONE and len(u.tasks) == 0:
			var pos: Vector3 = u.global_transform.origin
			var d2 := pos.distance_squared_to(closest_to)
			if d2 < closest_distance2:
				closest = u
				closest_distance2 = d2
	return closest


# Get any ore that is the closest to any of our structures and doesn't have a
# drill yet.
func _get_closest_ore() -> _ORE:
	var closest_ore: _ORE = null
	var closest_distance2 := _ORE_MAX_DISTANCE_2
	for ore in get_tree().get_nodes_in_group("ores"):
		assert(ore is _ORE)
		if ore.drill == null:
			var ore_pos = ore.global_transform.origin
			for u in _units:
				var u_pos: Vector3 = u.global_transform.origin
				var dist2 := u_pos.distance_squared_to(ore_pos)
				if dist2 < closest_distance2:
					closest_ore = ore
					closest_distance2 = dist2
	return closest_ore
