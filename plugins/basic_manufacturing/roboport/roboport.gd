tool
extends OwnWar_Structure


const Drone := preload("roboport_drone.gd")
const Tasks := preload("tasks.gd")
export var drone_scene: PackedScene
export var drone_limit := 10
export var _radius2 := 100.0 * 100.0
var _drones := []
var _immediate_geometry: ImmediateGeometry
var _units := []
var _providers := []
var _takers := []
var _needs_provider := []
var _needs_taker := []
var _tasks := []
var _dirty := false
var _assigning_tasks := false
onready var _spawn_timer := get_tree().create_timer(1.0, false)
onready var _spawn_point: Transform = ($SpawnPoint as Spatial).global_transform


func _ready():
	if not Engine.editor_hint:
		var types_count := OwnWar.Matter.get_matter_types_count()
		_providers.resize(types_count)
		_takers.resize(types_count)
		_needs_provider.resize(types_count)
		_needs_taker.resize(types_count)
		_set_radius2(_radius2)
		var e = game_master.connect("unit_added", self, "_unit_added")
		assert(e == OK)


func _exit_tree():
	# The same as _spawn_timer.free() but without complaints
	_spawn_timer = null


func _process(_delta: float) -> void:
	if Engine.editor_hint:
		show_feedback(null)
	else:
		set_process(false)


func get_actions() -> Array:
	var actions := .get_actions()
	var set_cov := OwnWar.Action.new(
		"Set Coverage",
		null,
		Action.INPUT_COORDINATE,
		funcref(self, "set_coverage_radius")
	)
	set_cov.feedback = funcref(self, "set_coverage_radius_feedback")
	actions.append(set_cov)
	return actions

func get_info() -> Dictionary:
	var info = .get_info()
	info["Drones"] = "%d / %d" % [len(_drones), drone_limit]
	info["Units"] = str(len(_units))
	info["Tasks"] = str(len(_tasks))
	return info


func show_feedback(_hud: Control) -> void:
	if _immediate_geometry == null:
		_immediate_geometry = ImmediateGeometry.new()
		var mat := SpatialMaterial.new()
		mat.albedo_color = Color.orange
		mat.flags_unshaded = true
		_immediate_geometry.material_override = mat
		add_child(_immediate_geometry)
	_draw_circle(sqrt(_radius2))


func hide_feedback():
	if _immediate_geometry != null:
		_immediate_geometry.queue_free()
		_immediate_geometry = null


func set_coverage_radius(_flags: int, position: Vector3) -> void:
	_set_radius2(translation.distance_squared_to(position))


func set_coverage_radius_feedback(viewport: Viewport, _flags: int,
	position: Vector3) -> void:
	var projected_position := Plane(transform.basis.y, 0).project(position)
	_draw_circle(translation.distance_to(projected_position))


func assign_tasks() -> void:
	if not _dirty:
		call_deferred("_assign_tasks")
		_dirty = true


func serialize_json() -> Dictionary:
	var d_list := []
	for d in _drones:
		d_list.append(d.uid)
	return {
			"drones": d_list,
			"radius2": _radius2,
			"spawn_timer": _spawn_timer.time_left
		}


func deserialize_json(data: Dictionary) -> void:
	_drones = []
	for d_uid in data["drones"]:
		var gm: OwnWar.GameMaster = game_master
		_drones.append(gm.get_unit_by_uid(d_uid))
	_spawn_timer = get_tree().create_timer(data["spawn_timer"], false)
	_set_radius2(data["radius2"])


func _assign_tasks() -> void:
	if _assigning_tasks:
		return
	_assigning_tasks = true

	for i in range(len(_tasks) - 1, -1, -1):
		var task: Tasks.Task = _tasks[i]
		if task is Tasks.Transport:
			var tr_task: Tasks.Transport = task
			if not tr_task.from in _units or not tr_task.to in _units:
				_tasks.remove(i)
		else:
			assert(false)

	while len(_tasks) > 0:
		var task: Tasks.Task
		for t in _tasks:
			if task == null or t.assignees < task.assignees:
				task = t
		var drone
		if task is Tasks.Transport:
			var tr_task: Tasks.Transport = task
			drone = _get_idle_drone(PoolVector3Array([tr_task.from, tr_task.to]))
		else:
			assert(false)
			drone = _get_idle_drone()
		if drone is GDScriptFunctionState:
			drone = yield(drone, "completed")
		if drone == null:
			break
		assert(drone is Drone)
		if task is Tasks.Transport:
			var tr_task: Tasks.Transport = task
			if drone.matter_count != 0 and drone.matter_id != tr_task.matter_id:
				var taker := _get_nearest(drone, _takers[drone.matter_id],
						drone.matter_id, drone.matter_count)
				if taker == null:
					break
				drone.dump_target = taker
		task.assignees += 1
		_tasks.push_back(_tasks.pop_front())
		if task is Tasks.Empty:
			drone.set_task(task)
		elif task is Tasks.Fill:
			drone.set_task(task)
		else:
			assert(false)

	_dirty = false
	_assigning_tasks = false


func _draw_circle(radius: float) -> void:
	var space_state := get_world().direct_space_state
	_immediate_geometry.clear()
	_immediate_geometry.begin(Mesh.PRIMITIVE_LINE_LOOP)
	for i in range(128):
		var r := i * 2.0 * PI / 128
		var v := Vector3(cos(r) * radius, 0.0, sin(r) * radius) + \
				global_transform.origin
		# NOTE: raycast tests against large bodies are very inaccurate because
		# reasons (https://pybullet.org/Bullet/phpBB3/viewtopic.php?t=3524)
		var result := space_state.intersect_ray(v + Vector3.UP * 1000,
				v + Vector3.DOWN * 1000, [], OwnWar.COLLISION_MASK_TERRAIN)
		if len(result) > 0:
			v = result.position + Vector3.UP * 0.025
		_immediate_geometry.add_vertex(to_local(v))
	_immediate_geometry.end()


func _set_radius2(radius2: float) -> void:
	_radius2 = radius2
	for unit in _units:
		unit.disconnect("destroyed", self, "_unit_destroyed")
		unit.disconnect("need_matter", self, "_on_need_matter")
		unit.disconnect("provide_matter", self, "_on_provide_matter")
		unit.disconnect("take_matter", self, "_on_take_matter")
		unit.disconnect("dump_matter", self, "_on_dump_matter")
	_units = []
	for i in range(OwnWar.Matter.get_matter_types_count()):
		_providers[i] = []
		_takers[i] = []
		_needs_provider[i] = []
		_needs_taker[i] = []
	var gm: OwnWar.GameMaster = game_master
	for unit in gm.get_units(team, OwnWar.Structure):
		if translation.distance_squared_to(unit.translation) < radius2:
			_add_unit(unit)
	assign_tasks()


func _on_need_matter(id: int, amount: int, unit: OwnWar.Unit):
	if amount > 0:
		var provider := _get_nearest(unit, _providers[id])
		if provider != null:
			_add_task(Tasks.Fill.new(provider, unit, id))
		else:
			_needs_taker[id].append(unit)
	else:
		_remove_task(Tasks.Fill, unit)
	assign_tasks()


func _on_provide_matter(id: int, amount: int, unit: OwnWar.Unit):
	if amount > 0:
		if not unit in _providers[id]:
			_add_matter_provider(unit, id)
	else:
		_providers[id].erase(unit)
	assign_tasks()


func _on_take_matter(id: int, amount: int, unit: OwnWar.Unit):
	if amount > 0:
		if not unit in _takers[id]:
			_add_matter_taker(unit, id)
	else:
		_takers[id].erase(unit)
	assign_tasks()


func _on_dump_matter(id: int, amount: int, unit: OwnWar.Unit):
	if amount > 0:
		var taker := _get_nearest(unit, _takers[id])
		if taker != null:
			_add_task(Tasks.Empty.new(unit, taker, id))
		else:
			_needs_taker[id].append(unit)
	else:
		_remove_task(Tasks.Empty, unit)
	_assign_tasks()


func _unit_destroyed(unit):
	_units.erase(unit)


func _get_idle_drone(near_points := PoolVector3Array()) -> Drone:
	var shortest_distance := INF
	var candidate: Drone = null
	for drone in _drones:
		if drone.task == null:
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

	if _spawn_timer.time_left > 0.0:
		yield(_spawn_timer, "timeout")

	if len(_drones) < drone_limit:
		var drone = drone_scene.instance()
		drone.transform = _spawn_point
		drone.connect("task_completed", self, "_task_completed", [drone])
		drone.team = team
		_drones.append(drone)
		game_master.add_child(drone)
		_spawn_timer = get_tree().create_timer(2.5, false)
		return drone
	return null


func _task_completed(drone: Drone) -> void:
	# ??? Editor complains "Task cannot be of type Fill ever"
#	assert(drone.task is Tasks.Fill or drone.task is Tasks.Empty)
	drone.task.assignees -= 1
	assign_tasks()


func _get_nearest(unit: OwnWar.Unit, unit_list: Array, matter_id := -1,
	matter_count := 0) -> OwnWar.Unit:
	var provider: OwnWar.Unit
	var shortest_distance := INF
	for prov in unit_list:
		if prov.get_matter_space(matter_id) >= matter_count:
			var dist: float = prov.translation.distance_squared_to(unit.translation)
			if dist < shortest_distance:
				provider = prov
				shortest_distance = dist
	return provider


func _unit_added(unit: OwnWar.Unit) -> void:
	if unit is OwnWar.Structure and \
			unit.team == team and \
			unit.translation.distance_squared_to(translation) < _radius2:
		_add_unit(unit)


func _add_unit(unit: OwnWar.Structure) -> void:
	if unit in _units:
		return
	_units.append(unit)

	var err := 0
	err |= unit.connect("destroyed", self, "_unit_destroyed")
	err |= unit.connect("need_matter", self, "_on_need_matter", [unit])
	err |= unit.connect("provide_matter", self, "_on_provide_matter", [unit])
	err |= unit.connect("take_matter", self, "_on_take_matter", [unit])
	err |= unit.connect("dump_matter", self, "_on_dump_matter", [unit])
	assert(err == OK)

	for id in unit.get_put_matter_list():
		if unit.needs_matter(id) > 0:
			var provider := _get_nearest(unit, _providers[id])
			if provider != null:
				_add_task(Tasks.Fill.new(provider, unit, id))
			else:
				_needs_provider[id].append(unit)
		if unit.takes_matter(id) > 0:
			_add_matter_taker(unit, id)

	for id in unit.get_take_matter_list():
		if unit.dumps_matter(id) > 0:
			var taker := _get_nearest(unit, _takers[id])
			if taker != null:
				_add_task(Tasks.Empty.new(unit, taker, id))
			else:
				_needs_taker[id].append(unit)
		if unit.provides_matter(id) > 0:
			_add_matter_provider(unit, id)


func _add_matter_provider(unit: OwnWar.Structure, id: int) -> void:
	_providers[id].append(unit)
	for needer in _needs_provider[id]:
		_add_task(Tasks.Fill.new(unit, needer, id))
	_needs_provider[id] = []


func _add_matter_taker(unit: OwnWar.Structure, id: int) -> void:
	_takers[id].append(unit)
	for needer in _needs_taker[id]:
		_add_task(Tasks.Empty.new(needer, unit, id))
	_needs_taker[id] = []


func _remove_unit(unit: OwnWar.Structure) -> void:
	unit.disconnect("message", self, "_get_message")
	unit.disconnect("destroyed", self, "_unit_destroyed")
	for id in unit.get_take_matter_list():
		_providers[id].erase(unit)
		_needs_provider[id].erase(unit)
	for id in unit.get_put_matter_list():
		_takers[id].erase(unit)
		_needs_taker[id].erase(unit)
	_units.erase(unit)


func _add_task(task: Tasks.Task) -> void:
	for t in _tasks:
		if (t is Tasks.Fill and task is Tasks.Fill) or \
			(t is Tasks.Empty and task is Tasks.Empty):
			var tr_t: Tasks.Transport = t
			var tr_task: Tasks.Transport = task
			if tr_task.from == tr_t.from and tr_task.to == tr_t.to:
				return
	_tasks.push_back(task)
	assign_tasks()


func _remove_task(task: GDScript, unit: OwnWar.Unit) -> void:
	# cba with the range() syntax
	var i := len(_tasks) - 1
	while i >= 0:
		var t = _tasks[i]
		if t is task:
			if t.from == unit or t.to == unit:
				_tasks.remove(i)
		i -= 1


func debug_draw():
	for drone in _drones:
		Debug.draw_line(translation, drone.translation, Color.orange)
	var uid_str := str(uid)
	for u in _units:
		var unit: OwnWar.Unit = u
		var msg := "Roboport UID: %s" % uid_str
		var prepended := false

		for i in len(_providers):
			if unit in _providers[i]:
				if not prepended:
					msg += "\nProvides: "
					prepended = true
				msg += str(i) + ", "

		prepended = false
		for i in len(_takers):
			if unit in _takers[i]:
				if not prepended:
					msg += "\nTakes: "
					prepended = true
				msg += str(i) + ", "

		prepended = false
		for t in _tasks:
			var task := t as Tasks.Fill
			if task != null and task.to == unit:
				if not prepended:
					msg += "\nNeeds: "
					prepended = true
				msg += str(task.matter_id) + ", "

		prepended = false
		for t in _tasks:
			var task := t as Tasks.Empty
			if task != null and task.from == unit:
				if not prepended:
					msg += "\nDumps: "
					prepended = true
				msg += str(task.matter_id) + ", "

		Debug.draw_text(unit.translation, msg, Color.orange)
