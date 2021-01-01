extends Node


# warning-ignore:unused_class_variable
export var max_power := 16000
export var pitch_min := 0.4
export var pitch_max := 1.8
onready var _audio: AudioStreamPlayer3D = $Audio


func _ready():
	_audio.playing = true
	_audio.stream_paused = true


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle, _meta):
	var manager = vehicle.get_manager("power")
	manager.add_engine(self)


func power_use_feedback(fraction: float) -> void:
	if fraction < 0.0:
		_audio.stream_paused = true
	else:
		_audio.stream_paused = false
		_audio.pitch_scale = pitch_min + (pitch_max + pitch_min) * fraction
