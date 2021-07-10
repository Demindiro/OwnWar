extends Spatial


export var tire := NodePath()
export var arrow := NodePath()

var color: Color
var team_color = OwnWar.ALLY_COLOR

# warning-ignore:unsafe_property_access
onready var tire_material: SpatialMaterial = get_node(tire).mesh.surface_get_material(0)


func _ready() -> void:
	$Rim.set_color(color)
	$Rim.set_team_color(team_color)
	$Bar.set_color(color)
	$Bar.set_team_color(team_color)
	$Bar.set_process(false)


func set_color(p_color: Color) -> void:
	p_color.a = color.a
	color = p_color
	$Bar.set_color(p_color)
	$Rim.set_color(p_color)
	$"Rim hinge".color = p_color


func set_transparency(alpha: float) -> void:
	color.a = alpha
	$Rim.set_transparency(alpha)
	$Bar.set_transparency(alpha)


func map_rotation(_rotation: int) -> int:
	return 0


func set_preview_mode(enable: bool) -> void:
	# warning-ignore:unsafe_property_access
	get_node(arrow).visible = not enable
