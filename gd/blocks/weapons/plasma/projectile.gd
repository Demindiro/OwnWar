tool
extends Spatial

# TODO
const BLOCK_SCALE := 0.25

const GRAVITY = 9.81
var velocity := Vector3()

export var explosion: PackedScene
var explosion_mask := 1

var damage := 500 * 5000
var radius := 7#3
var team := -1


func _get_property_list() -> Array:
	return [
		{
			"name": "explosion_mask",
			"type": TYPE_INT,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE,
			"hint": PROPERTY_HINT_LAYERS_3D_PHYSICS,
		},
	]


func _ready() -> void:
	if Engine.editor_hint:
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	var old_tr := translation
	translation += velocity * delta
	velocity.y -= GRAVITY * delta

	var state := get_world().direct_space_state
	var result := state.intersect_ray(old_tr, translation)
	if len(result) > 0:
		var collider = result["collider"]
		var pos: Vector3 = result["position"]
		if collider.has_method("raycast"):
			var p = collider.raycast(old_tr, translation - old_tr)
			if p == null:
				return
			# See https://github.com/bulletphysics/bullet3/issues/459, the moment we're inside
			# we can no longer detect the body
			# There may be a crafty workaround to this, but I can't be bothered
			#if p.distance_squared_to(old_tr) > translation.distance_squared_to(old_tr):
			#	return
			pos = p
		explode(pos)


func explode(position: Vector3) -> void:
	queue_free()
	var param := PhysicsShapeQueryParameters.new()
	var shape := SphereShape.new()
	shape.radius = radius * BLOCK_SCALE
	param.set_shape(shape)
	param.transform.origin = position
	param.collision_mask = explosion_mask
	var entities := []
	for result in get_world().direct_space_state.intersect_shape(param):
		var collider = result["collider"]
		if collider.has_method("apply_explosion_damage") and collider.get("team") != team:
			entities.push_back(collider)
	if len(entities) > 0:
		var dmg := damage / len(entities)
		for i in len(entities):
			var e = entities[i]
			# Make sure all damage is applied and somewhat evenly too
			var d := dmg if damage - dmg < i else (dmg + 1)
			e.apply_explosion_damage(position, radius, d)
	var n: Spatial = explosion.instance()
	n.translation = position
	n.radius = radius
	get_tree().current_scene.add_child(n)
