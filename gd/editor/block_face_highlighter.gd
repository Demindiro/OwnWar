extends Spatial


onready var mesh: MeshInstance = get_node("Mesh")


func set_valid(valid: bool) -> void:
	mesh.material_override.albedo_color = Color.green if valid else Color.red


func set_normal(normal: Vector3) -> void:
	var x := Vector3(normal.y, normal.z, normal.x)
	var y := Vector3(normal.z, normal.x, normal.y)
	transform.basis = Basis(x, y, normal)
