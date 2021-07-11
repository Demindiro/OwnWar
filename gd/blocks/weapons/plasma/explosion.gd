extends MeshInstance


var fade := 0.0
var radius := 3.0 setget set_radius
var layer := 1
var color := Color.purple


func _ready() -> void:
	scale = Vector3(radius, radius, radius)
	material_override.set_shader_param("time_offset", randf() * 64)
	material_override.set_shader_param("color", color)


# I'd use an animation player IF IT LET ME INSERT A DAMN KEY
func _process(delta: float) -> void:
	fade += delta
	if fade >= 1.0:
		visible = false
	if fade >= 2.0:
		queue_free()
	else:
		material_override.set_shader_param("fade", fade)


func set_radius(value: float) -> void:
	radius = value
	scale = Vector3(value, value, value)
