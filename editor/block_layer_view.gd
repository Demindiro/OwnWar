extends OptionButton


func _ready():
	add_icon_item(null, "All", 0)
	add_icon_item(null, "0", 1)
	add_icon_item(null, "1", 2)
	add_icon_item(null, "2", 3)
	add_icon_item(null, "3", 4)
	selected = 0


func _input(event):
	if event.is_action_released("designer_release_cursor"):
		get_popup().hide()
