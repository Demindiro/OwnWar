extends Reference


var _vehicle: OwnWar.Vehicle
var _mainframes := []


func init(vehicle: OwnWar.Vehicle) -> void:
	_vehicle = vehicle


func process(delta: float) -> void:
	for mainframe in _mainframes:
		mainframe.process(delta)


func add_mainframe(mainframe: Node) -> void:
	_mainframes.append(mainframe)
	var e := mainframe.connect("tree_exited", self, "_mainframe_destroyed", [mainframe])
	assert(e == OK)


func add_action(action: OwnWar.Action) -> void:
	_vehicle.add_action(action)


func serialize_json() -> Dictionary:
	return {}


func deserialize_json(_data: Dictionary) -> void:
	pass


func _mainframe_destroyed(mainframe: Node) -> void:
	_mainframes.erase(mainframe)
