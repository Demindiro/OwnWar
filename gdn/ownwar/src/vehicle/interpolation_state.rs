use crate::block;
use gdnative::api::{Resource, Spatial};
use gdnative::prelude::*;

pub(super) struct InterpolationState {
	previous_transform: Transform,
	current_transform: Transform,
	pub server_node: Ref<Spatial>,
	pub client_node: Ref<Spatial>,
}

impl InterpolationState {
	pub fn new(block: &block::Block) -> Option<Self> {
		if let Some(server_node) = block.server_node {
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
				block.client_node
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

	pub fn from(server_node: Ref<Spatial>, client_node: Ref<Spatial>) -> Self {
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

	pub fn update(&mut self) {
		self.previous_transform = self.current_transform;
		let trf = unsafe { self.server_node.assume_safe().global_transform() };
		let chk_nan = |v: Vector3| v.x.is_nan() || v.y.is_nan() || v.z.is_nan();
		if chk_nan(trf.origin)
			|| chk_nan(trf.basis.x())
			|| chk_nan(trf.basis.y())
			|| chk_nan(trf.basis.z())
		{
			let sn = unsafe { self.server_node.assume_safe() };
			godot_error!(
				"Transform has NaN components! Offender: [{}:{}], transform: {:?}",
				sn.get_class(),
				sn.get_instance_id(),
				trf,
			);
		} else {
			self.current_transform = trf;
		}
	}

	pub fn interpolate(&self, fraction: f32) {
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
