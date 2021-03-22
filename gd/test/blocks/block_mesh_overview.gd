extends Node

var manager := OwnWar_BlockManager.new()
var rotation := 0

func _ready() -> void:
	for c in $Blocks.get_children():
		c.queue_free()
	var ig := ImmediateGeometry.new()
	ig.material_override = SpatialMaterial.new()
	ig.material_override.flags_unshaded = true
	ig.material_override.albedo_color = Color.red
	$Blocks.add_child(ig)
	var blocks: Array = manager.get_all_blocks()
	var count := 0
	ig.begin(Mesh.PRIMITIVE_LINES)
	var dirs := PoolVector3Array([
		Vector3(0, 1, 0),
		Vector3(0, -1, 0),
		Vector3(1, 0, 0),
		Vector3(-1, 0, 0),
		Vector3(0, 0, 1),
		Vector3(0, 0, -1),
	])
	for b in blocks:
		if b.mesh != null:
			var mi := MeshInstance.new()
			mi.mesh = b.mesh
			mi.translation = Vector3(count % 16, count / 16, 0)
			mi.transform.basis = manager.rotation_to_basis(rotation)
			$Blocks.add_child(mi)
			var solid_faces: int = b.get_solid_faces(rotation)
			for i in 6:
				if solid_faces & (1 << i):
					ig.add_vertex(mi.translation)
					ig.add_vertex(mi.translation - dirs[i] / 2)
		count += 1
	ig.end()

	
func set_rotation(val) -> void:
	rotation = int(val)
	_ready()
