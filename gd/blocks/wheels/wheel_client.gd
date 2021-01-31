extends Spatial


export var dc_motor_audio_path := NodePath()
export var rim_path := NodePath()
export(float, 0.0, 2.0) var pitch_scale := 1.0
export var dc_motor_audio_max_db := -10.0

var server_node: OwnWar_Wheel 
var color: Color

onready var dc_motor_audio: AudioStreamPlayer3D = get_node(dc_motor_audio_path)
onready var rim: MeshInstance = get_node(rim_path)


func _ready() -> void:
	rim.material_override = MaterialCache.get_material(color)


func _process(_delta: float) -> void:
	var fraction := abs(server_node.get_rpm() / server_node.max_rpm)
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
