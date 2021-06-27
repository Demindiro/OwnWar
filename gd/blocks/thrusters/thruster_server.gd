extends Spatial
class_name OwnWar_Thruster_Server


const MAX_SPEED := 40.0
const MAX_FORCE := 500.0
var body: OwnWar_VoxelBody = null
var direction := -1
var last_drive := 0.0

var curr_pos := Vector3()
var prev_pos := Vector3()
var prev_delta := 1.0


func init(_coordinate: Vector3, voxel_body: OwnWar_VoxelBody, vehicle: OwnWar_Vehicle) -> void:
	body = voxel_body
	var b := transform.basis.z
	if abs(b.dot(Vector3.BACK)) > 0.01:
		direction = 0 if b.dot(Vector3.BACK) > 0 else 1
	elif abs(b.dot(Vector3.LEFT)) > 0.01:
		if (b.dot(Vector3.LEFT) > 0) == (transform.origin.z < 0):
			direction = 2
		else:
			direction = 3
	elif abs(b.dot(Vector3.UP)) > 0.01:
		direction = 4 if b.dot(Vector3.UP) > 0 else 5
	else:
		assert(false, "Can't determine direction")


func _ready() -> void:
	prev_pos = global_transform.origin
	process_priority -= 1
	

func _physics_process(delta: float) -> void:
	prev_pos = curr_pos
	curr_pos = global_transform.origin
	prev_delta = delta


func apply_drive(drive_forward: float, drive_yaw: float, drive_pitch: float) -> void:
	if body != null:
		var factor := 1.0 - clamp(prev_pos.distance_to(curr_pos) / prev_delta / MAX_SPEED, 0.0, 1.0)
		match direction:
			0:
				last_drive = max(drive_forward, 0.0)
			1:
				last_drive = max(-drive_forward, 0.0)
			2:
				last_drive = max(drive_yaw, 0.0)
			3:
				last_drive = max(-drive_yaw, 0.0)
			4:
				last_drive = max(drive_pitch, 0.0)
			5:
				last_drive = max(-drive_pitch, 0.0)
			_:
				assert(false, "Invalid direction!")
		body.add_force(
			global_transform.basis.z * last_drive * MAX_FORCE * factor,
			global_transform.origin - body.global_transform.origin
		)
