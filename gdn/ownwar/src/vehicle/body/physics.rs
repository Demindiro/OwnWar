use super::*;
use crate::util::*;

impl super::Body {
	/// Resize & reposition the collider so that it fits the body as tightly as possible.
	pub(super) fn correct_collider_size(&mut self) {
		let mut start = self.collider_end_point;
		let mut end = self.collider_start_point;
		for v in iter_3d_inclusive(
			self.collider_start_point.to_tuple(),
			self.collider_end_point.to_tuple(),
		)
		.map(Voxel::from)
		{
			if self.get_block_health(v) > 0 {
				start = start.min(v);
				end = end.max(v);
			}
		}
		if start != self.collider_start_point || end != self.collider_end_point {
			self.resize_collider(start, end);
		}
	}

	/// Resize the collider according to the given start and end position.
	pub(super) fn resize_collider(&mut self, start: Voxel, end: Voxel) {
		self.collider_start_point = start;
		self.collider_end_point = end;
		let middle = convert_vec::<_, usize>(start) + convert_vec::<_, usize>(end);
		let middle = convert_vec::<_, f32>(middle) * 0.5 * block::SCALE;
		let extents = convert_vec::<_, f32>(end - start + Vector3D::one()) * 0.5 * block::SCALE;
		unsafe {
			let col = self.collision_shape.assume_safe();
			col.set_extents(extents);
			let col = self.collision_shape_instance.unwrap().assume_safe();
			col.set_translation(middle);
		}
	}
}
