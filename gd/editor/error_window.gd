extends PanelContainer


export var message_path := NodePath()
export var animation_path := NodePath()
export var animation_name := ""
export var timer_path := NodePath()
onready var message: Label = get_node(message_path)
onready var animation: AnimationPlayer = get_node(animation_path)
onready var timer: Timer = get_node(timer_path)


func show_error(text: String) -> void:
	visible = true
	message.text = text
	animation.stop()
	animation.play(animation_name)
	timer.start()
	
