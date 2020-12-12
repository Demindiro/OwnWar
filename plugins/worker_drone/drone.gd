extends Unit


class Task:
	var oneshot: bool

	func _init() -> void:
		# Thanks Godot
#		assert(false)
		pass

	func _to_string() -> String:
		assert(false)
		return "(BUG)"

	func serialize() -> Dictionary:
		assert(false)
		return {}

	static func deserialize(game_master: GameMaster, state: Dictionary) -> Task:
		match state["task"]:
			"PUT": return TaskPut.deserialize(game_master, state)
			"TAKE": return TaskTake.deserialize(game_master, state)
			"PUT_ONLY": return TaskPutOnly.deserialize(game_master, state)
			"TAKE_ONLY": return TaskTakeOnly.deserialize(game_master, state)
			"BUILD_STRUCTURE": return TaskBuild.deserialize(game_master, state)
			"GOTO_WAYPOINT": return TaskGoto.deserialize(game_master, state)
		assert(false)
		return null

	func _serialize(type: String) -> Dictionary:
		return {
				"task": type,
				"oneshot": oneshot,
			}


class TaskPut:
	extends Task
	var unit: Unit
	var matter_id: int

	func _init(p_unit: Unit, p_matter_id: int, p_oneshot := false):
		unit = p_unit
		matter_id = p_matter_id
		oneshot = p_oneshot

	func _to_string() -> String:
		return "Put"

	func serialize() -> Dictionary:
		var s := ._serialize("PUT")
		s["target"] = unit.uid
		s["matter"] = Matter.get_matter_name(matter_id)
		return s

	static func deserialize(game_master: GameMaster, state: Dictionary) -> Task:
		return TaskPut.new(
				game_master.get_unit_by_uid(state["target"]),
				Matter.get_matter_id(state["matter"]),
				state.get("oneshot", false)
			)


class TaskTake:
	extends Task
	var unit: Unit
	var matter_id: int

	func _init(p_unit: Unit, p_matter_id: int, p_oneshot := false):
		unit = p_unit
		matter_id = p_matter_id
		oneshot = p_oneshot

	func _to_string() -> String:
		return "Take"

	func serialize() -> Dictionary:
		var s := ._serialize("TAKE")
		s["target"] = unit.uid
		s["matter"] = Matter.get_matter_name(matter_id)
		return s

	static func deserialize(game_master: GameMaster, state: Dictionary) -> Task:
		return TaskTake.new(
				game_master.get_unit_by_uid(state["target"]),
				Matter.get_matter_id(state["matter"]),
				state.get("oneshot", false)
			)


class TaskPutOnly:
	extends Task
	var unit: Unit
	var matter_id: int

	func _init(p_unit: Unit, p_matter_id: int, p_oneshot := false):
		unit = p_unit
		matter_id = p_matter_id
		oneshot = p_oneshot

	func _to_string() -> String:
		return "Put only"

	func serialize() -> Dictionary:
		var s := ._serialize("PUT_ONLY")
		s["target"] = unit.uid
		s["matter"] = Matter.get_matter_name(matter_id)
		return s

	static func deserialize(game_master: GameMaster, state: Dictionary) -> Task:
		return TaskPutOnly.new(
				game_master.get_unit_by_uid(state["target"]),
				Matter.get_matter_id(state["matter"]),
				state.get("oneshot", false)
			)


class TaskTakeOnly:
	extends Task
	var unit: Unit
	var matter_id: int

	func _init(p_unit: Unit, p_matter_id: int, p_oneshot := false):
		unit = p_unit
		matter_id = p_matter_id
		oneshot = p_oneshot

	func _to_string() -> String:
		return "Take only"

	func serialize() -> Dictionary:
		var s := ._serialize("TAKE_ONLY")
		s["target"] = unit.uid
		s["matter"] = Matter.get_matter_name(matter_id)
		return s

	static func deserialize(game_master: GameMaster, state: Dictionary) -> Task:
		return TaskTakeOnly.new(
				game_master.get_unit_by_uid(state["target"]),
				Matter.get_matter_id(state["matter"]),
				state.get("oneshot", false)
			)


class TaskBuild:
	extends Task
	var unit: Unit

	func _init(p_unit: Unit, p_oneshot := false):
		unit = p_unit
		oneshot = p_oneshot

	func _to_string() -> String:
		return "Build"

	func serialize() -> Dictionary:
		var s := ._serialize("BUILD_STRUCTURE")
		s["target"] = unit.uid
		return s

	static func deserialize(game_master: GameMaster, state: Dictionary) -> Task:
		return TaskBuild.new(
				game_master.get_unit_by_uid(state["target"]),
				state.get("oneshot", false)
			)


class TaskGoto:
	extends Task
	var coordinate: Vector3

	func _init(p_coordinate: Vector3, p_oneshot := false):
		coordinate = p_coordinate
		oneshot = p_oneshot

	func _to_string() -> String:
		return "Goto"

	func serialize() -> Dictionary:
		var s := ._serialize("GOTO_WAYPOINT")
		s["waypoint"] = var2str(coordinate)
		return s

	static func deserialize(_game_master: GameMaster, state: Dictionary) -> Task:
		return TaskGoto.new(
				str2var(state["waypoint"]),
				state.get("oneshot", false)
			)


signal task_completed(task)
const SPEED = 20.0
const INTERACTION_DISTANCE = 6.0
const INTERACTION_DISTANCE_2 = INTERACTION_DISTANCE * INTERACTION_DISTANCE
export(PackedScene) var drill_ghost
export(int) var cost = 20
var ghosts := {}
var tasks = []
var last_build_frame = 0
onready var rotors = [
		$ArmLF/Rotor,
		$ArmRF/Rotor,
		$ArmLB/Rotor,
		$ArmRB/Rotor,
	]
const _MAX_VOLUME := 20_000_000
var _task_cached_unit: Unit
var _matter_id := -1
var _matter_count := 0
onready var _material_id: int = Matter.get_matter_id("material")
onready var _raycast: RayCast = $RayCast


func _init() -> void:
	var d := Unit.get_all_units()
	for k in d:
		if k.ends_with("_ghost"):
			ghosts[k.substr(0, len(k) - 6)] = d[k]


func _process(delta):
	for rotor in rotors:
		rotor.rotate_object_local(Vector3.UP, delta * 50)


func _physics_process(delta):
	if len(tasks) == 0:
		return
	var task: Task = tasks[0]
	if task is TaskGoto:
		var t: TaskGoto = task
		if move_towards(t.coordinate, delta):
			current_task_completed()
	elif task is TaskBuild:
		var t: TaskBuild = task
		if _matter_id == _material_id and _matter_count > 0:
			if translation.distance_squared_to(t.unit.translation) <= INTERACTION_DISTANCE_2:
				if last_build_frame + Engine.iterations_per_second < Engine.get_physics_frames():
					var u: Ghost = t.unit
					_matter_count -= 1
					_matter_count += u.add_build_progress(1)
					last_build_frame = Engine.get_physics_frames()
			else:
				move_towards(t.unit.translation, delta)
		elif _matter_count == 0:
			if _take_matter_from_any(_material_id, [], delta) < 0:
				current_task_completed()
		else:
			if _put_matter_in_any(_matter_id, [], delta) < 0:
				current_task_completed()
	elif task is TaskPut:
		var t: TaskPut = task
		var id: int = t.matter_id
		var unit: Unit = t.unit
		if unit.get_matter_space(id) == 0:
			current_task_completed()
		elif _matter_id == id or _matter_count == 0:
			_matter_id = id
			if _matter_count > 0:
				if _put_matter(id, unit, delta):
					current_task_completed()
			else:
				if _take_matter_from_any(id, [unit], delta) < 0:
					current_task_completed()
		else:
			if _put_matter_in_any(_matter_id, [unit], delta) < 0:
				current_task_completed()
	elif task is TaskTake:
		var t: TaskTake = task
		var id: int = t.matter_id
		var unit: Unit = t.unit
		if unit.get_matter_count(id) == 0:
			current_task_completed()
		elif _matter_id == id or _matter_count == 0:
			_matter_id = id
			# warning-ignore:integer_division
			if _matter_count < _MAX_VOLUME / Matter.get_matter_volume(id):
				if _take_matter(id, unit, delta):
					current_task_completed()
			else:
				if _put_matter_in_any(id, [unit], delta) < 0:
					current_task_completed()
		else:
			if _put_matter_in_any(_matter_id, [unit], delta) < 0:
				current_task_completed()
	elif task is TaskPutOnly:
		var t: TaskPutOnly = task
		var id: int = t.matter_id
		var unit: Unit = t.unit
		if unit.get_matter_space(id) == 0:
			current_task_completed()
		elif _matter_id == id and _matter_count > 0:
			if _put_matter(id, unit, delta):
				current_task_completed()
		else:
			current_task_completed()
	elif task is TaskTakeOnly:
		var t: TaskTakeOnly = task
		var id: int = t.matter_id
		var unit: Unit = t.unit
		if unit.get_matter_count(id) == 0:
			current_task_completed()
		elif _matter_id == id or _matter_count == 0:
			if _take_matter(id, unit, delta):
				current_task_completed()
		else:
			current_task_completed()


func get_actions():
	var A := OwnWar.Action
	return [
		A.new("Set waypoint", Action.INPUT_COORDINATE,
			funcref(self, "set_waypoint")),
		A.new("Take", Action.INPUT_OWN_UNITS, funcref(self, "take_matter_from"),
			[false]),
		A.new("Put", Action.INPUT_OWN_UNITS, funcref(self, "put_matter_in"),
			[false]),
		A.new("Take only", Action.INPUT_OWN_UNITS,
			funcref(self, "take_matter_from"), [true]),
		A.new("Put only", Action.INPUT_OWN_UNITS,
			funcref(self, "put_matter_in"), [true]),
		A.new("Build", Action.SUBACTION, funcref(self, "get_build_actions")),
		A.new("Clear tasks", Action.INPUT_NONE, funcref(self, "clear_tasks")),
	]


func get_build_actions(_flags):
	var A := OwnWar.Action
	var actions = [
			A.new("Build", Action.INPUT_OWN_UNITS, funcref(self, "build")),
			A.new("Build drill", Action.INPUT_COORDINATE,
				funcref(self, "build_drill")),
		]
	for ghost_name in ghosts:
		actions.append(
			A.new(
				"Build " + ghost_name,
				Action.INPUT_COORDINATE | Action.INPUT_SCROLL,
				funcref(self, "build_ghost"),
				[ghost_name]
			)
		)
	return actions


func get_info():
	var info = .get_info()
	var task_string := str(tasks[0]) if len(tasks) > 0 else "None"
	info["Current task"] = task_string
	info["Total tasks"] = str(len(tasks))
	if _matter_count > 0:
		info["Matter type"] = Matter.get_matter_name(_matter_id)
		info["Matter count"] = "%d / %d" % [_matter_count,
# warning-ignore:integer_division
				_MAX_VOLUME / Matter.get_matter_volume(_matter_id)]
	return info


func add_task(task: Task, force_append: bool) -> void:
	if not force_append:
		clear_tasks(0)
	if not task is TaskGoto:
		# warning-ignore:unsafe_property_access
		var e: int = task.unit.connect("destroyed", self, "_unit_destroyed", [],
				CONNECT_REFERENCE_COUNTED)
		assert(e == OK)
	if task is TaskBuild:
		# warning-ignore:unsafe_property_access
		var e: int = task.unit.connect("built", self, "_ghost_built", [task])
		assert(e == OK)
	tasks.append(task)


func set_waypoint(flags, coordinate):
	add_task(TaskGoto.new(coordinate), flags & 0x1 > 0)


func move_towards(position, delta):
	var distance = position - translation
	var distance_xz = Vector3(distance.x, 0, distance.z)
	var distance_xz_length2 = distance_xz.length_squared()
	var speed = SPEED if distance_xz_length2 > SPEED * SPEED * delta * delta else \
			sqrt(distance_xz_length2) / delta
	var velocity_direction = distance_xz.normalized()
	var height := translation.y - _raycast.get_collision_point().y if \
			_raycast.is_colliding() else 5.0
	if height < 1:
		velocity_direction = (velocity_direction + Vector3.UP).normalized()
	elif height > 4:
		velocity_direction = (velocity_direction + Vector3.DOWN).normalized()
	if distance_xz_length2 > 1e-5:
		var kb: KinematicBody = self as Spatial
		# warning-ignore:return_value_discarded
		kb.move_and_slide(velocity_direction * speed, Vector3.UP,
				false, 4, PI / 4, false)
		return false
	else:
		return true


func build(flags, units):
	var force_append = flags & 0x1 > 0
	for ghost in units:
		if ghost is Ghost:
			var t := TaskBuild.new(ghost)
			add_task(t, force_append)
			force_append = true


func build_ghost(flags, position, scroll, ghost_name):
	var ghost = ghosts[ghost_name].instance()
	ghost.transform = Transform(Basis.IDENTITY.rotated(Vector3.UP, scroll * PI / 8), position)
	ghost.team = team
	game_master.add_child(ghost)
	var t := TaskBuild.new(ghost)
	add_task(t, flags & 0x1 > 0)


func build_drill(flags, coordinate):
	var closest_ore = null
	var max_distance = 3.0
	for ore in game_master.get_tree().get_nodes_in_group("ores"):
		var distance = (ore.translation - coordinate).length()
		if ore.drill == null and distance < max_distance:
			closest_ore = ore
			max_distance = distance
	if closest_ore != null:
		var ghost = drill_ghost.instance()
		ghost.translation = closest_ore.translation + Vector3.UP * 1.4
		ghost.init_arguments = [closest_ore]
		ghost.team = team
		game_master.add_child(ghost)
		var t := TaskBuild.new(ghost)
		add_task(t, flags & 0x1 > 0)


func put_matter_in(flags, units, only):
	var force_append = flags & 0x1 > 0
	for unit in units:
		var matter_ids = unit.get_put_matter_list()
		for id in matter_ids:
			if only:
				add_task(TaskPutOnly.new(unit, id), force_append)
			else:
				add_task(TaskPut.new(unit, id), force_append)
			force_append = true


func take_matter_from(flags, units, only):
	var force_append = flags & 0x1 > 0
	for unit in units:
		var matter_ids = unit.get_take_matter_list()
		for id in matter_ids:
			if only:
				add_task(TaskTakeOnly.new(unit, id), force_append)
			else:
				add_task(TaskTake.new(unit, id), force_append)
			force_append = true


func clear_tasks(_flags):
	for task in tasks:
		if not task is TaskGoto:
			task.unit.disconnect("destroyed", self, "_unit_destroyed")
		if task is TaskBuild:
			task.unit.disconnect("built", self, "_ghost_built")
	tasks = []


func current_task_completed():
	var task: Task = tasks.pop_front()
	emit_signal("task_completed", task)
	if not task.oneshot:
		tasks.push_back(task)
	_task_cached_unit = null


func get_cost():
	return cost


func debug_draw():
	var start = translation
	for task in tasks:
		var color
		var position
		if task is TaskGoto:
			color = Color.green
			position = task.coordinate + Vector3.UP * Block.BLOCK_SCALE
		elif task is TaskBuild:
			color = Color.orange
			position = task.unit.translation
		elif task is TaskPut or task is TaskPutOnly:
			color = Color.cyan
			position = task.unit.translation
		elif task is TaskTake or TaskTakeOnly:
			color = Color.purple
			position = task.unit.translation
		if color != null:
			Debug.draw_circle(position, color)
			Debug.draw_line(start, position, color)
			start = position
	if _task_cached_unit != null:
		Debug.draw_line(translation, _task_cached_unit.translation, Color.yellow)


func serialize_json() -> Dictionary:
	var t_list := []
	for t in tasks:
		t_list.append(t.serialize())
	var d := { "tasks": t_list }
	if _task_cached_unit != null:
		d["cached_unit"] = _task_cached_unit.uid
	return d


func deserialize_json(data: Dictionary) -> void:
	tasks = []
	for t_d in data["tasks"]:
		add_task(Task.deserialize(game_master, t_d), 1)
	var c_uid: int = data.get("cached_unit", -1)
	if c_uid >= 0:
		var gm: GameMaster = game_master
		_set_cached_unit(gm.get_unit_by_uid(c_uid))


func _ghost_built(task: Task):
	emit_signal("task_completed", task)


func _unit_destroyed(unit):
	for i in range(len(tasks) - 1, -1, -1):
		var task: Task = tasks[i]
		# warning-ignore:unsafe_property_access
		if not task is TaskGoto and task.unit == unit:
			tasks.remove(i)
			if i == 0:
				_task_cached_unit = null


func _put_matter(id: int, unit: Unit, delta: float) -> bool:
	if translation.distance_squared_to(unit.translation) <= INTERACTION_DISTANCE_2:
		_matter_count = unit.put_matter(id, _matter_count)
		return true
	else:
		move_towards(unit.translation, delta)
		return false


func _take_matter(id: int, unit: Unit, delta: float) -> bool:
	assert(id == _matter_id or _matter_count == 0)
# warning-ignore:integer_division
	var matter_space := _MAX_VOLUME / Matter.get_matter_volume(id) - _matter_count
	assert(matter_space != 0 or _matter_count != 0)
	if translation.distance_squared_to(unit.translation) <= INTERACTION_DISTANCE_2:
		_matter_count += unit.take_matter(id, matter_space)
		_matter_id = id
		return true
	else:
		move_towards(unit.translation, delta)
		return false


func _put_matter_in_any(id: int, exclude: Array, delta: float) -> int:
	assert(_matter_count > 0 and id == _matter_id)
	if _task_cached_unit == null:
		var closest_distance2 := INF
		var gm: GameMaster = game_master
		for unit in gm.get_units(team):
			if not unit in exclude:
				if unit.takes_matter(id) > 0:
					var d := translation.distance_squared_to(unit.translation)
					if d < closest_distance2:
						_task_cached_unit = unit
						closest_distance2 = d
	if _task_cached_unit != null:
		if _put_matter(id, _task_cached_unit, delta):
			_task_cached_unit = null
			return 1
		return 0
	return -1


func _take_matter_from_any(id: int, exclude: Array, delta: float) -> int:
	assert(_matter_count == 0)
	if _task_cached_unit == null:
		var closest_distance2 := INF
		var gm: GameMaster = game_master
		for unit in gm.get_units(team):
			if not unit in exclude and unit.provides_matter(id) > 0:
				var d := translation.distance_squared_to(unit.translation)
				if d < closest_distance2:
					_task_cached_unit = unit
					closest_distance2 = d
	if _task_cached_unit != null:
		if _take_matter(id, _task_cached_unit, delta):
			_task_cached_unit = null
			return 1
		return 0
	return -1


func _set_cached_unit(unit: Unit) -> void:
	if _task_cached_unit != null:
		_task_cached_unit.disconnect("destroyed", self, "_set_cached_unit")
	if unit != null:
		var e := unit.connect("destroyed", self, "_set_cached_unit", [null])
		assert(e == OK)
	_task_cached_unit = unit
