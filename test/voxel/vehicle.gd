extends Node


export(String, FILE) var file := "user://vehicles/fancy_box.json"
export var count := 1000
var index := 0


func _process(delta):
	get_tree().paused = true
	var start := OS.get_ticks_msec()
	while index < count:
		var vehicle = OwnWar.Vehicle.new()
		vehicle.pause_mode = Node.PAUSE_MODE_STOP
		vehicle.load_from_file(file)
		vehicle.translation = Vector3(index & 0xff, (index >> 8) & 0xff, (index >> 16) & 0xff) * 2
		for body in vehicle.voxel_bodies:
			body._process(delta) # Update meshes
		add_child(vehicle)
		index += 1
		if OS.get_ticks_msec() - start > 100:
			break
	$Label3.text = "%d / %d" % [index, count]
