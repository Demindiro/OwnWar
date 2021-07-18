use super::*;
use crate::util::*;

impl super::Body {
	/// Resize & reposition the collider so that it fits the body as tightly as possible.
	pub(super) fn correct_collider_size(&mut self) {
		let mut start = self.collider_end_point;
		let mut end = self.collider_start_point;
		for v in iter_3d_inclusive(
			self.collider_start_point.into(),
			self.collider_end_point.into(),
		)
		.map(voxel::Position::from)
		{
			if self.blocks[v].health.is_some() {
				start = start.min(v);
				end = end.max(v);
			}
		}
		if start != self.collider_start_point || end != self.collider_end_point {
			self.resize_collider(start, end);
		}
	}

	/// Resize the collider according to the given start and end position.
	pub(super) fn resize_collider(&mut self, start: voxel::Position, end: voxel::Position) {
		self.collider_start_point = start;
		self.collider_end_point = end;
		let middle = (Vector3::from(start) + Vector3::from(end)) * 0.5 * block::SCALE;
		let extents = Vector3::from(end - start + voxel::Delta::ONE) * 0.5 * block::SCALE;
		unsafe {
			let col = self.collision_shape.assume_safe();
			col.set_extents(extents);
			let col = self.collision_shape_instance.unwrap().assume_safe();
			col.set_translation(middle);
		}
	}
}
