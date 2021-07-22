extends Spatial

var team_color setget set_team_color

const TRANSPARENT_MESH = []
const SOLID_MESH = []
var transparent = false



func set_color(color):
	$Hull.color = color
	$Mount.color = color


func set_team_color(color):
	$Glow.color = color


func set_transparent(enable):
	if enable != transparent:
		transparent = enable
		if enable:
			if len(TRANSPARENT_MESH) == 0:

				SOLID_MESH.push_back($Hull.mesh)
				SOLID_MESH.push_back($Mount.mesh)
				for sm in SOLID_MESH:
					var tm = sm.duplicate()
					tm.surface_set_material(0, preload("res://effects/team_metal_transparent.tres"))
					TRANSPARENT_MESH.push_back(tm)

				SOLID_MESH.push_back($Glow.mesh)
				var tm = SOLID_MESH[2].duplicate()
				tm.surface_set_material(0, preload("res://effects/team_glow_transparent.tres"))
				TRANSPARENT_MESH.push_back(tm)

				SOLID_MESH.push_back($"Exhaust fixed".mesh)
				tm = SOLID_MESH[3].duplicate()
				tm.surface_set_material(0, preload("fixed_exhaust_transparent_shader.tres"))
				TRANSPARENT_MESH.push_back(tm)

			$Hull.mesh = TRANSPARENT_MESH[0]
			$Mount.mesh = TRANSPARENT_MESH[1]
			$Glow.mesh = TRANSPARENT_MESH[2]
			$"Exhaust fixed".mesh = TRANSPARENT_MESH[3]
		else:
			$Hull.mesh = SOLID_MESH[0]
			$Mount.mesh = SOLID_MESH[1]
			$Glow.mesh = SOLID_MESH[2]
			$"Exhaust fixed".mesh = SOLID_MESH[3]
