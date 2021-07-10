tool
extends OwnWar_SetColor
class_name OwnWar_Thruster_Editor

var color: Color

func set_color(p_color: Color) -> void:
	var mi: MeshInstance = get_node("Thruster")
	mi.mesh = mi.mesh.duplicate()
	p_color.a = color.a
	mi.mesh.surface_set_material(1, MaterialCache.get_material(p_color))
	color = p_color


func set_transparent(enable: bool) -> void:
	color.a = 0.25 if enable else 1.0
	set_color(color)
	var mi: MeshInstance = get_node("Thruster")
	for i in mi.mesh.get_surface_count():
		if i != 1:
			var mat = mi.mesh.surface_get_material(i).duplicate()
			mat.albedo_color.a = color.a
			mat.params_blend_mode = SpatialMaterial.BLEND_MODE_MIX if !enable else SpatialMaterial.BLEND_MODE_ADD
			mi.mesh.surface_set_material(i, mat)

