use crate::types::voxel;
use core::convert::TryFrom;
use gdnative::prelude::Vector3;

pub struct VoxelRaycast {
	voxel: voxel::Delta,
	limit: voxel::Delta,
	step: voxel::Delta,
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
	pub fn start(mut start: Vector3, direction: Vector3, aabb: voxel::AABB) -> VoxelRaycast {
		let in_aabb = voxel::Position::try_from(start)
			.map(|s| aabb.has_point(s))
			.unwrap_or(false);
		let mut last_step = LastStep::X;

		if !in_aabb {
			let t_a = vector_div(Vector3::from(aabb.start) - start, direction);
			let t_b = vector_div(Vector3::from(aabb.end) + Vector3::one() - start, direction);
			let t_min = t_a.x.min(t_b.x).max(t_a.y.min(t_b.y)).max(t_a.z.min(t_b.z));
			let t_max = t_a.x.max(t_b.x).min(t_a.y.max(t_b.y)).min(t_a.z.max(t_b.z));
			if t_min > t_max || t_min < 0.0 {
				return Self {
					voxel: voxel::Delta::ZERO,
					limit: voxel::Delta::ZERO,
					step: voxel::Delta::ZERO,
					t_max: Vector3::zero(),
					t_delta: Vector3::zero(),
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
		let voxel = voxel::Delta::try_from(voxel_f).expect("Failed to convert voxel");

		let step = voxel::Delta::new(
			direction.x.signum() as i16,
			direction.y.signum() as i16,
			direction.z.signum() as i16,
		);

		let (s, e): (voxel::Delta, voxel::Delta) = (aabb.start.into(), aabb.end.into());
		let limit = voxel::Delta::new(
			(step.x > 0).then(|| e.x + 1).unwrap_or(s.x - 1),
			(step.y > 0).then(|| e.y + 1).unwrap_or(s.y - 1),
			(step.z > 0).then(|| e.z + 1).unwrap_or(s.z - 1),
		);

		let planes = Vector3::new(
			f32::from(u8::from(step.x > 0)),
			f32::from(u8::from(step.y > 0)),
			f32::from(u8::from(step.z > 0)),
		);
		let impact_rel_pos = start - voxel_f;
		let t_max = vector_div(planes - impact_rel_pos, direction);
		let t_delta = vector_div(step.into(), direction);

		let last_step = if in_aabb {
			if t_max.x > t_max.y {
				(t_max.x > t_max.z)
					.then(|| LastStep::X)
					.unwrap_or(LastStep::Z)
			} else {
				(t_max.y > t_max.z)
					.then(|| LastStep::Y)
					.unwrap_or(LastStep::Z)
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

	// FIXME The naming is wrong: a voxel represents a value in a cell, not a coordinate
	pub fn voxel(&self) -> voxel::Delta {
		self.voxel
	}

	/// Return the normal of the last step, i.e. the last `Delta`.
	pub fn normal(&self) -> voxel::Delta {
		match self.last_step {
			LastStep::X => voxel::Delta::new(-self.step.x, 0, 0),
			LastStep::Y => voxel::Delta::new(0, -self.step.y, 0),
			LastStep::Z => voxel::Delta::new(0, 0, -self.step.z),
		}
	}

	pub fn finished(&self) -> bool {
		self.finished
	}
}

impl Iterator for VoxelRaycast {
	type Item = (voxel::Delta, voxel::Delta);

	/// FIXME this method effectively buffers the position, which is _very_
	/// unintuitive as voxel() and normal() don't work as expected now.
	fn next(&mut self) -> Option<Self::Item> {
		if self.finished {
			return None;
		}
		let voxel = self.voxel;
		let normal = self.normal();
		if self.t_max.x < self.t_max.y {
			if self.t_max.x < self.t_max.z {
				self.voxel.x += self.step.x as i16;
				self.finished = self.voxel.x == self.limit.x;
				self.t_max.x += self.t_delta.x;
				self.last_step = LastStep::X
			} else {
				self.voxel.z += self.step.z as i16;
				self.finished = self.voxel.z == self.limit.z;
				self.t_max.z += self.t_delta.z;
				self.last_step = LastStep::Z
			}
		} else {
			if self.t_max.y < self.t_max.z {
				self.voxel.y += self.step.y as i16;
				self.finished = self.voxel.y == self.limit.y;
				self.t_max.y += self.t_delta.y;
				self.last_step = LastStep::Y
			} else {
				self.voxel.z += self.step.z as i16;
				self.finished = self.voxel.z == self.limit.z;
				self.t_max.z += self.t_delta.z;
				self.last_step = LastStep::Z
			}
		}
		Some((voxel, normal))
	}
}
