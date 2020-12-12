var name: String
var input_flags: int
var function: FuncRef
var arguments: Array
var pressed: bool
var feedback: FuncRef


func _init(p_name: String, p_input_flags: int, p_function: FuncRef,
		p_arguments := [], p_pressed := false, p_feedback: FuncRef = null):
	name = p_name
	input_flags = p_input_flags
	function = p_function
	arguments = p_arguments
	pressed = p_pressed
	feedback = p_feedback
