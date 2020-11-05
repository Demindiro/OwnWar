extends Unit


signal task_completed()
enum Task {
	NONE,
	FILL,
	EMPTY,
	DESPAWN,
}
var task: int
var from_target: Unit
var to_target: Unit
var dump_target: Unit
var task_matter_id: int
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
onready var _spawn_point := translation


func _physics_process(_delta: float) -> void:
	_turn = Vector3.ZERO
	_forward = 0.0
	match task:
		Task.FILL, Task.EMPTY:
			var target: Unit = null
			if task_matter_id != matter_id and matter_count != 0:
				assert(dump_target != null)
				target = dump_target
				if _put_matter(target) and matter_count == 0:
					matter_id = task_matter_id
					target = null
					dump_target = null
			if target == null:
# warning-ignore:integer_division
				var matter_space := _MAX_VOLUME / Matter.matter_volume[task_matter_id] - matter_count
				if _task_step == 0 and (matter_count == 0 if task == Task.FILL else matter_space > 0):
					target = from_target
					if _take_matter(target):
						target = to_target
						_task_step = 1
				else:
					target = to_target
					if _put_matter(target):
						target = null
						_task_completed()
			if target != null:
				_move_towards(target)
		Task.DESPAWN:
			var proj_pos = Plane(transform.basis.y, 0).project(_spawn_point - translation)
			if proj_pos.length_squared() < 9:
				_task_completed()
			else:
				_move_towards(_spawn_point)
		Task.NONE:
			pass
		_:
			assert(false)



func _integrate_forces(state: PhysicsDirectBodyState):
	if _track.is_colliding():
		state.linear_velocity = transform.basis.z * _forward * 2
		state.angular_velocity = _turn * 2


func get_info() -> Dictionary:
	var info := .get_info() as Dictionary
	if matter_count > 0:
		info["Matter type"] = Matter.matter_name[matter_id]
# warning-ignore:integer_division
		info["Matter count"] = "%d / %d" % [matter_count, _MAX_VOLUME / Matter.matter_volume[matter_id]]
	match task:
		Task.NONE:
			info["Task"] = "None"
		Task.FILL, Task.EMPTY:
			info["Task"] = "Transport"
			var matter_space = Matter.matter_volume[task_matter_id] - matter_count
			if task_matter_id != matter_id and matter_count != 0:
				info["Dump"] = Matter.matter_name[matter_id]
			elif matter_count > 0 if task == Task.FILL else matter_space == 0:
				info["Empty"] = Matter.matter_name[task_matter_id]
			else:
				info["Fill"] = Matter.matter_name[task_matter_id]
		_:
			info["Task"] = "???"
	return info


func draw_debug():
	match task:
		Task.FILL, Task.EMPTY:
			Debug.draw_line(translation, from_target.get_interaction_port(), Color.greenyellow)
			Debug.draw_line(translation, to_target.get_interaction_port(), Color.cyan)
			if dump_target != null:
				Debug.draw_line(translation, to_target.get_interaction_port(), Color.red)
		Task.NONE:
			Debug.draw_line(translation + Vector3(0.5, 0, 0.5),
					translation + Vector3(-0.5, 0, -0.5), Color.red)
			Debug.draw_line(translation + Vector3(0.5, 0, -0.5),
					translation + Vector3(-0.5, 0, 0.5), Color.red)
		_:
			assert(false)


func set_task(p_task: int, task_data: Array) -> void:
	task = p_task
	from_target = task_data[0]
	to_target = task_data[1]
	task_matter_id = task_data[2]
	if task_matter_id != matter_id and matter_count == 0:
		matter_id = task_matter_id


func serialize_json() -> Dictionary:
	var d := {
			"matter_id": matter_id,
			"matter_count": matter_count,
			"task": Util.enum_to_str(Task, task),
		}
	match task:
		Task.FILL, Task.EMPTY:
			d["task_from"] = from_target.uid
			d["task_to"] = to_target.uid
			if dump_target != null:
				d["task_dump"] = dump_target.uid
			d["task_matter_id"] = task_matter_id
			d["task_step"] = _task_step
		Task.NONE:
			pass
		_:
			assert(false)
	return d


func deserialize_json(data: Dictionary) -> void:
	matter_id = data["matter_id"]
	matter_count = data["matter_count"]
	task = Task[data["task"]]
	if "task_dump" in data:
		dump_target = game_master.get_unit_by_uid(data["task_dump"])
	match task:
		Task.FILL, Task.EMPTY:
			task_matter_id = data["task_matter_id"]
			_task_step = data["task_step"]
			from_target = game_master.get_unit_by_uid(data["task_from"])
			to_target = game_master.get_unit_by_uid(data["task_to"])
		Task.NONE:
			pass
		_:
			assert(false)


func _move_towards(target) -> void:
	if target is Unit:
		target = target.get_interaction_port()
	elif target is Spatial:
		target = target.translation

	$".".sleeping = false
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
			var rel_pos := target as Vector3 - translation
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
	task = Task.NONE
	from_target = null
	to_target = null
	task_matter_id = -1
	_task_step = 0


func _take_matter(unit: Unit) -> bool:
# warning-ignore:integer_division
	var matter_space := _MAX_VOLUME / Matter.matter_volume[task_matter_id] - matter_count
	var proj_pos = Plane(transform.basis.y, 0).project(unit.get_interaction_port() - translation)
	if proj_pos.length_squared() < 9:
		matter_count += unit.take_matter(matter_id, matter_space)
		return true
	return false


func _put_matter(unit: Unit) -> bool:
	var proj_pos = Plane(transform.basis.y, 0).project(unit.get_interaction_port() - translation)
	if proj_pos.length_squared() < 9:
		matter_count = unit.put_matter(matter_id, matter_count)
		return true
	return false
