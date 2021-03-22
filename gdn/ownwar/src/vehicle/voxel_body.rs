use super::body::{Block, Body, DamageState};
use super::interpolation_state::InterpolationState;
use super::voxel_mesh::VoxelMesh;
use crate::block;
use crate::rotation::*;
use crate::util::{convert_vec, swap_erase, VoxelRaycast, VoxelSphereIterator, AABB};
use euclid::{UnknownUnit, Vector3D};
use gdnative::api::{
	BoxShape, CollisionShape, Engine, MeshInstance, PackedScene, PhysicsMaterial, Resource,
	VehicleBody, OS,
};
use gdnative::prelude::*;
use num_traits::float::FloatConst;
use std::cell::{Cell, RefCell};

type Voxel = Vector3D<u8, UnknownUnit>;

const DESTROY_BLOCK_EFFECT_SCENE: &str = "res://vehicles/destroy_block_effect.tscn";
const DESTROY_BODY_EFFECT_SCENE: &str = "res://vehicles/destroy_body_effect.tscn";
const PHYSICS_MATERIAL: &str = "res://vehicles/medium_friction.tres";

const COLLISION_LAYER: u32 = 2;
// Any + Vehicles + Terrain
const COLLISION_MASK: u32 = 1 | 2 | (1 << 7);

#[derive(NativeClass)]
#[inherit(VehicleBody)]
#[register_with(Self::register_voxelbody)]
pub(crate) struct VoxelBody {
	#[property]
	team: u16,
	#[property]
	is_ally: bool,
	#[property]
	id: u8,

	last_hit_position: Cell<Vector3>,

	collision_shape: Ref<BoxShape>,
	collision_shape_instance: Ref<CollisionShape>,

	voxel_mesh: Instance<VoxelMesh, Shared>,
	voxel_mesh_instance: Ref<MeshInstance>,

	interpolation_states: Vec<InterpolationState>,
	interpolation_state_dirty: bool,

	body: Option<RefCell<Body>>,

	wheels: Vec<Ref<Spatial>>,
	weapons: Vec<Ref<Spatial>>,
	thrusters: Vec<Ref<Spatial>>,

	#[cfg(debug_assertions)]
	debug_hit_points: Cell<Vec<Voxel>>,
}

#[methods]
impl VoxelBody {
	fn register_voxelbody(builder: &ClassBuilder<Self>) {
		builder.add_signal(Signal {
			name: "destroyed",
			args: &[],
		});
		builder.add_property("cost").with_getter(&Self::cost).done();
		builder
			.add_property("max_cost")
			.with_getter(&Self::max_cost)
			.done();
		builder
			.add_property("center_of_mass")
			.with_getter(&Self::center_of_mass)
			.done();
		builder.add_property("aabb").with_getter(&Self::aabb).done();
		builder
			.add_property("wheels")
			.with_getter(&Self::wheels)
			.done();
		builder
			.add_property("weapons")
			.with_getter(&Self::weapons)
			.done();
		builder
			.add_property("thrusters")
			.with_getter(&Self::thrusters)
			.done();
		builder
			.add_property("last_hit_position")
			.with_getter(&Self::last_hit_position)
			.done();
	}

	fn new(owner: TRef<VehicleBody>) -> Self {
		owner.set_as_toplevel(true);
		owner.set("can_sleep", false); // Prevent turrets from locking up

		let physics_material = ResourceLoader::godot_singleton()
			.load(PHYSICS_MATERIAL, "PhysicsMaterial", false)
			.and_then(|s| s.cast::<PhysicsMaterial>())
			.unwrap();
		owner.set_physics_material_override(physics_material);
		owner.set_collision_layer(COLLISION_LAYER as i64);
		owner.set_collision_mask(COLLISION_MASK as i64);

		let collision_shape = Ref::<BoxShape, Unique>::new().into_shared();
		let collision_shape_instance = Ref::<CollisionShape, Unique>::new();
		collision_shape_instance.set_shape(collision_shape.clone());
		collision_shape_instance.set_name("Collision box");
		let collision_shape_instance = collision_shape_instance.into_shared();
		owner.add_child(collision_shape_instance, false);

		let voxel_mesh = Instance::<VoxelMesh, Unique>::new().into_shared();
		let voxel_mesh_instance = Ref::<MeshInstance, Unique>::new();
		voxel_mesh_instance.set_mesh(voxel_mesh.base().clone());
		voxel_mesh_instance.set_as_toplevel(true);
		voxel_mesh_instance.set_name("Voxel mesh");
		let voxel_mesh_instance = voxel_mesh_instance.into_shared();
		owner.add_child(voxel_mesh_instance, false);

		let interpolation_states = if OS::godot_singleton().has_feature("Server") {
			owner.set_process(false);
			owner.set_physics_process(false);
			Vec::new()
		} else {
			let mut v = Vec::new();
			v.push(InterpolationState::from(
				owner.upcast::<Spatial>().claim(),
				// FIXME I don't get why a plain upcast won't work
				unsafe {
					voxel_mesh_instance
						.assume_safe()
						.upcast::<Spatial>()
						.claim()
				},
			));
			v
		};

		Self {
			wheels: Vec::new(),
			weapons: Vec::new(),
			thrusters: Vec::new(),

			team: 0,
			is_ally: false,
			id: 0,

			last_hit_position: Cell::new(Vector3::zero()),

			collision_shape,
			collision_shape_instance,

			voxel_mesh,
			voxel_mesh_instance,

			interpolation_states,
			interpolation_state_dirty: true,
			body: None,

			#[cfg(debug_assertions)]
			debug_hit_points: Cell::new(Vec::new()),
		}
	}

	#[export]
	fn _process(&mut self, _owner: &VehicleBody, _delta: f32) {
		unsafe {
			self.voxel_mesh
				.assume_safe()
				.map_mut(|s, o| {
					if s.dirty() {
						s.generate(&o);
					}
				})
				.unwrap();
		}
		if self.interpolation_state_dirty {
			for state in self.interpolation_states.iter_mut() {
				state.update();
			}
		}
		self.interpolation_state_dirty = false;
		let frac = Engine::godot_singleton().get_physics_interpolation_fraction() as f32;
		for state in self.interpolation_states.iter_mut() {
			state.interpolate(frac);
		}
		unsafe {
			let vmi = self.voxel_mesh_instance.assume_safe();
			let trf = vmi.transform();
			let body = self.body.as_ref().unwrap();
			let com = body.borrow().center_of_mass() * block::SCALE;
			vmi.set_translation(trf.origin - trf.basis.xform(com));
		}
	}

	#[export]
	fn _physics_process(&mut self, _owner: &VehicleBody, _delta: f32) {
		self.interpolation_state_dirty = true;
	}

	#[export]
	fn _exit_tree(&self, owner: &VehicleBody) {
		if !OS::godot_singleton().has_feature("Server") {
			if let Some(ref body) = self.body {
				let body = body.borrow();
				if body.count() > 0 {
					let node = Self::instance_effect(DESTROY_BODY_EFFECT_SCENE).unwrap();
					node.set_translation(owner.translation());
					node.set("amount", 4 * body.count());
					unsafe {
						owner
							.get_tree()
							.unwrap()
							.assume_safe()
							.current_scene()
							.unwrap()
							.assume_safe()
							.call_deferred("add_child", &[node.claim().to_variant()]);
					}
				}
			}
		}
	}

	#[export]
	#[cfg(debug_assertions)]
	fn debug_draw(&self, owner: &VehicleBody) {
		let debug = owner.get_node("/root/Debug").unwrap();
		let dhp = self.debug_hit_points.replace(Vec::new());
		let body = self.body().borrow();
		for point in &dhp {
			let point = owner.to_global((point.to_f32() - body.center_of_mass()) * block::SCALE);
			unsafe {
				debug.assume_safe().call(
					"draw_point",
					&[
						point.to_variant(),
						Color::rgb(0.5, 1.0, 0.5).to_variant(),
						(block::SCALE * 0.55).to_variant(),
					],
				);
			}
		}
		self.debug_hit_points.set(dhp);
	}

	#[cfg(not(debug_assertions))]
	fn debug_draw(&self, _owner: &VehicleBody) {}

	#[export]
	fn create_body(&mut self, _owner: &VehicleBody, aabb: Aabb) {
		if let None = self.body {
			self.body = Some(RefCell::new(Body::new(
				convert_vec(aabb.position),
				convert_vec(aabb.size),
			)));
		} else {
			godot_error!("Body is already created!");
		}
	}

	#[export]
	fn get_visual_transform(&self, _owner: &VehicleBody) -> Transform {
		let mut trf = unsafe { self.voxel_mesh_instance.assume_safe().transform() };
		trf.origin += trf
			.basis
			.xform(self.body.as_ref().unwrap().borrow().center_of_mass() * block::SCALE);
		trf
	}

	#[export]
	#[profiled]
	fn init(&self, owner: TRef<VehicleBody>, vehicle: Ref<Spatial>) {
		self.correct_mass(owner.as_ref());
		let mut body = if let Some(ref body) = self.body {
			body.borrow_mut()
		} else {
			godot_error!("No body assigned!");
			return;
		};
		body.total_cost = body.max_cost();
		body.total_health = body.max_health();
		// Drop is needed in case one of the nodes calls a method on us
		drop(body);
		let body = self.body().borrow();
		let middle = body.size().to_f32() * block::SCALE / 2.0;
		unsafe {
			self.collision_shape_instance.assume_safe().set_translation(
				middle - (body.center_of_mass() + Vector3::new(0.5, 0.5, 0.5)) * block::SCALE,
			);
			self.collision_shape.assume_safe().set_extents(middle);
		}

		owner.set_global_transform(Transform {
			basis: Basis::identity(),
			origin: (body.center_of_mass() + body.offset().to_f32()) * block::SCALE,
		});

		// We can't drop the body while iterating, so collect all nodes first, then
		// set them up
		let nodes = unsafe {
			let v = body
				.iter_multi_blocks()
				.map(|b| (b.reverse_indices().clone(), b.server_node.assume_safe()));
			let r = v.collect::<Vec<_>>();
			r
		};
		let offset = body.offset();
		drop(body);

		for (positions, node) in nodes {
			// TODO what about multi-voxel blocks?
			let pos = positions[0];
			node.set("team", self.team);
			if node.has_method("init") {
				let pos = (pos + offset).to_f32();
				unsafe {
					node.call(
						"init",
						&[pos.to_variant(), owner.to_variant(), vehicle.to_variant()],
					)
				};
			}
		}
	}

	#[export]
	fn add_anchor(
		&self,
		owner: TRef<VehicleBody>,
		position: Vector3,
		voxel_body: Ref<VehicleBody>,
	) {
		let mut body = self.body().borrow_mut();
		let position = convert_vec(position);
		if !AABB::new(body.offset().to_i32(), body.size().to_i32()).has_point(position) {
			godot_error!(
				"Position is out of range - body AABB: ({:?}, {:?}), position: {:?}",
				body.offset(),
				body.size(),
				position
			);
			return;
		}
		let position = convert_vec(position);
		let position = position - body.offset();
		body.add_anchor(position, voxel_body);
		unsafe {
			let vb = voxel_body.assume_safe();
			if !vb.is_connected("destroyed", owner, "remove_anchored_body") {
				let args = VariantArray::new();
				args.push(voxel_body);
				let err = vb.connect(
					"destroyed",
					owner,
					"remove_anchored_body",
					args.into_shared(),
					0,
				);
				if err != Ok(()) {
					godot_error!(
						"Failed to connect 'destroyed' signal from {:?} to {:?}",
						voxel_body,
						owner
					);
				}
			}
		}
	}

	#[export]
	#[profiled]
	fn remove_anchor(
		&self,
		owner: TRef<VehicleBody>,
		position: Vector3,
		voxel_body: Ref<VehicleBody>,
	) {
		let mut body = self.body.as_ref().expect("body is not set").borrow_mut();
		if !AABB::new(body.offset().to_f32(), body.size().to_f32()).has_point(position) {
			godot_error!(
				"Position is out of range - body AABB: ({:?}, {:?}), position: {:?}",
				body.offset(),
				body.size(),
				position
			);
			return;
		}
		let position = convert_vec(position) - body.offset();
		let removed = body.remove_anchor(position, voxel_body);
		drop(body);
		if removed {
			self.destroy_disconnected_blocks(owner, vec![position], true);
		}
	}

	#[export]
	#[profiled]
	fn remove_anchored_body(&self, owner: TRef<VehicleBody>, voxel_body: Ref<VehicleBody>) {
		let result = unsafe {
			self.voxel_mesh
				.assume_safe()
				.map_mut(|s, _| {
					let mut body = self.body().borrow_mut();
					body.remove_anchored_body(owner.claim(), s, voxel_body)
				})
				.unwrap()
		};
		if let Some(state) = result {
			match state {
				DamageState::BlocksDestroyed(destroy_blocks) => {
					destroy_blocks.into_iter().for_each(|b| b.destroy());
				}
				DamageState::BodyDestroyed => {
					owner.queue_free();
					owner.emit_signal("destroyed", &[]);
				}
			}
		}
	}

	#[export]
	fn apply_damage(
		&self,
		owner: TRef<VehicleBody>,
		origin: Vector3,
		direction: Vector3,
		damage: u32,
	) -> u32 {
		if !owner.is_network_master() {
			godot_error!("apply_damage is called on a puppet node (don't do that!)");
			return damage;
		}
		let (origin, direction) = self.global_to_voxel_space(&owner, origin, direction);
		self.apply_damage_local(owner, origin, direction, damage)
	}

	#[export(rpc = "puppet")]
	#[profiled]
	fn apply_damage_local(
		&self,
		owner: TRef<VehicleBody>,
		origin: Vector3,
		direction: Vector3,
		mut damage: u32,
	) -> u32 {
		if owner.is_network_master() {
			owner.rpc(
				"apply_damage_local",
				&[
					origin.to_variant(),
					direction.to_variant(),
					damage.to_variant(),
				],
			);
		}

		let body = self.body().borrow();
		let mut block_anchor_destroyed = false;
		let mut raycast = VoxelRaycast::start(
			origin + Vector3::new(0.5, 0.5, 0.5), // TODO figure out why +0.5 is suddenly needed
			direction,
			AABB::new(Vector3D::zero(), body.size().to_i32()),
		);
		if raycast.finished() {
			return damage;
		}
		if !AABB::new(
			Vector3D::zero(),
			body.size().to_i32() - Vector3D::new(1, 1, 1),
		)
		.has_point(raycast.voxel())
		{
			// TODO fix the raycast algorithm
			//godot_print!("Raycast started out of bounds! Stepping once...");
			raycast.next();
		}
		drop(body);

		self.debug_clear_points();

		let mut destroyed_blocks = Vec::new();
		let mut destroy_disconnected = true;
		// TODO rewrite to use proper Iterator functionality
		while !raycast.finished() {
			let voxel = convert_vec(raycast.voxel());

			self.debug_add_point(voxel);

			if let Ok(done) = self.destroy_block(
				owner,
				voxel,
				&mut damage,
				&mut destroy_disconnected,
				&mut block_anchor_destroyed,
				&mut destroyed_blocks,
			) {
				if done || damage == 0 {
					break;
				}
				if let None = raycast.next() {
					break;
				}
			} else {
				break;
			}
		}

		if destroy_disconnected {
			self.destroy_disconnected_blocks(owner, destroyed_blocks, block_anchor_destroyed);
		}
		self.last_hit_position
			.set(convert_vec(raycast.voxel()) - Vector3::new(0.5, 0.5, 0.5));
		damage
	}

	// FIXME can't convert I64 to F32
	#[export]
	fn apply_explosion_damage(
		&self,
		owner: TRef<VehicleBody>,
		origin: Vector3,
		radius: i16,
		damage: u32,
	) -> u32 {
		if !owner.is_network_master() {
			godot_error!("apply_explosion_damage is called on a puppet node (don't do that!)");
			return damage;
		}
		let (origin, _) = self.global_to_voxel_space(&owner, origin, Vector3D::zero());
		self.apply_explosion_damage_local(owner, origin, radius, damage)
	}

	#[export(rpc = "puppet")]
	fn apply_explosion_damage_local(
		&self,
		owner: TRef<VehicleBody>,
		origin: Vector3,
		radius: i16,
		mut damage: u32,
	) -> u32 {
		if owner.is_network_master() {
			owner.rpc(
				"apply_explosion_damage_local",
				&[
					origin.to_variant(),
					radius.to_variant(),
					damage.to_variant(),
				],
			);
		}

		let mut destroy_disconnected = true;
		let mut block_anchor_destroyed = false;
		let mut destroyed_blocks = Vec::new();

		let origin = convert_vec(origin);
		// TODO maybe this should be rounded up (sometimes)?
		// FIXME find an alternative to 'as' that accounts for overflow
		let radius = radius as i16;

		self.debug_clear_points();

		for v in VoxelSphereIterator::new(origin, radius) {
			let body = self.body().borrow();
			if body.is_valid_voxel(v) {
				self.debug_add_point(convert_vec(v));
				drop(body);
				if let Ok(done) = self.destroy_block(
					owner,
					convert_vec(v),
					&mut damage,
					&mut destroy_disconnected,
					&mut block_anchor_destroyed,
					&mut destroyed_blocks,
				) {
					if done || damage == 0 {
						break;
					}
				} else {
					break;
				}
			}
		}

		if destroy_disconnected {
			self.destroy_disconnected_blocks(owner, destroyed_blocks, block_anchor_destroyed);
		}

		damage
	}

	#[export]
	fn raycast(&self, owner: &VehicleBody, origin: Vector3, direction: Vector3) -> Option<Vector3> {
		let (origin, direction) = self.global_to_voxel_space(owner, origin, direction);
		self.raycast_local(origin, direction).map(|pos| {
			self.voxel_to_global_space(owner, convert_vec(pos), Vector3::zero())
				.0
		})
	}

	#[export]
	#[profiled]
	fn spawn_block(
		&mut self,
		owner: TRef<VehicleBody>,
		position: Vector3,
		rotation: u8,
		block: Ref<Resource>,
		color: Color,
		state: Option<TypedArray<i32>>,
	) {
		let rotation = if let Ok(rotation) = Rotation::new(rotation) {
			rotation
		} else {
			godot_error!("Rotation is out of bounds");
			return;
		};

		let mut body = self.body().borrow_mut();

		let position = position.to_i32();
		if !AABB::new(body.offset().to_i32(), body.size().to_i32()).has_point(position) {
			godot_error!(
				"Position out of bounds (Corrupt data?): {:?} is outside {:?} - {:?}",
				position,
				body.offset(),
				body.size(),
			);
			return;
		}

		let position = convert_vec(position) - body.offset();
		let is_ally = self.is_ally;
		let interpolation_state = unsafe {
			block
				.assume_safe()
				.cast_instance::<block::Block>()
				.unwrap()
				.map(|block, _| {
					self.voxel_mesh
						.assume_safe()
						.map_mut(|s, _| {
							body.add_block(
								owner,
								s,
								position,
								rotation,
								block,
								color,
								state.as_ref(),
								is_ally,
							)
						})
						.unwrap()
				})
				.unwrap()
		};
		drop(body);

		if let Some(bb) = interpolation_state {
			unsafe {
				let bsn = bb.server_node.assume_safe();
				if bsn.has_method("set_engine_force") {
					// TODO ditto as below
					self.wheels.push(bb.server_node);
				} else if bsn.has_method("fire") {
					// TODO handle weapons properly
					self.weapons.push(bb.server_node);
				} else if bsn.has_method("apply_drive") {
					// TODO ditto
					self.thrusters.push(bb.server_node);
				}
			}
			self.interpolation_states.push(bb);
		}
	}

	#[export]
	fn remove_interpolator(&mut self, _owner: &VehicleBody, server_node: Ref<Spatial>) {
		let interp = swap_erase(&mut self.interpolation_states, |e| {
			e.server_node == server_node
		});
		unsafe {
			let bsn = interp.unwrap().server_node.assume_safe();
			if bsn.has_method("set_engine_force") {
				swap_erase(&mut self.wheels, |e| e == &bsn.claim())
					.expect("Wheel not present in array!");
			} else if bsn.has_method("fire") {
				// TODO handle weapons properly
				swap_erase(&mut self.weapons, |e| e == &bsn.claim())
					.expect("Weapon not present in array!");
			}
		}
	}

	#[export]
	fn get_block_id(&self, _owner: &VehicleBody, position: Vector3) -> i32 {
		let body = self.body().borrow();
		let position = position.to_i32() - body.offset().to_i32();
		if let Ok(block) = body.try_get_block(position) {
			if let Some(block) = block {
				block.id().get() as i32
			} else {
				0
			}
		} else {
			-1
		}
	}

	#[export]
	fn serialize_state(&self, _owner: &VehicleBody) -> TypedArray<i32> {
		self.body().borrow().serialize_state()
	}

	fn correct_mass(&self, owner: &VehicleBody) {
		let mut body = self.body().borrow_mut();
		body.calculate_mass();
		assert_ne!(body.total_mass, 0.0, "Mass is zero!");

		let center = (body.center_of_mass() + Vector3::new(0.5, 0.5, 0.5)) * block::SCALE;

		unsafe {
			let vmi = self.voxel_mesh_instance.assume_safe();
			vmi.set_translation(vmi.translation() - center);
		}

		for block in body.iter_multi_blocks() {
			let bsn = block.server_node();
			let pos = bsn.translation() - center;
			bsn.set_translation(pos);
			//if let Some(wheel) = bsn.cast::<VehicleWheel>() {
			//	owner.remove_child(wheel); // Necessary to force VehicleWheel to move
			//	owner.add_child(wheel, false);
			if bsn.has_method("set_engine_force") {
				let angle = pos.z.atan2(pos.x);
				//wheel.set(
				bsn.set(
					"max_angle",
					if angle > f32::PI() / 2.0 {
						f32::PI() - angle
					} else if angle < -f32::PI() / 2.0 {
						-f32::PI() - angle
					} else {
						angle
					},
				)
			}
		}

		owner.set_mass(body.total_mass as f64);
	}
}

impl VoxelBody {
	pub(super) fn body(&self) -> &RefCell<Body> {
		self.body.as_ref().expect("body is not set!")
	}

	fn cost(&self, _owner: TRef<VehicleBody>) -> u32 {
		self.body().borrow().total_cost
	}

	fn max_cost(&self, _owner: TRef<VehicleBody>) -> u32 {
		self.body().borrow().max_cost()
	}

	fn center_of_mass(&self, _owner: TRef<VehicleBody>) -> Vector3 {
		self.body().borrow().center_of_mass() * block::SCALE
	}

	fn aabb(&self, _owner: TRef<VehicleBody>) -> Aabb {
		let body = self.body().borrow();
		Aabb {
			position: convert_vec(body.offset()),
			size: convert_vec(body.size()),
		}
	}

	fn wheels(&self, _owner: TRef<VehicleBody>) -> VariantArray {
		let v = VariantArray::new();
		for w in &self.wheels {
			v.push(w.clone());
		}
		v.into_shared()
	}

	fn weapons(&self, _owner: TRef<VehicleBody>) -> VariantArray {
		let v = VariantArray::new();
		for w in &self.weapons {
			v.push(w.clone());
		}
		v.into_shared()
	}

	fn thrusters(&self, _owner: TRef<VehicleBody>) -> VariantArray {
		let v = VariantArray::new();
		for w in &self.thrusters {
			v.push(w.clone());
		}
		v.into_shared()
	}

	fn last_hit_position(&self, _owner: TRef<VehicleBody>) -> Vector3 {
		self.last_hit_position.get()
	}

	fn instance_effect(path: &str) -> Result<TRef<Spatial, Shared>, ()> {
		ResourceLoader::godot_singleton()
			.load(path, "PackedScene", false)
			.and_then(|s| unsafe { s.assume_thread_local().cast::<PackedScene>() })
			.and_then(|s| s.instance(0))
			.and_then(|s| unsafe { s.assume_safe().cast::<Spatial>() })
			.ok_or(())
	}

	fn global_to_voxel_space(
		&self,
		owner: &VehicleBody,
		origin: Vector3,
		direction: Vector3,
	) -> (Vector3, Vector3) {
		let body = self.body().borrow();
		let local_unscaled_origin = owner.to_local(origin);
		let local_origin = local_unscaled_origin / block::SCALE + body.center_of_mass();
		let local_direction = owner.to_local(origin + direction) - local_unscaled_origin;
		(local_origin, local_direction)
	}

	fn voxel_to_global_space(
		&self,
		owner: &VehicleBody,
		origin: Vector3,
		direction: Vector3,
	) -> (Vector3, Vector3) {
		let body = self.body().borrow();
		let local_unscaled_origin = (origin - body.center_of_mass()) * block::SCALE;
		let global_origin = owner.to_global(local_unscaled_origin);
		let global_direction = owner.to_global(origin + direction) - global_origin;
		(global_origin, global_direction)
	}

	#[profiled]
	fn destroy_disconnected_blocks(
		&self,
		owner: TRef<VehicleBody>,
		voxels: Vec<Voxel>,
		check_anchors: bool,
	) {
		let vm = unsafe { self.voxel_mesh.assume_safe() };
		let result = vm
			.map_mut(|s, _| {
				let mut body = self.body().borrow_mut();
				body.destroy_disconnected_blocks(owner.claim(), s, voxels, check_anchors)
			})
			.unwrap();
		match result {
			DamageState::BlocksDestroyed(destroy_blocks) => {
				destroy_blocks.into_iter().for_each(|e| e.destroy());
			}
			DamageState::BodyDestroyed => {
				owner.queue_free();
				owner.emit_signal("destroyed", &[]);
			}
		}
	}

	fn destroy_block(
		&self,
		owner: TRef<VehicleBody>,
		voxel: Voxel,
		damage: &mut u32,
		destroy_disconnected: &mut bool,
		block_anchor_destroyed: &mut bool,
		destroyed_blocks: &mut Vec<Voxel>,
	) -> Result<bool, ()> {
		let mut body = self.body().borrow_mut();
		if let Ok((
			destroyed,
			remaining_damage,
			other_anchor_destroyed,
			is_mainframe,
			destroyed_block,
		)) = body.try_damage_block(voxel, *damage)
		{
			let count = body.count();
			let center_of_mass = body.center_of_mass();
			drop(body);
			*block_anchor_destroyed |= other_anchor_destroyed;
			*damage = remaining_damage;
			if destroyed {
				destroyed_blocks.push(voxel);
				if is_mainframe {
					// The vehicle is done for, no point in continuing
					*destroy_disconnected = false;
					unsafe {
						owner.get_parent().unwrap().assume_safe().queue_free();
					}
					// Drop the body, as it may be referenced again by one of the callees
					owner.emit_signal("destroyed", &[]);
					return Ok(true);
				} else if count == 0 {
					// No more blocks remaining, again, don't bother
					*destroy_disconnected = false;
					owner.emit_signal("destroyed", &[]);
					owner.queue_free();
					return Ok(true);
				} else {
					unsafe {
						self.voxel_mesh
							.assume_safe()
							.map_mut(|s, _| s.remove_block(voxel))
							.unwrap()
					};
					if let Ok(node) = Self::instance_effect(DESTROY_BLOCK_EFFECT_SCENE) {
						node.set_translation((voxel.to_f32() - center_of_mass) * block::SCALE);
						owner.add_child(node, false);
					}
				}
				if let Some(block) = destroyed_block {
					block.destroy();
				}
			}
			Ok(false)
		} else {
			godot_error!(
				"Position is out of bounds! {:?} in {:?}",
				voxel,
				body.size()
			);
			Err(())
		}
	}

	fn raycast_local(&self, origin: Vector3, direction: Vector3) -> Option<Voxel> {
		let body = self.body().borrow();
		let raycast = VoxelRaycast::start(
			origin + Vector3::new(0.5, 0.5, 0.5), // TODO figure out why +0.5 is needed
			direction,
			AABB::new(Vector3D::zero(), body.size().to_i32()),
		);
		for (voxel, _) in raycast {
			if let Ok(Some(block)) = body.try_get_block(voxel) {
				if let Block::Destroyed(_) = block {
					/* pass */
				} else {
					return Some(convert_vec(voxel));
				}
			}
		}
		None
	}

	#[cfg(debug_assertions)]
	fn debug_add_point(&self, point: Voxel) {
		let mut dhp = self.debug_hit_points.replace(Vec::new());
		dhp.push(point);
		self.debug_hit_points.set(dhp);
	}

	#[cfg(debug_assertions)]
	fn debug_clear_points(&self) {
		self.debug_hit_points.set(Vec::new());
	}

	#[cfg(not(debug_assertions))]
	fn debug_add_point(&self, _point: Voxel) {}

	#[cfg(not(debug_assertions))]
	fn debug_clear_points(&self) {}
}
