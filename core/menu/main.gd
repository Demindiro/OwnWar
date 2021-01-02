extends Control


onready var _version: Label = $Main/Version


func _ready():
	_version.text = Util.version_vector_to_str(OwnWar.VERSION)


func _on_Designer_pressed():
	Global.goto_scene(Global.SCENE_DESIGNER)


func _on_Settings_pressed():
	pass # Replace with function body.


func _on_Exit_pressed():
	get_tree().quit()


func goto_designer(vehicle_path: String) -> void:
	assert(vehicle_path != "")
	var scene = load("res://core/designer/designer.tscn").instance()
	scene.vehicle_path = vehicle_path
	queue_free()
	var tree := get_tree()
	tree.root.remove_child(self)
	tree.root.add_child(scene)
	tree.current_scene = scene
