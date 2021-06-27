extends Node
class_name OwnWar_VehicleController


puppet var turn_left := false setget set_turn_left
puppet var turn_right := false setget set_turn_right
puppet var pitch_up := false setget set_pitch_up
puppet var pitch_down := false setget set_pitch_down
puppet var move_forward := false setget set_move_forward
puppet var move_back := false setget set_move_back
puppet var fire := false setget set_fire
puppet var aim_at := Vector3()
puppet var flip := false

var bitmask := 0
var _last_seq_id := -1


func _ready() -> void:
	name = "Controller"
	assert(name == "Controller")


func _physics_process(_delta: float) -> void:
	if is_network_master():
		bitmask = 0
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
		if flip:
			bitmask |= 128
		rpc_unreliable_id(-OwnWar_NetInfo.disable_broadcast_id, "_sync",
			Engine.get_physics_frames(), bitmask, aim_at)


func set_turn_left(value):
	turn_left = value
	bitmask &= ~1
	bitmask |= int(value)


func set_turn_right(value):
	turn_right = value
	bitmask &= ~2
	bitmask |= int(value) << 1


func set_pitch_up(value):
	pitch_up = value
	bitmask &= ~4
	bitmask |= int(value) << 2


func set_pitch_down(value):
	pitch_down = value
	bitmask &= ~8
	bitmask |= int(value) << 3


func set_move_forward(value):
	move_forward = value
	bitmask &= ~16
	bitmask |= int(value) << 4


func set_move_back(value):
	move_back = value
	bitmask &= ~32
	bitmask |= int(value) << 5


func set_fire(value):
	fire = value
	bitmask &= ~64
	bitmask |= int(value) << 6


func set_flip(value):
	flip = value
	bitmask &= ~128
	bitmask |= int(value) << 7


func clear() -> void:
	bitmask = 0
	turn_left = false
	turn_right = false
	pitch_up = false
	pitch_down = false
	move_forward = false
	move_back = false
	fire = false
	flip = false


puppet func _sync(seq_id: int, bm: int, p_aim_at: Vector3) -> void:
	if _last_seq_id < seq_id:
		set_inputs(bm, p_aim_at)
		_last_seq_id = seq_id


func set_inputs(bm: int, p_aim_at: Vector3) -> void:
	bitmask = bm
	turn_left = bitmask & 1
	turn_right = bitmask & 2
	pitch_up = bitmask & 4
	pitch_down = bitmask & 8
	move_forward = bitmask & 16
	move_back = bitmask & 32
	fire = bitmask & 64
	flip = bitmask & 128
	aim_at = p_aim_at
