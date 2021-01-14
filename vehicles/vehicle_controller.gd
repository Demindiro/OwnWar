extends Node
class_name OwnWar_VehicleController


puppet var turn_left := false
puppet var turn_right := false
puppet var pitch_up := false
puppet var pitch_down := false
puppet var move_forward := false
puppet var move_back := false
puppet var fire := false
puppet var aim_at := Vector3()

var _last_seq_id := -1


func _ready() -> void:
	name = "Controller"
	assert(name == "Controller")


func _physics_process(_delta: float) -> void:
	if is_network_master():
		var bitmask := 0
		if turn_left:
			bitmask |= 1
		if turn_right:
			bitmask |= 2
		if pitch_up:
			bitmask |= 4
		if pitch_down:
			bitmask |= 8
		if move_forward:
			bitmask |= 16
		if move_back:
			bitmask |= 32
		if fire:
			bitmask |= 64
		rpc_unreliable_id(-OwnWar_NetInfo.disable_broadcast_id, "_sync",
			Engine.get_physics_frames(), bitmask, aim_at)


puppet func _sync(seq_id: int, bitmask: int, p_aim_at: Vector3) -> void:
	if _last_seq_id < seq_id:
		turn_left = bitmask & 1
		turn_right = bitmask & 2
		pitch_up = bitmask & 4
		pitch_down = bitmask & 8
		move_forward = bitmask & 16
		move_back = bitmask & 32
		fire = bitmask & 64
		aim_at = p_aim_at
		_last_seq_id = seq_id
