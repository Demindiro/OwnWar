extends Unit


signal task_completed()
const MAX_MATERIAL := 30
enum Task {
	NONE,
	TRANSPORT,
}
var task: int
var task_data
var material: int
var _turn: Vector3
var _forward: float
onready var _left_sensor := $LeftSensor as RayCast
onready var _right_sensor := $RightSensor as RayCast


func _physics_process(_delta: float) -> void:
	_turn = Vector3.ZERO
	_forward = 0.0
	match task:
		Task.TRANSPORT:
			var target: Unit
			if material == 0:
				target = task_data[0]
				var proj_pos = Plane(transform.basis.y, 0).project(target.translation - translation)
				if proj_pos.length_squared() < 1:
					material += target.take_material(MAX_MATERIAL - material)
					target = task_data[1]
			else:
				target = task_data[1]
				var proj_pos = Plane(transform.basis.y, 0).project(target.translation - translation)
				if proj_pos.length_squared() < 1:
					material = target.put_material(material)
					target = null
					_task_completed()
			if target != null:
				_move_towards(target)


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
		Task.TRANSPORT:
			info["Task"] = "Transport"
			if material == 0:
				info["Taking"] = "Material"
			else:
				info["Putting"] = "Material"
		_:
			info["Task"] = "???"
	return info


func _move_towards(target: Unit) -> void:
	$".".sleeping = false
	var sensor_mask = 0
	if _right_sensor.is_colliding():
		sensor_mask |= 0b01
	if _left_sensor.is_colliding():
		sensor_mask |= 0b10
	
	var rel_pos := target.translation - translation
	var proj_pos := Plane(transform.basis.y, 0.0).project(rel_pos)
	var direction := proj_pos.normalized()
	var error := 1.0 - transform.basis.z.dot(proj_pos)
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
		_forward = clamp(proj_pos.length_squared(), 0.0, 1.0) if error < 0.5 else 0.0
	else:
		_forward = -1.0


func _task_completed() -> void:
	emit_signal("task_completed")
	task = Task.NONE
	task_data = null
