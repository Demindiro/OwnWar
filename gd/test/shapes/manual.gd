extends "res://test/shapes/shapes.gd"


export(String, FILE, "*.json") var data_path := "res://blocks/chassis/shapes.json"
var data: Dictionary
var rotation := 0
var mirror := 0


func _ready():
	load_data()
	_on_RotationOffset_value_changed(rotation)


func load_data():
	var file := File.new()
	var err := file.open(data_path, File.READ)
	match err:
		OK:
			data = parse_json(file.get_as_text())
		ERR_FILE_NOT_FOUND:
			print("File '%s' not found" % data_path)
			data = {}
		_:
			assert(false)


func save_data():
	var file := File.new()
	var err := file.open(data_path, File.WRITE)
	assert(err == OK)
	var delete_keys = []
	for key in data:
		if len(data[key]) == 0:
			delete_keys.append(key)
	for key in delete_keys:
		data.erase(key)
	file.store_string(to_json(data))
	print("Data saved to '%s'" % data_path)


func update():
	transform = Transform(OwnWar_BlockManager.new().rotation_to_basis(rotation), Vector3.ZERO)
	transform = transform.scaled(Vector3.ONE * 2)
	transform = transform.translated(-Vector3.ONE / 2)
	.update()
	if generator.name in data and $Save/BlockName.text in data[generator.name]:
		$Save/SaveState.text = "Saved"
		$Save/Load.disabled = false
		$Save/Delete.disabled = false
	else:
		$Save/SaveState.text = "Not saved"
		$Save/Load.disabled = true
		$Save/Delete.disabled = true
	for child in $UI/SavedBlocks.get_children():
		child.queue_free()
	if generator.name in data:
		for block_name in data[generator.name]:
			var button := Button.new()
			button.text = block_name
			button.connect("pressed", $Save/BlockName, "set_text", [block_name])
			button.connect("pressed", self, "_on_Load_pressed", [], CONNECT_DEFERRED)
			$UI/SavedBlocks.add_child(button)
	update_mirror()


func update_mirror():
	var mirror_transform
	var flip_faces = false
	$MirrorInstance.visible = true
	if mirror < 0:
		mirror_transform = Transform.FLIP_X * transform
		flip_faces = true
	else:
		mirror_transform = Transform(
			OwnWar_BlockManager.new().rotation_to_basis(mirror),
			Vector3.ZERO
		) * transform
	$MirrorInstance.mesh = generator.get_mesh(meshes[variant_index], mirror_transform, flip_faces)


func _on_RotationOffset_value_changed(value):
	rotation = value
	update()


func _on_GenerateMirrorMesh_toggled(button_pressed):
	if button_pressed:
		$Save/MirrorRotationOffset.value = 0
		mirror = -1
	else:
		mirror = 0
	update()


func _on_MirrorRotationOffset_value_changed(value):
	mirror = value
	$Save/GenerateMirrorMesh.pressed = false
	update()


func _on_Save_pressed():
	var block_name = $Save/BlockName.text
	if not generator.name in data:
		data[generator.name] = {}
	data[generator.name][block_name] = {
			"indices": mesh_indices[variant_index],
			"rotation": rotation,
			"mirror": mirror
		}
	save_data()
	update()


func _on_Load_pressed():
	var block_data = data[generator.name][$Save/BlockName.text]
	variant_index = -1
	for i in range(len(mesh_indices)):
		var indices = mesh_indices[i]
		if indices == PoolIntArray(block_data["indices"]):
			variant_index = i
			break
	assert(variant_index >= 0)
	mirror = block_data["mirror"]
	rotation = block_data["rotation"]
	$Save/RotationOffset.value = rotation
	$Save/MirrorRotationOffset.value = mirror if mirror >= 0 else 0
	$Save/GenerateMirrorMesh.pressed = mirror < 0
	update()


func _on_Delete_pressed():
	data[generator.name].erase($Save/BlockName.text)
	save_data()
	update()


func _on_BlockName_focus_entered():
	$Camera.enabled = false


func _on_BlockName_focus_exited():
	$Camera.enabled = true


func _on_BlockName_text_changed(_new_text):
	update()
