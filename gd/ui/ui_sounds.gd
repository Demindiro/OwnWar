extends Node


var audio_hover := AudioStreamPlayer.new()
var audio_click := AudioStreamPlayer.new()


func _enter_tree() -> void:
	var e := get_tree().connect("node_added", self, "node_added")
	assert(e == OK)
	e = get_tree().connect("node_removed", self, "node_removed")
	assert(e == OK)
	audio_hover.stream = preload("res://addons/ui/397599__nightflame__menu-fx-02.wav")
	audio_hover.bus = "UI"
	add_child(audio_hover)
	audio_click.stream = preload("res://addons/ui/397599__nightflame__menu-fx-02.wav")
	audio_click.bus = "UI"
	audio_click.volume_db *= 5
	audio_click.pitch_scale *= 1.25
	add_child(audio_click)


func node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("ui_audio_disable"):
		var e := node.connect("mouse_entered", self, "mouse_entered", [node])
		assert(e == OK)
		e = node.connect("mouse_exited", self, "mouse_exited", [node])
		assert(e == OK)
		e = node.connect("pressed", audio_click, "play")
		assert(e == OK)
		if node is OptionButton:
			e = node.connect("item_focused", self, "option_button_hovered")
			assert(e == OK)
			e = node.connect("item_selected", self, "option_button_pressed")
			assert(e == OK)
		# Recursing is necessary because https://github.com/godotengine/godot/issues/16854
		for n in Util.get_children_recursive(node):
			if n is Control:
				e = n.connect("mouse_entered", self, "mouse_entered", [node])
				assert(e == OK)
				e = n.connect("mouse_exited", self, "mouse_exited", [node])
				assert(e == OK)
		node.set_meta("ui_audio_mouse_entered", false)


func node_removed(_node: Node) -> void:
	# TODO is it safe to assume the node has been deleted?
	pass


func mouse_entered(node: BaseButton) -> void:
	assert(node != null)
	if not node.get_meta("ui_audio_mouse_entered"):
		audio_hover.play()
	node.call_deferred("set_meta", "ui_audio_mouse_entered", true)


func mouse_exited(node: BaseButton) -> void:
	node.call_deferred("set_meta", "ui_audio_mouse_entered", false)


func option_button_pressed(_index: int) -> void:
	audio_click.play()


func option_button_hovered(_index: int) -> void:
	audio_hover.play()
