extends Sprite3D


const GRID_SIZE = preload("designer.gd").GRID_SIZE


func _ready():
	$Origin.translation = -Vector3(1, 0, 1) * (GRID_SIZE / 2.0 - 0.5) + Vector3.UP / 2
	translation = -$Origin.translation + Vector3(0.5, 0.5, 0.5)
	if texture == null:
		_generate_texture()
	$Mirror.scale.y = GRID_SIZE


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
	texture = ImageTexture.new()
	texture.create_from_image(image)
	texture.flags &= ~Texture.FLAG_FILTER
	texture.flags &= ~Texture.FLAG_MIPMAPS
	texture.flags |= Texture.FLAG_ANISOTROPIC_FILTER
	region_enabled = true
	region_rect = Rect2(0, 0, size * GRID_SIZE, size * GRID_SIZE)
	pixel_size = 1.0 / size
