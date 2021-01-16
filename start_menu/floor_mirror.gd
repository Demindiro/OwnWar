tool
extends MeshInstance


onready var floor_cam: Camera = $"../Viewport/Camera"
onready var floor_viewport: Viewport = $"../Viewport"
onready var parent_viewport: Viewport = get_tree().root


func _ready() -> void:
	floor_cam.set_as_toplevel(true)
	var e := OwnWar_Settings.connect("floor_mirror_toggled", self, "enable_mirror")
	assert(e == OK)
	enable_mirror(OwnWar_Settings.enable_floor_mirror)


func _process(_delta) -> void:
	var main_cam := parent_viewport.get_camera()
	if main_cam == null:
		# Goddamnit Godot
		return

	var cam_pos := main_cam.translation
	var proj_pos := Vector3(cam_pos.x, 0, cam_pos.z)
	var mirror_pos := Vector3(cam_pos.x, -cam_pos.y, cam_pos.z)

	var trf := Transform(Basis(), mirror_pos)
	floor_cam.transform = trf.looking_at(proj_pos, Vector3.RIGHT)

	var offset := Vector2(-cam_pos.z, cam_pos.x)

	floor_cam.set_frustum(20, -offset, proj_pos.distance_to(cam_pos), 100.0)


func enable_mirror(enable: bool) -> void:
	if enable:
		material_override.albedo_texture = floor_viewport.get_texture()
		floor_viewport.render_target_update_mode = Viewport.UPDATE_WHEN_VISIBLE
		set_process(true)
	else:
		material_override.albedo_texture = null
		floor_viewport.render_target_update_mode = Viewport.UPDATE_DISABLED
		set_process(false)
