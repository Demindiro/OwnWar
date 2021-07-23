extends Spatial

var team_color setget set_team_color

const TRANSPARENT_MESH = []
const SOLID_MESH = []
var transparent = false



func set_color(color):
	$Hull.color = color


func set_team_color(color):
	$Glow.color = color


func set_transparent(enable):
	if enable != transparent:
		transparent = enable
		if enable:
			if len(TRANSPARENT_MESH) == 0:

				SOLID_MESH.push_back($Hull.mesh)
				var tm = SOLID_MESH[0].duplicate()
				tm.surface_set_material(0, preload("res://effects/team_metal_transparent.tres"))
				TRANSPARENT_MESH.push_back(tm)

				SOLID_MESH.push_back($Glow.mesh)
				tm = SOLID_MESH[1].duplicate()
				tm.surface_set_material(0, preload("res://effects/team_glow_transparent.tres"))
				TRANSPARENT_MESH.push_back(tm)

			$Hull.mesh = TRANSPARENT_MESH[0]
			$Glow.mesh = TRANSPARENT_MESH[1]
		else:
			$Hull.mesh = SOLID_MESH[0]
			$Glow.mesh = SOLID_MESH[1]
