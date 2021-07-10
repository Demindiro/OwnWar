extends Spatial


export var tire := NodePath()
export var arrow := NodePath()

var color := Color.white
var team_color = OwnWar.ALLY_COLOR

# warning-ignore:unsafe_property_access
onready var tire_material: SpatialMaterial = get_node(tire).mesh.surface_get_material(0)

export var solid_material: Material = preload("res://effects/team_metal.tres")
export var transparent_material: Material = preload("res://effects/team_metal_transparent.tres")

const MESH_CACHE = {}
var transparent = false


func _ready() -> void:
	$Rim.set_color(color)
	$Rim.set_team_color(team_color)
	$Bar.set_color(color)
	$Bar.set_team_color(team_color)
	$Bar.set_process(false)
	

func set_color(p_color: Color) -> void:
	color = p_color
	$Bar.set_color(p_color)
	$Rim.set_color(p_color)
	$"Rim hinge".color = p_color


func set_transparent(enable: bool) -> void:
	if enable == transparent:
		return
	transparent = enable
	var c = $Tire
	var mesh = MESH_CACHE.get(c.mesh)
	if mesh == null:
		mesh = c.mesh.duplicate()
		var mat = tire_material.duplicate()
		mat.albedo_color.a = 0.25
		mat.flags_transparent = true
		mat.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
		mesh.surface_set_material(0, mat)
		MESH_CACHE[c.mesh] = mesh
		MESH_CACHE[mesh] = c.mesh
	c.mesh = mesh

	$Rim.set_transparent(enable)
	$Bar.set_transparent(enable)

	c = $"Rim hinge"
	mesh = MESH_CACHE.get(c.mesh)
	if mesh == null:
		mesh = c.mesh.duplicate()
		mesh.surface_set_material(0, transparent_material)
		MESH_CACHE[c.mesh] = mesh
		MESH_CACHE[mesh] = c.mesh
	c.mesh = mesh


func map_rotation(_rotation: int) -> int:
	return 0


func set_preview_mode(enable: bool) -> void:
	# warning-ignore:unsafe_property_access
	get_node(arrow).visible = not enable
