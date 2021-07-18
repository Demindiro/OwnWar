use super::*;
use crate::rotation::Rotation;
use core::convert::TryInto;
use core::num::NonZeroU32;
use gdnative::api::Spatial;
use gdnative::prelude::*;

pub(in super::super) struct MultiBlock {
	pub(super) health: NonZeroU32,
	// TODO fix borrow stuff
	pub(in super::super) server_node: Option<Ref<Spatial>>,
	#[cfg(not(feature = "server"))]
	pub(super) client_node: Option<Ref<Spatial>>,
	pub(super) reverse_indices: Box<[voxel::Position]>,
	#[cfg(not(feature = "server"))]
	pub(super) interpolation_state_index: u16,
	pub(super) rotation: Rotation,
	pub(super) base_position: voxel::Position,

	pub(super) weapon_index: u16,
	pub(super) turret_index: u16,
	pub(super) movement_index: u16,
	pub(super) steppable_index: u16,
	pub(super) saveable_index: u16,
	pub(super) temporary_index: u16,
	pub(super) permanent_index: u16,

	/// The index of the child body this anchor connects to, if any
	pub(super) anchor_body_index: Option<u8>,
}

#[derive(Debug)]
pub struct BodyAlreadySet;

impl MultiBlock {
	/// Destroys this MultiBlock, clearing it from the Shared and InterpolationState
	/// structures. It returns the index of the anchored child body, if any.
	#[must_use]
	pub fn destroy(
		mut self,
		shared: &mut vehicle::Shared,
		#[cfg(not(feature = "server"))] interpolation_states: &mut [Option<InterpolationState>],
	) -> Option<u8> {
		// Remove any nodes to be destroyed from the shared lists.
		if self.turret_index < u16::MAX {
			debug_assert!(shared.turrets[usize::from(self.turret_index)].is_some());
			shared.turrets[usize::from(self.turret_index)] = None;
		}
		if self.weapon_index < u16::MAX {
			debug_assert!(shared.weapons[usize::from(self.weapon_index)].is_some());
			shared.weapons[usize::from(self.weapon_index)] = None;
		}
		if self.movement_index < u16::MAX {
			debug_assert!(shared.movement[usize::from(self.movement_index)].is_some());
			shared.movement[usize::from(self.movement_index)] = None;
		}
		if self.saveable_index < u16::MAX {
			debug_assert!(shared.saveable[usize::from(self.steppable_index)].is_some());
			shared.saveable[usize::from(self.saveable_index)] = None;
		}
		if self.steppable_index < u16::MAX {
			debug_assert!(shared.steppable[usize::from(self.steppable_index)].is_some());
			shared.steppable[usize::from(self.steppable_index)] = None;
		}
		if self.temporary_index < u16::MAX {
			debug_assert!(shared.temporary[usize::from(self.temporary_index)].is_some());
			shared.temporary[usize::from(self.temporary_index)] = None;
		}
		if self.permanent_index < u16::MAX {
			debug_assert!(shared.permanent[usize::from(self.permanent_index)].is_some());
			shared.permanent[usize::from(self.permanent_index)] = None;
		}

		// Remove from interpolation list
		#[cfg(not(feature = "server"))]
		if self.interpolation_state_index < u16::MAX {
			interpolation_states[usize::from(self.interpolation_state_index)] = None;
		}

		// Destroy the nodes
		if let Some(sn) = self.server_node.take() {
			unsafe {
				let sn = sn.assume_safe();
				sn.queue_free();
				if sn.has_method("destroy") {
					sn.call("destroy", &[]);
				}
			}
		}
		#[cfg(not(feature = "server"))]
		if let Some(cn) = self.client_node.take() {
			unsafe {
				cn.assume_safe().queue_free();
			}
		}

		self.anchor_body_index
	}

	/// Set the anchored body. The body may not already have been set.
	///
	/// It will not return an error if the same body is set twice.
	pub fn set_anchored_body(&mut self, body: u8) -> Result<(), BodyAlreadySet> {
		if let Some(i) = self.anchor_body_index {
			(i == body).then(|| ()).ok_or(BodyAlreadySet)
		} else {
			self.anchor_body_index = Some(body);
			Ok(())
		}
	}

	/// Initialize the block for the given body.
	pub(super) fn init(
		&mut self,
		offset: voxel::Position,
		center_of_mass: Vector3,
		shared: &mut vehicle::Shared,
	) {
		if let Some(server_node) = self.server_node.as_ref() {
			let server_node = unsafe { server_node.assume_safe() };

			server_node.set("team", shared.team);
			server_node.set("base_position", self.base_position.to_variant());
			server_node.set("body_offset", offset.to_variant());
			server_node.set("body_center_of_mass", center_of_mass.to_variant());

			// Check if the block has a "step" function
			if !server_node.get("steppable_index").is_nil() {
				self.steppable_index = shared.steppable.len().try_into().unwrap();
				shared.steppable.push(self.server_node);
			}

			// Check if the block is a movement part
			if !server_node.get("movement_index").is_nil() {
				self.movement_index = shared.movement.len().try_into().unwrap();
				shared.movement.push(self.server_node);
			}

			// Check if the block is a weapon
			if !server_node.get("weapon_index").is_nil() {
				self.weapon_index = shared.weapons.len().try_into().unwrap();
				shared.weapons.push(self.server_node);
			}

			// Check if the block is a turret
			if !server_node.get("turret_index").is_nil() {
				self.turret_index = shared.turrets.len().try_into().unwrap();
				shared.turrets.push(self.server_node);
			}

			// Check if the block has saveable state
			if !server_node.get("saveable_index").is_nil() {
				self.saveable_index = shared.saveable.len().try_into().unwrap();
				shared.saveable.push(self.server_node);
			}

			// Check if the block has temporary data each frame
			if !server_node.get("temporary_index").is_nil() {
				self.temporary_index = shared.temporary.len().try_into().unwrap();
				shared.temporary.push(self.server_node);
			}

			// Check if the block has permanent data each frame
			if !server_node.get("permanent_index").is_nil() {
				self.permanent_index = shared.permanent.len().try_into().unwrap();
				shared.permanent.push(self.server_node);
			}
		}
	}
}
