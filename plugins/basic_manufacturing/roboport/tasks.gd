class Task:
	var assignees := 0

	func _init() -> void:
		# (┛◉Д◉) ┛彡┻━┻
#		assert(false)
		pass


class Fill:
	extends Task
	var from: Structure
	var to: Structure
	var matter_id: int

	func _init(p_from: Structure, p_to: Structure, p_matter_id: int) -> void:
		from = p_from
		to = p_to
		matter_id = p_matter_id


class Empty:
	extends Task
	var from: Structure
	var to: Structure
	var matter_id: int

	func _init(p_from: Structure, p_to: Structure, p_matter_id: int) -> void:
		from = p_from
		to = p_to
		matter_id = p_matter_id
