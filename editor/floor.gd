tool
extends Spatial


const GRID_SIZE = preload("editor.gd").GRID_SIZE
onready var _origin: Spatial = $Origin
onready var _mirror: Spatial = $Mirror


func _ready() -> void:
	_origin.translation = -Vector3(1, 0, 1) * (GRID_SIZE / 2.0 - 0.5) + Vector3.UP / 2
	translation = -_origin.translation + Vector3(0.5, 0.5, 0.5)
	_mirror.scale.y = GRID_SIZE
