extends ScrollContainer


export var _msaa := NodePath()
export var _shadows := NodePath()
export var _shadow_filter_mode := NodePath()
export var _floor_mirror := NodePath()

onready var msaa: OptionButton = get_node(_msaa)
onready var shadows: BaseButton = get_node(_shadows)
onready var shadow_filter_mode: OptionButton = get_node(_shadow_filter_mode)
onready var floor_mirror: BaseButton = get_node(_floor_mirror)


func _ready():
	msaa.selected = OwnWar_Settings.get_msaa()
	shadows.pressed = OwnWar_Settings.enable_shadows
	shadow_filter_mode.selected = OwnWar_Settings.get_shadow_filter_mode()
	floor_mirror.pressed = OwnWar_Settings.enable_floor_mirror
	var e := msaa.connect("item_selected", OwnWar_Settings, "set_msaa")
	assert(e == OK)
	e = msaa.connect("item_selected", self, "_save")
	assert(e == OK)
	e = shadows.connect("toggled", OwnWar_Settings, "set_enable_shadows")
	assert(e == OK)
	e = shadows.connect("toggled", self, "_save")
	assert(e == OK)
	e = shadow_filter_mode.connect("item_selected", OwnWar_Settings, "set_shadow_filter_mode")
	assert(e == OK)
	e = shadow_filter_mode.connect("item_selected", self, "_save")
	assert(e == OK)
	e = floor_mirror.connect("toggled", OwnWar_Settings, "set_enable_floor_mirror")
	assert(e == OK)
	e = floor_mirror.connect("toggled", self, "_save")
	assert(e == OK)
	shadow_filter_mode.get_parent().visible = OwnWar_Settings.enable_shadows


func _save(_argsplzsadface = null) -> void:
	OwnWar_Settings.call_deferred("save_settings")
