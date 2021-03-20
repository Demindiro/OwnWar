extends Spatial


var color: Color


func _ready() -> void:
	$Base.color = color


func set_color(p_color: Color) -> void:
	color = p_color
	var n = get_node_or_null("Base")
	if n != null:
		n.color = color
