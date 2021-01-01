extends Control


onready var _version: Label = $Main/Version
onready var _background := $"../Background"


func _ready():
	_version.text = Util.version_vector_to_str(OwnWar.VERSION)
	var bg := OwnWar.get_random_main_menu_background()
	if bg != null:
		_background.add_child(bg.instance())


func _on_Designer_pressed():
	Global.goto_scene(Global.SCENE_DESIGNER)


func _on_Settings_pressed():
	pass # Replace with function body.


func _on_Exit_pressed():
	get_tree().quit()
