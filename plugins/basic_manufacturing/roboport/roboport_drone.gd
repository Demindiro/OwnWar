extends OwnWar.Unit


const Tasks := preload("tasks.gd")
signal task_completed()
var task: Tasks.Task
var dump_target: OwnWar.Unit
var matter_count := 0
var matter_id := -1
const _MAX_VOLUME := 30_000_000
var _turn: Vector3
var _forward: float
var _task_step := 0
onready var _l_sensor: RayCast = $LSensor
onready var _fl_sensor: RayCast = $FRSensor
onready var _fr_sensor: RayCast = $FLSensor
onready var _r_sensor: RayCast = $RSensor
onready var _track: RayCast = $Track


func _physics_process(_delta: float) -> void:
	_turn = Vector3.ZERO
	_forward = 0.0
	if task == null:
		pass
	elif task is Tasks.Transport:
		var tr_task: Tasks.Transport = task
		var target: OwnWar.Unit = null
		if tr_task.matter_id != matter_id and matter_count != 0:
			assert(dump_target != null)
			target = dump_target
			if _put_matter(target) and matter_count == 0:
				matter_id = tr_task.matter_id
				target = null
				dump_target = null
		if target == null:
# warning-ignore:integer_division
			var matter_space := _MAX_VOLUME / Matter.get_matter_volume(
					tr_task.matter_id) - matter_count
			if _task_step == 0 and (matter_count == 0 if tr_task is Tasks.Fill \
					else matter_space > 0):
				target = tr_task.from
				if _take_matter(target):
					target = tr_task.to
					_task_step = 1
			else:
				target = tr_task.to
				if _put_matter(target):
					target = null
					_task_completed()
		if target != null:
			_move_towards(target)
	else:
		assert(false)


func _integrate_forces(state: PhysicsDirectBodyState):
	if _track.is_colliding():
		state.linear_velocity = transform.basis.z * _forward * 2
		state.angular_velocity = _turn * 2


func get_info() -> Dictionary:
	var info: Dictionary = .get_info()
	if matter_count > 0:
		info["Matter type"] = Matter.get_matter_name(matter_id)
# warning-ignore:integer_division
		var m_vol := Matter.get_matter_volume(matter_id)
		info["Matter count"] = "%d / %d" % [matter_count, _MAX_VOLUME / m_vol]
	if task == null:
		info["Task"] = "None"
	elif task is Tasks.Transport:
		var tr_task: Tasks.Transport = task
		info["Task"] = "Transport"
		var matter_space = Matter.get_matter_volume(tr_task.matter_id) - \
				matter_count
		if tr_task.matter_id != matter_id and matter_count != 0:
			info["Dump"] = Matter.get_matter_name(matter_id)
		elif matter_count > 0 if tr_task is Tasks.Fill else matter_space == 0:
			info["Empty"] = Matter.get_matter_name(tr_task.matter_id)
		else:
			info["Fill"] = Matter.get_matter_name(tr_task.matter_id)
	else:
		assert(false)
	return info


func debug_draw():
	if task == null:
		Debug.draw_line(translation + Vector3(0.5, 0, 0.5),
				translation + Vector3(-0.5, 0, -0.5), Color.red)
		Debug.draw_line(translation + Vector3(0.5, 0, -0.5),
				translation + Vector3(-0.5, 0, 0.5), Color.red)
	elif task is Tasks.Transport:
		var tr_task: Tasks.Transport = task
		Debug.draw_line(translation, tr_task.from.get_interaction_port(), \
				Color.greenyellow)
		Debug.draw_line(translation, tr_task.to.get_interaction_port(), \
				Color.cyan)
		if dump_target != null:
			Debug.draw_line(translation, tr_task.to.get_interaction_port(), \
					Color.red)
	else:
		assert(false)


func set_task(p_task: Tasks.Task) -> void:
	assert(p_task == null or p_task is Tasks.Fill or p_task is Tasks.Empty)
	task = p_task


func serialize_json() -> Dictionary:
	var task_str: String
	if task == null:
		task_str = "NONE"
	elif task is Tasks.Fill:
		task_str = "FILL"
	elif task is Tasks.Empty:
		task_str = "EMPTY"
	else:
		assert(false)
	var d := {
			"matter_id": matter_id,
			"matter_count": matter_count,
			"task": task_str,
		}
	if task == null:
		pass
	elif task is Tasks.Transport:
		var tr_task: Tasks.Transport = task
		d["task_from"] = tr_task.from.uid
		d["task_to"] = tr_task.to.uid
		if dump_target != null:
			d["task_dump"] = dump_target.uid
		d["task_matter_id"] = tr_task.matter_id
		d["task_step"] = _task_step
	else:
		assert(false)
	return d


func deserialize_json(data: Dictionary) -> void:
	matter_id = data["matter_id"]
	matter_count = data["matter_count"]
	var gm: GameMaster = game_master
	match data["task"]:
		"NONE":
			task = null
		"FILL":
			task = Tasks.Fill.new(
				gm.get_unit_by_uid(data["task_from"]),
				gm.get_unit_by_uid(data["task_to"]),
				data["task_matter_id"]
			)
		"EMPTY":
			task = Tasks.Empty.new(
				gm.get_unit_by_uid(data["task_from"]),
				gm.get_unit_by_uid(data["task_to"]),
				data["task_matter_id"]
			)
		_:
			assert(false)
	if "task_dump" in data:
		dump_target = gm.get_unit_by_uid(data["task_dump"])
	_task_step = data.get("task_step", 0)


func _move_towards(target_node: Spatial) -> void:
	var target: Vector3
	if target_node is OwnWar.Unit:
		var u: OwnWar.Unit = target_node
		target = u.get_interaction_port()
	elif target_node is Spatial:
		target = target_node.translation

	var rb: RigidBody = (self as Spatial)
	rb.sleeping = false
	var sensor_mask = 0
	if _l_sensor.is_colliding():
		sensor_mask |= 0b100
	if _fl_sensor.is_colliding() or _fr_sensor.is_colliding():
		sensor_mask |= 0b010
	if _r_sensor.is_colliding():
		sensor_mask |= 0b001

	# Set forward drive
	match sensor_mask:
		0b000, 0b001, 0b100, 0b101: _forward = 1.0
		0b010, 0b110: _forward = 0.0
		0b011, 0b111: _forward = -1.0
		_: assert(false)

	# Set turning angle
	match sensor_mask:
		0b000:
			var rel_pos := target - translation
			var proj_pos := Plane(transform.basis.y, 0.0).project(rel_pos)
			var direction := proj_pos.normalized()
			var error := 1.0 - transform.basis.z.dot(direction)
			if error < 1.5:
				_turn = transform.basis.z.cross(direction)
				if error > 1.0:
					_turn = _turn.normalized()
			else:
				# Turn right to prevent "hug of death"
				_turn = -transform.basis.y
		0b001, 0b101: _turn = Vector3.ZERO
		0b010, 0b011, 0b100, 0b110, 0b111: _turn = -transform.basis.y
		_: assert(false)


func _task_completed() -> void:
	emit_signal("task_completed")
	task = null
	_task_step = 0


func _take_matter(unit: OwnWar.Unit) -> bool:
	var task_tr: Tasks.Transport = task
	assert(task_tr.matter_id == matter_id or matter_count == 0)
	var m_vol := Matter.get_matter_volume(task_tr.matter_id)
# warning-ignore:integer_division
	var matter_space := _MAX_VOLUME / m_vol - matter_count
	var proj_pos = Plane(transform.basis.y, 0).project(unit.get_interaction_port() \
			- translation)
	if proj_pos.length_squared() < 9:
		matter_id = task_tr.matter_id
		matter_count += unit.take_matter(matter_id, matter_space)
		return true
	return false


func _put_matter(unit: OwnWar.Unit) -> bool:
	var proj_pos = Plane(transform.basis.y, 0).project(unit.get_interaction_port() - translation)
	if proj_pos.length_squared() < 9:
		matter_count = unit.put_matter(matter_id, matter_count)
		return true
	return false
