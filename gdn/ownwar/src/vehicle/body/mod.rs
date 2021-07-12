mod damage;
mod debug;
mod godot;
mod init;
#[cfg(not(feature = "server"))]
mod mesh;
mod multi_block;
mod packet;
mod serialize;
mod util;
mod visual;

pub(super) use damage::DamageEvent;
pub(super) use multi_block::MultiBlock;

#[cfg(not(feature = "server"))]
use super::interpolation_state::InterpolationState;
#[cfg(not(feature = "server"))]
use super::voxel_mesh::VoxelMesh;
use super::*;
use crate::block;
use crate::rotation::*;
use crate::util::*;
#[cfg(debug_assertions)]
use core::cell::Cell;
use core::mem;
use euclid::{UnknownUnit, Vector3D};
#[cfg(not(feature = "server"))]
use gdnative::api::MeshInstance;
use gdnative::api::{BoxShape, CollisionShape, VehicleBody};
use gdnative::prelude::*;
use num_traits::{AsPrimitive, PrimInt};
use std::convert::{TryFrom, TryInto};
use std::num::{NonZeroU16, NonZeroU32};

type Voxel = Vector3D<u8, UnknownUnit>;

const MAINFRAME_ID: NonZeroU16 = unsafe { NonZeroU16::new_unchecked(76) };

const COLLISION_LAYER: u32 = 2;
// Any + Vehicles + Terrain
const COLLISION_MASK: u32 = 1 | 2 | (1 << 7);

pub(super) struct Body {
	// TODO don't make this public
	node: Option<Ref<VehicleBody>>,
	#[cfg(not(feature = "server"))]
	voxel_mesh: Option<Instance<VoxelMesh, Shared>>,
	#[cfg(not(feature = "server"))]
	voxel_mesh_instance: Option<Ref<MeshInstance>>,
	collision_shape: Ref<BoxShape>,
	collision_shape_instance: Option<Ref<CollisionShape>>,

	#[cfg(not(feature = "server"))]
	interpolation_states: Vec<Option<InterpolationState>>,
	#[cfg(not(feature = "server"))]
	interpolation_state_dirty: bool,

	offset: Voxel,
	size: Voxel,

	/// The ID of each block of this body. Multiblocks use only one spot.
	ids: Box<[Option<NonZeroU16>]>,
	/// The health of each block. The upper bit indicates whether it points
	/// to a multiblock or if it is a regular single block.
	health: Box<[Option<NonZeroU16>]>,
	/// All multiblocks.
	multi_blocks: Vec<Option<MultiBlock>>,
	/// The color of each block. Needed for serialization.
	colors: Box<[u8]>,
	/// The rotation of each blocks. Needed for serialization.
	rotations: Box<[Rotation]>,

	center_of_mass: Vector3,
	mass: f32,
	cost: u32,
	max_cost: u32,

	#[cfg(debug_assertions)]
	debug_hit_points: Cell<Vec<Voxel>>,

	/// Damage events to be applied.
	damage_events: Vec<DamageEvent>,

	/// Bodies connected to this vehicle.
	children: Vec<Self>,

	/// Anchors connecting this body to it's parent.
	///
	/// This has one entry if it is the main body: the mainframe. The mainframe
	/// is not a real anchor but pretending it is one simplifies things quite a bit.
	parent_anchors: Vec<Voxel>,
}

pub(super) enum Block<'a> {
	Destroyed(NonZeroU16),
	Single(NonZeroU16, NonZeroU16),
	Multi(NonZeroU16, &'a MultiBlock),
}

/// Enum returned when an error occurs during `init_all`
#[derive(Debug)]
pub enum InitError {
	/// One of the anchors causes a body cycle.
	CyclicAnchor,
	/// There are multiple bodies connected to the same anchor.
	MultipleBodiesPerAnchor,
}

impl Body {
	// TODO remove the "visible" argument, it's redundant now the "server" feature is a thing.
	pub fn new(aabb: AABB<u8>, visible: bool) -> Self {
		let (offset, size) = (aabb.position, aabb.size);

		let _ = visible; // Make it shut up for now.

		use std::iter::repeat;
		let real_size = (size.x + 1) as usize * (size.y + 1) as usize * (size.z + 1) as usize;

		let mut slf = Self {
			node: None,
			#[cfg(not(feature = "server"))]
			voxel_mesh: visible.then(Self::create_voxel_mesh),
			#[cfg(not(feature = "server"))]
			voxel_mesh_instance: None,
			collision_shape: Self::create_collision_shape(),
			collision_shape_instance: None,

			#[cfg(not(feature = "server"))]
			interpolation_states: Vec::new(),
			#[cfg(not(feature = "server"))]
			interpolation_state_dirty: true,

			offset,
			size,
			ids: repeat(None).take(real_size).collect(),
			health: repeat(None).take(real_size).collect(),
			multi_blocks: Vec::new(),
			colors: repeat(0).take(real_size).collect(),
			rotations: repeat(Rotation::new(0).unwrap()).take(real_size).collect(),

			center_of_mass: Vector3D::zero(),
			mass: 0.0,
			cost: 0,
			max_cost: 0,

			#[cfg(debug_assertions)]
			debug_hit_points: Cell::new(Vec::new()),

			damage_events: Vec::new(),

			children: Vec::new(),

			parent_anchors: Vec::new(),
		};

		slf.create_godot_nodes();

		slf
	}

	pub fn init_all(
		bodies: &mut [Option<Self>],
		shared: &mut vehicle::Shared,
	) -> Result<Self, InitError> {
		const BODY_TREE: Vec<u8> = Vec::new();
		let mut body_tree = [BODY_TREE; 256];
		let mut parent = None;

		// Find the body with the mainframe.
		for (i, b) in bodies.iter().enumerate() {
			if let Some(b) = b {
				if !b.parent_anchors.is_empty() {
					assert!(parent.is_none(), "Multiple mainframes");
					parent = Some(u8::try_from(i).unwrap());
				}
			}
		}
		assert!(parent.is_some(), "No mainframe");

		// Setup total cost, health ... & find special blocks.
		for i in 0..u8::try_from(bodies.len()).unwrap() {
			let (left, right) = bodies.split_at_mut(i.into());
			let (body, right) = right.split_at_mut(1);

			if let Some(body) = &mut body[0] {
				body.correct_mass();
				body.cost = body.max_cost();
				let middle = (body.size().to_f32() + Vector3::one()) * block::SCALE / 2.0;
				unsafe {
					body.collision_shape_instance
						.unwrap()
						.assume_safe()
						.set_translation(
							middle
								- (body.center_of_mass() + Vector3::new(0.5, 0.5, 0.5))
									* block::SCALE,
						);
					body.collision_shape.assume_safe().set_extents(middle);
				}

				for block in body.multi_blocks.iter_mut().filter_map(Option::as_mut) {
					block.init(body.offset, shared);
					if let Some(server_node) = block.server_node.as_ref() {
						let server_node = unsafe { server_node.assume_safe() };

						// Check if the block is an anchor
						if !server_node.get("anchor_index").is_nil() {
							let anchor_bodies = VariantArray::new();
							let parent_anchors = &mut body_tree[usize::from(i)];

							'find_mount: for mount in server_node
								.get("anchor_mounts")
								.to_vector3_array()
								.read()
								.iter()
							{
								let mount = convert_vec::<_, i16>(block.base_position)
									+ convert_vec(
										block
											.rotation
											.basis()
											.to_quat()
											.transform_vector3d(*mount)
											.round(),
									) + convert_vec(body.offset);
								let mount = mount.x.try_into().and_then(|x| {
									mount.y.try_into().and_then(|y| {
										mount.z.try_into().map(|z| Voxel::new(x, y, z))
									})
								});
								let mount = match mount {
									Ok(m) => m,
									Err(_) => continue,
								};

								let iter = left.iter_mut().enumerate().chain(
									right
										.iter_mut()
										.enumerate()
										.map(move |(k, v)| (k + usize::from(i) + 1, v)),
								);
								for (k, b) in iter {
									let k = u8::try_from(k).unwrap();
									if let Some(b) = b {
										let m =
											convert_vec::<_, i16>(mount) - convert_vec(b.offset);
										let m = m.x.try_into().and_then(|x| {
											m.y.try_into().and_then(|y| {
												m.z.try_into().map(|z| Voxel::new(x, y, z))
											})
										});
										let m = match m {
											Ok(m) => m,
											Err(_) => continue,
										};
										if let Ok(Some(_)) = b.try_get_block(m) {
											b.parent_anchors.push(m);
											if parent_anchors.iter().find(|b| **b == k).is_none() {
												parent_anchors.push(k);
												if block.set_anchored_body(k).is_err() {
													return Err(InitError::MultipleBodiesPerAnchor);
												}
											};
											anchor_bodies.push(b.node);
											break 'find_mount;
										}
									}
								}
							}

							server_node.set(
								"anchor_mounts_bodies",
								anchor_bodies.into_shared().to_variant(),
							);
						}
					}
				}
			}
		}

		// Ensure the bodies can't collide with each other for performance and to avoid funky
		// glitches due to colliders being approximations.
		for a in bodies.iter().filter_map(Option::as_ref) {
			for b in bodies.iter().filter_map(Option::as_ref) {
				unsafe {
					a.node
						.unwrap()
						.assume_safe()
						.add_collision_exception_with(b.node.unwrap());
				}
			}
		}

		// Create the body tree.
		fn add_children(
			bodies: &mut [Option<Body>],
			anchors: &mut [Vec<u8>],
			parent: &mut Body,
			tree: Vec<u8>,
		) -> Result<(), InitError> {
			unsafe {
				parent
					.node
					.unwrap()
					.assume_safe()
					.set_translation(Vector3::zero())
			};
			let mut rev_body_map = [0xff; 256]; // 0xff is easier to spot as "wrong"
									//for i in tree.into_iter() {
			for i in tree.iter().copied() {
				let i = usize::from(i);
				if let Some(mut child) = bodies[i].take() {
					let bte = mem::take(&mut anchors[i]);
					unsafe {
						debug_assert!(child.node.unwrap().assume_safe().get_parent().is_none());
						parent
							.node
							.unwrap()
							.assume_safe()
							.add_child(&child.node.unwrap(), false);
					}
					add_children(bodies, anchors, &mut child, bte)?;
					rev_body_map[i] = parent.children.len().try_into().unwrap();
					parent.children.push(child);
				} else {
					return Err(InitError::CyclicAnchor);
				}
			}
			for mb in parent.multi_blocks.iter_mut().filter_map(Option::as_mut) {
				if let Some(i) = mb.anchor_body_index.map(usize::from) {
					// The assert may trigger false positives in extreme cases, hence why it's
					// debug only
					debug_assert_ne!(rev_body_map[i], 0xff);
					mb.anchor_body_index = Some(rev_body_map[i]);
				}
			}
			Ok(())
		}

		let parent = usize::from(parent.unwrap());
		let mut body = bodies[parent].take().unwrap();
		let bte = mem::take(&mut body_tree[parent]);
		add_children(bodies, &mut body_tree, &mut body, bte)?;
		Ok(body)
	}

	/// Apply damage events. This should be called before `step`
	///
	/// Returns `true` if the body is destroyed.
	#[must_use]
	pub fn apply_damage(&mut self, shared: &mut vehicle::Shared) -> bool {
		// Iterate the children first to ensure damage events are cleared
		// (important for determinism).
		self.children_mut().for_each(|b| {
			let _ = b.apply_damage(shared);
		});
		if self.apply_damage_events(shared) {
			self.destroy(shared);
			true
		} else {
			false
		}
	}

	/// Step this & it's children.
	pub fn step(&mut self) {
		// Indicate that interpolation should update the next position.
		#[cfg(not(feature = "server"))]
		{
			self.interpolation_state_dirty = true;
		}

		self.children.iter_mut().for_each(Self::step);
	}

	pub fn node(&self) -> Option<&Ref<VehicleBody>> {
		self.node.as_ref()
	}

	pub fn add_block(
		&mut self,
		shared: &mut vehicle::Shared,
		position: Voxel,
		rotation: Rotation,
		block_id: NonZeroU16,
		color: u8,
	) {
		let position = position - self.offset;

		let index = if let Ok(index) = self.get_index(position) {
			index
		} else {
			godot_error!(
				"Position out of bounds! {:?} outside {:?}",
				position,
				self.size
			);
			return;
		};

		if self.ids[index as usize].is_some() {
			godot_error!("Position is already occupied! {:?}", position);
			return;
		}

		let block = block::Block::get(block_id).expect("Invalid block ID");

		self.ids[index as usize] = Some(block.id);
		self.rotations[index as usize] = rotation;
		self.colors[index as usize] = color;

		if block.is_multi_block() {
			let i: u16 = self
				.multi_blocks
				.len()
				.try_into()
				.expect("Too many multiblocks");
			self.health[index as usize] = NonZeroU16::new(0x8000 | i);
			self.multi_blocks.push(Some(MultiBlock {
				health: block.health,
				server_node: None,
				#[cfg(not(feature = "server"))]
				client_node: None,
				reverse_indices: Box::new([]),
				#[cfg(not(feature = "server"))]
				interpolation_state_index: u16::MAX,
				base_position: Voxel::new(u8::MAX, u8::MAX, u8::MAX),
				rotation: Rotation::new(0).unwrap(),

				weapon_index: u16::MAX,
				turret_index: u16::MAX,
				movement_index: u16::MAX,
				steppable_index: u16::MAX,
				saveable_index: u16::MAX,
				temporary_index: u16::MAX,
				permanent_index: u16::MAX,

				anchor_body_index: None,
			}));
		} else {
			self.health[index as usize] = Some(block.health.try_into().unwrap());
		}

		self.init_block(shared, position);
	}

	pub fn try_get_block<T: PrimInt + AsPrimitive<isize>>(
		&self,
		position: Vector3D<T, UnknownUnit>,
	) -> Result<Option<Block>, ()> {
		self.get_index(position).and_then(|i| {
			let i = i as usize;
			if let Some(id) = self.ids[i] {
				if let Some(hp) = self.health[i] {
					if hp.get() & 0x8000 != 0 {
						let index = (hp.get() & 0x7fff) as usize;
						debug_assert!(self.multi_blocks[index].is_some());
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

	fn get_index<T: PrimInt + AsPrimitive<isize>>(
		&self,
		position: Vector3D<T, UnknownUnit>,
	) -> Result<u32, ()> {
		let position = convert_vec(position);
		let size = convert_vec(self.size);
		if AABB::new(Vector3D::zero(), size).has_point(position) {
			Ok(
				((position.x * (size.y + 1) + position.y) * (size.z + 1) + position.z)
					.try_into()
					.unwrap(),
			)
		} else {
			Err(())
		}
	}

	pub fn is_valid_voxel<T: PrimInt + AsPrimitive<isize>>(
		&self,
		position: Vector3D<T, UnknownUnit>,
	) -> bool {
		self.get_index(position) != Err(())
	}

	pub fn calculate_mass(&mut self) {
		let mut total_mass = 0.0;
		// TODO temporary for now to make sure vehicles are synced correctly
		let mut substract_mass = 0.0;
		let mut center_of_mass = Vector3::zero();
		let size = self.size;
		for (x, y, z) in (0..=size.x)
			.flat_map(move |x| (0..=size.y).map(move |y| (x, y)))
			.flat_map(move |(x, y)| (0..=size.z).map(move |z| (x, y, z)))
		{
			let blk = self.try_get_block(Voxel::new(x, y, z)).unwrap();
			if let Some(blk) = blk {
				let mass = block::Block::get(blk.id()).unwrap().mass;
				center_of_mass += Vector3::new(x as f32, y as f32, z as f32) * mass;
				total_mass += mass;
				if blk.health() == 0 {
					substract_mass += mass;
				}
			}
		}
		self.mass = total_mass - substract_mass;
		self.center_of_mass = center_of_mass / total_mass;
	}

	pub fn size(&self) -> Voxel {
		self.size
	}

	pub fn center_of_mass(&self) -> Vector3 {
		self.center_of_mass
	}

	pub fn max_cost(&self) -> u32 {
		self.max_cost
	}

	#[track_caller]
	pub fn position(&self) -> (Vector3, Quat) {
		self.node().map(|n| {
			let trf = unsafe { n.assume_safe().transform() };
			(trf.origin, trf.basis.to_quat())
		}).unwrap_or((Vector3::zero(), Quat::identity()))
	}

	pub fn set_position(&self, translation: Vector3, rotation: Quat) {
		// FIXME for whatever reason I need to invert the rotation every time ??
		// Not sure if it's a bug in to_transform, need to check.
		let trf = rotation.to_transform().then_translate(translation);
		unsafe {
			self.node()
				.map(|b| b.assume_safe().set_transform(Transform::from_transform(&trf)));
		}
	}

	pub fn linear_velocity(&self) -> Vector3 {
		unsafe { self.node().map(|b| b.assume_safe().linear_velocity()).unwrap_or(Vector3::zero()) }
	}

	pub fn set_linear_velocity(&self, velocity: Vector3) {
		unsafe { self.node().map(|b| b.assume_safe().set_linear_velocity(velocity)); }
	}

	pub fn angular_velocity(&self) -> Vector3 {
		unsafe { self.node().map(|b| b.assume_safe().angular_velocity()).unwrap_or(Vector3::zero()) }
	}

	pub fn set_angular_velocity(&self, velocity: Vector3) {
		unsafe { self.node().map(|b| b.assume_safe().set_angular_velocity(velocity)); }
	}

	pub fn aabb(&self) -> AABB<u8> {
		AABB::new(self.offset, self.size)
	}

	/// Return the total cost of all blocks of this body.
	pub fn cost(&self) -> u32 {
		self.cost
	}

	pub fn children(&self) -> impl Iterator<Item = &Self> {
		self.children.iter()
	}

	pub fn children_mut(&mut self) -> impl Iterator<Item = &mut Self> {
		self.children.iter_mut()
	}

	/// Iterate all children and subchildren of this body
	///
	/// This includes the body itself.
	pub fn iter_all_bodies(&self, f: &mut impl FnMut(&Self)) {
		f(self);
		self.children().for_each(|b| b.iter_all_bodies(f));
	}

	/// Iterate all children and subchildren of this body
	///
	/// This includes the body itself.
	pub fn iter_all_bodies_mut(&mut self, f: &mut impl FnMut(&mut Self)) {
		f(self);
		self.children_mut().for_each(|b| b.iter_all_bodies_mut(f));
	}

	/// Update the mass of the rigidbody with the current `mass`.
	fn update_node_mass(&mut self) {
		unsafe { self.node().map(|b| b.assume_safe().set_mass(self.mass.into())); }
	}
}

impl Block<'_> {
	pub fn id(&self) -> NonZeroU16 {
		match self {
			Block::Destroyed(id) => *id,
			Block::Single(id, _) => *id,
			Block::Multi(id, _) => *id,
		}
	}

	pub fn health(&self) -> u32 {
		match self {
			Block::Destroyed(_) => 0,
			Block::Single(_, hp) => hp.get() as u32,
			Block::Multi(_, mb) => mb.health.get(),
		}
	}
}
