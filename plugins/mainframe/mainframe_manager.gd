extends Reference


var _vehicle: OwnWar.Vehicle
var _mainframes := []
var _actions := {}


func init(vehicle: OwnWar.Vehicle) -> void:
	_vehicle = vehicle


func process(delta: float) -> void:
	for mainframe in _mainframes:
		mainframe.process(delta)


func add_mainframe(mainframe: Node) -> void:
	_mainframes.append(mainframe)
	var e := mainframe.connect("tree_exited", self, "_mainframe_destroyed", [mainframe])
	assert(e == OK)


func add_action(mainframe: Node, name: String, flags: int, function: String,
		arguments := []) -> void:
	if name in _actions:
		_actions[name].append(funcref(mainframe, function))
	else:
		_actions[name] = [funcref(mainframe, function)]
		var callback = "_do_action_input" if flags != 0 else "_do_action"
		_vehicle.add_action(self, name, flags, callback, [name, arguments])


func serialize_json() -> Dictionary:
	return {}


func deserialize_json(_data: Dictionary) -> void:
	pass


func _do_action(flags, name, arguments) -> void:
	arguments = [flags] + arguments
	for function in _actions[name]:
		function.call_funcv(arguments)


func _do_action_input(flags, input, name, arguments) -> void:
	arguments = [flags, input] + arguments
	for function in _actions[name]:
		function.call_funcv(arguments)


func _mainframe_destroyed(mainframe: Node) -> void:
	_mainframes.erase(mainframe)
	for functions in _actions.values():
		for i in range(len(functions) - 1, -1, -1):
			if not functions[i].is_valid():
				functions.remove(i)
