extends Node


export(int, 1, 8) var segments := 1 setget set_segments
export var generator_index := 0
export(Array, String) var generator_names := [
		"corner",
		"square_corner",
		"cube_a",
		"cube_b",
		"edge_a",
		"inverse_corner",
		"inverse_square_corner",
	]
export(Array, GDScript) var generator_paths := [
		preload("res://blocks/chassis/variant/complex/corner.gd"),
		preload("res://blocks/chassis/variant/complex/square_corner.gd"),
		preload("res://blocks/chassis/variant/complex/cube_a.gd"),
		preload("res://blocks/chassis/variant/complex/cube_b.gd"),
		preload("res://blocks/chassis/variant/complex/edge_a.gd"),
		preload("res://blocks/chassis/variant/complex/inverse_corner.gd"),
		preload("res://blocks/chassis/variant/complex/inverse_square_corner.gd"),
	]
var generator
var meshes := []
var mesh_names := []
var mesh_indices := []
var variant_index: int
var transform := Transform.IDENTITY


func _ready():
	assert(len(generator_names) == len(generator_paths))
	generator_index %= len(generator_names)
	set_segments(segments)


func set_segments(p_segments):
	segments = p_segments
	generator = generator_paths[generator_index].new()
	generator.start(segments)
	meshes = []
	mesh_names = []
	mesh_indices = []
	while not generator.finished:
		meshes.append(generator.get_result())
		mesh_names.append(generator.get_name())
		mesh_indices.append(generator.indice_generator.indices)
		generator.step()
	var name = generator_names[generator_index]
	variant_index = posmod(variant_index, len(meshes))
	call_deferred("update")


func update():
#	VisualServer.set_debug_generate_wireframes(true)
#	get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	$MeshInstance.mesh = generator.get_mesh(meshes[variant_index], transform)
	$UI/VariantIndex.text = "%d (%d)" % [variant_index, len(meshes)]
	$UI/MeshName.text = mesh_names[variant_index]
	$UI/Segments.text = str(segments)


func _on_NextVariant_pressed():
	variant_index = posmod(variant_index + 1, len(meshes))
	update()


func _on_PreviousVariant_pressed():
	variant_index = posmod(variant_index - 1, len(meshes))
	update()


func _on_IncreaseSegments_pressed():
	set_segments(segments + 1)


func _on_DecreaseSegments_pressed():
	if segments > 1:
		set_segments(segments - 1)


func _on_NextMesh_pressed():
	generator_index = posmod(generator_index + 1, len(generator_names))
	set_segments(segments)
	update()


func _on_PreviousMesh_pressed():
	generator_index = posmod(generator_index - 1, len(generator_names))
	set_segments(segments)
	update()
