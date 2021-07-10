extends Spatial


var color: Color


func _ready() -> void:
	$Base.color = color


func set_color(p_color: Color) -> void:
	color = p_color
	var n = get_node_or_null("Base")
	if n != null:
		n.color = color


func set_transparency(alpha):
	color.a = alpha
	var n = get_node_or_null("Base")
	if n != null:
		var mesh = n.mesh.duplicate()
		var mat = mesh.surface_get_material(0)
		mat = MaterialCache.get_material(color, mat)
		mesh.surface_set_material(0, mat)
		n.mesh = mesh
