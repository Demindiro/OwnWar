extends Spatial


const GRAVITY = 9.81
var velocity := Vector3()

export var explosion: PackedScene

var damage := 500
var radius := 3
var team := -1

func _physics_process(delta: float) -> void:
	var old_tr := translation
	translation += velocity * delta
	velocity.y -= GRAVITY * delta

	var state := get_world().direct_space_state
	var result := state.intersect_ray(old_tr, translation)
	if len(result) > 0:
		var collider = result["collider"]
		var pos: Vector3 = result["position"]
		if collider.has_method("apply_explosion_damage"):
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
			if collider.get("team") != team:
				collider.apply_explosion_damage(pos, radius, damage)
		explode(pos)


func explode(position: Vector3) -> void:
	queue_free()
	var n: Spatial = explosion.instance()
	n.translation = position
	get_tree().current_scene.add_child(n)
