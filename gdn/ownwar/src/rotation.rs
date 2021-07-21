#![cfg_attr(feature = "server", allow(dead_code))]

use crate::types::voxel;
use core::convert::TryInto;
use core::ops;
use gdnative::prelude::{Basis, Vector3};

#[derive(Copy, Clone, Debug, Hash, PartialEq, Eq)]
pub struct Rotation(u8);

#[derive(Copy, Clone, Debug, Hash, PartialEq, Eq)]
pub enum Direction {
	Up,
	Down,
	Right,
	Left,
	Forward,
	Back,
}

#[derive(Debug)]
pub struct OutOfBounds;

impl Rotation {
	pub const MAX: Self = Self(23);

	/// Create a new `Rotation`
	///
	/// `n` must be smaller than 24
	pub const fn new(n: u8) -> Result<Self, OutOfBounds> {
		if n <= Self::MAX.0 {
			Ok(Self(n))
		} else {
			Err(OutOfBounds)
		}
	}

	/// Get the value inside the `Rotation`
	pub const fn get(self) -> u8 {
		self.0
	}

	/// Map the rotations
	pub fn rotation_map(self) -> [Rotation; 24] {
		assert!(
			self.0 < 4,
			"Only rotations below 4 are supported at the moment"
		);
		let mut map = [Self::default(); 24];
		for i in 0..24 {
			let angle = i & 3;
			let direction = i >> 2;

			let angle = if self.0 % 2 == 0 {
				[0, 3, 2, 1][angle]
			} else {
				[3, 2, 1, 0][angle]
			};
			let direction = match direction {
				3 => 2,
				2 => 3,
				_ => direction,
			};

			map[i] = Self(((direction << 2) | angle) as u8);
			debug_assert!(map[i].0 <= Self::MAX.0, "Mapped value is greater than MAX");
		}
		map
	}

	/// Get the `Basis` for this rotation
	pub fn basis(self) -> Basis {
		let angle = self.0 & 3;
		let direction = self.0 >> 2;
		const fn v(x: i8, y: i8, z: i8) -> Vector3 {
			Vector3::new(x as f32, y as f32, z as f32)
		}
		const fn b(x: Vector3, y: Vector3, z: Vector3) -> Basis {
			Basis {
				elements: [x, y, z],
			}
		}
		let b_a = [
			// 0, 0, 0
			b(v(1, 0, 0), v(0, 1, 0), v(0, 0, 1)),
			// 0, PI/2, 0
			b(v(0, 0, 1), v(0, 1, 0), v(-1, 0, 0)),
			// 0, PI, 0
			b(v(-1, 0, 0), v(0, 1, 0), v(0, 0, -1)),
			// 0, PI*3/2, 0
			b(v(0, 0, -1), v(0, 1, 0), v(1, 0, 0)),
		][angle as usize];
		let b_b = [
			// 0, 0, 0
			b(v(1, 0, 0), v(0, 1, 0), v(0, 0, 1)),
			// 0, 0, PI
			b(v(-1, 0, 0), v(0, -1, 0), v(0, 0, 1)),
			// 0, 0, -PI/2
			b(v(0, 1, 0), v(-1, 0, 0), v(0, 0, 1)),
			// 0, 0, PI/2
			b(v(0, -1, 0), v(1, 0, 0), v(0, 0, 1)),
			// PI/2, 0, 0
			b(v(1, 0, 0), v(0, 0, -1), v(0, 1, 0)),
			// TODO do the math for this. I'm lazy :(
			// (0, PI, 0) * (PI/2, 0, 0)
			b(v(-1, 0, 0), v(0, 1, 0), v(0, 0, -1)) * b(v(1, 0, 0), v(0, 0, -1), v(0, 1, 0)),
		][direction as usize];
		b_b * b_a
	}

	pub fn snap_to_direction<T>(self, axis: (T, T, T)) -> Result<Self, ()>
	where
		T: TryInto<i64> + Copy,
	{
		let f = |v: T| v.try_into().map_err(|_| ());
		let axis = (f(axis.0)?, f(axis.1)?, f(axis.2)?);
		let d = match axis {
			(0, 1, 0) => 0,
			(0, -1, 0) => 1,
			(1, 0, 0) => 2,
			(-1, 0, 0) => 3,
			(0, 0, 1) => 4,
			(0, 0, -1) => 5,
			_ => return Err(()),
		};
		let v = (self.0 & 3) | (d << 2);
		assert!(v <= Self::MAX.0);
		Ok(Self(v))
	}

	pub fn map_counter_clockwise(self) -> Self {
		let a = self.0 & 3;
		let (d, a) = match self.0 >> 2 {
			0 => (0, [1, 2, 3, 0][a as usize]),
			1 => (1, [3, 0, 1, 2][a as usize]),
			2 => (5, [3, 0, 1, 2][a as usize]),
			3 => (4, (a + 1) & 3),
			4 => (2, (a + 1) & 3),
			5 => (3, [3, 4, 1, 2][a as usize]),
			_ => unreachable!(),
		};
		let v = (d << 2) | a;
		assert!(v <= Self::MAX.0);
		Self(v)
	}

	pub fn transform_direction(self, direction: Direction) -> Direction {
		// TODO figure out the proper mapping and use that directly instead of this thing
		// that likely won't be optimized properly
		Direction::from_vector(
			self.basis()
				.to_quat()
				.transform_vector3d(direction.delta().into()),
		)
		.expect("Failed to get direction from vector")
	}
}

impl Direction {
	pub const fn new(n: u8) -> Result<Self, OutOfBounds> {
		match n {
			0 => Ok(Self::Up),
			1 => Ok(Self::Down),
			2 => Ok(Self::Right),
			3 => Ok(Self::Left),
			4 => Ok(Self::Forward),
			5 => Ok(Self::Back),
			_ => Err(OutOfBounds),
		}
	}

	pub const fn get(self) -> u8 {
		match self {
			Self::Up => 0,
			Self::Down => 1,
			Self::Right => 2,
			Self::Left => 3,
			Self::Forward => 4,
			Self::Back => 5,
		}
	}

	pub fn from_vector(axis: Vector3) -> Result<Self, OutOfBounds> {
		let axis = (axis.x.round(), axis.y.round(), axis.z.round());
		match axis {
			_ if axis == (0.0, 1.0, 0.0) => Ok(Self::Up),
			_ if axis == (0.0, -1.0, 0.0) => Ok(Self::Down),
			_ if axis == (1.0, 0.0, 0.0) => Ok(Self::Right),
			_ if axis == (-1.0, 0.0, 0.0) => Ok(Self::Left),
			_ if axis == (0.0, 0.0, 1.0) => Ok(Self::Forward),
			_ if axis == (0.0, 0.0, -1.0) => Ok(Self::Back),
			_ => Err(OutOfBounds),
		}
	}

	/// Return the corresponding `Delta` for this `Direction`.
	pub fn delta(self) -> voxel::Delta {
		match self {
			Self::Up => voxel::Delta::Y,
			Self::Down => -voxel::Delta::Y,
			Self::Right => voxel::Delta::X,
			Self::Left => -voxel::Delta::X,
			Self::Forward => voxel::Delta::Z,
			Self::Back => -voxel::Delta::Z,
		}
	}

	pub fn invert(self) -> Self {
		Self::new([1, 0, 3, 2, 5, 4][self.get() as usize]).unwrap()
	}
}

impl Default for Rotation {
	fn default() -> Self {
		Self(0)
	}
}

impl Default for Direction {
	fn default() -> Self {
		Self::Up
	}
}

impl ops::Neg for Direction {
	type Output = Self;

	fn neg(self) -> Self::Output {
		match self {
			Self::Up => Self::Down,
			Self::Down => Self::Up,
			Self::Right => Self::Left,
			Self::Left => Self::Right,
			Self::Forward => Self::Back,
			Self::Back => Self::Forward,
		}
	}
}

#[cfg(test)]
mod tests {

	use super::*;

	#[test]
	fn rotation_to_basis() {
		fn orig(rotation: u8) -> Basis {
			use std::f32::consts::{FRAC_PI_2, PI};
			assert!(rotation < 24);
			let angle = rotation & 3;
			let direction = rotation >> 2;
			let f = |x, y, z| Basis::from_euler(Vector3::new(x, y, z));
			let basis = f(0.0, FRAC_PI_2 * angle as f32, 0.0);
			let b2 = match direction {
				0 => Basis::identity(),
				1 => f(0.0, 0.0, PI),
				2 => f(0.0, 0.0, -FRAC_PI_2),
				3 => f(0.0, 0.0, FRAC_PI_2),
				4 => f(FRAC_PI_2, 0.0, 0.0),
				5 => f(0.0, PI, 0.0) * f(FRAC_PI_2, 0.0, 0.0),
				_ => unreachable!(),
			};
			b2 * basis
		}

		for i in 0..24 {
			let r = Rotation::new(i).unwrap();
			let mut org = orig(i);
			for e in org.elements.iter_mut() {
				*e = e.round();
			}
			assert_eq!(
				r.basis(),
				org,
				"Rotation {}, angle {}, direction {}",
				i,
				i & 3,
				i >> 2
			);
		}
	}
}
