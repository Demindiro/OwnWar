extends MeshInstance


var fade := 0.0
var radius := 3.0 setget set_radius


func _ready() -> void:
	# TODO figure out how to make 
	material_override = material_override.duplicate()
	scale = Vector3(radius, radius, radius)


# I'd use an animation player IF IT LET ME INSERT A DAMN KEY
func _process(delta: float) -> void:
	fade += delta
	if fade >= 1.0:
		queue_free()
	else:
		material_override.set_shader_param("fade", fade)


func set_radius(value: float) -> void:
	radius = value
	scale = Vector3(value, value, value)
