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
const _MAX_VOLUME := 30_00
var _turn: Vector3
var _forward: float
var _task_step := 0
onready var _ll_sensor: RayCast = $LLSensor
onready var _lf_sensor: RayCast = $LFSensor
onready var _rf_sensor: RayCast = $RFSensor
onready var _rr_sensor: RayCast = $RRSensor
onready var _track_l: RayCast = $TrackL
onready var _track_r: RayCast = $TrackR
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
	if _track_l.is_colliding() or _track_r.is_colliding():
		state.linear_velocity = transform.basis.z * _forward * 2
		state.angular_velocity = _turn * 2


func get_info() -> Dictionary:
	var info := .get_info() as Dictionary
	if matter_count > 0:
		info["Matter type"] = Matter.matter_name[matter_id]
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


func draw_debug(debug):
	match task:
		Task.FILL, Task.EMPTY:
			debug.draw_line(translation, from_target.get_interaction_port(), Color.greenyellow)
			debug.draw_line(translation, to_target.get_interaction_port(), Color.cyan)
			if dump_target != null:
				debug.draw_line(translation, to_target.get_interaction_port(), Color.red)
		Task.NONE:
			debug.draw_line(translation + Vector3(0.5, 0, 0.5),
					translation + Vector3(-0.5, 0, -0.5), Color.red)
			debug.draw_line(translation + Vector3(0.5, 0, -0.5),
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


func _move_towards(target) -> void:
	if target is Unit:
		target = target.get_interaction_port()
	elif target is Spatial:
		target = target.translation

	$".".sleeping = false
	var sensor_mask = 0
	if _ll_sensor.is_colliding():
		sensor_mask |= 0b0001
	if _lf_sensor.is_colliding():
		sensor_mask |= 0b0010
	if _rf_sensor.is_colliding():
		sensor_mask |= 0b0100
	if _rr_sensor.is_colliding():
		sensor_mask |= 0b1000

	# Set forward drive
	match sensor_mask:
		0b0000, 0b0001, 0b1000: _forward = 1.0
		0b0111, 0b1011, 0b1101, 0b1110, 0b1111: _forward = -1.0
		_: _forward = 0.0

	# Set turning angle
	match sensor_mask:
		0b0000:
			var rel_pos := target as Vector3 - translation
			var proj_pos := Plane(transform.basis.y, 0.0).project(rel_pos)
			var direction := proj_pos.normalized()
			var error := 1.0 - transform.basis.z.dot(direction)
			_turn = transform.basis.z.cross(direction)
			if error > 1.0:
				_turn = _turn.normalized()
		0b1001: _turn = Vector3.ZERO
		0b0011, 0b0101, 0b0111, 0b1011, 0b0010: _turn = -transform.basis.y
		0b0100, 0b1010, 0b1100, 0b1101, 0b1110: _turn = transform.basis.y
		0b0110, 0b1111: _turn = transform.basis.y
		0b0001:
			if _ll_sensor.to_local(_ll_sensor.get_collision_point()).length_squared() < 0.25:
				_turn = -transform.basis.y / 4.0
			else:
				_turn = Vector3.ZERO
		0b1000:
			if _rr_sensor.to_local(_rr_sensor.get_collision_point()).length_squared() < 0.25:
				_turn = transform.basis.y / 4.0
			else:
				_turn = Vector3.ZERO


func _task_completed() -> void:
	emit_signal("task_completed")
	task = Task.NONE
	from_target = null
	to_target = null
	task_matter_id = -1
	_task_step = 0


func _take_matter(unit: Unit) -> bool:
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
