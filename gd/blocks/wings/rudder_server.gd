extends Spatial


export var lift_factor := 1.0
export var speed_factor := 1.0
export var drive_angle := 0.1

var last_drive := 0.0

var pitch_factor = 0.0
var roll_factor = 0.0

var movement_index = 0
var base_position
var body_center_of_mass


func _ready() -> void:
	var b = transform.basis
	var delta_pos = base_position - body_center_of_mass
	if abs(b.z.dot(Vector3.BACK)) > 0.01:
		#pitch_factor = 1.0 * sign(round(f.dot(Vector3.FORWARD))) * sign(round(b.y.dot(Vector3.DOWN))) * sign(round(b.x.dot(Vector3.LEFT)))
		#pitch_factor = 1.0 * sign(round(f.dot(Vector3.FORWARD))) * sign(round(b.y.dot(Vector3.DOWN))) * sign(round(b.x.dot(Vector3.LEFT)))
		pitch_factor = 1.0
		pitch_factor *= sign(round(b.x.dot(Vector3.LEFT))) # Correct for forward orientation
		pitch_factor *= sign(delta_pos.z) # Correct for position relative to CoM (back/forward)
		roll_factor = 1.0
		roll_factor *= sign(round(b.x.dot(Vector3.RIGHT))) # Correct for forward orientation
		roll_factor *= sign(delta_pos.x) # Correct for position relative to CoM (left/right)
	process_priority -= 1
	

func drive(forward: float, yaw: float, pitch: float, roll: float) -> void:
	var body = get_parent()
	var com = PhysicsServer.body_get_local_com(body.get_rid())
	var world_com = body.global_transform * com
	var pos = base_position * 0.25 # BLOCK_SCALE

	roll = yaw
	pitch = pitch * pitch_factor
	roll = roll * roll_factor
	last_drive = clamp(pitch + roll, -1.0, 1.0)

	var trf = global_transform
	# Apply drive
	var basis = trf.basis * Basis(Vector3(1, 0, 0), last_drive * drive_angle)
	_aoa = basis.y

	# The linear velocity at the wing
	var vel = body.linear_velocity + body.angular_velocity.cross(trf.origin - world_com)
	# The perpendicular velocity
	var perp_vel = basis.y.dot(vel)
	# The forward velocity
	var fwd_vel = basis.z.dot(vel)
	_vel = vel * 0.1
	_perp_vel = perp_vel * basis.y * 0.1
	_fwd_vel = fwd_vel * basis.z * 0.1

	var lift = lift_factor * -(perp_vel * abs(perp_vel) * (1.0 + fwd_vel * fwd_vel * speed_factor))

	PhysicsServer.body_add_local_force(
		body.get_rid(),
		transform.basis.y * lift,
		pos
	)

var _vel = Vector3()
var _perp_vel = Vector3()
var _fwd_vel = Vector3()
var _aoa = Vector3()
func debug_draw():
	Debug.draw_line(global_transform.origin, global_transform.origin + _vel, Color.red)
	Debug.draw_line(global_transform.origin, global_transform.origin + _perp_vel, Color.cyan)
	Debug.draw_line(global_transform.origin, global_transform.origin + _fwd_vel, Color.yellow)
	Debug.draw_line(global_transform.origin, global_transform.origin + _aoa, Color.orange)
