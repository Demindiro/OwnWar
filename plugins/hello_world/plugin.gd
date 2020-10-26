const PLUGIN_ID = "hello_world"


func _init():
	print("Hello!")


func pre_init():
	print("Hello again!")


func post_init():
	print("Hello for the last time!")
