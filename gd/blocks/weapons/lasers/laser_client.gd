extends Spatial
class_name OwnWar_WeaponLaserClient


export var laser_ray: PackedScene
export var audio_sample_length := 3.0
export var audio_sample_count := 10

var server_node: OwnWar_WeaponLaser setget set_server_node
var team_color setget set_team_color
onready var fire_point: Position3D = get_node("FirePoint")
onready var audio_nodes := [
	get_node("Audio1"),
	get_node("Audio2"),
	get_node("Audio3"),
]
var audio_node_index := 0


func set_server_node(value: OwnWar_WeaponLaser) -> void:
	assert(value != null, "value is null (wrong type passed?)")
	server_node = value
	var e := server_node.connect("fired", self, "_on_fired")
	assert(e == OK)


func set_color(color):
	$Hull.color = color


func set_team_color(color):
	$Glow.color = color
	team_color = color


func _on_fired(at: Vector3) -> void:
	var node: Spatial = laser_ray.instance()
	node.color = team_color
	get_tree().current_scene.add_child(node)
	var g_pos := fire_point.global_transform.origin
	node.translation = g_pos
	node.look_at(at, Vector3.UP)
	node.scale = Vector3(1, 1, g_pos.distance_to(at))
	var audio: AudioStreamPlayer3D = audio_nodes[audio_node_index]
	audio.play(audio_sample_length * (randi() % audio_sample_count))
	audio.get_node("Timer").start(audio_sample_length - 0.1)
	audio_node_index = (audio_node_index + 1) % len(audio_nodes)
