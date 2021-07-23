tool
extends Spatial

# TODO
const BLOCK_SCALE := 0.25

const GRAVITY = 9.81

# Reusing shapes of the same size is slightly more efficient
# This dictionary gets cleared whenever the script itself is unloaded.
const SHAPE_CACHE = {}

var velocity := Vector3()

export var explosion: PackedScene
var explosion_mask := 1

export var damage := 500 * 5000
export var radius := 9
var team := -1

var color := Color.purple


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
	var v = get_node("Visual")
	v.material_override.set_shader_param("color", color)
	v = v.get_node("Tracer")
	v.material_override.emission = color
	# Step once to prevent colliding immediately against the shooter in the next frame
	_physics_process(1.0 / Engine.iterations_per_second)


func _physics_process(delta: float) -> void:
	var old_tr := translation
	translation += velocity * delta
	velocity.y -= GRAVITY * delta

	if is_network_master():
		var results = PhysicsServer.space_intersections_with_ray(
			get_world().space,
			old_tr,
			translation,
			true
		)
		while len(results) > 0:
			# Find the closest entry
			var res = results.pop_back()
			var toi = res["time_of_impact"]
			for i in len(results):
				var r = results[i]
				var t = r["time_of_impact"]
				if t < toi:
					results[i] = res
					res = r
					toi = t

			# Check if we should explode
			var col = instance_from_id(res["object_id"])
			var pos: Vector3 = res["position"]
			if col.has_meta("ownwar_vehicle_index"):
				var v = col.get_meta("ownwar_vehicle_list")[col.get_meta("ownwar_vehicle_index")]
				var p = v.raycast(col.get_meta("ownwar_body_index"), old_tr, translation - old_tr)
				if p == null:
					# We hit nothing so continue
					continue
				# See https://github.com/bulletphysics/bullet3/issues/459, the moment we're inside
				# we can no longer detect the body
				# There may be a crafty workaround to this, but I can't be bothered

				# TODO Rapier3D can handle rays inside bodies with the "solid" parameter! We just
				# need to expose it
				# https://docs.rs/rapier3d/0.9.2/rapier3d/pipeline/struct.QueryPipeline.html#method.cast_ray

				#if p.distance_squared_to(old_tr) > translation.distance_squared_to(old_tr):
				#	return
				pos = p

			# Explode & stop iterating
			rpc("explode", pos)
			break


puppetsync func explode(position: Vector3) -> void:
	queue_free()
	if is_network_master():
		var param := PhysicsShapeQueryParameters.new()
		var shape = SHAPE_CACHE.get(radius)
		if shape == null:
			shape = SphereShape.new()
			shape.radius = radius * BLOCK_SCALE
			SHAPE_CACHE[radius] = shape
		param.set_shape(shape)
		param.transform.origin = position
		param.collision_mask = explosion_mask
		var bodies := []
		var vlist
		for result in get_world().direct_space_state.intersect_shape(param):
			var collider = result["collider"]
			if collider.has_meta("ownwar_vehicle_team") and \
				collider.get_meta("ownwar_vehicle_team") != team:
				vlist = collider.get_meta("ownwar_vehicle_list")
				bodies.push_back(collider.get_meta("ownwar_vehicle_index"))
				bodies.push_back(collider.get_meta("ownwar_body_index"))
		var bodies_count := len(bodies) / 2
		if bodies_count > 0:
			var dmg := damage / bodies_count
			var cutoff := damage - dmg * bodies_count
			for i in bodies_count:
				var vi = bodies[i * 2]
				var bi = bodies[i * 2 + 1]
				# Make sure all damage is applied and somewhat evenly too
				var d := (dmg + 1) if i < cutoff else dmg
				vlist[vi].apply_explosion_damage(bi, position, radius, d)

	# Spawn explosion effect
	if !OS.has_feature("Server"):
		var n: Spatial = explosion.instance()
		n.translation = position
		n.radius = radius
		n.color = color
		get_tree().current_scene.add_child(n)
