extends Spatial


onready var _mesh: MeshInstance = get_node("Mesh")


func set_color(color: Color) -> void:
	_mesh.material_override.albedo_color = color
