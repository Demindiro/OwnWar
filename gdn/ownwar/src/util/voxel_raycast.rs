use crate::util::AABB;
use euclid::{UnknownUnit, Vector3D};
use gdnative::prelude::Vector3;

pub type Vector3i = Vector3D<i32, UnknownUnit>;
pub type Vector3i8 = Vector3D<i8, UnknownUnit>;

pub struct VoxelRaycast {
	voxel: Vector3i,
	limit: Vector3i,
	step: Vector3i8,
	t_max: Vector3,
	t_delta: Vector3,
	last_step: LastStep,
	finished: bool,
}

enum LastStep {
	X,
	Y,
	Z,
}

fn vector_div(a: Vector3, b: Vector3) -> Vector3 {
	Vector3::new(a.x / b.x, a.y / b.y, a.z / b.z)
}

impl VoxelRaycast {
	pub fn start(mut start: Vector3, direction: Vector3, aabb: AABB<i32>) -> VoxelRaycast {
		let in_aabb = aabb.convert().has_point(start);
		let mut last_step = LastStep::X;

		if !in_aabb {
			let aabb = aabb.convert();
			let t_a = vector_div(aabb.position - start, direction);
			let t_b = vector_div(aabb.end() - start, direction);
			let t_min = t_a.x.min(t_b.x).max(t_a.y.min(t_b.y)).max(t_a.z.min(t_b.z));
			let t_max = t_a.x.max(t_b.x).min(t_a.y.max(t_b.y)).min(t_a.z.max(t_b.z));
			if t_min > t_max || t_min < 0.0 {
				return Self {
					voxel: Vector3D::zero(),
					limit: Vector3D::zero(),
					step: Vector3D::zero(),
					t_max: Vector3D::zero(),
					t_delta: Vector3D::zero(),
					last_step: LastStep::X,
					finished: true,
				};
			}
			start += direction * t_min;
			let (tax, tay, taz) = (t_a.x, t_a.y, t_a.z);
			let (tbx, tby, tbz) = (t_b.x, t_b.y, t_b.z);
			last_step = if t_min == tax || t_min == tbx {
				LastStep::X
			} else if t_min == tay || t_min == tby {
				LastStep::Y
			} else if t_min == taz || t_min == tbz {
				LastStep::Z
			} else {
				unreachable!();
			}
		}

		let voxel_f = start.floor();
		let voxel = voxel_f.to_i32();

		let step = Vector3i8::new(
			direction.x.signum() as i8,
			direction.y.signum() as i8,
			direction.z.signum() as i8,
		);

		let limit = Vector3i::new(
			if step.x > 0 {
				aabb.end().x
			} else {
				aabb.position.x - 1
			},
			if step.y > 0 {
				aabb.end().y
			} else {
				aabb.position.y - 1
			},
			if step.z > 0 {
				aabb.end().z
			} else {
				aabb.position.z - 1
			},
		);

		let planes = Vector3::new(
			if step.x > 0 { 1.0 } else { 0.0 },
			if step.y > 0 { 1.0 } else { 0.0 },
			if step.z > 0 { 1.0 } else { 0.0 },
		);
		let impact_rel_pos = start - voxel_f;
		let t_max = vector_div(planes - impact_rel_pos, direction);
		let t_delta = vector_div(step.to_f32(), direction);

		let last_step = if in_aabb {
			if t_max.x > t_max.y {
				if t_max.x > t_max.z {
					LastStep::X
				} else {
					LastStep::Z
				}
			} else {
				if t_max.y > t_max.z {
					LastStep::Y
				} else {
					LastStep::Z
				}
			}
		} else {
			last_step
		};

		Self {
			voxel,
			limit,
			step,
			t_max,
			t_delta,
			last_step,
			finished: false,
		}
	}

	pub fn voxel(&self) -> Vector3i {
		self.voxel
	}

	// This will be used later for the editor
	#[allow(dead_code)]
	pub fn normal(&self) -> Vector3i {
		match self.last_step {
			LastStep::X => Vector3i::new(-self.step.x as i32, 0, 0),
			LastStep::Y => Vector3i::new(0, -self.step.y as i32, 0),
			LastStep::Z => Vector3i::new(0, 0, -self.step.z as i32),
		}
	}

	pub fn finished(&self) -> bool {
		self.finished
	}
}

impl Iterator for VoxelRaycast {
	type Item = Vector3i;

	fn next(&mut self) -> Option<Self::Item> {
		if self.finished {
			return None;
		}
		let voxel = self.voxel;
		if self.t_max.x < self.t_max.y {
			if self.t_max.x < self.t_max.z {
				self.voxel.x += self.step.x as i32;
				self.finished = self.voxel.x == self.limit.x;
				self.t_max.x += self.t_delta.x;
				self.last_step = LastStep::X
			} else {
				self.voxel.z += self.step.z as i32;
				self.finished = self.voxel.z == self.limit.z;
				self.t_max.z += self.t_delta.z;
				self.last_step = LastStep::Z
			}
		} else {
			if self.t_max.y < self.t_max.z {
				self.voxel.y += self.step.y as i32;
				self.finished = self.voxel.y == self.limit.y;
				self.t_max.y += self.t_delta.y;
				self.last_step = LastStep::Y
			} else {
				self.voxel.z += self.step.z as i32;
				self.finished = self.voxel.z == self.limit.z;
				self.t_max.z += self.t_delta.z;
				self.last_step = LastStep::Z
			}
		}
		Some(voxel)
	}
}
