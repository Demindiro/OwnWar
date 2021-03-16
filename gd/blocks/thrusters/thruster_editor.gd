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
