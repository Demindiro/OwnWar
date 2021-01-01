extends Control


onready var _version: Label = $Main/Version
onready var _button_campaign: Control = $Campaign
onready var _button_plugins: Control = $Plugins
onready var _button_saves: Control = $Saves
onready var _background := $"../Background"


func _ready():
	_version.text = Util.version_vector_to_str(OwnWar.VERSION)
	var bg := OwnWar.get_random_main_menu_background()
	if bg != null:
		_background.add_child(bg.instance())


func _on_Campaign_pressed():
	_button_campaign.visible = not _button_campaign.visible
	_button_plugins.visible = false
	_button_saves.visible = false


func _on_RandomMap_pressed():
	pass # Replace with function body.


func _on_Designer_pressed():
	Global.goto_scene(Global.SCENE_DESIGNER)


func _on_Settings_pressed():
	pass # Replace with function body.


func _on_Exit_pressed():
	get_tree().quit()


func _on_Tutorial_pressed():
	Global.goto_scene("res://campaign/tutorial/hill.tscn")


func _on_Plugins_pressed():
	_button_plugins.visible = not _button_plugins.visible
	_button_campaign.visible = false
	_button_saves.visible = false


func _on_Saves_pressed():
	_button_saves.visible = not _button_saves.visible
	_button_campaign.visible = false
	_button_plugins.visible = false
