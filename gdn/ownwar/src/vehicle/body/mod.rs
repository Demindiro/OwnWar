mod check;
mod damage;
mod debug;
#[cfg(not(feature = "server"))]
mod godot;
mod init;
#[cfg(not(feature = "server"))]
mod mesh;
mod multi_block;
mod packet;
mod physics;
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
use crate::types::*;
use crate::util::*;
#[cfg(debug_assertions)]
use core::cell::Cell;
use core::fmt;
use core::mem;
use gdnative::api::{BoxShape, CollisionShape, PhysicsServer, VehicleBody};
#[cfg(not(feature = "server"))]
use gdnative::api::MeshInstance;
use gdnative::prelude::*;
use std::convert::{TryFrom, TryInto};
use std::num::{NonZeroU16, NonZeroU32};

const MAINFRAME_ID: NonZeroU16 = unsafe { NonZeroU16::new_unchecked(76) };

const COLLISION_LAYER: u32 = 2;
// Any + Vehicles + Terrain
const COLLISION_MASK: u32 = 1 | 2 | (1 << 7);
// Helps with preventing the physics from exploding.
const LINEAR_DAMPING: f32 = 0.2;
const ANGULAR_DAMPING: f32 = 0.2;
// A slippery surface makes it easier to take off in planes & prevents getting stuck
// on corners.
const FRICTION: f32 = 0.1;

/// A single voxel. Each voxel represents a block's ID and health.
#[derive(Default)]
struct Voxel {
	/// The ID of the block. `None` if there is no block.
	///
	/// Multiblocks use only one spot.
	id: Option<NonZeroU16>,
	/// The health of the block. The upper bit (`0x8000`) is set if it points to a multiblock.
	///
	/// Multiblocks use one or more spots.
	health: Option<NonZeroU16>,
}

pub(super) struct Body {
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

	offset: voxel::Position,

	/// The ID & health of each block of this body.
	blocks: voxel::Grid<Voxel>,
	/// A bitmap indicating if the left & right side of each pair of blocks connect.
	connections_x: Option<voxel::BitGrid>,
	/// A bitmap indicating if the top & bottom side of each pair of blocks connect.
	connections_y: Option<voxel::BitGrid>,
	/// A bitmap indicating if the front & back side of each pair of blocks connect.
	connections_z: Option<voxel::BitGrid>,
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
	debug_hit_points: Cell<Vec<voxel::Position>>,

	/// Damage events to be applied.
	damage_events: Vec<DamageEvent>,

	/// Bodies connected to this vehicle.
	children: Vec<Self>,

	/// Anchors connecting this body to it's parent.
	///
	/// This has one entry if it is the main body: the mainframe. The mainframe
	/// is not a real anchor but pretending it is one simplifies things quite a bit.
	parent_anchors: Vec<voxel::Position>,

	/// The lowest corner of the box collider.
	collider_start_point: voxel::Position,
	/// The highest corner of the box collider.
	collider_end_point: voxel::Position,
}

/// Enum returned when an error occurs during `init_all`
#[derive(Debug)]
pub enum InitError {
	/// One of the anchors causes a body cycle.
	CyclicAnchor,
	/// There are multiple bodies connected to the same anchor.
	MultipleBodiesPerAnchor,
	/// No mainframes were found.
	NoMainframe,
	/// Multiple mainframes were found.
	MultipleMainframes,
	/// Some blocks are not connected to an anchor.
	DisconnectedBlocks,
}

impl fmt::Display for InitError {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		match self {
			Self::CyclicAnchor => "cyclic anchor".fmt(f),
			Self::MultipleBodiesPerAnchor => "multiple bodies on an anchor".fmt(f),
			Self::NoMainframe => "no mainframe found".fmt(f),
			Self::MultipleMainframes => "multiple mainframes found".fmt(f),
			Self::DisconnectedBlocks => "some blocks are disconnected".fmt(f),
		}
	}
}

impl Body {
	pub fn new(aabb: voxel::AABB) -> Self {
		let (offset, end) = (aabb.start, aabb.end);
		let end = (end - offset).try_into().expect("Failed to convert Delta");

		use core::iter::repeat;
		let blocks = voxel::Grid::new(end);
		let size = blocks.len();

		let mut slf = Self {
			node: None,
			#[cfg(not(feature = "server"))]
			voxel_mesh: Some(Self::create_voxel_mesh()),
			#[cfg(not(feature = "server"))]
			voxel_mesh_instance: None,
			collision_shape: Self::create_collision_shape(),
			collision_shape_instance: None,

			#[cfg(not(feature = "server"))]
			interpolation_states: Vec::new(),
			#[cfg(not(feature = "server"))]
			interpolation_state_dirty: true,

			offset,
			blocks,
			connections_x: (end - voxel::Delta::X).map(|e| voxel::BitGrid::new(e)).ok(),
			connections_y: (end - voxel::Delta::Y).map(|e| voxel::BitGrid::new(e)).ok(),
			connections_z: (end - voxel::Delta::Z).map(|e| voxel::BitGrid::new(e)).ok(),
			multi_blocks: Vec::new(),
			colors: repeat(0).take(size).collect(),
			rotations: repeat(Rotation::new(0).unwrap()).take(size).collect(),

			center_of_mass: Vector3::zero(),
			mass: 0.0,
			cost: 0,
			max_cost: 0,

			#[cfg(debug_assertions)]
			debug_hit_points: Cell::new(Vec::new()),

			damage_events: Vec::new(),

			children: Vec::new(),

			parent_anchors: Vec::new(),

			collider_start_point: voxel::Position::ZERO,
			collider_end_point: end,
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
		for (i, b) in bodies.iter_mut().enumerate() {
			if let Some(b) = b {
				if !b.parent_anchors.is_empty() {
					if parent.is_some() || b.parent_anchors.len() != 1 {
						return Err(InitError::MultipleMainframes);
					}
					parent = Some(u8::try_from(i).unwrap());
				}
				b.setup_connection_bitmaps();
			}
		}
		if parent.is_none() {
			return Err(InitError::NoMainframe);
		}

		// Setup total cost, health ... & find special blocks.
		for i in 0..u8::try_from(bodies.len()).unwrap() {
			let (left, right) = bodies.split_at_mut(i.into());
			let (body, right) = right.split_at_mut(1);

			if let Some(body) = &mut body[0] {
				body.correct_mass();
				body.cost = body.max_cost();
				body.resize_collider(body.collider_start_point, body.collider_end_point);

				let offt = body.offset();
				for block in body.multi_blocks.iter_mut().filter_map(Option::as_mut) {
					block.init(body.offset, body.center_of_mass, shared);
					if let Some(server_node) = block.server_node.as_ref() {
						let server_node = unsafe { server_node.assume_safe() };

						// Check if the block is an anchor
						if !server_node.get("anchor_index").is_nil() {
							let mut anchor_body = None;
							let parent_anchors = &mut body_tree[usize::from(i)];

							for mount in server_node
								.get("anchor_mounts")
								.to_vector3_array()
								.read()
								.iter()
								.copied()
							{
								let mount = match voxel::Delta::try_from(mount) {
									Ok(m) => m,
									Err(e) => {
										godot_error!("Failed to convert mount: {:?}", e);
										continue;
									}
								};
								let delta = block.rotation * mount + offt;
								let mount = match block.base_position + delta {
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
										let m = match mount - b.offset() {
											Ok(m) => m,
											Err(_) => continue,
										};
										if let Some(Some(_)) = b.blocks.get(m).map(|b| b.health) {
											b.parent_anchors.push(m);
											if parent_anchors.iter().find(|b| **b == k).is_none() {
												parent_anchors.push(k);
												if block.set_anchored_body(k).is_err() {
													return Err(InitError::MultipleBodiesPerAnchor);
												}
											};
											anchor_body = Some(b.node);
										}
									}
								}
							}

							server_node.set("anchor_mount_body", anchor_body.to_variant());
						}
					}
				}
			}
		}

		// Check if all blocks are connected
		for b in bodies.iter().filter_map(Option::as_ref) {
			if !b.are_all_blocks_connected() {
				return Err(InitError::DisconnectedBlocks);
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
			/*
			unsafe {
			parent
			.node
			.unwrap()
			.assume_safe()
			.set_translation(Vector3::zero())
			};
			*/
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

		#[cfg(not(feature = "server"))]
		let old_com = self.center_of_mass;
		if self.apply_damage_events(shared) {

			#[cfg(not(feature = "server"))]
			self.destroy(shared, old_com);
			#[cfg(feature = "server")]
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
		position: voxel::Position,
		rotation: Rotation,
		block_id: NonZeroU16,
		color: u8,
	) {
		let position =
			(position - voxel::Delta::from(self.offset)).expect("Position is out of bounds");
		let index = self.get_index(position).expect("Position is out of bounds");
		assert!(
			self.blocks[position].health.is_none(),
			"Position is already occupied"
		);

		let block = block::Block::get(block_id).expect("Invalid block ID");

		self.blocks[position].id = Some(block.id);
		self.rotations[index as usize] = rotation;
		self.colors[index as usize] = color;

		if block.is_multi_block() {
			let i: u16 = self
				.multi_blocks
				.len()
				.try_into()
				.expect("Too many multiblocks");
			self.blocks[position].health = NonZeroU16::new(0x8000 | i);
			for d in block.extra_mount_points.iter() {
				let d = voxel::Delta::from(d.position);
				if let Ok(pos) = position + rotation * d {
					self.blocks
						.get_mut(pos)
						.map(|b| b.health = NonZeroU16::new(0x8000 | i));
				}
			}
			self.multi_blocks.push(Some(MultiBlock {
				health: block.health,
				server_node: None,
				#[cfg(not(feature = "server"))]
				client_node: None,
				reverse_indices: Box::new([]),
				#[cfg(not(feature = "server"))]
				interpolation_state_index: u16::MAX,
				base_position: position,
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
			self.blocks[position].health = Some(block.health.try_into().unwrap());
		}

		self.init_block(shared, position);
	}

	fn get_index(&self, position: voxel::Position) -> Result<usize, ()> {
		if self.blocks.get(position).is_some() {
			let voxel::Delta { x, y, z } = self.size();
			let (_, sy, sz) = (x as usize, y as usize, z as usize);
			let (x, y, z): (usize, _, _) = position.into();
			Ok((x * sy + y) * sz + z)
		} else {
			Err(())
		}
	}

	pub fn calculate_mass(&mut self) {
		let mut total_mass = 0.0;
		let mut center_of_mass = Vector3::zero();
		for pos in iter_3d_inclusive((0, 0, 0), self.end().into()).map(voxel::Position::from) {
			if let Voxel {
				id: Some(id),
				health: Some(_),
			} = self.blocks[pos]
			{
				let mass = block::Block::get(id).unwrap().mass;
				center_of_mass += Vector3::from(pos) * mass;
				total_mass += mass;
			}
		}
		self.mass = total_mass;
		self.center_of_mass = center_of_mass / total_mass;
	}

	pub fn center_of_mass(&self) -> Vector3 {
		self.center_of_mass
	}

	pub fn max_cost(&self) -> u32 {
		self.max_cost
	}

	#[track_caller]
	pub fn position(&self) -> (Vector3, Quat) {
		self.node()
			.map(|n| {
				let trf = unsafe { n.assume_safe().transform() };
				(trf.origin, trf.basis.to_quat())
			})
			.unwrap_or((Vector3::zero(), Quat::identity()))
	}

	pub fn set_position(&self, translation: Vector3, rotation: Quat) {
		// FIXME for whatever reason I need to invert the rotation every time ??
		// Not sure if it's a bug in to_transform, need to check.
		let trf = rotation.to_transform().then_translate(translation);
		unsafe {
			self.node().map(|b| {
				b.assume_safe()
					.set_transform(Transform::from_transform(&trf))
			});
		}
	}

	pub fn linear_velocity(&self) -> Vector3 {
		unsafe {
			self.node()
				.map(|b| b.assume_safe().linear_velocity())
				.unwrap_or(Vector3::zero())
		}
	}

	pub fn set_linear_velocity(&self, velocity: Vector3) {
		unsafe {
			self.node()
				.map(|b| b.assume_safe().set_linear_velocity(velocity));
		}
	}

	pub fn angular_velocity(&self) -> Vector3 {
		unsafe {
			self.node()
				.map(|b| b.assume_safe().angular_velocity())
				.unwrap_or(Vector3::zero())
		}
	}

	pub fn set_angular_velocity(&self, velocity: Vector3) {
		unsafe {
			self.node()
				.map(|b| b.assume_safe().set_angular_velocity(velocity));
		}
	}

	pub fn aabb(&self) -> voxel::AABB {
		voxel::AABB::new(self.offset, self.end())
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

	/// The end/top point of this body.
	fn end(&self) -> voxel::Position {
		self.blocks.end()
	}

	/// The offset of this body, expressed as a `Delta`
	fn offset(&self) -> voxel::Delta {
		self.offset.into()
	}

	/// The size of this body, expressed as a `Delta`
	fn size(&self) -> voxel::Delta {
		voxel::Delta::from(self.blocks.end()) + voxel::Delta::ONE
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
		self.node().map(|b| unsafe {
			let b = b.assume_safe();
			b.set_mass(self.mass.into());
			let rid = b.get_rid();
			let com = self.center_of_mass * block::SCALE;
			PhysicsServer::godot_singleton()
				.call("body_set_local_com", &[rid.to_variant(), com.to_variant()]);
		});
	}
}
