#![cfg_attr(feature = "server", allow(dead_code))]

use crate::util::convert_vec;
use euclid::UnknownUnit;
use euclid::Vector3D;
use gdnative::prelude::{Basis, Vector3};
use std::convert::TryInto;

#[derive(Copy, Clone, Debug, Hash, PartialEq, Eq)]
pub struct Rotation(u8);

#[derive(Copy, Clone, Debug, Hash, PartialEq, Eq)]
pub struct Direction(u8);

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
				.transform_vector3d(convert_vec(direction.vector())),
		)
		.expect("Failed to get direction from vector")
	}
}

impl Direction {
	pub const MAX: Self = Self(5);

	pub const fn new(n: u8) -> Result<Self, OutOfBounds> {
		if n <= Self::MAX.0 {
			Ok(Self(n))
		} else {
			Err(OutOfBounds)
		}
	}

	pub const fn get(self) -> u8 {
		self.0
	}

	pub fn from_vector<T>(axis: Vector3D<T, UnknownUnit>) -> Result<Self, OutOfBounds>
	where
		T: Into<f64>,
	{
		let axis = (
			axis.x.into().round(),
			axis.y.into().round(),
			axis.z.into().round(),
		);
		let d = match axis {
			_ if axis == (0.0, 1.0, 0.0) => 0,
			_ if axis == (0.0, -1.0, 0.0) => 1,
			_ if axis == (1.0, 0.0, 0.0) => 2,
			_ if axis == (-1.0, 0.0, 0.0) => 3,
			_ if axis == (0.0, 0.0, 1.0) => 4,
			_ if axis == (0.0, 0.0, -1.0) => 5,
			_ => return Err(OutOfBounds),
		};
		Ok(Self(d))
	}

	pub fn vector(self) -> Vector3D<i8, UnknownUnit> {
		match self.0 {
			0 => Vector3D::new(0, 1, 0),
			1 => Vector3D::new(0, -1, 0),
			2 => Vector3D::new(1, 0, 0),
			3 => Vector3D::new(-1, 0, 0),
			4 => Vector3D::new(0, 0, 1),
			5 => Vector3D::new(0, 0, -1),
			_ => unreachable!(),
		}
	}

	pub fn invert(self) -> Self {
		Self([1, 0, 3, 2, 5, 4][self.0 as usize])
	}
}

impl Default for Rotation {
	fn default() -> Self {
		Self(0)
	}
}

impl Default for Direction {
	fn default() -> Self {
		Self(0)
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
