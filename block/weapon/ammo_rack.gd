extends Node


export var max_shells := 4
var shells := 0


func put_shell():
	if shells < max_shells:
		shells += 1
		return 1
	return 0


func take_shell():
	if shells > 0:
		shells -= 1
		return 0
	return 1
