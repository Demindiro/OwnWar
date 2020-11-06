extends Spatial


export var brightness := 1.0 setget set_brightness


func _init():
	if not Engine.editor_hint:
		visible = false


func _on_fired():
	if not Engine.editor_hint:
		visible = true
		# Yikes
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
		visible = false


func set_brightness(p_brightness):
	brightness = p_brightness
	$OmniLight.light_energy = brightness
	$OmniLight2.light_energy = brightness
	$OmniLight3.light_energy = brightness
