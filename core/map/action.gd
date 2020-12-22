var name: String
var thumbnail: Texture
var input_flags: int
var function: FuncRef
var arguments: Array
var pressed: bool
var feedback: FuncRef
var cursor: Texture
var flip_y := false


func _init(p_name: String, p_thumbnail: Texture, p_input_flags: int,
		p_function: FuncRef, p_arguments := [], p_pressed := false,
		p_feedback: FuncRef = null, p_cursor: Texture = null):
	name = p_name
	thumbnail = p_thumbnail
	input_flags = p_input_flags
	function = p_function
	arguments = p_arguments
	pressed = p_pressed
	feedback = p_feedback
	cursor = p_cursor
