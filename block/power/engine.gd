extends Node

export var max_power := 16000.0
var _power_requesters := {}
onready var _remaining_power := max_power


func _physics_process(_delta: float) -> void:
	_remaining_power = max_power
	var requested_power := 0.0
	for power in _power_requesters.values():
		requested_power += power
	if requested_power > 0.0:
		var used_power := max_power if requested_power > max_power else requested_power
		for requester in _power_requesters:
			var supplied_power = requested_power * used_power / requested_power \
					/ len(_power_requesters)
			requester.supply_power(_power_requesters[requester])
			_remaining_power -= supplied_power
		assert(_remaining_power >= 0.0)


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle):
	vehicle.add_block_function(self, "_static_reserve_power", "reserve_power")
	vehicle.add_info_function(self, "_static_get_power", "Power")


func _remove_requester(requester):
	_power_requesters.erase(requester)


static func _static_reserve_power(engines, arguments):
	var requester = arguments[0]
	var power = arguments[1]
	for engine in engines:
		if not requester in engine._power_requesters:
			requester.connect("tree_exited", engine, "_remove_requester", [engine, requester])
		engine._power_requesters[requester] = power
		break


static func _static_get_power(engines):
	var total_power := 0
	var total_max_power := 0
	for engine in engines:
		total_power += engine._remaining_power
		total_max_power += engine.max_power
	return "%d / %d" % [total_power, total_max_power]
