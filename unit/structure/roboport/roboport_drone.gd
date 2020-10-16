extends Unit


signal task_completed()
const MAX_MATERIAL := 30
enum Task {
	NONE,
	FILL,
	EMPTY,
	DESPAWN,
}
var task: int
var task_data
var material: int
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
			var target: Unit
			if _task_step == 0 and (material == 0 if task == Task.FILL else material < MAX_MATERIAL):
				target = task_data[0]
				var proj_pos = Plane(transform.basis.y, 0).project(target.get_interaction_port() - translation)
				if proj_pos.length_squared() < 9:
					material += target.take_material(MAX_MATERIAL - material)
					target = task_data[1]
					_task_step = 1
			else:
				target = task_data[1]
				var proj_pos = Plane(transform.basis.y, 0).project(target.get_interaction_port() - translation)
				if proj_pos.length_squared() < 9:
					material = target.put_material(material)
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
	info["Material"] = "%d / %d" % [material, MAX_MATERIAL]
	match task:
		Task.NONE:
			info["Task"] = "None"
		Task.FILL, Task.EMPTY:
			info["Task"] = "Transport"
			if material == 0 if task == Task.FILL else material < MAX_MATERIAL:
				info["Empty"] = "Material"
			else:
				info["Fill"] = "Material"
		_:
			info["Task"] = "???"
	return info


func draw_debug(debug):
	match task:
		Task.FILL, Task.EMPTY:
			debug.draw_line(translation, task_data[0].get_interaction_port(), Color.greenyellow)
			debug.draw_line(translation, task_data[1].get_interaction_port(), Color.cyan)
		Task.NONE:
			debug.draw_line(translation + Vector3(0.5, 0, 0.5),
					translation + Vector3(-0.5, 0, -0.5), Color.red)
			debug.draw_line(translation + Vector3(0.5, 0, -0.5),
					translation + Vector3(-0.5, 0, 0.5), Color.red)
		_:
			assert(false)


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
	task_data = null
	_task_step = 0
