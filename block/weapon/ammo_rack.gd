extends Node


export var max_shells := 4
var shells := []


func _enter_tree():
	shells


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle):
	vehicle.add_block_function(self, "_static_put_shell", "put_shell")
	vehicle.add_block_function(self, "_static_take_shell", "take_shell")
	vehicle.add_block_function(self, "_static_get_shell_space", "get_shell_space")
	vehicle.add_block_function(self, "_static_get_shell_count", "get_shell_count")
	vehicle.add_info_function(self, "_static_get_info_shells", "Shells")


func put_shell(shell):
	if len(shells) < max_shells:
		shells.append(shell)
		return null
	return shell


func take_shell():
	if len(shells) > 0:
		return shells.pop_back()
	return null


static func _static_put_shell(blocks, arguments):
	var shell = arguments[0]
	for block in blocks:
		shell = block.put_shell(shell)
		if shell == null:
			break
	return shell


static func _static_take_shell(blocks, _arguments):
	for block in blocks:
		var shell = block.take_shell()
		if shell != null:
			return shell
	return null


static func _static_get_shell_space(blocks, _arguments):
	var shell_space = 0
	for block in blocks:
		shell_space += block.max_shells - len(block.shells)
	return shell_space


static func _static_get_shell_count(blocks, _arguments):
	var shell_count = 0
	for block in blocks:
		shell_count += len(block.shells)
	return shell_count


static func _static_get_info_shells(blocks):
	var max_total_shells = 0
	var total_shells = 0
	for block in blocks:
		max_total_shells += block.max_shells
		total_shells += len(block.shells)
	return "%d / %d" % [total_shells, max_total_shells]
