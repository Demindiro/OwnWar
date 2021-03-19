extends MeshInstance


func set_team_color(color):
	$Glow.material_override = $Glow.material_override.duplicate()
	$Glow.material_override.albedo_color = color
	$Glow.material_override.emission = color * 5.0
