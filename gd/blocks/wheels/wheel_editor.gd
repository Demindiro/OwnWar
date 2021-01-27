extends Spatial


export var rim_l := NodePath()
export var rim_r := NodePath()
export var tire := NodePath()
export var arrow := NodePath()

var color: Color

# warning-ignore:unsafe_property_access
onready var tire_material: SpatialMaterial = get_node(tire).mesh.surface_get_material(0)


func set_color(p_color: Color) -> void:
	p_color.a = color.a
	color = p_color
	var mat := MaterialCache.get_material(p_color)
	# warning-ignore:unsafe_property_access
	get_node(rim_l).material_override = mat
	# warning-ignore:unsafe_property_access
	get_node(rim_r).material_override = mat


func set_transparency(alpha: float) -> void:
	color.a = alpha
	if true:
		var clr := color
		var mat := MaterialCache.get_material(clr)
		# warning-ignore:unsafe_property_access
		get_node(rim_l).material_override = mat
		# warning-ignore:unsafe_property_access
		get_node(rim_r).material_override = mat
	if true:
		var clr := Color.white
		clr.a = alpha
		var mat := MaterialCache.get_material(clr, tire_material)
		# warning-ignore:unsafe_property_access
		get_node(tire).material_override = mat


func map_rotation(_rotation: int) -> int:
	return 0


func set_preview_mode(enable: bool) -> void:
	# warning-ignore:unsafe_property_access
	get_node(arrow).visible = not enable
