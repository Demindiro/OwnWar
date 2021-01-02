tool
extends Control


export var title := "Title" setget set_title


func set_title(p_title):
	title = p_title
	if is_inside_tree():
		var node: Label = $Title
		node.text = title
	else:
		call_deferred("set_title", title)
