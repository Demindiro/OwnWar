extends Sprite3D


const GRID_SIZE = preload("designer.gd").GRID_SIZE
onready var _origin: Spatial = $Origin
onready var _mirror: Spatial = $Mirror


func _ready():
	_origin.translation = -Vector3(1, 0, 1) * (GRID_SIZE / 2.0 - 0.5) + Vector3.UP / 2
	translation = -_origin.translation + Vector3(0.5, 0.5, 0.5)
	if texture == null:
		_generate_texture()
	_mirror.scale.y = GRID_SIZE


func _generate_texture():
	var size = 16
	var image = Image.new()
	image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.black)
	image.lock()
	for i in range(size):
		image.set_pixel(i, 0, Color.cyan)
		image.set_pixel(0, i, Color.cyan)
		image.set_pixel(i, size - 1, Color.cyan)
		image.set_pixel(size - 1, i, Color.cyan)
	image.unlock()
	var img_tex := ImageTexture.new()
	img_tex.create_from_image(image)
	img_tex.flags &= ~Texture.FLAG_FILTER
	img_tex.flags &= ~Texture.FLAG_MIPMAPS
	img_tex.flags |= Texture.FLAG_ANISOTROPIC_FILTER
	texture = img_tex
	region_enabled = true
	region_rect = Rect2(0, 0, size * GRID_SIZE, size * GRID_SIZE)
	pixel_size = 1.0 / size
