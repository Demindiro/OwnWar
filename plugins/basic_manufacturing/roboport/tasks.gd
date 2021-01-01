class Task:
	# warning-ignore:unused_class_variable
	var assignees := 0

#	func _init() -> void:
		# (┛◉Д◉) ┛彡┻━┻
#		assert(false)
#		pass


class Transport:
	extends Task
	var from: OwnWar.Structure
	var to: OwnWar.Structure
	var matter_id: int

	func _init(p_from: OwnWar.Structure, p_to: OwnWar.Structure,
		p_matter_id: int) -> void:
		from = p_from
		to = p_to
		matter_id = p_matter_id


class Fill:
	extends Transport

	func _init(p_from: OwnWar.Structure, p_to: OwnWar.Structure,
		p_matter_id: int).(p_from, p_to, p_matter_id) -> void:
		pass


class Empty:
	extends Transport

	func _init(p_from: OwnWar.Structure, p_to: OwnWar.Structure,
		p_matter_id: int).(p_from, p_to, p_matter_id) -> void:
		pass
