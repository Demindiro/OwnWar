const PLUGIN_ID := "hello_world"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)


func _init():
	print("Hello!")


func pre_init():
	print("Hello again!")


func post_init():
	print("Hello for the last time!")
