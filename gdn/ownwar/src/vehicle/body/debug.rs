use euclid::{UnknownUnit, Vector3D};

type Voxel = Vector3D<u8, UnknownUnit>;

impl super::Body {
	#[cfg(debug_assertions)]
	pub(super) fn debug_add_point(&self, point: Voxel) {
		let mut dhp = self.debug_hit_points.replace(Vec::new());
		dhp.push(point);
		self.debug_hit_points.set(dhp);
	}

	#[cfg(debug_assertions)]
	pub(super) fn debug_clear_points(&self) {
		self.debug_hit_points.set(Vec::new());
	}

	#[cfg(not(debug_assertions))]
	pub(super) fn debug_add_point(&self, _point: Voxel) {}

	#[cfg(not(debug_assertions))]
	pub(super) fn debug_clear_points(&self) {}
}
