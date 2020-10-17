extends Unit


const Drone = preload("roboport_drone.gd")
export var drone_scene: PackedScene
export var drone_limit := 10
var _drones := []
var _radius2 := 100.0 * 100.0
var _immediate_geometry: ImmediateGeometry
var _units := []
var _providers := []
var _takers := []
var _needs_provider := []
var _needs_taker := []
var _tasks := []
var _dirty := false
onready var _spawn_timer := get_tree().create_timer(1.0, false)


func _ready():
	game_master.connect("unit_added", self, "_unit_added")
	_providers.resize(len(Matter.matter_name))
	_takers.resize(len(Matter.matter_name))
	_needs_provider.resize(len(Matter.matter_name))
	_needs_taker.resize(len(Matter.matter_name))
	_set_radius2(_radius2)


func _process(_delta):
	var debug := get_tree().current_scene.find_node("Debug")
	if debug != null:
		draw_debug(debug)


func _physics_process(_delta: float) -> void:
	_assign_tasks()


func get_actions() -> Array:
	var actions := .get_actions()
	actions += [
			["Set Coverage", Action.INPUT_COORDINATE, "set_coverage_radius", []]
		]
	return actions

func get_info() -> Dictionary:
	var info = .get_info()
	info["Drones"] = "%d / %d" % [len(_drones), drone_limit]
	info["Units"] = str(len(_units))
	info["Tasks"] = str(len(_tasks))
	return info


func show_feedback():
	if _immediate_geometry == null:
		_immediate_geometry = ImmediateGeometry.new()
		_immediate_geometry.material_override = SpatialMaterial.new()
		_immediate_geometry.material_override.albedo_color = Color.orange
		_immediate_geometry.material_override.flags_unshaded = true
		add_child(_immediate_geometry)
	_draw_circle(sqrt(_radius2))


func hide_feedback():
	if _immediate_geometry != null:
		_immediate_geometry.queue_free()
		_immediate_geometry = null


func show_action_feedback(function: String, viewport: Viewport, arguments: Array) -> void:
	match function:
		"set_coverage_radius":
			var position := arguments[1] as Vector3
			var projected_position := Plane(transform.basis.y, 0).project(position)
			_draw_circle(translation.distance_to(projected_position))
		_:
			.show_action_feedback(function, viewport, arguments)


func set_coverage_radius(_flags: int, position: Vector3) -> void:
	_set_radius2(translation.distance_squared_to(position))


func assign_tasks() -> void:
	if not _dirty:
		call_deferred("_assign_tasks")
		_dirty = true


func _assign_tasks() -> void:
	for i in range(len(_tasks) - 1, -1, -1):
		var task: int = _tasks[i][0]
		var task_data = _tasks[i][1]
		match task:
			Drone.Task.EMPTY, Drone.Task.FILL:
				if not task_data[0] in _units or not task_data[1] in _units:
					_tasks.remove(i)
			Drone.Task.DESPAWN, Drone.Task.NONE:
				pass
			_:
				assert(false)

	while len(_tasks) > 0:
		var task: int
		var task_data: Array
		var assignees: int = 1 << 62
		var _task: Array
		for t in _tasks:
			if t[2] < assignees:
				task = t[0]
				task_data = t[1]
				assignees = t[2]
				_task = t
		var drone: Drone
		if task == Drone.Task.EMPTY or task == Drone.Task.FILL:
			drone = _get_idle_drone(PoolVector3Array(
				[task_data[0].translation, task_data[1].translation]))
		else:
			drone = _get_idle_drone()
		if drone == null:
			break
		_task[2] += 1
		_tasks.push_back(_tasks.pop_front())
		drone.task = task
		drone.task_data = task_data
	_dirty = false


func _draw_circle(radius: float) -> void:
	var space_state := get_world().direct_space_state
	_immediate_geometry.clear()
	_immediate_geometry.begin(Mesh.PRIMITIVE_LINE_LOOP)
	for i in range(128):
		var r := i * 2.0 * PI / 128
		var v := to_global(Vector3(cos(r) * radius, 0.0, sin(r) * radius))
		# NOTE: raycast tests against large bodies are very inaccurate because
		# reasons (https://pybullet.org/Bullet/phpBB3/viewtopic.php?t=3524)
		var result := space_state.intersect_ray(v + Vector3.UP * 1000,
				v + Vector3.DOWN * 1000, [], Global.COLLISION_MASK_TERRAIN)
		if len(result) > 0:
			v = result.position + Vector3.UP * 0.025
		_immediate_geometry.add_vertex(to_local(v))
	_immediate_geometry.end()


func _set_radius2(radius2: float) -> void:
	_radius2 = radius2
	for unit in _units:
		unit.disconnect("message", self, "_get_message")
		unit.disconnect("destroyed", self, "_unit_destroyed")
	_units = []
	for i in range(len(Matter.matter_name)):
		_providers[i] = []
		_takers[i] = []
		_needs_provider[i] = []
		_needs_provider[i] = []
	for unit in game_master.get_units(team):
		if translation.distance_squared_to(unit.translation) < radius2:
			_add_unit(unit)
	_assign_tasks()


func _on_need_matter(id: int, amount: int, unit: Unit):
	if amount > 0:
		var provider := _get_nearest(unit, _providers[id])
		_add_task(Drone.Task.FILL, [provider, unit])
	else:
		_remove_task(Drone.Task.FILL, unit)
	assign_tasks()


func _on_provide_matter(id: int, amount: int, unit: Unit):
	if amount > 0:
		if not unit in _providers[id]:
			_providers[id].append(unit)
	else:
		_providers[id].erase(unit)
	assign_tasks()


func _on_take_matter(id: int, amount: int, unit: Unit):
	if amount > 0:
		if not unit in _takers[id]:
			_takers[id].append(unit)
	else:
		_takers[id].erase(unit)
	assign_tasks()


func _on_dump_matter(id: int, amount: int, unit: Unit):
	if amount > 0:
		var taker := _get_nearest(unit, _takers[id])
		_add_task(Drone.Task.EMPTY, [unit, taker])
	else:
		_remove_task(Drone.Task.FILL, unit)
	assign_tasks()


func _unit_destroyed(unit):
	_units.erase(unit)


func _get_idle_drone(near_points := PoolVector3Array()) -> Drone:
	var shortest_distance := INF
	var candidate: Drone = null
	for drone in _drones:
		if drone.task == drone.Task.NONE:
			var nearest_distance := INF
			for point in near_points:
				var distance: float = drone.translation.distance_squared_to(point)
				if distance < nearest_distance:
					nearest_distance = distance
			if nearest_distance < shortest_distance:
				shortest_distance = nearest_distance
				candidate = drone
	if candidate != null:
		return candidate

	if _spawn_timer.time_left < 1e-4 and len(_drones) < drone_limit:
		var drone = drone_scene.instance()
		drone.transform = $SpawnPoint.global_transform
		drone.connect("task_completed", self, "_task_completed", [drone])
		_drones.append(drone)
		game_master.add_unit(team, drone)
		_spawn_timer = get_tree().create_timer(2.5)
		return drone
	return null


func _task_completed(drone: Drone) -> void:
	match drone.task:
		Drone.Task.FILL:
			pass
		Drone.Task.EMPTY:
			pass
		Drone.Task.DESPAWN:
			drone.queue_free()
		_:
			assert(false)
	for t in _tasks:
		if t[0] == drone.task and t[1] == drone.task_data:
			t[2] -= 1
			break
	assign_tasks()


func _get_nearest(unit, unit_list) -> Unit:
	var provider: Unit
	var shortest_distance := INF
	for prov in unit_list:
		var dist: float = prov.translation.distance_squared_to(unit.translation)
		if dist < shortest_distance:
			provider = prov
			shortest_distance = dist
	return provider


func _unit_added(unit: Unit) -> void:
	if unit.team == team and unit.translation.distance_squared_to(translation) < _radius2:
		_add_unit(unit)


func _add_unit(unit: Unit) -> void:
	_units.append(unit)
	unit.connect("destroyed", self, "_unit_destroyed")

	if has_signal("need_matter"):
		unit.connect("need_matter", self, "_on_need_matter", [unit])
	if has_signal("dump_matter"):
		unit.connect("dump_matter", self, "_on_dump_matter", [unit])

	var needs = unit.request_info("need_matter")
	if needs != null:
		for id in needs:
			if needs[id] > 0:
				var provider := _get_nearest(unit, _providers[id])
				if provider != null:
					_add_task(Drone.Task.FILL, [provider, unit])
				else:
					_needs_provider[id].append(unit)

	var provides = unit.request_info("provide_matter")
	if provides != null:
		for id in provides:
			if provides[id] > 0:
				_providers[id].append(unit)
				for needer in _needs_provider[id]:
					_add_task(Drone.Task.FILL, [unit, needer])
				_needs_provider[id] = []

	var takes = unit.request_info("take_matter")
	if takes != null:
		for id in takes:
			if takes[id] > 0:
				_takers[id].append(unit)
				for needer in _needs_taker:
					_add_task(Drone.Task.EMPTY, [needer, unit])
				_needs_taker = []

	var dumps = unit.request_info("dump_matter")
	if dumps != null:
		for id in dumps:
			if dumps[id] > 0:
				var taker := _get_nearest(unit, _takers)
				if taker != null:
					_add_task(Drone.Task.EMPTY, [unit, taker])
				else:
					_needs_taker.append(unit)


func _add_matter_provider(unit: Unit, ids: Array) -> void:
	for id in ids:
		_providers[id].append(unit)


func _add_matter_taker(unit: Unit, ids: Array) -> void:
	for id in ids:
		_takers[id].append(unit)


func _remove_unit(unit: Unit) -> void:
	unit.disconnect("message", self, "_get_message")
	unit.disconnect("destroyed", self, "_unit_destroyed")
	for id in unit.get_take_matter_list():
		_providers[id].erase(unit)
		_needs_provider[id].erase(unit)
	for id in unit.get_put_matter_list():
		_takers[id].erase(unit)
		_needs_taker[id].erase(unit)
	_units.erase(unit)


func _add_task(task: int, data: Array) -> void:
	for t in _tasks:
		if t[0] == task and t[1] == data:
			return
	_tasks.push_back([task, data, 0])
	assign_tasks()


func _remove_task(task: int, unit: Unit) -> void:
	for i in range(len(_tasks)):
		var t = _tasks[i]
		if t[0] == task and unit in t[1]:
			_tasks.remove(i)
			break


func draw_debug(debug):
	for drone in _drones:
		debug.draw_line(translation, drone.translation, Color.orange)
		drone.draw_debug(debug)
