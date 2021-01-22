tool
extends Control


func _ready():
	var e := connect("item_rect_changed", self, "_on_item_rect_changed")
	assert(e == OK)


func _on_item_rect_changed() -> void:
	rect_pivot_offset = rect_size / 2
