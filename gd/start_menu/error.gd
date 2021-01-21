extends Popup
class_name OwnWar_ErrorPopup


export var _text_node := NodePath()


func show_error(message: String) -> void:
	get_node(_text_node).text = message
	popup()
