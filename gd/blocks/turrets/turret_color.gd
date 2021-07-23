extends Spatial


const TRANSPARENT_MESH = {}
const SOLID_MESH = {}

var team_color setget set_team_color
var transparent = false

export var size := 1


func set_color(color):
	# This is stupid as hell but idk wtf is going on
	for c in get_children():
		if c.name in ["Mount", "Top"]:
			c.color = color


func set_team_color(color):
	# Ditto
	for c in get_children():
		if c.name in ["Glow"]:
			c.color = color
	team_color = color


func set_transparent(enable):
	if enable != transparent:
		transparent = enable

		var solid = SOLID_MESH.get(size)
		var transparent = TRANSPARENT_MESH.get(size)

		if enable:
			if transparent == null:
				solid = []
				transparent = []

				solid.push_back($Mount.mesh)
				solid.push_back($Top.mesh)

				for mesh in solid:
					mesh = mesh.duplicate()
					mesh.surface_set_material(0, preload("res://effects/team_metal_transparent.tres"))
					transparent.push_back(mesh)

				solid.push_back($Glow.mesh)
				var mesh = solid[2].duplicate()
				mesh.surface_set_material(0, preload("res://effects/team_glow_transparent.tres"))
				transparent.push_back(mesh)

				SOLID_MESH[size] = solid
				TRANSPARENT_MESH[size] = transparent

			$Mount.mesh = transparent[0]
			$Top.mesh = transparent[1]
			$Glow.mesh = transparent[2]

		else:

			$Mount.mesh = solid[0]
			$Top.mesh = solid[1]
			$Glow.mesh = solid[2]
