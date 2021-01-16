extends ScrollContainer


export var buses_sliders_parent := NodePath()
var post_ready := false
# Use timer to prevent log and save spam
var save_timer: SceneTreeTimer = null


func _ready() -> void:
	for child in get_node(buses_sliders_parent).get_children():
		var i := AudioServer.get_bus_index(child.name)
		assert(i >= 0, "Bus not found")
		child.value = AudioServer.get_bus_volume_db(i)
	post_ready = true



func set_bus_volume(value: float, bus_name: String) -> void:
	if not post_ready:
		return
	var i := AudioServer.get_bus_index(bus_name)
	assert(i >= 0, "Bus not found")
	AudioServer.set_bus_mute(i, value < -49.99)
	AudioServer.set_bus_volume_db(i, value)
	if save_timer == null:
		save_timer = get_tree().create_timer(1.0)
		var e := save_timer.connect("timeout", OwnWar_Settings, "save_settings")
		assert(e == OK)
		e = save_timer.connect("timeout", self, "set", ["save_timer", null])
		assert(e == OK)
