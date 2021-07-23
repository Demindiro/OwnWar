extends Spatial
class_name OwnWar_Thruster_Server


const MAX_SPEED := 100.0 # 360 km/h
const MAX_FORCE := 500.0

var direction := 0
var last_drive := 0.0

var movement_index = 0
var base_position
var body_center_of_mass


func _ready() -> void:
	var b := transform.basis.z
	var delta_pos = base_position - body_center_of_mass
	if abs(b.dot(Vector3.BACK)) > 0.01:
		direction = 0 if b.dot(Vector3.BACK) > 0 else 1
	elif abs(b.dot(Vector3.LEFT)) > 0.01:
		if (b.dot(Vector3.LEFT) > 0) == (delta_pos.z < 0):
			direction = 2
		else:
			direction = 3
	elif abs(b.dot(Vector3.UP)) > 0.01:
		direction = 4 if b.dot(Vector3.UP) > 0 else 5
	else:
		assert(false, "Can't determine direction")
	process_priority -= 1
	

func drive(forward: float, yaw: float, pitch: float, roll: float) -> void:
	var body = get_parent()
	var factor = 1.0 - clamp(body.linear_velocity.dot(global_transform.basis.z) / MAX_SPEED, 0.0, 1.0)
	var com = PhysicsServer.body_get_local_com(body.get_rid())
	var pos = base_position * 0.25 # BLOCK_SCALE
	match direction:
		0:
			last_drive = max(forward, 0.0)
		1:
			last_drive = max(-forward, 0.0)
		2:
			last_drive = max(yaw, 0.0)
		3:
			last_drive = max(-yaw, 0.0)
		4:
			last_drive = max(pitch, 0.0)
		5:
			last_drive = max(-pitch, 0.0)
		_:
			assert(false, "Invalid direction!")
	PhysicsServer.body_add_local_force(
		body.get_rid(),
		transform.basis.z * last_drive * MAX_FORCE * factor,
		pos
	)
