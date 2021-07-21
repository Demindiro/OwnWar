extends Spatial


var team_color setget set_team_color

const TRANSPARENT_MESH = []
const SOLID_MESH = []
var transparent = false


func set_color(color):
	$Moving/Rudder.color = color
	$Fixed/Rudder.color = color

func set_team_color(color):
	team_color = color
	$Moving/Glow.color = color

func set_transparent(enable):
	if enable != transparent:
		transparent = enable
		if enable:
			if len(TRANSPARENT_MESH) == 0:
				SOLID_MESH.push_back($Moving/Rudder.mesh)
				SOLID_MESH.push_back($Moving/Mount.mesh)
				SOLID_MESH.push_back($Fixed/Rudder.mesh)
				SOLID_MESH.push_back($Fixed/Mount.mesh)
				for sm in SOLID_MESH:
					var tm = sm.duplicate()
					var mat = tm.surface_get_material(0).duplicate()
					mat.flags_transparent = true
					mat.params_blend_mode = SpatialMaterial.BLEND_MODE_ADD
					mat.albedo_color.a = 0.25
					tm.surface_set_material(0, mat)
					TRANSPARENT_MESH.push_back(tm)
				# The glow material uses a custom shader.
				SOLID_MESH.push_back($Moving/Glow.mesh)
				if true:
					var sm = SOLID_MESH[4]
					var tm = sm.duplicate()
					tm.surface_set_material(0, preload("res://effects/team_glow_transparent.tres"))
					TRANSPARENT_MESH.push_back(tm)
			$Moving/Rudder.mesh = TRANSPARENT_MESH[0]
			$Moving/Mount.mesh = TRANSPARENT_MESH[1]
			$Fixed/Rudder.mesh = TRANSPARENT_MESH[2]
			$Fixed/Mount.mesh = TRANSPARENT_MESH[3]
			$Moving/Glow.mesh = TRANSPARENT_MESH[4]
		else:
			$Moving/Rudder.mesh = SOLID_MESH[0]
			$Moving/Mount.mesh = SOLID_MESH[1]
			$Fixed/Rudder.mesh = SOLID_MESH[2]
			$Fixed/Mount.mesh = SOLID_MESH[3]
			$Moving/Glow.mesh = SOLID_MESH[4]
