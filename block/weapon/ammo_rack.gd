extends Node


export var max_shells := 4
var shells := 0


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle):
	vehicle.add_block_function(self, "_static_put_shell", "put_shell")
	vehicle.add_block_function(self, "_static_take_shell", "take_shell")
	vehicle.add_block_function(self, "_static_get_shell_space", "get_shell_space")


func put_shell():
	if shells < max_shells:
		shells += 1
		return 0
	return 1


func take_shell():
	if shells > 0:
		shells -= 1
		return 1
	return 0


static func _static_put_shell(blocks, _arguments):
	for block in blocks:
		if not block.put_shell():
			return 0
	return 1


static func _static_take_shell(blocks, _arguments):
	for block in blocks:
		if block.take_shell():
			return 1
	return 0


static func _static_get_shell_space(blocks, _arguments):
	var shell_space = 0
	for block in blocks:
		shell_space = block.max_shells - block.shells
	return shell_space
