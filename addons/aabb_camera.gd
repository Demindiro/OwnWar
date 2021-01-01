tool
extends FreeCamera
class_name AABBCamera


export var aabb := AABB(Vector3(-INF, -INF, -INF), Vector3(INF, INF, INF))


func _ready():
	if Engine.editor_hint:
		set_process_input(false)
		var ig := ImmediateGeometry.new()
		ig.name = "_imm_geometry"
		var mat := SpatialMaterial.new()
		mat.flags_unshaded = true
		mat.albedo_color = Color.cyan
		ig.material_override = mat
		add_child(ig)
		ig.set_as_toplevel(true)


func _process(_delta: float) -> void:
	translation = Vector3(
		max(aabb.position.x, min(aabb.end.x, translation.x)),
		max(aabb.position.y, min(aabb.end.y, translation.y)),
		max(aabb.position.z, min(aabb.end.z, translation.z))
	)
	if Engine.editor_hint:
		var ig: ImmediateGeometry = $_imm_geometry
		if ig == null:
			_ready()
			return
		var a := aabb.position
		var b := aabb.end
		ig.global_transform = Transform.IDENTITY
		ig.clear()
		ig.begin(Mesh.PRIMITIVE_LINE_STRIP)
		ig.add_vertex(Vector3(a.x, a.y, a.z))
		ig.add_vertex(Vector3(b.x, a.y, a.z))
		ig.add_vertex(Vector3(b.x, b.y, a.z))
		ig.add_vertex(Vector3(a.x, b.y, a.z))
		ig.add_vertex(Vector3(a.x, a.y, a.z))
		ig.add_vertex(Vector3(a.x, a.y, b.z))
		ig.add_vertex(Vector3(a.x, a.y, b.z))
		ig.add_vertex(Vector3(b.x, a.y, b.z))
		ig.add_vertex(Vector3(b.x, b.y, b.z))
		ig.add_vertex(Vector3(a.x, b.y, b.z))
		ig.add_vertex(Vector3(a.x, a.y, b.z))
		ig.end()
		ig.begin(Mesh.PRIMITIVE_LINES)
		ig.add_vertex(Vector3(b.x, a.y, a.z))
		ig.add_vertex(Vector3(b.x, a.y, b.z))
		ig.add_vertex(Vector3(b.x, b.y, a.z))
		ig.add_vertex(Vector3(b.x, b.y, b.z))
		ig.add_vertex(Vector3(a.x, b.y, a.z))
		ig.add_vertex(Vector3(a.x, b.y, b.z))
		ig.end()
