extends Unit


signal task_completed(task, target)
enum Task {
		PUT,
		TAKE,
		PUT_ONLY,
		TAKE_ONLY,
		BUILD_STRUCTURE,
		GOTO_WAYPOINT,
	}
const SPEED = 20.0
const INTERACTION_DISTANCE = 6.0
const INTERACTION_DISTANCE_2 = INTERACTION_DISTANCE * INTERACTION_DISTANCE
export(Dictionary) var ghosts = {}
export(PackedScene) var drill_ghost
export(int) var cost = 20
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
onready var _material_id: int = Matter.name_to_id["material"]


func _process(delta):
	for rotor in rotors:
		rotor.rotate_object_local(Vector3.UP, delta * 50)
	draw_debug(game_master.get_node("Debug"))
		
		
func _physics_process(delta):
	if len(tasks) == 0:
		return
	var task = tasks[0]
	match task[0]:
		Task.GOTO_WAYPOINT:
			if move_towards(task[1], delta):
				current_task_completed()
		Task.BUILD_STRUCTURE:
			if _matter_id == _material_id and _matter_count > 0:
				if translation.distance_squared_to(task[1].translation) <= INTERACTION_DISTANCE_2:
					if last_build_frame + Engine.iterations_per_second < Engine.get_physics_frames():
						_matter_count -= 1
						_matter_count += task[1].add_build_progress(1)
						last_build_frame = Engine.get_physics_frames()
				else:
					move_towards(task[1].translation, delta)
			elif _matter_count == 0:
				if _take_matter_from_any(_material_id, [], delta) < 0:
					current_task_completed()
			else:
				if _put_matter_in_any(_matter_id, [], delta) < 0:
					current_task_completed()
		Task.PUT:
			var id: int = task[2]
			if task[1].get_matter_space(id) == 0:
				current_task_completed()
			elif _matter_id == id or _matter_count == 0:
				_matter_id = id
				if _matter_count > 0:
					if _put_matter(id, task[1], delta):
						current_task_completed()
				else:
					if _take_matter_from_any(id, [task[1]], delta) < 0:
						current_task_completed()
			else:
				if _put_matter_in_any(_matter_id, [task[1]], delta) < 0:
					current_task_completed()
		Task.TAKE:
			var id: int = task[2]
			if task[1].get_matter_count(id) == 0:
				current_task_completed()
			elif _matter_id == id or _matter_count == 0:
				_matter_id = id
# warning-ignore:integer_division
				if _matter_count < _MAX_VOLUME / Matter.matter_volume[id]:
					if _take_matter(id, task[1], delta):
						current_task_completed()
				else:
					if _put_matter_in_any(id, [task[1]], delta) < 0:
						current_task_completed()
			else:
				if _put_matter_in_any(_matter_id, [task[1]], delta) < 0:
					current_task_completed()
		Task.PUT_ONLY:
			var id: int = task[2]
			if task[1].get_matter_space(id) == 0:
				current_task_completed()
			elif _matter_id == id and _matter_count > 0:
				if _put_matter(id, task[1], delta):
					current_task_completed()
			else:
				current_task_completed()
		Task.TAKE_ONLY:
			var id: int = task[2]
			if task[1].get_matter_count(id) == 0:
				current_task_completed()
			elif _matter_id == id or _matter_count == 0:
				if _take_matter(id, task[1], delta):
					current_task_completed()
			else:
				current_task_completed()


func get_actions():
	return [
			["Set waypoint", Action.INPUT_COORDINATE, "set_waypoint", []],
			["Take", Action.INPUT_OWN_UNITS, "take_matter_from", [false]],
			["Put", Action.INPUT_OWN_UNITS, "put_matter_in", [false]],
			["Take only", Action.INPUT_OWN_UNITS, "take_matter_from", [true]],
			["Put only", Action.INPUT_OWN_UNITS, "put_matter_in", [true]],
			["Build", Action.SUBACTION, "get_build_actions", []],
			["Clear tasks", Action.INPUT_NONE, "clear_tasks", []],
		]


func get_build_actions(_flags):
	var actions = [
			["Build", Action.INPUT_OWN_UNITS, "build", []],
			["Build drill", Action.INPUT_COORDINATE, "build_drill", []],
		]
	for ghost_name in ghosts:
		actions += [["Build " + ghost_name, Action.INPUT_COORDINATE | Action.INPUT_SCROLL,
				"build_ghost", [ghost_name]]]
	return actions


func get_info():
	var info = .get_info()
	var task_string
	if len(tasks) > 0:
		match tasks[0][0]:
			Task.GOTO_WAYPOINT:
				task_string = "Goto"
			Task.BUILD_STRUCTURE:
				task_string = "Build"
			Task.PUT:
				task_string = "Put"
			Task.TAKE:
				task_string = "Take"
			Task.PUT_ONLY:
				task_string = "Put only"
			Task.TAKE_ONLY:
				task_string = "Take only"
			_:
				task_string = "Unknown (BUG)"
	else:
		task_string = "None"
	info["Current task"] = task_string
	info["Total tasks"] = str(len(tasks))
	if _matter_count > 0:
		info["Matter type"] = Matter.matter_name[_matter_id]
		info["Matter count"] = "%d / %d" % [_matter_count,
# warning-ignore:integer_division
				_MAX_VOLUME / Matter.matter_volume[_matter_id]]
	return info


func add_task(task, force_append):
	if not force_append:
		clear_tasks(0)
	if task[1] is Unit and not task[1].is_connected("destroyed", self, "_unit_destroyed"):
		task[1].connect("destroyed", self, "_unit_destroyed", [task])
	tasks.append(task)


func set_waypoint(flags, coordinate):
	add_task([Task.GOTO_WAYPOINT, coordinate], flags & 0x1 > 0)


func move_towards(position, delta):
	var distance = position - translation
	var distance_xz = Vector3(distance.x, 0, distance.z)
	var distance_xz_length2 = distance_xz.length_squared()
	var speed = SPEED if distance_xz_length2 > SPEED * SPEED * delta * delta else \
			sqrt(distance_xz_length2) / delta
	var velocity_direction = distance_xz.normalized()
	var height = translation.y - $RayCast.get_collision_point().y if \
			$RayCast.is_colliding() else 5
	if height < 1:
		velocity_direction = (velocity_direction + Vector3.UP).normalized()
	elif height > 4:
		velocity_direction = (velocity_direction + Vector3.DOWN).normalized()
	if distance_xz_length2 > 1e-5:
		$".".move_and_slide(velocity_direction * speed, Vector3.UP,
				false, 4, PI / 4, false)
		return false
	else:
		return true


func build(flags, units):
	var force_append = flags & 0x1 > 0
	for ghost in units:
		if ghost is Ghost:
			add_task([Task.BUILD_STRUCTURE, ghost], force_append)
			ghost.connect("built", self, "_ghost_built")
			force_append = true
			
			
func build_ghost(flags, position, scroll, ghost_name):
	var ghost = ghosts[ghost_name].instance()
	ghost.transform = Transform(Basis.IDENTITY.rotated(Vector3.UP, scroll * PI / 8), position)
	game_master.add_unit(team, ghost)
	add_task([Task.BUILD_STRUCTURE, ghost], flags & 0x1 > 0)
	ghost.connect("built", self, "_ghost_built")


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
		game_master.add_unit(team, ghost)
		add_task([Task.BUILD_STRUCTURE, ghost], flags & 0x1 > 0)
		ghost.connect("built", self, "_ghost_built")


func put_matter_in(flags, units, only):
	var force_append = flags & 0x1 > 0
	for unit in units:
		var matter_ids = unit.get_put_matter_list()
		for id in matter_ids:
			add_task([Task.PUT_ONLY if only else Task.PUT, unit, id], force_append)
			force_append = true


func take_matter_from(flags, units, only):
	var force_append = flags & 0x1 > 0
	for unit in units:
		var matter_ids = unit.get_take_matter_list()
		for id in matter_ids:
			add_task([Task.TAKE_ONLY if only else Task.TAKE, unit, id], force_append)
			force_append = true


func clear_tasks(_flags):
	for task in tasks:
		if task[1] is Unit:
			task[1].disconnect("destroyed", self, "_unit_destroyed")
		if task[0] == Task.BUILD_STRUCTURE and task[1] != null:
			task[1].disconnect("built", self, "emit_signal")
	tasks = []


func current_task_completed():
	var task = tasks.pop_front()
	emit_signal("task_completed", task[0], task[1])
	tasks.push_back(task)
	_task_cached_unit = null


func get_cost():
	return cost


func draw_debug(debug):
	var start = translation
	for task in tasks:
		var color
		var position
		match task[0]:
			Task.GOTO_WAYPOINT:
				color = Color.green
				position = task[1] + Vector3.UP * Global.BLOCK_SCALE
			Task.BUILD_STRUCTURE:
				color = Color.orange
				position = task[1].translation
			Task.PUT, Task.PUT_ONLY:
				color = Color.cyan
				position = task[1].translation
			Task.TAKE, Task.TAKE_ONLY:
				color = Color.purple
				position = task[1].translation
		if color != null:
			debug.draw_circle(position, color)
			debug.draw_line(start, position, color)
			start = position
	if _task_cached_unit != null:
		debug.draw_line(translation, _task_cached_unit.translation, Color.yellow)


func serialize_json() -> Dictionary:
	var t_list := []
	for t in tasks:
		var d := { "task": Util.enum_to_str(Task, t[0]) }
		match t[0]:
			Task.GOTO_WAYPOINT:
				d["waypoint"] = var2str(t[1])
			Task.BUILD_STRUCTURE:
				d["target"] = t[1].uid
			Task.PUT, Task.PUT_ONLY, \
			Task.TAKE, Task.TAKE_ONLY:
				d["target"] = t[1].uid
				d["matter"] = Matter.matter_name[t[2]]
			_:
				assert(false)
		t_list.append(d)
	var d := { "tasks": t_list }
	if _task_cached_unit != null:
		d["cached_unit"] = _task_cached_unit.uid
	return d


func deserialize_json(data: Dictionary) -> void:
	tasks = []
	for t_d in data["tasks"]:
		var t := [Task[t_d["task"]]]
		match t[0]:
			Task.GOTO_WAYPOINT:
				t.append(str2var(t_d["waypoint"]))
			Task.BUILD_STRUCTURE:
				var u: Unit = game_master.get_unit_by_uid(t_d["target"])
				t.append(u)
			Task.PUT, Task.PUT_ONLY, \
			Task.TAKE, Task.TAKE_ONLY:
				var u: Unit = game_master.get_unit_by_uid(t_d["target"])
				t.append(u)
				t.append(Matter.name_to_id[t_d["matter"]])
			_:
				assert(false)
		tasks.append(t)
	var c_uid: int = data.get("cached_unit", -1)
	if c_uid >= 0:
		_task_cached_unit = game_master.get_unit_by_uid(c_uid)


func _ghost_built(unit):
	emit_signal("task_completed", Task.BUILD_STRUCTURE, unit)


func _unit_destroyed(_unit, task):
	while true:
		var index = tasks.find_last(task)
		if index < 0:
			break
		tasks.remove(index)
		if index == 0:
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
	var matter_space := _MAX_VOLUME / Matter.matter_volume[id] - _matter_count
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
		for unit in game_master.get_units(team):
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
		for unit in game_master.get_units(team):
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
	var e := unit.connect("destroyed", self, "_set_cached_unit", [null])
	assert(e == OK)
	_task_cached_unit = unit
