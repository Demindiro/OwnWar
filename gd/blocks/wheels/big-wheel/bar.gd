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
	for c in Util.get_children_recursive(self):
		if "color" in c:
			c.color = color


func set_transparency(alpha: float) -> void:
	clr.a = alpha
	var mat := MaterialCache.get_material(clr)
	for c in Util.get_children_recursive(self):
		if "color" in c:
			c.color = clr
	$"Bar mount base/Bar mount base/Bar".visible = alpha > 0.99


func set_team_color(color: Color) -> void:
	$"Bar mount base/Bar mount base/Bar".color = color
