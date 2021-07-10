extends Spatial


export var solid_material: Material = preload("res://effects/team_metal.tres")
export var transparent_material: Material = preload("res://effects/team_metal_transparent.tres")

const TRANSPARENT_METAL_MESH = []
const SOLID_METAL_MESH = []

var color = Color.purple

func _ready() -> void:
	$Base.color = color


func set_color(p_color: Color) -> void:
	color = p_color
	var n = get_node_or_null("Base")
	if n != null:
		n.color = color


func set_transparent(enable):
	var c = $Base
	if len(TRANSPARENT_METAL_MESH) == 0:
		var mesh = c.mesh.duplicate()
		mesh.surface_set_material(0, transparent_material)
		TRANSPARENT_METAL_MESH.push_back(mesh)
		SOLID_METAL_MESH.push_back(mesh)
	c.mesh = TRANSPARENT_METAL_MESH[0] if enable else SOLID_METAL_MESH[0]
