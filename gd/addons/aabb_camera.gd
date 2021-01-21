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
	call_deferred("_post_process")


func _post_process() -> void:
	translation = Vector3(
		clamp(translation.x, aabb.position.x, aabb.end.x),
		clamp(translation.y, aabb.position.y, aabb.end.y),
		clamp(translation.z, aabb.position.z, aabb.end.z)
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
