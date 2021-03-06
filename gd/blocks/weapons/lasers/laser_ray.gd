extends Spatial


export var audio_sample_length := 3.0

var color: Color

onready var mesh: MeshInstance = get_node("Mesh")


func _ready() -> void:
	mesh.material_override.set_shader_param("albedo_color", color)
	mesh.material_override.set_shader_param("start_time", OS.get_ticks_msec() / 1000.0)
	get_node("Timer").start(audio_sample_length)
