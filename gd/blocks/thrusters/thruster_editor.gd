tool
extends OwnWar_SetColor
class_name OwnWar_Thruster_Editor


func set_color(color: Color) -> void:
	var mi: MeshInstance = get_node("Thruster")
	mi.mesh = mi.mesh.duplicate()
	mi.mesh.surface_set_material(1, MaterialCache.get_material(color))
