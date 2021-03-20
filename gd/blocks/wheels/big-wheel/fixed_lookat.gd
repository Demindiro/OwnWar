extends Spatial


export var fix_at := NodePath()
export var look_at := NodePath()

onready var fix_at_node: Spatial = get_node(fix_at)
onready var look_at_node: Spatial = get_node(look_at)
onready var org_scale := scale


func _process(_delta: float) -> void:
	var from := fix_at_node.global_transform
	var to := look_at_node.global_transform
	var dir := (to.origin - from.origin).normalized()
	var axis := from.basis.x.normalized()
	var trf := Transform()
	trf.basis = Basis(axis, dir.cross(axis), dir)
	trf.origin = fix_at_node.global_transform.origin
	global_transform = trf
	set_scale(org_scale)
