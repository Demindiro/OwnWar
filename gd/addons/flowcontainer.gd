extends GridContainer
class_name FlowContainer


func _draw():
	columns = 1
	var max_width := 1.0
	for child in get_children():
		if child is Control:
			max_width = max(max_width, child.rect_size.x)
	max_width += get_constant("hseparation")
	var parent: Control = get_parent()
	columns = int(parent.rect_size.x / max_width)
