use crate::block;
use gdnative::api::Engine;
use gdnative::prelude::Vector3;

impl super::Body {
	/// Update the position of visual nodes (meshes).
	pub fn visual_step(&mut self, _delta: f32) {
		if self.is_destroyed() {
			return;
		}

		self.update_mesh();

		if self.interpolation_state_dirty {
			for state in self
				.interpolation_states
				.iter_mut()
				.filter_map(Option::as_mut)
			{
				state.update();
			}
		}
		self.interpolation_state_dirty = false;
		let frac = Engine::godot_singleton().get_physics_interpolation_fraction() as f32;
		for state in self
			.interpolation_states
			.iter_mut()
			.filter_map(Option::as_mut)
		{
			state.interpolate(frac);
		}
		self.children_mut().for_each(|b| b.visual_step(_delta));
	}

	pub fn update_mesh(&mut self) {
		self.voxel_mesh.as_ref().map(|vm| unsafe {
			vm.assume_safe()
				.map_mut(|s, o| {
					if s.dirty() {
						s.generate(&o);
					}
				})
				.unwrap()
		});
	}

	/// Returns the *visual* origin of the body, i.e. the position of the voxelmesh after
	/// interpolation.
	///
	/// ## Panics
	///
	/// There is no voxel mesh instance.
	pub fn visual_origin(&self) -> Vector3 {
		let trf = unsafe { self.voxel_mesh_instance.unwrap().assume_safe().transform() };
		trf.origin + trf.basis.xform(self.center_of_mass() * block::SCALE)
	}
}
