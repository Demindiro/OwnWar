const PLUGIN_ID := "hello_world"
const PLUGIN_VERSION := Vector3(0, 0, 1)
const MIN_VERSION := Vector3(0, 12, 0)


static func pre_init(_plugin_path: String):
	print("Hello!")


static func init(_plugin_path: String):
	print("Hello again!")


static func post_init(_plugin_path: String):
	print("Hello for the last time!")
