extends Spatial


export var anchor := NodePath()
export var mount := NodePath()

onready var anchor_node: Spatial = get_node_or_null(anchor)
onready var mount_node: Spatial = get_node(mount)

var team_color = OwnWar.ALLY_COLOR


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
	var mat = MaterialCache.get_material(clr)
	for c in Util.get_children_recursive(self):
		if c.name != "Bar" and "color" in c:
			c.mesh = c.mesh.duplicate()
			c.mesh.surface_set_material(0, mat)

	if 0:
		team_color.a = alpha
		var bar = $"Bar mount base/Bar mount base/Bar"
		mat = bar.mesh.surface_get_material(0)
		mat = MaterialCache.get_material(team_color, mat)
		bar.mesh = bar.mesh.duplicate()
		bar.mesh.surface_set_material(0, mat)


func set_team_color(color: Color) -> void:
	team_color = color
	$"Bar mount base/Bar mount base/Bar".color = color
