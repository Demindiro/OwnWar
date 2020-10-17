class_name Unit

extends Spatial


signal destroyed(unit)
signal message(message, data)
enum Action {
	INPUT_NONE = 0x0,
	INPUT_COORDINATE = 0x1,
	INPUT_ENEMY_UNITS = 0x2,
	INPUT_ALLIED_UNITS = 0x4,
	INPUT_OWN_UNITS = 0x8,
#	INPUT_UNITS = INPUT_ENEMY_UNITS | INPUT_ALLIED_UNITS | INPUT_OWN_UNITS,
	INPUT_UNITS = 0x2 | 0x4 | 0x8,
	INPUT_TOGGLE = 0x10,
	INPUT_SCROLL = 0x20,

	SUBACTION = 0x100,
}

export var max_health := 10
export var team := 0
# warning-ignore:unused_class_variable
export var unit_name := "unit"
onready var health := max_health
onready var game_master = GameMaster.get_game_master(self)


func projectile_hit(_origin: Vector3, _direction: Vector3, damage: int):
	health -= damage
	if health <= 0:
		destroy()
		return -health
	return 0


func get_actions() -> Array:
	# Return format: [human_name, flags, function_name, [args...]]
	# If INPUT_TOGGLE is specified, append a bool to indicate on/off
	return []


func show_feedback():
	pass


func hide_feedback():
	pass


func show_action_feedback(function: String, viewport: Viewport, arguments: Array) -> void:
	pass


func hide_action_feedback() -> void:
	pass


func get_info():
	return {
			"Health": str(health) + " / " + str(max_health)
		}


func has_function(function_name):
	return has_method(function_name)


func call_function(function_name, arguments := []):
	assert(has_method(function_name))
	return callv(function_name, arguments)


func send_message(message, data) -> void:
	emit_signal("message", message, data)


func request_info(info: String):
	return null


func get_interaction_port() -> Vector3:
	return translation


func get_matter_count(id: int) -> int:
	return 0


func get_matter_space(id: int) -> int:
	return 0


func put_matter(id: int, amount: int) -> int:
	return 0


func take_matter(id: int, amount: int) -> int:
	return 0


func destroy():
	game_master.remove_unit(team, self)
	emit_signal("destroyed", self)
