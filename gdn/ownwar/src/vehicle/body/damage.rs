use super::*;
use crate::block;
use crate::util::*;
use crate::vehicle::vehicle::Shared;
use core::fmt;
use core::mem;
use core::num::{NonZeroU16, NonZeroU32};
use core::slice;
use euclid::{UnknownUnit, Vector3D};
use gdnative::prelude::*;
use std::error::Error;
use std::io;

type Voxel = Vector3D<u8, UnknownUnit>;

const DESTROY_BLOCK_EFFECT_SCENE: &str = "res://vehicles/destroy_block_effect.tscn";
#[cfg(not(feature = "server"))]
const DESTROY_BODY_EFFECT_SCENE: &str = "res://vehicles/destroy_body_effect.tscn";

/// Damage event.
pub enum DamageEvent {
	Ray {
		damage: u32,
		origin: Vector3,
		direction: Vector3,
	},
	Explosion {
		damage: u32,
		origin: Vector3,
		radius: u8,
	},
}

/// Error returned if the damage type isn't known
#[derive(Debug)]
pub struct UnknownDamageType(u8);

impl fmt::Display for UnknownDamageType {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		write!(f, "Unknown damage type: {}", self.0)
	}
}

impl Error for UnknownDamageType {}

impl DamageEvent {
	/// Serialize the damage event for transmission over a network.
	pub(super) fn serialize(&self, out: &mut impl io::Write) -> io::Result<()> {
		match self {
			Self::Ray {
				damage,
				origin,
				direction,
			} => {
				out.write_all(&[0])?;
				out.write_all(&damage.to_le_bytes())?;
				super::Body::serialize_vector3(out, *origin)?;
				super::Body::serialize_vector3(out, *direction)?;
			}
			Self::Explosion {
				damage,
				origin,
				radius,
			} => {
				out.write_all(&[1])?;
				out.write_all(&damage.to_le_bytes())?;
				super::Body::serialize_vector3(out, *origin)?;
				out.write_all(&radius.to_le_bytes())?;
			}
		}
		Ok(())
	}

	/// Deserialize the damage event.
	pub(super) fn deserialize(in_: &mut impl io::Read) -> io::Result<Self> {
		let mut ty = 0;
		in_.read_exact(slice::from_mut(&mut ty))?;
		match ty {
			0 => {
				let mut damage = [0; 4];
				in_.read_exact(&mut damage)?;
				let damage = u32::from_le_bytes(damage);
				let origin = super::Body::deserialize_vector3(in_)?;
				let direction = super::Body::deserialize_vector3(in_)?;
				Ok(Self::Ray {
					damage,
					origin,
					direction,
				})
			}
			1 => {
				let mut damage = [0; 4];
				in_.read_exact(&mut damage)?;
				let damage = u32::from_le_bytes(damage);
				let origin = super::Body::deserialize_vector3(in_)?;
				let mut radius = 0;
				in_.read_exact(slice::from_mut(&mut radius))?;
				Ok(Self::Explosion {
					damage,
					origin,
					radius,
				})
			}
			ty => Err(io::Error::new(
				io::ErrorKind::InvalidData,
				UnknownDamageType(ty),
			)),
		}
	}
}

/// Result of damaging a block
enum DamageBlockResult {
	/// The body is entirely destroyed, due to no parent anchors remaining.
	BodyDestroyed,
	/// A MultiBlock got destroyed
	MultiBlockDestroyed {
		multi_block: MultiBlock,
		damage: u32,
	},
	/// A regular block got destroyed
	BlockDestroyed { damage: u32 },
	/// Nothing got destroyed because there is no block
	Empty { damage: u32 },
	/// Nothing got destroyed because the block absorbed all the damage
	Absorbed,
}

impl DamageBlockResult {
	/// The amount of remaining damage
	fn damage(&self) -> u32 {
		match self {
			Self::BodyDestroyed | Self::Absorbed => 0,
			Self::MultiBlockDestroyed { damage, .. }
			| Self::BlockDestroyed { damage }
			| Self::Empty { damage } => *damage,
		}
	}
}

impl super::Body {
	pub fn add_damage_event(&mut self, event: DamageEvent) {
		self.damage_events.push(event);
	}

	/// Returns `true` if the body is destroyed.
	#[must_use]
	pub(super) fn apply_damage_events(&mut self, shared: &mut Shared) -> bool {
		let mut destroyed = Vec::new();
		let mut destroy_disconnected = false;
		let mut evts = mem::take(&mut self.damage_events);
		let mut body_destroyed = self.is_destroyed();

		let old_mass = self.mass;

		for evt in evts.drain(..) {
			let mut dd = false;
			body_destroyed |= match evt {
				DamageEvent::Ray {
					damage,
					origin,
					direction,
				} => self.apply_ray_damage(
					shared,
					origin,
					direction,
					damage,
					&mut destroyed,
					&mut dd,
				),
				DamageEvent::Explosion {
					damage,
					origin,
					radius,
				} => self.apply_explosion_damage(
					shared,
					origin,
					radius,
					damage,
					&mut destroyed,
					&mut dd,
				),
			};
			destroy_disconnected |= dd;
		}

		self.damage_events = evts;

		if body_destroyed {
			true
		} else {
			let ret = destroy_disconnected && self.destroy_disconnected_blocks(shared, destroyed);
			if old_mass != self.mass {
				// Correct the mass and center of mass
				self.update_node_mass();
				// Correct the collision shape
				self.correct_collider_size();
			}
			ret
		}
	}

	/// Returns `true` if the body is destroyed.
	#[must_use]
	fn apply_ray_damage(
		&mut self,
		shared: &mut Shared,
		origin: Vector3,
		direction: Vector3,
		mut damage: u32,
		destroyed_blocks: &mut Vec<Voxel>,
		destroy_disconnected: &mut bool,
	) -> bool {
		*destroy_disconnected = true;

		let mut raycast = VoxelRaycast::start(
			origin + Vector3::new(0.5, 0.5, 0.5), // TODO figure out why +0.5 is suddenly needed
			direction,
			AABB::new(Vector3D::zero(), self.size.to_i32() + Vector3D::one()),
		);
		if raycast.finished() {
			return false;
		}
		if !AABB::new(Vector3D::zero(), self.size.to_i32()).has_point(raycast.voxel()) {
			// TODO fix the raycast algorithm
			//godot_print!("Raycast started out of bounds! Stepping once...");
			raycast.next();
		}

		self.debug_clear_points();

		// TODO rewrite to use proper Iterator functionality
		while !raycast.finished() {
			let voxel = convert_vec(raycast.voxel());

			self.debug_add_point(voxel);

			if let Ok(body_destroyed) = self.destroy_block(
				shared,
				voxel,
				&mut damage,
				destroy_disconnected,
				destroyed_blocks,
			) {
				if body_destroyed {
					return true;
				}
				if damage == 0 {
					break;
				}
				if let None = raycast.next() {
					break;
				}
			} else {
				break;
			}
		}

		false
	}

	/// Returns `true` if the body is destroyed.
	#[must_use]
	fn apply_explosion_damage(
		&mut self,
		shared: &mut Shared,
		origin: Vector3,
		radius: u8,
		mut damage: u32,
		destroyed_blocks: &mut Vec<Voxel>,
		destroy_disconnected: &mut bool,
	) -> bool {
		*destroy_disconnected = true;
		let origin = convert_vec(origin);

		self.debug_clear_points();

		for v in VoxelSphereIterator::new(origin, radius.into()) {
			if self.is_valid_voxel(v) {
				self.debug_add_point(convert_vec(v));
				if let Ok(body_destroyed) = self.destroy_block(
					shared,
					convert_vec(v),
					&mut damage,
					destroy_disconnected,
					destroyed_blocks,
				) {
					if body_destroyed {
						return true;
					}
					if damage == 0 {
						break;
					}
				} else {
					break;
				}
			}
		}

		false
	}

	pub(in super::super) fn raycast(&self, origin: Vector3, direction: Vector3) -> Option<Vector3> {
		let (origin, direction) = self.global_to_voxel_space(origin, direction);
		self.raycast_local(origin, direction).map(|pos| {
			self.voxel_to_global_space(convert_vec(pos), Vector3::zero())
				.0
		})
	}

	pub(in super::super) fn raycast_local(
		&self,
		origin: Vector3,
		direction: Vector3,
	) -> Option<Voxel> {
		let raycast = VoxelRaycast::start(
			origin + Vector3::new(0.5, 0.5, 0.5), // TODO figure out why +0.5 is needed
			direction,
			AABB::new(Vector3D::zero(), self.size().to_i32() + Vector3D::one()),
		);
		for (voxel, _) in raycast {
			if let Ok(Some(block)) = self.try_get_block(voxel) {
				if let super::Block::Destroyed(_) = block {
					/* pass */
				} else {
					return Some(convert_vec(voxel));
				}
			}
		}
		None
	}

	pub(super) fn correct_mass(&mut self) {
		self.calculate_mass();

		if !self.is_destroyed() {
			// TODO
			self.update_node_mass()
		}
	}

	/// Attempt to destroy a block.
	///
	/// Returns `true` if the entire body is destroyed.
	#[must_use]
	fn destroy_block(
		&mut self,
		shared: &mut Shared,
		voxel: Voxel,
		damage: &mut u32,
		destroy_disconnected: &mut bool,
		destroyed_blocks: &mut Vec<Voxel>,
	) -> Result<bool, ()> {
		if let Ok(result) = self.try_damage_block(voxel, *damage) {
			let node = unsafe { self.node().unwrap().assume_safe() };
			*damage = result.damage();
			match result {
				DamageBlockResult::BodyDestroyed => {
					*destroy_disconnected = false;
					Ok(true)
				}
				DamageBlockResult::BlockDestroyed { .. }
				| DamageBlockResult::MultiBlockDestroyed { .. } => {
					*destroy_disconnected = true;

					if let Ok(n) = super::godot::instance_effect(DESTROY_BLOCK_EFFECT_SCENE) {
						n.set_translation(voxel.to_f32() * block::SCALE);
						node.add_child(n, false);
					}

					// Properly cleanup multiblocks
					let pos = if let DamageBlockResult::MultiBlockDestroyed {
						multi_block, ..
					} = result
					{
						let pos = multi_block.base_position;
						#[cfg(not(feature = "server"))]
						let body = multi_block.destroy(shared, &mut self.interpolation_states[..]);
						#[cfg(feature = "server")]
						let body = multi_block.destroy(shared);

						// Destroy the connected body, if any.
						body.map(|body| {
							let body = &mut self.children[usize::from(body)];
							body.destroy(shared, body.center_of_mass);
						});

						let index = self.get_index(pos).unwrap();
						let blk = block::Block::get(self.ids[index as usize].unwrap()).unwrap();

						// Set the base position to 0 HP
						self.health[self.get_index(pos).unwrap() as usize] = None;

						// Set all mount points to 0 HP
						for d in blk.extra_mount_points.iter().copied() {
							// TODO account for rotation
							let p = convert_vec::<_, isize>(pos) + convert_vec::<_, isize>(d);
							if let Ok(index) = self.get_index(p) {
								self.health[index as usize] = None;
								destroyed_blocks.push(convert_vec(p));
							}
						}

						pos
					} else {
						voxel
					};

					destroyed_blocks.push(pos);

					#[cfg(not(feature = "server"))]
					if let Some(vm) = &self.voxel_mesh {
						unsafe {
							vm.assume_safe()
								.map_mut(|s, _| s.remove_block(pos))
								.unwrap()
						}
					}
					#[cfg(feature = "server")]
					let _ = pos;

					Ok(false)
				}
				DamageBlockResult::Empty { .. } | DamageBlockResult::Absorbed => Ok(false),
			}
		} else {
			godot_error!("Position is out of bounds! {:?} in {:?}", voxel, self.size);
			Err(())
		}
	}

	fn try_damage_block(&mut self, position: Voxel, damage: u32) -> Result<DamageBlockResult, ()> {
		self.get_index(position).map(|i| {
			let i = i as usize;
			if let Some(hp) = self.health[i] {
				if hp.get() & 0x8000 != 0 {
					let block_index = (hp.get() & 0x7fff) as usize;
					if let Some(ref block) = self.multi_blocks[block_index] {
						let hp = block.health.get();
						if hp <= damage {
							let id = self
								.get_index(block.base_position)
								.ok()
								.and_then(|i| self.ids[i as usize])
								.unwrap();
							let block = self.multi_blocks[block_index].take().unwrap();
							let damage = damage - hp;
							self.correct_for_removed_block(position, id);
							self.multi_blocks[block_index] = None;
							for &pos in block.reverse_indices.iter() {
								self.health[self.get_index(pos).unwrap() as usize] = None;
								if self.remove_all_anchors(pos) {
									// Reinsert MultiBlock so it's properly destroyed
									self.multi_blocks[block_index] = Some(block);
									return DamageBlockResult::BodyDestroyed;
								}
							}
							DamageBlockResult::MultiBlockDestroyed {
								multi_block: block,
								damage,
							}
						} else {
							self.multi_blocks[block_index].as_mut().unwrap().health =
								NonZeroU32::new(block.health.get() - damage).unwrap();
							DamageBlockResult::Absorbed
						}
					} else {
						godot_error!("Block was already destroyed!");
						// Try to carry on anyways, we can recover from this
						self.health[i] = None;
						DamageBlockResult::Empty { damage }
					}
				} else {
					let hp = hp.get() as u32;
					if hp <= damage {
						let id = self.ids[i].unwrap();
						let damage = damage - hp;
						self.health[i] = None;
						self.correct_for_removed_block(position, id);
						if self.remove_all_anchors(position) {
							DamageBlockResult::BodyDestroyed
						} else {
							DamageBlockResult::BlockDestroyed { damage }
						}
					} else {
						// unwrap() may seem silly, but the check is worth it
						self.health[i] = Some(NonZeroU16::new((hp - damage) as u16).unwrap());
						DamageBlockResult::Absorbed
					}
				}
			} else {
				DamageBlockResult::Empty { damage }
			}
		})
	}

	/// Correct the mass & cost accounting for a removed block at the given position.
	///
	/// # Panics
	///
	/// The block ID is invalid.
	fn correct_for_removed_block(&mut self, position: Voxel, id: NonZeroU16) {
		let blk = block::Block::get(id).expect("Invalid block ID");
		self.cost -= blk.cost.get() as u32;
		let new_mass = self.mass - blk.mass;
		// TODO correct center of mass. This is a bit tricky due to joint mounts being relative
		// to the rigidbody & the rigidbody's CoM always being at the center.
		// We can already do the math, we just can't apply it yet.
		self.center_of_mass =
			(self.center_of_mass * self.mass - convert_vec(position) * blk.mass) / new_mass;
		self.mass = new_mass;
	}

	/// Destroy any blocks not connected to a mainframe in any way.
	///
	/// Returns `true` if the entire body is destroyed.
	#[must_use]
	pub fn destroy_disconnected_blocks(
		&mut self,
		shared: &mut Shared,
		destroyed_blocks: Vec<Voxel>,
	) -> bool {
		if self.parent_anchors.is_empty() || !self.is_connected_to_parent() {
			return true;
		}

		const X: Voxel = Voxel::new(1, 0, 0);
		const Y: Voxel = Voxel::new(0, 1, 0);
		const Z: Voxel = Voxel::new(0, 0, 1);

		let marks = convert_vec::<_, usize>(self.size) + Vector3D::one();
		let mut marks = BitArray::new(marks.x * marks.y * marks.z);
		for voxel in destroyed_blocks {
			let mut connections = Vec::new();
			let mut add_conn_fn = |direction| {
				let p = voxel.to_i32() + direction;
				if self
					.get_index(p)
					.ok()
					.map(|p| self.health[p as usize])
					.flatten()
					.is_some()
				{
					connections.push(convert_vec(p));
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
				if marks.get(index as usize).unwrap() {
					continue;
				}
				let anchor_found = self.mark_connected_blocks(&mut marks, side_voxel, index, false);
				if anchor_found {
					for i in (0..connections.len()).rev() {
						let index = self.get_index(connections[i]).unwrap();
						if marks.get(index as usize).unwrap() {
							connections.swap_remove(i);
						}
					}
				} else {
					self.destroy_connected_blocks(shared, side_voxel, index);
				}
			}
		}
		false
	}

	pub(super) fn mark_connected_blocks(
		&self,
		marks: &mut BitArray,
		voxel: Voxel,
		index: u32,
		mut found: bool,
	) -> bool {
		debug_assert_eq!(index, self.get_index(voxel).unwrap());
		marks.set(index as usize, true).unwrap();
		found |= self.parent_anchors.contains(&voxel);

		let size = self.size;
		let cf = |x, y, z, index_offset: i32| {
			let index = index as i32 + index_offset;
			if !marks.get(index as usize).unwrap() && self.health[index as usize].is_some() {
				let voxel = convert_vec(voxel.to_i32() + Vector3D::new(x, y, z));
				found = self.mark_connected_blocks(marks, voxel, index as u32, found);
			}
		};
		Self::apply_to_all_sides(size, voxel, cf);
		found
	}

	/// Destroy all blocks and bodies connected to a certain other block in any way.
	fn destroy_connected_blocks(&mut self, shared: &mut Shared, voxel: Voxel, index: u32) {
		debug_assert_eq!(index, self.get_index(voxel).unwrap());
		debug_assert_ne!(self.health[index as usize], Some(MAINFRAME_ID));

		let size = self.size;
		fn closure(
			slf: &mut Body,
			shared: &mut Shared,
			voxel: Voxel,
			index: u32,
			x: i32,
			y: i32,
			z: i32,
			index_offset: i32,
		) {
			let index = index as i32 + index_offset;
			if slf.health[index as usize].is_some() {
				let voxel = convert_vec(voxel.to_i32() + Vector3D::new(x, y, z));
				slf.destroy_connected_blocks(shared, voxel, index as u32)
			}
		}

		if let Some(hp) = self.health[index as usize].take() {
			let hp = hp.get();

			let _ = self.remove_all_anchors(voxel);

			let pos = if hp & 0x8000 == 0 {
				self.correct_for_removed_block(voxel, self.ids[index as usize].unwrap());
				let cf = |x, y, z, index_offset| {
					closure(self, shared, voxel, index, x, y, z, index_offset)
				};
				Self::apply_to_all_sides(size, voxel, cf);
				voxel
			} else {
				let index = hp & 0x7fff;
				let block = self.multi_blocks[index as usize].take();
				let block = block.expect("Multi block is None but HP is not zero!");

				let pos = block.base_position;

				// Destroy the block & any attached bodies.
				#[cfg(not(feature = "server"))]
				let body = block.destroy(shared, &mut self.interpolation_states[..]);
				#[cfg(feature = "server")]
				let body = block.destroy(shared);
				body.map(|body| {
					let body = &mut self.children[usize::from(body)];
					body.destroy(shared, body.center_of_mass);
				});

				let index = self.get_index(pos).unwrap();
				let id = self.ids[index as usize].unwrap();
				let blk = block::Block::get(id).unwrap();

				self.correct_for_removed_block(pos, id);

				// Set the base position to 0 HP
				self.health[self.get_index(pos).unwrap() as usize] = None;

				// Set all mount points to 0 HP
				for d in blk.extra_mount_points.iter().copied() {
					// TODO account for rotation
					let p = convert_vec::<_, isize>(pos) + convert_vec::<_, isize>(d);
					if let Ok(index) = self.get_index(p) {
						self.health[index as usize] = None;
					}
				}

				// Destroy all blocks attached to the base position
				let cf = |x, y, z, index_offset| {
					closure(self, shared, voxel, index, x, y, z, index_offset)
				};
				Self::apply_to_all_sides(size, pos, cf);

				// Destroy all blocks attached to the mount points.
				for d in blk.extra_mount_points.iter().copied() {
					// TODO account for rotation
					let p = convert_vec::<_, isize>(pos) + convert_vec::<_, isize>(d);
					if let Ok(index) = self.get_index(p) {
						let cf = |x, y, z, index_offset| {
							closure(self, shared, voxel, index, x, y, z, index_offset)
						};
						Self::apply_to_all_sides(size, convert_vec(p), cf);
					}
				}

				pos
			};

			#[cfg(not(feature = "server"))]
			if let Some(vm) = &self.voxel_mesh {
				let vm = unsafe { vm.assume_safe() };
				vm.map_mut(|vm, _| vm.remove_block(pos)).unwrap();
			}
			#[cfg(feature = "server")]
			let _ = pos;
		}
	}

	fn apply_to_all_sides(size: Voxel, voxel: Voxel, mut f: impl FnMut(i32, i32, i32, i32)) {
		let size = convert_vec::<_, i32>(size) + Vector3D::one();
		let voxel = convert_vec::<_, i32>(voxel);
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

	/// Check whether this body is still connected to its parent.
	#[must_use]
	fn is_connected_to_parent(&self) -> bool {
		!self.parent_anchors.is_empty()
	}

	/// Remove all parent anchors at the given position.
	///
	/// Returns `true` if all parent anchors are gone, i.e. the body is destroyed.
	#[must_use]
	fn remove_all_anchors(&mut self, position: Voxel) -> bool {
		if let Some(i) = self.parent_anchors.iter().position(|&p| p == position) {
			self.parent_anchors.swap_remove(i);
			if self.parent_anchors.is_empty() {
				return true;
			}
		}

		false
	}

	/// Clean up stale entries in the shared struct to avoid UB & remove rigidbody nodes of self
	/// and children.
	pub(in super::super) fn destroy(
		&mut self,
		shared: &mut vehicle::Shared,
		old_center_of_mass: Vector3,
	) {
		if let Some(node) = self.node.take() {
			self.cost = 0;

			// Destroy multiblocks.
			#[cfg(not(feature = "server"))]
			{
				let ip = &mut self.interpolation_states;
				for block in self.multi_blocks.iter_mut() {
					block.take().map(|b| b.destroy(shared, ip));
				}
			}
			#[cfg(feature = "server")]
			{
				for block in self.multi_blocks.iter_mut() {
					block.take().map(|b| b.destroy(shared));
				}
			}

			self.children.iter_mut().for_each(|b| {
				b.destroy(shared, b.center_of_mass);
			});

			#[cfg(not(feature = "server"))]
			{
				// Spawn an effect if there are visual effects.
				if self.voxel_mesh_instance.is_some() {
					if let Ok(n) = godot::instance_effect(damage::DESTROY_BODY_EFFECT_SCENE) {
						unsafe {
							if node.assume_safe().is_inside_tree() {
								// Doesn't print an error
								let tree = node.assume_safe().get_tree().unwrap();
								if let Some(root) = tree.assume_safe().current_scene() {
									let trf = node.assume_safe().transform();
									let tr = trf.basis.xform(old_center_of_mass * block::SCALE);
									n.set_translation(tr + trf.origin);
									root.assume_safe().add_child(n, false);
								}
							}
						}
					}
				}
				self.voxel_mesh_instance = None;
			}

			// While it doesn't make much sense to zero out all blocks right now, it'll be useful
			// if (when) some form of healing is introduced. It also fixes a synchronization issue
			// with multiblocks right now (which can be fixed while avoiding this but w/e).
			self.health.fill(None);

			// Remove the node itself. This will automatically free the collision
			// shape, voxel mesh and child body nodes, as those are children.
			unsafe { node.assume_unique().free() };
		}
	}

	/// Check whether the body is completely destroyed.
	pub(in super::super) fn is_destroyed(&self) -> bool {
		self.cost == 0
	}
}
