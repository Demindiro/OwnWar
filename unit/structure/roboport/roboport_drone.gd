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
onready var _left_sensor := $LeftSensor as RayCast
onready var _right_sensor := $RightSensor as RayCast
onready var _spawn_point := translation


func _physics_process(_delta: float) -> void:
	_turn = Vector3.ZERO
	_forward = 0.0
	match task:
		Task.FILL, Task.EMPTY:
			var target: Unit
			if _task_step == 0 and (material == 0 if task == Task.FILL else material < MAX_MATERIAL):
				target = task_data[0]
				var proj_pos = Plane(transform.basis.y, 0).project(target.translation - translation)
				if proj_pos.length_squared() < 9:
					material += target.take_material(MAX_MATERIAL - material)
					target = task_data[1]
					_task_step = 1
			else:
				target = task_data[1]
				var proj_pos = Plane(transform.basis.y, 0).project(target.translation - translation)
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
	if $RayCast.is_colliding():
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
			debug.draw_line(translation, task_data[0].translation, Color.greenyellow)
			debug.draw_line(translation, task_data[1].translation, Color.cyan)
		Task.NONE:
			debug.draw_line(translation + Vector3(0.5, 0, 0.5),
					translation + Vector3(-0.5, 0, -0.5), Color.red)
			debug.draw_line(translation + Vector3(0.5, 0, -0.5),
					translation + Vector3(-0.5, 0, 0.5), Color.red)
		_:
			assert(false)


func _move_towards(target) -> void:
	
	if target is Spatial:
		target = target.translation
	
	$".".sleeping = false
	var sensor_mask = 0
	if _right_sensor.is_colliding():
		sensor_mask |= 0b01
	if _left_sensor.is_colliding():
		sensor_mask |= 0b10
	
	var rel_pos := target as Vector3 - translation
	var proj_pos := Plane(transform.basis.y, 0.0).project(rel_pos)
	var direction := proj_pos.normalized()
	var error := 1.0 - transform.basis.z.dot(direction)
	if sensor_mask == 0b01:
		_turn = transform.basis.y
	elif sensor_mask == 0b10:
		_turn = -transform.basis.y
	elif error > 1.99:
		_turn = transform.basis.y
	else:
		_turn = transform.basis.z.cross(direction)
		if error > 1.0:
			_turn = _turn.normalized()

	if sensor_mask != 0b11:
		if sensor_mask == 0b00:
			_forward = 1.0 if error < 0.5 else 0.0
		elif error > 0.5:
			# Move forward in case of conflict
			var side := transform.basis.x.dot(direction)
			_forward = 1.0 if (side < 0) == (sensor_mask == 0b01) else 0.0
		else:
			_forward = 0.0
	else:
		_forward = -1.0


func _task_completed() -> void:
	emit_signal("task_completed")
	task = Task.NONE
	task_data = null
	_task_step = 0
