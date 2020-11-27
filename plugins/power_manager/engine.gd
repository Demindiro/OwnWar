extends Node


# warning-ignore:unused_class_variable
export var max_power := 16000


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle, _meta):
	var manager = vehicle.get_manager("power")
	manager.add_engine(self)
