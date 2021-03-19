extends Spatial


export var tire := NodePath()
export(Array, NodePath) var color_nodes := []
export var arrow := NodePath()

var color: Color

# warning-ignore:unsafe_property_access
onready var tire_material: SpatialMaterial = get_node(tire).mesh.surface_get_material(0)


func _ready() -> void:
	$Bar.set_color(color)
	$Bar.set_process(false)


func set_color(p_color: Color) -> void:
	p_color.a = color.a
	color = p_color
	var mat := MaterialCache.get_material(p_color)
	for n in color_nodes:
		# warning-ignore:unsafe_property_access
		get_node(n).material_override = mat
	$Bar.set_color(p_color)


func set_transparency(alpha: float) -> void:
	color.a = alpha
	var mat := MaterialCache.get_material(color)
	# warning-ignore:unsafe_property_access
	for n in color_nodes:
		get_node(n).material_override = mat
	$Bar.set_transparency(alpha)
	var n = get_node(tire)
	var clr = n.material_override.albedo_color
	clr.a = alpha
	n.material_override = n.material_override.duplicate()
	n.material_override.flags_transparent = alpha < 0.99
	n.material_override.albedo_color = clr


func map_rotation(_rotation: int) -> int:
	return 0


func set_preview_mode(enable: bool) -> void:
	# warning-ignore:unsafe_property_access
	get_node(arrow).visible = not enable
