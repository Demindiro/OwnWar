extends Node


export var max_munitions := 4
var munitions := []


func _enter_tree():
	munitions


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle):
	vehicle.add_block_function(self, "_static_put_munition", "put_munition")
	vehicle.add_block_function(self, "_static_take_munition", "take_munition")
	vehicle.add_block_function(self, "_static_get_munition_space", "get_munition_space")
	vehicle.add_block_function(self, "_static_get_munition_count", "get_munition_count")
	vehicle.add_info_function(self, "_static_get_info_munition", "Shells")


func put_munition(munition):
	if len(munitions) < max_munitions:
		munitions.append(munition)
		return null
	return munition


func take_munition():
	if len(munitions) > 0:
		return munitions.pop_back()
	return null


static func _static_put_munition(blocks, arguments):
	var munition = arguments[0]
	for block in blocks:
		munition = block.put_munition(munition)
		if munition == null:
			break
	return munition


static func _static_take_munition(blocks, _arguments):
	for block in blocks:
		var munition = block.take_munition()
		if munition != null:
			return munition
	return null


static func _static_get_munition_space(blocks, _arguments):
	var munition_space = 0
	for block in blocks:
		munition_space += block.max_munitions - len(block.munitions)
	return munition_space


static func _static_get_munition_count(blocks, _arguments):
	var munition_count = 0
	for block in blocks:
		munition_count += len(block.munitions)
	return munition_count


static func _static_get_info_munition(blocks):
	var max_total_munitions = 0
	var total_munitions = 0
	for block in blocks:
		max_total_munitions += block.max_munitions
		total_munitions += len(block.munitions)
	return "%d / %d" % [total_munitions, max_total_munitions]
