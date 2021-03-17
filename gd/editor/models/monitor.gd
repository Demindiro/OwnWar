tool
extends MeshInstance


func _ready():
	material_override.albedo_texture = $Viewport.get_texture()
	material_override.albedo_texture.flags = Texture.FLAG_FILTER
