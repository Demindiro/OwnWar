class_name Unit

extends Spatial


signal destroyed(unit)

enum Action {
	INPUT_COORDINATE = 0x1,
	INPUT_ENEMY_UNITS = 0x2,
	INPUT_ALLIED_UNITS = 0x4,
	INPUT_OWN_UNITS = 0x8,
#	INPUT_UNITS = INPUT_ENEMY_UNITS | INPUT_ALLIED_UNITS | INPUT_OWN_UNITS,
	INPUT_UNITS = 0x2 | 0x4 | 0x8,
	INPUT_TOGGLE = 0x10,
}

export var max_health := 10
export var team := 0
export var unit_name := "unit"

onready var health := max_health
onready var game_master = get_tree().get_current_scene()


func projectile_hit(_origin: Vector3, _direction: Vector3, damage: int):
	health -= damage
	if health <= 0:
		destroy()
		return -health
	return 0


func get_actions():
	# Return format: [human_name, flags, function_name, [args...]]
	# If INPUT_TOGGLE is specified, append a bool to indicate on/off
	return []


func destroy():
	game_master.remove_unit(team, self)
	emit_signal("destroyed", self)
