tool
extends Control


export var title := "Title" setget set_title


func set_title(p_title):
	title = p_title
	$Title.text = title
