extends Spatial


export var anchor := NodePath()
export var mount := NodePath()

export(Array, NodePath) var metal_mesh_nodes = []
export(Array, NodePath) var team_glow_mesh_nodes = []

export var solid_material: Material = preload("res://effects/team_metal.tres")
export var solid_team_glow: Material = preload("res://effects/team_glow.tres")
export var transparent_material: Material = preload("res://effects/team_metal_transparent.tres")
export var transparent_team_glow: Material = preload("res://effects/team_glow_transparent.tres")

onready var anchor_node: Spatial = get_node_or_null(anchor)
onready var mount_node: Spatial = get_node(mount)

var color = Color.white
var team_color = OwnWar.ALLY_COLOR

const MESH_CACHE = {}
var transparent = false


func _ready():
	set_color(color)
	set_team_color(team_color)


func _process(_delta: float) -> void:
	mount_node.global_transform.origin = anchor_node.global_transform.origin
	mount_node.translation.z = 0


func set_color(p_color: Color) -> void:
	color = p_color
	for c in metal_mesh_nodes:
		get_node(c).color = p_color
		get_node(c).use_color = true


func set_transparent(enable: bool) -> void:

	if transparent == enable:
		return

	transparent = enable

	for c in metal_mesh_nodes:
		c = get_node(c)
		var mesh = MESH_CACHE.get(c.mesh)
		if mesh == null:
			mesh = c.mesh.duplicate()
			mesh.surface_set_material(0, transparent_material)
			MESH_CACHE[c.mesh] = mesh
			MESH_CACHE[mesh] = c.mesh
		c.mesh = mesh

	for c in team_glow_mesh_nodes:
		c = get_node(c)
		var mesh = MESH_CACHE.get(c.mesh)
		if mesh == null:
			mesh = c.mesh.duplicate()
			mesh.surface_set_material(0, transparent_team_glow)
			MESH_CACHE[c.mesh] = mesh
			MESH_CACHE[mesh] = c.mesh
		c.mesh = mesh


func set_team_color(color: Color) -> void:
	team_color = color
	for c in team_glow_mesh_nodes:
		get_node(c).color = color
		get_node(c).use_color = true
