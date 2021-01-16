extends ScrollContainer


func set_bus_volume(value: float, bus_name: String) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	assert(i >= 0, "Bus not found")
	if value < -49.99:
		AudioServer.set_bus_mute(i, true)
	else:
		AudioServer.set_bus_mute(i, false)
		AudioServer.set_bus_volume_db(i, value)
