extends Control


export var camera: NodePath
onready var _camera: Camera = get_node(camera)


func _ready():
	assert(_camera != null)


func _unhandled_input(event):
	if event.is_action_pressed("campaign_debug"):
		if event.pressed:
			Debug.visible = not Debug.visible
		get_tree().set_input_as_handled()
