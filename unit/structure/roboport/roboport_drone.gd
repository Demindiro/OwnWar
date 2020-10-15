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


func _physics_process(_delta: float) -> void:
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
	var rel_pos := target.translation - translation
	var proj_pos := Plane(transform.basis.y, 0.0).project(rel_pos)
	var direction := proj_pos.normalized()
	var error := 1.0 - transform.basis.z.dot(proj_pos)
	var turn: Vector3
	if error > 1.9:
		turn = transform.basis.y
	else:
		turn = transform.basis.z.cross(direction)
		if error > 1.0:
			turn = turn.normalized()
	var force: float
	if not $FrontSensor.is_colliding():
		force = clamp(proj_pos.length_squared(), 0.0, 1.0)
	else:
		force = 0.0
	if $RayCast.is_colliding():
		$".".add_torque(turn * 1.3)
		$".".add_central_force(transform.basis.z * force * 55.0)


func _task_completed() -> void:
	emit_signal("task_completed")
	task = Task.NONE
	task_data = null
