tool
extends OwnWar_SetColor
class_name OwnWar_Thruster_Client


onready var mesh: MeshInstance = get_node("Exhaust/Mesh")

var server_node: OwnWar_Thruster_Server

var visual_drive := 0.0


func _ready() -> void:
	mesh.material_override = mesh.material_override.duplicate()
	set_process(not Engine.editor_hint)


func _process(delta: float) -> void:
	var last_drive := server_node.last_drive
	if visual_drive < last_drive:
		visual_drive += delta
		if visual_drive > last_drive:
			visual_drive = last_drive
	elif visual_drive > last_drive:
		visual_drive -= delta
		if visual_drive < last_drive:
			visual_drive = last_drive
	mesh.material_override.set_shader_param("strength", visual_drive)


func set_color(color: Color) -> void:
	var mi: MeshInstance = get_node("Thruster")
	mi.mesh = mi.mesh.duplicate()
	mi.mesh.surface_set_material(1, MaterialCache.get_material(color))
