extends Spatial


export(bool) var autocomplete = true

var coroutine


func _ready():
	coroutine = $Vehicle.load_from_file("user://vehicles/apc.json")
	while autocomplete and coroutine is GDScriptFunctionState:
		coroutine = coroutine.resume()


func _on_Button_pressed():
	if coroutine is GDScriptFunctionState:
		coroutine = coroutine.resume()
