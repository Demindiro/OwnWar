extends Node


signal shadows_toggled(enabled)
signal floor_mirror_toggled(enabled)

var enable_shadows := false setget set_enable_shadows
var enable_floor_mirror := true setget set_enable_floor_mirror


func set_msaa(value: int) -> void:
	assert(0 <= value)
	assert(value <= Viewport.MSAA_16X)
	var root := get_tree().root
	root.msaa = value
	ProjectSettings.set_setting("rendering/quality/filters/msaa", value)


func get_msaa() -> int:
	return ProjectSettings.get_setting("rendering/quality/filters/msaa")


func enable_shadows(enabled: bool) -> void:
	enable_shadows = enabled


func set_shadow_filter_mode(value: int) -> void:
	assert(0 <= value)
	assert(value <= 2)
	ProjectSettings.set_setting("rendering/quality/shadows/filter_mode", value)


func get_shadow_filter_mode() -> int:
	return ProjectSettings.get_setting("rendering/quality/shadows/filter_mode")


func enable_floor_mirror(enabled: bool) -> void:
	enable_floor_mirror = enabled


func set_enable_shadows(value: bool) -> void:
	enable_shadows = value
	emit_signal("shadows_toggled", value)


func set_enable_floor_mirror(value: bool) -> void:
	enable_floor_mirror = value
	emit_signal("floor_mirror_toggled", value)
