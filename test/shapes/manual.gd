extends "res://test/shapes/shapes.gd"


enum MirrorMode { NONE, GENERATE, OFFSET }
export(String, FILE, "*.json") var data_path := "res://block/chassis/shapes.json"
var data: Dictionary
var mirror_mode: int = MirrorMode.NONE


func _ready():
	load_data()
	_on_RotationOffset_value_changed(0)


func load_data():
	var file := File.new()
	var err := file.open(data_path, File.READ)
	match err:
		OK:
			data = parse_json(file.get_text())
		ERR_FILE_NOT_FOUND:
			print("File '%s' not found" % data_path)
			data = {}
		_:
			assert(false)


func save_data():
	var file := File.new()
	var err := file.open(data_path, File.WRITE)
	assert(err == OK)
	file.store_string(to_json(data))
	
	
func update():
	.update()
	update_mirror()
	
	
func update_mirror():
	var mirror_transform
	$MirrorInstance.visible = true
	if mirror_mode == MirrorMode.GENERATE:
		mirror_transform = Transform.FLIP_X * transform
	elif mirror_mode == MirrorMode.OFFSET:
		mirror_transform = Transform.IDENTITY.rotated(Vector3.UP, -PI / 2) * transform
	else:
		mirror_transform = transform
	$MirrorInstance.mesh = generator.get_mesh(meshes[variant_index], mirror_transform)


func _on_RotationOffset_value_changed(value):
	transform = Transform(Block.rotation_to_basis(value), Vector3.ZERO)
	transform = transform.scaled(Vector3.ONE * 2)
	transform = transform.translated(-Vector3.ONE / 2)
	update()


func _on_GenerateMirrorMesh_toggled(button_pressed):
	mirror_mode = MirrorMode.GENERATE if button_pressed else MirrorMode.NONE
	$Save/MirrorRotationOffset.pressed = false
	update()


func _on_MirrorRotationOffset_toggled(button_pressed):
	mirror_mode = MirrorMode.OFFSET if button_pressed else MirrorMode.NONE
	$Save/GenerateMirrorMesh.pressed = false
	update()
