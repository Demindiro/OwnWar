use super::voxel_mesh::VoxelMesh;
use crate::util::{convert_vec, swap_erase, BitArray, VoxelRaycast, AABB};
use euclid::{UnknownUnit, Vector3D};
use gdnative::api::{
	BoxShape, CollisionShape, Engine, MeshInstance, PackedScene, Resource, Script, Spatial,
	VehicleBody, VehicleWheel, OS,
};
use gdnative::prelude::*;
use num_traits::float::FloatConst;
use num_traits::{AsPrimitive, PrimInt};
use std::cell::{Cell, RefCell};
use std::collections::{HashMap, HashSet};
use std::convert::TryInto;
use std::num::{NonZeroU16, NonZeroU32};

type Voxel = Vector3D<u8, UnknownUnit>;

const BLOCK_SCALE: f32 = 0.25;
const MAINFRAME_ID: NonZeroU16 = unsafe { NonZeroU16::new_unchecked(76) };
const DESTROY_BLOCK_EFFECT_SCENE: &str = "res://vehicles/destroy_block_effect.tscn";
const DESTROY_BODY_EFFECT_SCENE: &str = "res://vehicles/destroy_body_effect.tscn";
// TODO port Block in Rust so we don't have to do this for performance
static mut BLOCK_COST_CACHE: Vec<Option<CachedBlock>> = Vec::new();

#[derive(NativeClass)]
#[inherit(VehicleBody)]
#[register_with(Self::register_voxelbody)]
pub struct VoxelBody {
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

	wheels: Vec<Ref<VehicleWheel>>,
	weapons: Vec<Ref<Spatial>>,

	// TODO this is god-awful but it seems there is no other way without access
	// to the ScriptServer (ノಠ益ಠ)ノ彡┻━┻
	ownwar_block_script: Option<Ref<Script>>,

	debug_hit_points: Cell<Vec<Voxel>>,
}

struct InterpolationState {
	previous_transform: Transform,
	current_transform: Transform,
	server_node: Ref<Spatial>,
	client_node: Ref<Spatial>,
}

struct Body {
	offset: Voxel,
	size: Voxel,
	ids: Box<[Option<NonZeroU16>]>,
	health: Box<[Option<NonZeroU16>]>,
	multi_blocks: Vec<Option<MultiBlock>>,
	count: u32,
	anchors: HashMap<Voxel, Vec<Ref<VehicleBody>>>,
	has_mainframe: bool,
	center_of_mass: Vector3,
	total_mass: f32,
	total_cost: u32,
	total_health: u32,
	max_cost: u32,
	max_health: u32,
}

#[derive(Debug)]
struct MultiBlock {
	health: NonZeroU32,
	server_node: Ref<Spatial>,
	client_node: Ref<Spatial>,
	reverse_indices: Box<[Voxel]>,
}

struct CachedBlock {
	health: NonZeroU32,
	cost: NonZeroU32,
}

#[derive(Debug)]
enum Block<'a> {
	Destroyed(NonZeroU16),
	Single(NonZeroU16, NonZeroU16),
	Multi(NonZeroU16, &'a MultiBlock),
}

enum DamageState {
	BodyDestroyed,
	BlocksDestroyed(Vec<MultiBlock>),
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
			.add_property("last_hit_position")
			.with_getter(&Self::last_hit_position)
			.done();
	}

	fn new(owner: TRef<VehicleBody>) -> Self {
		owner.set_as_toplevel(true);
		owner.set("can_sleep", false); // Prevent turrets from locking up

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
				// TODO wtf is this
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

			ownwar_block_script: None,

			debug_hit_points: Cell::new(Vec::new()),
		}
	}

	#[export]
	fn _process(&mut self, _owner: &VehicleBody, _delta: f32) {
		let voxel_mesh = unsafe { self.voxel_mesh.assume_safe() };
		voxel_mesh
			.map_mut(|s, o| {
				if s.dirty() {
					s.generate(&o);
				}
			})
			.unwrap();
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
			let com = body.borrow().center_of_mass * BLOCK_SCALE;
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
				if body.count > 0 {
					let node = Self::instance_effect(DESTROY_BODY_EFFECT_SCENE).unwrap();
					node.set_translation(owner.translation());
					node.set("amount", 4 * body.count);
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
	fn debug_draw(&self, owner: &VehicleBody) {
		let debug = owner.get_node("/root/Debug").unwrap();
		let dhp = self.debug_hit_points.replace(Vec::new());
		let body = self.body().borrow();
		for point in &dhp {
			let point = owner.to_global((point.to_f32() - body.center_of_mass) * BLOCK_SCALE);
			unsafe {
				debug.assume_safe().call(
					"draw_point",
					&[
						point.to_variant(),
						Color::rgb(0.5, 1.0, 0.5).to_variant(),
						(BLOCK_SCALE * 0.55).to_variant(),
					],
				);
			}
		}
		self.debug_hit_points.set(dhp);
	}

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
		let vmi = unsafe { self.voxel_mesh_instance.assume_safe() };
		let mut trf = vmi.transform();
		trf.origin += trf
			.basis
			.xform(self.body.as_ref().unwrap().borrow().center_of_mass * BLOCK_SCALE);
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
		body.total_cost = body.max_cost;
		body.total_health = body.max_health;
		// Drop is needed in case one of the nodes calls a method on us
		drop(body);
		let body = self.body().borrow();
		let middle = body.size.to_f32() * BLOCK_SCALE / 2.0;
		unsafe {
			self.collision_shape_instance.assume_safe().set_translation(
				middle - (body.center_of_mass + Vector3::new(0.5, 0.5, 0.5)) * BLOCK_SCALE,
			);
		}
		unsafe {
			self.collision_shape.assume_safe().set_extents(middle);
		}

		owner.set_global_transform(Transform {
			basis: Basis::identity(),
			origin: (body.center_of_mass + body.offset.to_f32()) * BLOCK_SCALE,
		});

		// We can't drop the body while iterating, so collect all nodes first, then
		// set them up
		let nodes = body
			.iter_multi_blocks()
			.map(|b| {
				(b.reverse_indices.clone(), unsafe {
					b.server_node.assume_safe()
				})
			})
			.collect::<Vec<_>>();
		let offset = body.offset;
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
		if !AABB::new(body.offset.to_i32(), body.size.to_i32()).has_point(position) {
			godot_error!(
				"Position is out of range - body AABB: ({:?}, {:?}), position: {:?}",
				body.offset,
				body.size,
				position
			);
			return;
		}
		let position = convert_vec(position);
		let position = position - body.offset;
		body.add_anchor(position, voxel_body);
		let vb = unsafe { voxel_body.assume_safe() };
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

	#[export]
	#[profiled]
	fn remove_anchor(
		&self,
		owner: TRef<VehicleBody>,
		position: Vector3,
		voxel_body: Ref<VehicleBody>,
	) {
		let mut body = if let Some(ref body) = self.body {
			body.borrow_mut()
		} else {
			godot_error!("Body is not set!");
			return;
		};
		if !AABB::new(body.offset.to_f32(), body.size.to_f32()).has_point(position) {
			godot_error!(
				"Position is out of range - body AABB: ({:?}, {:?}), position: {:?}",
				body.offset,
				body.size,
				position
			);
			return;
		}
		let position = convert_vec(position) - body.offset;
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
					body.remove_anchored_body(
						owner.claim(),
						s,
						voxel_body,
					)
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
			AABB::new(Vector3D::zero(), body.size.to_i32()),
		);
		if raycast.finished() {
			return damage;
		}
		if !AABB::new(
			Vector3D::zero(),
			body.size.to_i32() - Vector3D::new(1, 1, 1),
		)
		.has_point(raycast.voxel())
		{
			// TODO fix the raycast algorithm
			//godot_print!("Raycast started out of bounds! Stepping once...");
			raycast.next();
		}
		drop(body);

		let mut dhp = self.debug_hit_points.replace(Vec::new());
		dhp.clear();

		let mut destroyed_blocks = Vec::new();
		let mut destroy_disconnected = true;
		// TODO rewrite to use proper Iterator functionality
		while !raycast.finished() {
			let voxel = convert_vec(raycast.voxel());

			dhp.push(voxel);

			let mut body = self.body().borrow_mut();
			if let Ok((
				destroyed,
				remaining_damage,
				other_anchor_destroyed,
				is_mainframe,
				destroyed_block,
			)) = body.try_damage_block(voxel, damage)
			{
				let count = body.count;
				let center_of_mass = body.center_of_mass;
				drop(body);
				block_anchor_destroyed |= other_anchor_destroyed;
				damage = remaining_damage;
				if destroyed {
					destroyed_blocks.push(voxel);
					if is_mainframe {
						// The vehicle is done for, no point in continuing
						destroy_disconnected = false;
						unsafe {
							owner.get_parent().unwrap().assume_safe().queue_free();
						}
						// Drop the body, as it may be referenced again by one of the callees
						owner.emit_signal("destroyed", &[]);
						break;
					} else if count == 0 {
						// No more blocks remaining, again, don't bother
						destroy_disconnected = false;
						owner.emit_signal("destroyed", &[]);
						owner.queue_free();
						break;
					} else {
						unsafe {
							self.voxel_mesh
								.assume_safe()
								.map_mut(|s, _| s.remove_block(voxel))
								.unwrap()
						};
						if let Ok(node) = Self::instance_effect(DESTROY_BLOCK_EFFECT_SCENE) {
							node.set_translation((voxel.to_f32() - center_of_mass) * BLOCK_SCALE);
							owner.add_child(node, false);
						}
					}
					if let Some(block) = destroyed_block {
						block.destroy();
					}
				}
				if damage == 0 {
					break;
				}
				if let None = raycast.next() {
					break;
				}
			} else {
				godot_error!("Position is out of bounds! {:?} in {:?}", voxel, body.size);
				break;
			}
		}

		self.debug_hit_points.set(dhp);

		if destroy_disconnected {
			self.destroy_disconnected_blocks(owner, destroyed_blocks, block_anchor_destroyed);
		}
		self.last_hit_position
			.set(convert_vec(raycast.voxel()) - Vector3::new(0.5, 0.5, 0.5));
		damage
	}

	#[export]
	fn can_ray_pass_through(
		&self,
		owner: &VehicleBody,
		origin: Vector3,
		direction: Vector3,
	) -> bool {
		let (origin, direction) = self.global_to_voxel_space(owner, origin, direction);
		let body = self.body().borrow();
		let raycast = VoxelRaycast::start(
			origin + Vector3::new(0.5, 0.5, 0.5), // TODO figure out why +0.5 is needed
			direction,
			AABB::new(Vector3D::zero(), body.size.to_i32()),
		);
		for voxel in raycast {
			if let Ok(Some(block)) = body.try_get_block(voxel) {
				if let Block::Destroyed(_) = block {
					/* pass */
				} else {
					return false;
				}
			}
		}
		true
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
		if let None = self.ownwar_block_script {
			self.ownwar_block_script = unsafe {
				Some(
					block
						.assume_safe()
						.get_script()
						.unwrap()
						.cast::<Script>()
						.unwrap(),
				)
			};
		}

		let mut body = self.body().borrow_mut();

		let position = position.to_i32();
		if !AABB::new(body.offset.to_i32(), body.size.to_i32()).has_point(position) {
			godot_error!(
				"Position out of bounds (Corrupt data?): {:?} is outside {:?} - {:?}",
				position,
				body.offset,
				body.size,
			);
			return;
		}

		let block = unsafe { block.assume_safe() };

		let position = convert_vec(position) - body.offset;
		let is_ally = self.is_ally;
		let interpolation_state = unsafe {
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
		};
		drop(body);

		if let Some(bb) = interpolation_state {
			let bsn = unsafe { bb.server_node.assume_safe() };
			// TODO do this without assume_safe() or unsafe
			if let Some(wheel) = bsn.cast::<VehicleWheel>() {
				self.wheels.push(wheel.claim());
			} else if bsn.has_method("fire") {
				// TODO handle weapons properly
				self.weapons.push(bb.server_node);
			}
			self.interpolation_states.push(bb);
		}
	}

	#[export]
	fn remove_interpolator(&mut self, _owner: &VehicleBody, server_node: Ref<Spatial>) {
		let interp = swap_erase(&mut self.interpolation_states, |e| {
			e.server_node == server_node
		});
		let bsn = if let Ok(interp) = interp {
			unsafe { interp.server_node.assume_safe() }
		} else {
			godot_error!("Interpolation state for {:?} not found!", server_node);
			return;
		};

		if let Some(wheel) = bsn.cast::<VehicleWheel>() {
			if swap_erase(&mut self.wheels, |e| e == &wheel.claim()).is_err() {
				godot_error!("Wheel not present in array!");
			}
		} else if bsn.has_method("fire") {
			// TODO handle weapons properly
			if swap_erase(&mut self.weapons, |e| e == &bsn.claim()).is_err() {
				godot_error!("Weapon not present in array!");
			}
		}
	}

	#[export]
	fn get_block_id(&self, _owner: &VehicleBody, position: Vector3) -> i32 {
		let body = self.body().borrow();
		let position = position.to_i32() - body.offset.to_i32();
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
		body.calculate_mass(self.ownwar_block_script.as_ref().unwrap());
		if body.total_mass == 0.0 {
			godot_error!("Mass is zero!");
			return;
		}
		let center = (body.center_of_mass + Vector3::new(0.5, 0.5, 0.5)) * BLOCK_SCALE;

		let vmi = unsafe { self.voxel_mesh_instance.assume_safe() };
		let pos = vmi.translation();
		vmi.set_translation(pos - center);

		for block in body.iter_multi_blocks() {
			let bsn = unsafe { block.server_node.assume_safe() };
			let pos = bsn.translation() - center;
			bsn.set_translation(pos);
			if let Some(wheel) = bsn.cast::<VehicleWheel>() {
				owner.remove_child(wheel); // Necessary to force VehicleWheel to move
				owner.add_child(wheel, false);
				let angle = pos.z.atan2(pos.x);
				wheel.set(
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

	fn body(&self) -> &RefCell<Body> {
		self.body.as_ref().unwrap()
	}

	fn cost(&self, _owner: TRef<VehicleBody>) -> u32 {
		if let Some(ref body) = self.body {
			body.borrow().total_cost
		} else {
			godot_error!("Body is not set!");
			0
		}
	}

	fn max_cost(&self, _owner: TRef<VehicleBody>) -> u32 {
		if let Some(ref body) = self.body {
			body.borrow().max_cost
		} else {
			godot_error!("Body is not set!");
			0
		}
	}

	fn center_of_mass(&self, _owner: TRef<VehicleBody>) -> Vector3 {
		if let Some(ref body) = self.body {
			body.borrow().center_of_mass * BLOCK_SCALE
		} else {
			godot_error!("Body is not set!");
			Vector3::zero()
		}
	}

	fn aabb(&self, _owner: TRef<VehicleBody>) -> Aabb {
		if let Some(ref body) = self.body {
			let body = body.borrow();
			Aabb {
				position: convert_vec(body.offset),
				size: convert_vec(body.size),
			}
		} else {
			godot_error!("Body is not set!");
			Aabb {
				position: Vector3::zero(),
				size: Vector3::zero(),
			}
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
		let local_origin = owner.to_local(origin) / BLOCK_SCALE + body.center_of_mass;
		let local_direction = owner.to_local(origin + direction) - owner.to_local(origin);
		(local_origin, local_direction)
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
				body.destroy_disconnected_blocks(
					owner.claim(),
					s,
					voxels,
					check_anchors,
				)
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
}

impl InterpolationState {
	fn new(block: TRef<Resource>) -> Option<Self> {
		if let Some(server_node) = block.get("server_node").try_to_object::<Spatial>() {
			let server_node = unsafe {
				server_node
					.assume_safe()
					.duplicate(7)
					.unwrap()
					.assume_safe()
					.cast::<Spatial>()
					.unwrap()
			};
			let client_node = unsafe {
				block
					.get("client_node")
					.try_to_object::<Spatial>()
					.unwrap()
					.assume_safe()
					.duplicate(7)
					.unwrap()
					.assume_safe()
					.cast::<Spatial>()
					.unwrap()
			};
			client_node.set_as_toplevel(true);
			Some(Self {
				server_node: server_node.claim(),
				client_node: client_node.claim(),
				previous_transform: Transform {
					basis: Basis::identity(),
					origin: Vector3::zero(),
				},
				current_transform: Transform {
					basis: Basis::identity(),
					origin: Vector3::zero(),
				},
			})
		} else {
			None
		}
	}

	fn from(server_node: Ref<Spatial>, client_node: Ref<Spatial>) -> Self {
		Self {
			server_node,
			client_node,
			previous_transform: Transform {
				basis: Basis::identity(),
				origin: Vector3::zero(),
			},
			current_transform: Transform {
				basis: Basis::identity(),
				origin: Vector3::zero(),
			},
		}
	}

	fn update(&mut self) {
		self.previous_transform = self.current_transform;
		self.current_transform = unsafe { self.server_node.assume_safe().global_transform() };
	}

	fn interpolate(&self, fraction: f32) {
		// TODO ask for implementation of interpolate_with on godot-rust repo
		// TODO this is stupid but it seems I am too stupid to apply slerp correctly?
		let trf = self
			.previous_transform
			.to_variant()
			.call(
				"interpolate_with",
				&[self.current_transform.to_variant(), fraction.to_variant()],
			)
			.unwrap()
			.try_to_transform()
			.unwrap();
		unsafe { self.client_node.assume_safe().set_global_transform(trf) };
	}
}

impl Body {
	fn new(offset: Voxel, size: Voxel) -> Self {
		use std::iter::repeat;
		let real_size = size.x as usize * size.y as usize * size.z as usize;
		Self {
			offset,
			size,
			ids: repeat(None).take(real_size).collect(),
			health: repeat(None).take(real_size).collect(),
			multi_blocks: Vec::new(),
			anchors: HashMap::new(),
			has_mainframe: false,
			count: 0,
			center_of_mass: Vector3D::zero(),
			total_mass: 0.0,
			total_cost: 0,
			total_health: 0,
			max_cost: 0,
			max_health: 0,
		}
	}

	fn add_block(
		&mut self,
		owner: TRef<VehicleBody>,
		voxel_mesh: &mut VoxelMesh,
		position: Voxel,
		rotation: u8,
		block: TRef<Resource>,
		color: Color,
		state: Option<&TypedArray<i32>>,
		is_ally: bool,
	) -> Option<InterpolationState> {
		let index = if let Ok(index) = self.get_index(position) {
			index
		} else {
			godot_error!(
				"Position out of bounds! {:?} outside {:?}",
				position,
				self.size
			);
			return None;
		};
		if let Some(_) = self.ids[index as usize] {
			godot_error!("Position is already occupied! {:?}", position);
			return None;
		}

		let (id, cached) = add_block_to_cache(block);
		let hp = if let Some(state) = state {
			if let Some(hp) = NonZeroU32::new(state.get(index as i32) as u32) {
				hp
			} else {
				return None;
			}
		} else {
			cached.health
		};
		let cost = cached.cost.get();

		voxel_mesh.add_block(block, color, position, rotation);

		let mut bb = InterpolationState::new(block);

		if id == MAINFRAME_ID {
			if self.has_mainframe {
				godot_error!("Body has two mainframes!");
				// Carry on anyways...
			}
			self.has_mainframe = true;
		}
		self.ids[index as usize] = Some(id);
		self.max_health += hp.get();
		self.max_cost += cost;
		self.count += 1;

		if let Some(ref mut bb) = bb {
			let basis = unsafe {
				block
					.call("rotation_to_basis", &[rotation.to_variant()])
					.try_to_basis()
					.unwrap()
			};
			let origin = Vector3::new(
				position.x as f32 + 0.5,
				position.y as f32 + 0.5,
				position.z as f32 + 0.5,
			) * BLOCK_SCALE;
			let server_node = unsafe { bb.server_node.assume_safe() };
			let client_node = unsafe { bb.client_node.assume_safe() };
			server_node.set_name(format!("S {},{},{}", position.x, position.y, position.z));
			client_node.set_name(format!("C {},{},{}", position.x, position.y, position.z));
			server_node.set_transform(Transform { basis, origin });
			client_node.set_transform(Transform { basis, origin });
			if client_node.has_method("set_color") {
				unsafe { client_node.call("set_color", &[color.to_variant()]) };
			}
			client_node.set("server_node", bb.server_node);
			// TODO add a proper way to detect allied vehicles
			client_node.set(
				"team_color",
				if is_ally {
					Color::rgb(0.0, 0.0, 1.0)
				} else {
					Color::rgb(1.0, 0.0, 0.0)
				},
			);
			owner.add_child(bb.server_node, false);
			owner.add_child(bb.client_node, false);
			let args = VariantArray::new();
			args.push(bb.server_node);
			server_node
				.connect(
					"tree_exiting",
					owner,
					"remove_interpolator",
					args.into_shared(),
					0,
				)
				.unwrap();

			self.health[index as usize] =
				Some(NonZeroU16::new(self.multi_blocks.len() as u16 | 0x8000).unwrap());
			self.multi_blocks.push(Some(MultiBlock {
				health: hp,
				server_node: bb.server_node,
				client_node: bb.client_node,
				reverse_indices: vec![position].into_boxed_slice(),
			}));
		} else {
			self.health[index as usize] = Some(hp.try_into().unwrap());
		}

		bb
	}

	fn try_get_block<T: PrimInt + AsPrimitive<isize>>(
		&self,
		position: Vector3D<T, UnknownUnit>,
	) -> Result<Option<Block>, ()> {
		self.get_index(position).and_then(|i| {
			let i = i as usize;
			if let Some(id) = self.ids[i] {
				if let Some(hp) = self.health[i] {
					if hp.get() & 0x8000 != 0 {
						let index = (hp.get() & 0x7fff) as usize;
						if let Some(ref block) = self.multi_blocks[index] {
							Ok(Some(Block::Multi(id, block)))
						} else {
							godot_error!("Block is already destroyed!");
							// We can recover from this, move on.
							// This won't leak nodes as long as the vehicle itself is destroyed
							//self.multi_blocks[index] = None; // self is immutable :/
							Ok(Some(Block::Destroyed(id)))
						}
					} else {
						Ok(Some(Block::Single(id, hp)))
					}
				} else {
					Ok(Some(Block::Destroyed(id)))
				}
			} else {
				Ok(None)
			}
		})
	}

	fn get_block_health<T: PrimInt + AsPrimitive<isize>>(
		&self,
		position: Vector3D<T, UnknownUnit>,
	) -> u32 {
		if let Ok(Some(block)) = self.try_get_block(position) {
			block.health()
		} else {
			0
		}
	}

	fn iter_multi_blocks(&self) -> impl Iterator<Item = &MultiBlock> {
		self.multi_blocks.iter().filter_map(|s| s.as_ref())
	}

	fn add_anchor(&mut self, position: Voxel, body: Ref<VehicleBody>) {
		self.anchors
			.entry(position)
			.and_modify(|e| e.push(body))
			.or_insert_with(|| vec![body]);
	}

	fn remove_anchor(&mut self, position: Voxel, body: Ref<VehicleBody>) -> bool {
		let mut empty = false;
		let mut found = false;
		self.anchors.entry(position).and_modify(|e| {
			for (i, b) in e.iter().enumerate() {
				if b == &body {
					e.swap_remove(i);
					empty = e.len() == 0;
					found = true;
					return;
				}
			}
		});
		if empty {
			self.anchors.remove(&position);
		}
		found
	}

	fn remove_all_anchors(&mut self, position: Voxel) -> bool {
		self.anchors.remove(&position).map(|_| Some(())).is_some()
	}

	fn remove_anchored_body(
		&mut self,
		owner: Ref<VehicleBody>,
		voxel_mesh: &mut VoxelMesh,
		body: Ref<VehicleBody>,
	) -> Option<DamageState> {
		let mut removed_something = false;
		let mut remove_keys = Vec::new();
		for (k, v) in self.anchors.iter_mut() {
			for i in 0..v.len() {
				if v[i] == body {
					v.swap_remove(i);
					removed_something = true
				}
			}
			if v.len() == 0 {
				remove_keys.push(*k);
			}
		}
		for k in remove_keys {
			self.anchors.remove(&k).unwrap();
		}
		if removed_something {
			Some(self.destroy_disconnected_blocks(
				owner,
				voxel_mesh,
				Vec::new(),
				true,
			))
		} else {
			None
		}
	}

	fn get_index<T: PrimInt + AsPrimitive<isize>>(
		&self,
		position: Vector3D<T, UnknownUnit>,
	) -> Result<u32, ()> {
		let position = convert_vec(position);
		let size = convert_vec(self.size);
		if AABB::new(Vector3D::zero(), size - Vector3D::new(1, 1, 1)).has_point(position) {
			Ok(((position.x * size.y + position.y) * size.z + position.z)
				.try_into()
				.unwrap())
		} else {
			Err(())
		}
	}

	fn calculate_mass(
		&mut self,
		ownwar_block_script: &Ref<Script>, /* TODO this is a shitty hack */
	) {
		let mut total_mass = 0.0;
		let mut center_of_mass = Vector3::zero();
		let size = self.size;
		for (x, y, z) in (0..size.x)
			.flat_map(move |x| (0..size.y).map(move |y| (x, y)))
			.flat_map(move |(x, y)| (0..size.z).map(move |z| (x, y, z)))
		{
			let blk = self.try_get_block(Voxel::new(x, y, z)).unwrap();
			if let Some(blk) = blk {
				let mass = unsafe {
					ownwar_block_script
						.assume_safe()
						.call("get_block", &[blk.id().get().to_variant()])
						.try_to_object::<Resource>()
						.unwrap()
						.assume_safe()
						.get("mass")
						.try_to_f64()
						.unwrap() as f32
				};
				center_of_mass += Vector3::new(x as f32, y as f32, z as f32) * mass;
				total_mass += mass;
			}
		}
		self.total_mass = total_mass;
		self.center_of_mass = center_of_mass / total_mass;
	}

	fn try_damage_block(
		&mut self,
		position: Voxel,
		damage: u32,
	) -> Result<(bool, u32, bool, bool, Option<MultiBlock>), ()> {
		self.get_index(position).and_then(|i| {
			let i = i as usize;
			if let Some(id) = self.ids[i] {
				let is_mainframe = id == MAINFRAME_ID;
				if let Some(hp) = self.health[i] {
					if hp.get() & 0x8000 != 0 {
						let block_index = (hp.get() & 0x7fff) as usize;
						if let Some(ref block) = self.multi_blocks[block_index] {
							let hp = block.health.get();
							if hp <= damage {
								let block = self.multi_blocks[block_index].take().unwrap();
								let damage = damage - hp;
								self.count -= 1;
								self.total_health -= hp;
								self.total_cost -= get_cached_block(id).cost.get();
								let mut anchor_destroyed = false;
								for &pos in block.reverse_indices.iter() {
									self.health[self.get_index(pos).unwrap() as usize] = None;
									anchor_destroyed |= self.remove_all_anchors(pos);
								}
								self.multi_blocks[block_index] = None;
								Ok((true, damage, anchor_destroyed, is_mainframe, Some(block)))
							} else {
								self.multi_blocks[block_index].as_mut().unwrap().health =
									NonZeroU32::new(block.health.get() - damage).unwrap();
								self.total_health -= damage;
								Ok((false, 0, false, is_mainframe, None))
							}
						} else {
							godot_error!("Block was already destroyed!");
							// Try to carry on anyways, we can recover from this
							self.health[i] = None;
							Ok((false, damage, false, is_mainframe, None))
						}
					} else {
						let hp = hp.get() as u32;
						if hp <= damage {
							let damage = damage - hp;
							self.health[i] = None;
							self.count -= 1;
							self.total_health -= hp;
							self.total_cost -= get_cached_block(id).cost.get();
							let mut anchor_destroyed = false;
							let anchor_destroyed = self.remove_all_anchors(position);
							Ok((true, damage, anchor_destroyed, is_mainframe, None))
						} else {
							self.total_health -= damage;
							// unwrap() may seem silly, but the check is worth it
							self.health[i] = Some(NonZeroU16::new((hp - damage) as u16).unwrap());
							Ok((false, 0, false, is_mainframe, None))
						}
					}
				} else {
					Ok((false, damage, false, is_mainframe, None))
				}
			} else {
				Ok((false, damage, false, false, None))
			}
		})
	}

	#[profiled]
	fn destroy_disconnected_blocks(
		&mut self,
		vehicle: Ref<VehicleBody>,
		voxel_mesh: &mut VoxelMesh,
		destroyed_blocks: Vec<Voxel>,
		block_anchor_destroyed: bool,
	) -> DamageState {
		if !self.has_mainframe {
			if self.anchors.len() == 0 {
				return DamageState::BodyDestroyed;
			} else if block_anchor_destroyed {
				if !self.is_connected_to_mainframe(&mut HashSet::new(), vehicle) {
					return DamageState::BodyDestroyed;
				}
			}
		}

		const X: Voxel = Voxel::new(1, 0, 0);
		const Y: Voxel = Voxel::new(0, 1, 0);
		const Z: Voxel = Voxel::new(0, 0, 1);

		let mut destroy_blocks_list = Vec::new();
		let mut marks =
			BitArray::new(self.size.x as usize * self.size.y as usize * self.size.z as usize);
		for voxel in destroyed_blocks {
			let mut connections = Vec::new();
			let mut add_conn_fn = |direction| {
				let voxel = convert_vec(voxel.to_i32() + direction);
				if self.get_block_health(voxel) > 0 {
					connections.push(voxel);
				}
			};
			add_conn_fn(X.to_i32());
			add_conn_fn(-X.to_i32());
			add_conn_fn(Y.to_i32());
			add_conn_fn(-Y.to_i32());
			add_conn_fn(Z.to_i32());
			add_conn_fn(-Z.to_i32());
			while let Some(side_voxel) = connections.pop() {
				let index = self.get_index(side_voxel).unwrap();
				if marks
					.get(self.get_index(side_voxel).unwrap() as usize)
					.unwrap()
				{
					continue;
				}
				let anchor_found = self.mark_connected_blocks(&mut marks, side_voxel, index, false);
				if anchor_found {
					while let Some(side_voxel) = connections.pop() {
						if !marks
							.get(self.get_index(side_voxel).unwrap() as usize)
							.unwrap()
						{
							connections.push(side_voxel);
							break;
						}
					}
				} else {
					self.destroy_connected_blocks(
						&mut Some(voxel_mesh),
						side_voxel,
						index,
						&mut destroy_blocks_list,
					);
				}
			}
		}
		DamageState::BlocksDestroyed(destroy_blocks_list)
	}

	fn mark_connected_blocks(
		&self,
		marks: &mut BitArray,
		voxel: Voxel,
		index: u32,
		mut found: bool,
	) -> bool {
		debug_assert_eq!(index, self.get_index(voxel).unwrap());
		marks.set(index as usize, true).unwrap();
		if !found {
			if self.has_mainframe {
				found = self.ids[index as usize] == Some(MAINFRAME_ID);
			} else {
				found = self.anchors.contains_key(&voxel);
			}
		}
		let size = self.size;
		let cf = |x, y, z, index_offset: i32| {
			let index = index as i32 + index_offset;
			if !marks.get(index as usize).unwrap() && self.health[index as usize] != None {
				let voxel = convert_vec(voxel.to_i32() + Vector3D::new(x, y, z));
				found = self.mark_connected_blocks(marks, voxel, index as u32, found);
			}
		};
		Self::apply_to_all_sides(size, voxel, cf);
		found
	}

	fn destroy_connected_blocks(
		&mut self,
		voxel_mesh: &mut Option<&mut VoxelMesh>,
		voxel: Voxel,
		index: u32,
		destroy_blocks_list: &mut Vec<MultiBlock>,
	) {
		debug_assert_eq!(index, self.get_index(voxel).unwrap());
		debug_assert_ne!(self.health[index as usize], Some(MAINFRAME_ID));
		if let Some(voxel_mesh) = voxel_mesh {
			voxel_mesh.remove_block(voxel);
		}
		self.total_cost -= get_cached_block(self.ids[index as usize].unwrap()).cost.get();
		if let Some(hp) = self.health[index as usize] {
			let hp = hp.get();
			self.health[index as usize] = None;
			self.count -= 1;
			if hp & 0x8000 != 0 {
				let index = hp & 0x7fff;
				let block = self.multi_blocks[index as usize].take();
				if let Some(block) = block {
					self.total_health -= block.health.get() as u32;
					destroy_blocks_list.push(block)
				} else {
					godot_error!("Multi block is None but HP is not zero!");
				}
			} else {
				self.total_health -= hp as u32;
			}
		}
		let size = self.size;
		let cf = |x, y, z, index_offset: i32| {
			let index = index as i32 + index_offset;
			if self.health[index as usize] != None {
				let voxel = convert_vec(voxel.to_i32() + Vector3D::new(x, y, z));
				self.destroy_connected_blocks(
					voxel_mesh,
					voxel,
					index as u32,
					destroy_blocks_list,
				)
			}
		};
		Self::apply_to_all_sides(size, voxel, cf);
	}

	fn apply_to_all_sides(size: Voxel, voxel: Voxel, mut f: impl FnMut(i32, i32, i32, i32)) {
		if voxel.x < size.x - 1 {
			f(1, 0, 0, size.y as i32 * size.z as i32);
		}
		if voxel.x > 0 {
			f(-1, 0, 0, -(size.y as i32 * size.z as i32));
		}
		if voxel.y < size.y - 1 {
			f(0, 1, 0, size.z as i32);
		}
		if voxel.y > 0 {
			f(0, -1, 0, -(size.z as i32));
		}
		if voxel.z < size.z - 1 {
			f(0, 0, 1, 1);
		}
		if voxel.z > 0 {
			f(0, 0, -1, -1);
		}
	}

	fn is_connected_to_mainframe(
		&self,
		marks: &mut HashSet<Ref<VehicleBody>>,
		insert: Ref<VehicleBody>,
	) -> bool {
		marks.insert(insert);
		for (_, nodes) in &self.anchors {
			for node in nodes {
				if marks.contains(&node) {
					continue;
				}
				let instance = unsafe { node.assume_safe().cast_instance::<VoxelBody>().unwrap() };
				let mut mainframe_found = false;
				instance
					.map(|s, o| {
						let body = s.body().borrow();
						if body.has_mainframe || body.is_connected_to_mainframe(marks, o.claim()) {
							mainframe_found = true;
						}
					})
					.unwrap();
				if mainframe_found {
					return true;
				}
			}
		}
		false
	}

	fn serialize_state(&self) -> TypedArray<i32> {
		let size = self.size.to_i32();
		let mut array = TypedArray::new();
		array.resize(size.x * size.y * size.z);
		let mut write = array.write();
		for (i, hp) in self.health.iter().enumerate() {
			if let Some(hp) = hp {
				let hp = hp.get();
				if hp & 0x8000 != 0 {
					if let Some(block) = self.multi_blocks[(hp & 0x7fff) as usize].as_ref() {
						write[i] = block.health.get() as i32;
					} else {
						godot_error!("Block is destroyed but HP is not 0!");
						write[i] = 0;
					}
				} else {
					write[i] = hp as i32;
				}
			} else {
				write[i] = 0;
			}
		}
		drop(write);
		array
	}
}

impl Block<'_> {
	fn id(&self) -> NonZeroU16 {
		match self {
			Block::Destroyed(id) => *id,
			Block::Single(id, _) => *id,
			Block::Multi(id, _) => *id,
		}
	}

	fn health(&self) -> u32 {
		match self {
			Block::Destroyed(_) => 0,
			Block::Single(_, hp) => hp.get() as u32,
			Block::Multi(_, mb) => mb.health.get(),
		}
	}
}

impl MultiBlock {
	fn destroy(self) {
		unsafe {
			let sn = self.server_node.assume_safe();
			let cn = self.client_node.assume_safe();
			sn.queue_free();
			cn.queue_free();
			if sn.has_method("destroy") {
				sn.call("destroy", &[]);
			}
		}
	}
}

fn add_block_to_cache(block: TRef<Resource>) -> (NonZeroU16, &'static CachedBlock) {
	unsafe {
		let id = NonZeroU16::new(block.get("id").try_to_u64().unwrap() as u16).unwrap();
		let index = id.get() as usize - 1;
		if let Some(cached) = BLOCK_COST_CACHE.get(index).and_then(Option::as_ref) {
			(id, cached)
		} else {
			let health = block.get("health").try_to_u64().unwrap() as u32;
			let cost = block.get("cost").try_to_u64().unwrap() as u32;
			let cached = CachedBlock {
				health: NonZeroU32::new(health).unwrap(),
				cost: NonZeroU32::new(cost).unwrap(),
			};
			if BLOCK_COST_CACHE.len() <= index {
				BLOCK_COST_CACHE.resize_with(index + 1, || None);
			}
			BLOCK_COST_CACHE[index] = Some(cached);
			//godot_print!("Cached block {}, cache size: {}", id, BLOCK_COST_CACHE.len());
			(id, BLOCK_COST_CACHE[index].as_ref().unwrap())
		}
	}
}

fn get_cached_block(id: NonZeroU16) -> &'static CachedBlock {
	unsafe {
		BLOCK_COST_CACHE[id.get() as usize - 1].as_ref().unwrap()
	}
}
