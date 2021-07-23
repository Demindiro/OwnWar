tool
extends Spatial


onready var mesh: MeshInstance = get_node("Exhaust/Mesh")

var server_node: OwnWar_Thruster_Server

var visual_drive := 0.0

var team_color setget set_team_color


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
	$Hull.color = color
	$Mount.color = color


func set_team_color(p_color):
	$Glow.color = p_color
