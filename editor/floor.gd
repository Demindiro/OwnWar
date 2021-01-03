tool
extends Spatial


const GRID_SIZE = preload("editor.gd").GRID_SIZE
var _sprite := Sprite3D.new()
onready var _origin: Spatial = $Origin
onready var _mirror: Spatial = $Mirror


func _ready() -> void:
	_origin.translation = -Vector3(1, 0, 1) * (GRID_SIZE / 2.0 - 0.5) + Vector3.UP / 2
	translation = -_origin.translation + Vector3(0.5, 0.5, 0.5)
	_mirror.scale.y = GRID_SIZE
	_create_floor()


func _create_floor() -> void:
	var size := 16
	_sprite.texture = _generate_texture(size)
	_sprite.pixel_size = 1.0 / size
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, size * GRID_SIZE, size * GRID_SIZE)
	_sprite.pixel_size = 0.0625
	_sprite.axis = Vector3.AXIS_Y
	_sprite.transparent = false
	_sprite.double_sided = false
	add_child(_sprite)


func _generate_texture(size: int) -> Texture:
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
	return img_tex
