extends Spatial


export var anchor := NodePath()
export var mount := NodePath()

onready var anchor_node: Spatial = get_node_or_null(anchor)
onready var mount_node: Spatial = get_node(mount)


func _process(_delta: float) -> void:
	mount_node.global_transform.origin = anchor_node.global_transform.origin
	mount_node.translation.z = 0


var clr := Color.white

func set_color(color: Color) -> void:
	color.a = clr.a
	clr = color
	var mat := MaterialCache.get_material(color)
	for c in get_children():
		if c is MeshInstance:
			c.material_override = mat
		else:
			for d in c.get_children():
				d.material_override = mat


func set_transparency(alpha: float) -> void:
	clr.a = alpha
	var mat := MaterialCache.get_material(clr)
	for c in get_children():
		if c is MeshInstance:
			c.material_override = mat
		else:
			for d in c.get_children():
				d.material_override = mat
	$"Bar mount base/Bar".visible = alpha > 0.99


func set_team_color(color: Color) -> void:
	var node = $"Bar mount base/Bar"
	node.material_override = node.material_override.duplicate()
	node.material_override.albedo_color = color
	node.material_override.emission = color * 2
