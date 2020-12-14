extends Node


func _ready():
	var tn: Viewport = preload("thumbnail.tscn").instance()
	add_child(tn)
	var mi: MeshInstance = tn.get_node("MeshInstance")
	for b in OwnWar.Block.get_all_blocks():
		var block: OwnWar.Block = b
		var path := _get_path(block.name)
		if not File.new().file_exists(path):
			print("Generating thumbnail for ", block.name)
			mi.scale = Vector3.ONE / max(block.size.x, max(block.size.y, block.size.z))
			mi.mesh = block.mesh
			var scene: Spatial
			if block.scene != null:
				scene = block.scene.instance()
				scene.propagate_call("set_script", [null], true)
				scene.transform = mi.transform
				tn.add_child(scene)
			yield(VisualServer, "frame_post_draw")
			yield(VisualServer, "frame_post_draw")
			var img := tn.get_texture().get_data()
			img.convert(Image.FORMAT_RGBA8)
			var e := img.save_png(path)
			assert(e == OK)
			if scene != null:
				tn.remove_child(scene)
				scene.queue_free()


static func get_thumbnail(name: String) -> Image:
	var img := Image.new()
	var e := img.load(_get_path(name))
	assert(e == OK)
	return img


static func _get_path(name: String) -> String:
	return "/tmp/godot-thumbnail/" + name + ".png"
