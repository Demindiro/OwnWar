class_name Unit

extends Spatial


signal destroyed(unit)
# warning-ignore:unused_signal
signal need_matter(id, amount)
# warning-ignore:unused_signal
signal provide_matter(id, amount)
# warning-ignore:unused_signal
signal take_matter(id, amount)
# warning-ignore:unused_signal
signal dump_matter(id, amount)
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
enum TypeFlags {
	DEFAULT = 0x0,
	STRUCTURE = 0x1,
	GHOST = 0x2,
}
const UNITS := {}
export var max_health := 10
export var team := 0
# warning-ignore:unused_class_variable
export var unit_name := "unit"
export var type_flags := TypeFlags.DEFAULT
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


func show_action_feedback(_function: String, _viewport: Viewport, _arguments: Array) -> void:
	pass


func hide_action_feedback() -> void:
	pass


func get_info():
	return {
			"Health": str(health) + " / " + str(max_health)
		}


func get_interaction_port() -> Vector3:
	return translation


func get_matter_count(_id: int) -> int:
	return 0


func get_matter_space(_id: int) -> int:
	return 0


func get_put_matter_list() -> PoolIntArray:
	return PoolIntArray()


func get_take_matter_list() -> PoolIntArray:
	return PoolIntArray()


func needs_matter(_id: int) -> int:
	return 0


func provides_matter(_id: int) -> int:
	return 0


func takes_matter(_id: int) -> int:
	return 0


func dumps_matter(_id: int) -> int:
	return 0


func put_matter(_id: int, amount: int) -> int:
	return amount


func take_matter(_id: int, _amount: int) -> int:
	return 0


func destroy():
	game_master.remove_unit(team, self)
	emit_signal("destroyed", self)


static func add_unit(p_name: String, unit) -> void:
	assert(not p_name in UNITS)
	UNITS[p_name] = unit
