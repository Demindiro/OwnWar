use super::*;
use crate::block;
use crate::util::*;
use crate::vehicle::vehicle::Shared;
use core::fmt;
use core::mem;
use core::num::{NonZeroU16, NonZeroU32};
use core::slice;
use gdnative::prelude::*;
use std::error::Error;
use std::io;

#[cfg(not(feature = "server"))]
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
		radius: i8,
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
					radius: radius as i8,
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
		destroyed_blocks: &mut Vec<voxel::Position>,
		destroy_disconnected: &mut bool,
	) -> bool {
		*destroy_disconnected = true;

		let mut raycast = VoxelRaycast::start(
			origin + Vector3::new(0.5, 0.5, 0.5), // TODO figure out why +0.5 is suddenly needed
			direction,
			voxel::AABB::new(voxel::Position::ZERO, self.end()),
		);
		if raycast.finished() {
			return false;
		}
		if let Ok(pos) = raycast.voxel().try_into() {
			if !voxel::AABB::new(voxel::Position::ZERO, self.end()).has_point(pos) {
				// TODO fix the raycast algorithm
				raycast.next();
			}
		} else {
			// TODO ditto
			raycast.next();
		}

		self.debug_clear_points();

		// TODO rewrite to use proper Iterator functionality
		while !raycast.finished() {
			let pos = raycast.voxel();
			let x = u8::try_from(pos.x);
			let y = u8::try_from(pos.y);
			let z = u8::try_from(pos.z);
			if let (Ok(x), Ok(y), Ok(z)) = (x, y, z) {
				let pos = voxel::Position::new(x, y, z);

				self.debug_add_point(pos);

				if let Ok(body_destroyed) = self.destroy_block(
					shared,
					pos,
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
		}

		false
	}

	/// Returns `true` if the body is destroyed.
	#[must_use]
	fn apply_explosion_damage(
		&mut self,
		shared: &mut Shared,
		origin: Vector3,
		radius: i8,
		mut damage: u32,
		destroyed_blocks: &mut Vec<voxel::Position>,
		destroy_disconnected: &mut bool,
	) -> bool {
		*destroy_disconnected = true;

		let origin = match origin.try_into() {
			Ok(o) => o,
			Err(_) => return false, // Just return, we won't be hitting anything anyways.
		};

		self.debug_clear_points();

		for pos in VoxelSphereIterator::new(origin, radius) {
			let x = u8::try_from(pos.x);
			let y = u8::try_from(pos.y);
			let z = u8::try_from(pos.z);
			if let (Ok(x), Ok(y), Ok(z)) = (x, y, z) {
				let pos = voxel::Position::new(x, y, z);
				if self.blocks.get(pos).is_some() {
					self.debug_add_point(pos);
					if let Ok(body_destroyed) = self.destroy_block(
						shared,
						pos,
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
		}

		false
	}

	pub(in super::super) fn raycast(&self, origin: Vector3, direction: Vector3) -> Option<Vector3> {
		let (origin, direction) = self.global_to_voxel_space(origin, direction);
		self.raycast_local(origin, direction).map(|pos| {
			self.voxel_to_global_space(Vector3::from(pos), Vector3::zero())
				.0
		})
	}

	pub(in super::super) fn raycast_local(
		&self,
		origin: Vector3,
		direction: Vector3,
	) -> Option<voxel::Position> {
		let raycast = VoxelRaycast::start(
			origin + Vector3::new(0.5, 0.5, 0.5), // TODO figure out why +0.5 is needed
			direction,
			voxel::AABB::new(voxel::Position::ZERO, self.end()),
		);
		for (pos, _) in raycast {
			let x = u8::try_from(pos.x);
			let y = u8::try_from(pos.y);
			let z = u8::try_from(pos.z);
			if let (Ok(x), Ok(y), Ok(z)) = (x, y, z) {
				let pos = voxel::Position::new(x, y, z);
				if let Some(Some(_)) = self.blocks.get(pos).map(|b| b.health) {
					return Some(pos);
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
		position: voxel::Position,
		damage: &mut u32,
		destroy_disconnected: &mut bool,
		destroyed_blocks: &mut Vec<voxel::Position>,
	) -> Result<bool, ()> {
		if let Ok(result) = self.try_damage_block(position, *damage) {
			*damage = result.damage();
			match result {
				DamageBlockResult::BodyDestroyed => {
					*destroy_disconnected = false;
					Ok(true)
				}
				DamageBlockResult::BlockDestroyed { .. }
				| DamageBlockResult::MultiBlockDestroyed { .. } => {
					*destroy_disconnected = true;

					#[cfg(not(feature = "server"))]
					if let Ok(n) = super::godot::instance_effect(DESTROY_BLOCK_EFFECT_SCENE) {
						n.set_translation(Vector3::from(position) * block::SCALE);
						unsafe {
							self.voxel_mesh_instance
								.unwrap()
								.assume_safe()
								.add_child(n, false);
						}
					}

					// Properly cleanup multiblocks
					let pos = if let DamageBlockResult::MultiBlockDestroyed {
						multi_block, ..
					} = result
					{
						let pos = multi_block.base_position;
						let rot = multi_block.rotation;

						#[cfg(not(feature = "server"))]
						let body = multi_block.destroy(shared, &mut self.interpolation_states[..]);
						#[cfg(feature = "server")]
						let body = multi_block.destroy(shared);

						// Destroy the connected body, if any.
						body.map(|body| {
							let body = &mut self.children[usize::from(body)];
							#[cfg(not(feature = "server"))]
							body.destroy(shared, body.center_of_mass);
							#[cfg(feature = "server")]
							body.destroy(shared);
						});

						let blk = block::Block::get(self.blocks[pos].id.unwrap()).unwrap();

						// Set the base position to 0 HP
						self.blocks[pos].health = None;

						// Set all mount points to 0 HP
						for d in blk.extra_mount_points.iter().copied() {
							let d = voxel::Delta::from(d.position);
							if let Ok(pos) = pos + rot * d {
								if let Some(blk) = self.blocks.get_mut(pos) {
									blk.health = None;
									destroyed_blocks.push(pos);
								}
							}
						}

						pos
					} else {
						position
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
			godot_error!(
				"Position is out of bounds! {:?} in {:?}",
				position,
				self.size()
			);
			Err(())
		}
	}

	fn try_damage_block(
		&mut self,
		position: voxel::Position,
		damage: u32,
	) -> Result<DamageBlockResult, ()> {
		if let Some(blk) = self.blocks.get(position) {
			Ok(if let Some(hp) = blk.health {
				if hp.get() & 0x8000 != 0 {
					let block_index = (hp.get() & 0x7fff) as usize;
					let block = self.multi_blocks[block_index]
						.as_mut()
						.expect("Block was already destroyed");
					let hp = block.health.get();
					if hp <= damage {
						let block = self.multi_blocks[block_index].take().unwrap();
						let damage = damage - hp;
						self.correct_for_removed_block(block.base_position);
						self.multi_blocks[block_index] = None;
						for &pos in block.reverse_indices.iter() {
							self.blocks[position].health = None;
							if self.remove_all_anchors(pos) {
								// Reinsert MultiBlock so it's properly destroyed
								self.multi_blocks[block_index] = Some(block);
								return Ok(DamageBlockResult::BodyDestroyed);
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
					let hp = hp.get() as u32;
					if hp <= damage {
						let damage = damage - hp;
						self.blocks[position].health = None;
						self.correct_for_removed_block(position);
						if self.remove_all_anchors(position) {
							DamageBlockResult::BodyDestroyed
						} else {
							DamageBlockResult::BlockDestroyed { damage }
						}
					} else {
						self.blocks[position].health = NonZeroU16::new((hp - damage) as u16);
						DamageBlockResult::Absorbed
					}
				}
			} else {
				DamageBlockResult::Empty { damage }
			})
		} else {
			Err(())
		}
	}

	/// Correct the mass & cost accounting for a removed block at the given position.
	///
	/// # Panics
	///
	/// The block ID is invalid.
	fn correct_for_removed_block(&mut self, position: voxel::Position) {
		let id = self.blocks[position].id.unwrap();
		let blk = block::Block::get(id).expect("Invalid block ID");
		self.cost -= blk.cost.get() as u32;
		let new_mass = self.mass - blk.mass;
		// TODO correct center of mass. This is a bit tricky due to joint mounts being relative
		// to the rigidbody & the rigidbody's CoM always being at the center.
		// We can already do the math, we just can't apply it yet.
		self.center_of_mass =
			(self.center_of_mass * self.mass - Vector3::from(position) * blk.mass) / new_mass;
		self.mass = new_mass;
	}

	/// Destroy any blocks not connected to a mainframe in any way.
	///
	/// Returns `true` if the entire body is destroyed.
	#[must_use]
	pub fn destroy_disconnected_blocks(
		&mut self,
		shared: &mut Shared,
		destroyed_blocks: Vec<voxel::Position>,
	) -> bool {
		if self.parent_anchors.is_empty() || !self.is_connected_to_parent() {
			return true;
		}

		for pos in destroyed_blocks {
			let mut connections = Vec::new();
			let mut add_conn_fn = |direction| {
				if let Ok(p) = pos + direction {
					if self
						.blocks
						.get(p)
						.map(|b| b.health.is_some())
						.unwrap_or(false)
					{
						connections.push(p);
					}
				}
			};
			add_conn_fn(voxel::Delta::Z);
			add_conn_fn(-voxel::Delta::Z);
			add_conn_fn(voxel::Delta::Y);
			add_conn_fn(-voxel::Delta::Y);
			add_conn_fn(voxel::Delta::X);
			add_conn_fn(-voxel::Delta::X);
			while let Some(side_pos) = connections.pop() {
				if self.blocks[side_pos].health.is_none() {
					continue;
				}
				let mut marks = voxel::BitGrid::new(self.blocks.end());
				let anchor_found = self.mark_connected_blocks(&mut marks, side_pos, false);
				if anchor_found {
					for i in (0..connections.len()).rev() {
						if marks[connections[i]] {
							connections.swap_remove(i);
						}
					}
				} else {
					self.destroy_connected_blocks(shared, side_pos, &mut marks);
				}
			}
		}
		false
	}

	pub(super) fn mark_connected_blocks(
		&self,
		marks: &mut voxel::BitGrid,
		position: voxel::Position,
		mut found: bool,
	) -> bool {
		marks.set(position, true).unwrap();
		found |= self.parent_anchors.contains(&position);

		let mut f = |pos, conn_pos, n| {
			let map = match n {
				0 => self.connections_x.as_ref(),
				1 => self.connections_y.as_ref(),
				2 => self.connections_z.as_ref(),
				_ => unreachable!(),
			};
			if Some(false) == marks.get(pos) {
				if self.blocks[pos].health.is_some() && map.map_or(false, |m| m[conn_pos]) {
					found = self.mark_connected_blocks(marks, pos, found);
				}
			}
		};

		(position + voxel::Delta::Z).ok().map(|p| f(p, position, 2));
		(position - voxel::Delta::Z).ok().map(|p| f(p, p, 2));
		(position + voxel::Delta::Y).ok().map(|p| f(p, position, 1));
		(position - voxel::Delta::Y).ok().map(|p| f(p, p, 1));
		(position + voxel::Delta::X).ok().map(|p| f(p, position, 0));
		(position - voxel::Delta::X).ok().map(|p| f(p, p, 0));

		found
	}

	/// Destroy all blocks and bodies connected to a certain other block in any way.
	fn destroy_connected_blocks(&mut self, shared: &mut Shared, position: voxel::Position, marks: &mut voxel::BitGrid) {

		fn closure(slf: &mut Body, shared: &mut Shared, position: voxel::Position, marks: &mut voxel::BitGrid) {
			if slf
				.blocks
				.get(position)
				.map(|b| b.health.is_some())
				.unwrap_or(false)
			{
				slf.destroy_connected_blocks(shared, position, marks)
			}
		}

		//if let Some(hp) = self.blocks[position].health.take() {
		if marks.set(position, false).unwrap() {
			debug_assert_ne!(self.blocks[position].id, Some(MAINFRAME_ID));

			let hp = self.blocks[position].health.take().unwrap().get();

			let _ = self.remove_all_anchors(position);

			let pos = if hp & 0x8000 == 0 {
				self.correct_for_removed_block(position);
				Self::apply_to_all_sides(position, |pos| closure(self, shared, pos, marks));
				position
			} else {
				let index = hp & 0x7fff;
				let mb = self.multi_blocks[index as usize].take();
				let mb = mb.expect("Multi mb is None but HP is not zero!");

				let pos = mb.base_position;
				let rot = mb.rotation;

				// Destroy the block & any attached bodies.
				#[cfg(not(feature = "server"))]
				let body = mb.destroy(shared, &mut self.interpolation_states[..]);
				#[cfg(feature = "server")]
				let body = mb.destroy(shared);
				body.map(|body| {
					let body = &mut self.children[usize::from(body)];
					#[cfg(not(feature = "server"))]
					body.destroy(shared, body.center_of_mass);
					#[cfg(feature = "server")]
					body.destroy(shared);
				});

				let id = self.blocks[pos].id.unwrap();
				let blk = block::Block::get(id).unwrap();

				self.correct_for_removed_block(pos);

				// Set the base position to 0 HP
				self.blocks[pos].health = None;

				// Set all mount points to 0 HP
				for d in blk.extra_mount_points.iter().copied() {
					let d = voxel::Delta::from(d.position);
					if let Ok(p) = pos + rot * d {
						self.blocks.get_mut(p).map(|b| b.health = None);
					}
				}

				// Destroy all blocks attached to the base position
				Self::apply_to_all_sides(pos, |pos| closure(self, shared, pos, marks));

				// Destroy all blocks attached to the mount points.
				for d in blk.extra_mount_points.iter().copied() {
					let d = voxel::Delta::from(d.position);
					if let Ok(pos) = pos + rot * d {
						Self::apply_to_all_sides(pos, |pos| closure(self, shared, pos, marks));
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

	fn apply_to_all_sides(voxel: voxel::Position, mut f: impl FnMut(voxel::Position)) {
		(voxel + voxel::Delta::Z).ok().map(&mut f);
		(voxel - voxel::Delta::Z).ok().map(&mut f);
		(voxel + voxel::Delta::Y).ok().map(&mut f);
		(voxel - voxel::Delta::Y).ok().map(&mut f);
		(voxel + voxel::Delta::X).ok().map(&mut f);
		(voxel - voxel::Delta::X).ok().map(&mut f);
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
	fn remove_all_anchors(&mut self, position: voxel::Position) -> bool {
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
		#[cfg(not(feature = "server"))]
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
				#[cfg(not(feature = "server"))]
				b.destroy(shared, b.center_of_mass);
				#[cfg(feature = "server")]
				b.destroy(shared);
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
			self.blocks.values_mut().for_each(|v| v.health = None);

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
