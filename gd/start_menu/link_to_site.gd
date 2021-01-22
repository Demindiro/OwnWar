extends BaseButton


export var url := ""


func _ready():
	var e := connect("pressed", OS, "shell_open", [url])
	assert(e == OK)
	hint_tooltip = url
