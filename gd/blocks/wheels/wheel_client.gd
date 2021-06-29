extends Spatial


export var dc_motor_audio_path := NodePath()
export var rim_path := NodePath()
export(float, 0.0, 2.0) var pitch_scale := 1.0
export var dc_motor_audio_max_db := -10.0
export var invert_hinge := false

var server_node: OwnWar_Wheel
var color: Color
var team_color: Color

onready var dc_motor_audio: AudioStreamPlayer3D = get_node(dc_motor_audio_path)
onready var rim: Spatial = get_node(rim_path)
onready var wheel: Spatial = get_node("Wheel")


var prev_trf := Transform()
var curr_trf := Transform()
var prev_steer := 0.0
var curr_steer := 0.0
var trf_dirty := false


func _ready() -> void:
	rim.set_color(color)
	rim.set_team_color(team_color)
	$Bar.set_color(color)
	$Bar.set_team_color(team_color)
	$"Rim hinge".color = color
	wheel.set_as_toplevel(true)


func _physics_process(_delta: float) -> void:
	trf_dirty = true


func _process(_delta: float) -> void:
	if trf_dirty:
		prev_trf = curr_trf
		curr_trf = server_node.wheel.global_transform
		# TODO figure out why in the name of God the scale of VehicelWheel is negative
		#curr_trf.basis = curr_trf.basis.scaled(-Vector3.ONE)
		prev_steer = curr_steer
		curr_steer = server_node.wheel.steering
		trf_dirty = false
	var frac := Engine.get_physics_interpolation_fraction()
	wheel.global_transform = prev_trf.interpolate_with(curr_trf, frac)
	$"Rim hinge".global_transform = Transform(
		global_transform.basis.rotated(
			global_transform.basis.y,
			lerp(prev_steer, curr_steer, frac) + (PI if invert_hinge else 0)
		),
		wheel.global_transform.origin
	)
	var fraction := abs(server_node.wheel.get_rpm() / server_node.max_rpm)
	var pitch := fraction * pitch_scale
	if pitch <= 0.000001:
		dc_motor_audio.stop()
	else:
		if not dc_motor_audio.is_playing():
			dc_motor_audio.play()
		dc_motor_audio.pitch_scale = pitch
		var volume := linear2db(db2linear(dc_motor_audio_max_db) * fraction)
		dc_motor_audio.max_db = min(dc_motor_audio_max_db, volume)


func set_color(p_color: Color) -> void:
	color = p_color
