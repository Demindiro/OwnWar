extends Spatial


export var material: Material

var color: Color
var life_start := 0.0


func _ready() -> void:
	material.set_shader_param("albedo_color", color)
	material.set_shader_param("start_time", OS.get_ticks_msec() / 1000.0)
	life_start = OS.get_ticks_msec()
