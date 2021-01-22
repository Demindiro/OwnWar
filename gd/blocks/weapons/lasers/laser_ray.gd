extends Spatial


export var material: Material
export var audio_sample_length := 3.0

var color: Color


func _ready() -> void:
	material.set_shader_param("albedo_color", color)
	material.set_shader_param("start_time", OS.get_ticks_msec() / 1000.0)
	get_node("Timer").start(audio_sample_length)
