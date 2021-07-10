extends Spatial


export var solid_material: Material = preload("res://effects/team_metal.tres")
export var solid_team_glow: Material = preload("res://effects/team_glow.tres")
export var transparent_material: Material = preload("res://effects/team_metal_transparent.tres")
export var transparent_team_glow: Material = preload("res://effects/team_glow_transparent.tres")

const MESH_CACHE = {}
var transparent = false


func set_color(color):
	$Rim.color = color


func set_team_color(color):
	$Glow.color = color


func set_transparent(enable):
	if transparent == enable:
		return
	transparent = enable

	var c = $Rim
	var mesh = MESH_CACHE.get(c.mesh)
	if mesh == null:
		mesh = c.mesh.duplicate()
		mesh.surface_set_material(0, transparent_material)
		MESH_CACHE[c.mesh] = mesh
		MESH_CACHE[mesh] = c.mesh
	c.mesh = mesh

	c = $Glow
	mesh = MESH_CACHE.get(c.mesh)
	if mesh == null:
		mesh = c.mesh.duplicate()
		mesh.surface_set_material(0, transparent_team_glow)
		MESH_CACHE[c.mesh] = mesh
		MESH_CACHE[mesh] = c.mesh
	c.mesh = mesh
