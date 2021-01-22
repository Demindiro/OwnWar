extends ScrollContainer


const Toggle := preload("toggle.gd")
const Option = preload("option.gd")

export var _msaa := NodePath()
export var _shadows := NodePath()
export var _shadow_filter_mode := NodePath()
export var _floor_mirror := NodePath()
export var _vsync := NodePath()
export var _vsync_compositor := NodePath()
export var _fps := NodePath()
export var _borderless_window := NodePath()
export var _fullscreen_window := NodePath()
export var _tonemap_mode := NodePath()

onready var msaa: OptionButton = get_node(_msaa)
onready var shadows: Toggle = get_node(_shadows)
onready var shadow_filter_mode: OptionButton = get_node(_shadow_filter_mode)
onready var floor_mirror: BaseButton = get_node(_floor_mirror)
onready var vsync: BaseButton = get_node(_vsync)
onready var vsync_compositor: BaseButton = get_node(_vsync_compositor)
onready var fps: Range = get_node(_fps)
onready var borderless_window: BaseButton = get_node(_borderless_window)
onready var fullscreen_window: BaseButton = get_node(_fullscreen_window)
onready var tonemap_mode: Option = get_node(_tonemap_mode)


func _ready():
	msaa.selected = OwnWar_Settings.get_msaa()
	shadows.pressed = OwnWar_Settings.enable_shadows
	shadow_filter_mode.selected = OwnWar_Settings.get_shadow_filter_mode()
	floor_mirror.pressed = OwnWar_Settings.enable_floor_mirror
	var e := msaa.connect("item_selected", OwnWar_Settings, "set_msaa")
	assert(e == OK)
	e = shadows.connect("toggled", OwnWar_Settings, "set_enable_shadows")
	assert(e == OK)
	e = shadow_filter_mode.connect("item_selected", OwnWar_Settings, "set_shadow_filter_mode")
	assert(e == OK)
	e = floor_mirror.connect("toggled", OwnWar_Settings, "set_enable_floor_mirror")
	assert(e == OK)

	e = vsync.connect("toggled", OS, "set_use_vsync")
	assert(e == OK)
	e = vsync.connect("pressed", OwnWar_Settings, "set", ["dirty", true])
	assert(e == OK)
	e = vsync_compositor.connect("toggled", OS, "set_vsync_via_compositor")
	assert(e == OK)
	e = vsync_compositor.connect("pressed", OwnWar_Settings, "set", ["dirty", true])
	assert(e == OK)
	e = borderless_window.connect("toggled", OS, "set_borderless_window")
	assert(e == OK)
	e = borderless_window.connect("pressed", OwnWar_Settings, "set", ["dirty", true])
	assert(e == OK)
	e = fullscreen_window.connect("toggled", OS, "set_window_fullscreen")
	assert(e == OK)
	e = fullscreen_window.connect("pressed", OwnWar_Settings, "set", ["dirty", true])
	assert(e == OK)
	e = fps.connect("value_changed", OwnWar_Settings, "set_fps")
	assert(e == OK)
	e = fps.connect("value_changed", self, "_save")
	assert(e == OK)

	e = tonemap_mode.connect("item_selected", OwnWar_Settings, "set_tonemap_mode")
	assert(e == OK)

	shadow_filter_mode.get_parent().visible = OwnWar_Settings.enable_shadows
	vsync.pressed = OS.vsync_enabled
	vsync_compositor.pressed = OS.vsync_via_compositor
	borderless_window.pressed = OS.window_borderless
	fullscreen_window.pressed = OS.window_fullscreen
	fps.value = Engine.target_fps
	tonemap_mode.selected = OwnWar_Settings.tonemap_mode


func _save(_argsplzsadface = null) -> void:
	OwnWar_Settings.call_deferred("save_settings")
