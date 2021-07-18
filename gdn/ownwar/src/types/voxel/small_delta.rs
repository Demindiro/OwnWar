use super::*;
use crate::rotation::Rotation;
use core::convert::{TryFrom, TryInto};
use core::fmt;
use core::ops;
use gdnative::core_types::{ToVariant, Variant, Vector3};

/// A 3D offset or delta relative to a position
///
/// This is similar to `Delta` except it uses `i8` internally, making it unable
/// to address the full possible distance between two `Position`s.
#[derive(Clone, Copy, PartialEq, Eq)]
pub struct SmallDelta {
	pub x: i8,
	pub y: i8,
	pub z: i8,
}

impl SmallDelta {
	/// The identity delta, i.e. the delta that won't change a position if added to.
	pub const ZERO: Self = Self::new(0, 0, 0);
	/// A delta that increases each component of a position by one.
	pub const ONE: Self = Self::new(1, 1, 1);
	/// A unit delta along the X axis
	pub const X: Self = Self::new(1, 0, 0);
	/// A unit delta along the Y axis
	pub const Y: Self = Self::new(0, 1, 0);
	/// A unit delta along the Z axis
	pub const Z: Self = Self::new(0, 0, 1);

	/// Create a new position.
	pub const fn new(x: i8, y: i8, z: i8) -> Self {
		Self { x, y, z }
	}

	/// Return the delta where each component is the minimum of each position.
	pub fn min(self, rhs: Self) -> Self {
		Self::new(self.x.min(rhs.x), self.y.min(rhs.y), self.z.min(rhs.z))
	}

	/// Return the delta where each component is the maximum of each position.
	pub fn max(self, rhs: Self) -> Self {
		Self::new(self.x.max(rhs.x), self.y.max(rhs.y), self.z.max(rhs.z))
	}
}

impl fmt::Debug for SmallDelta {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		write!(f, "({}, {}, {})", self.x, self.y, self.z)
	}
}

impl fmt::Display for SmallDelta {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		fmt::Debug::fmt(self, f)
	}
}

impl ops::Add<SmallDelta> for SmallDelta {
	type Output = Self;

	fn add(self, rhs: Self) -> Self::Output {
		Self::new(self.x + rhs.x, self.y + rhs.y, self.z + rhs.z)
	}
}

impl ops::Sub<SmallDelta> for SmallDelta {
	type Output = Self;

	fn sub(self, rhs: Self) -> Self::Output {
		Self::new(self.x - rhs.x, self.y - rhs.y, self.z - rhs.z)
	}
}

impl ops::Add<SmallDelta> for Position {
	type Output = Result<Self, <i16 as TryInto<u8>>::Error>;

	fn add(self, rhs: SmallDelta) -> Self::Output {
		let Delta { x, y, z } = Delta::from(self) + Delta::from(rhs);
		let x = x.try_into()?;
		let y = y.try_into()?;
		let z = z.try_into()?;
		Ok(Self::new(x, y, z))
	}
}

impl ops::Sub<SmallDelta> for Position {
	type Output = Result<Self, <i16 as TryInto<u8>>::Error>;

	fn sub(self, rhs: SmallDelta) -> Self::Output {
		let Delta { x, y, z } = Delta::from(self) - Delta::from(rhs);
		let x = x.try_into()?;
		let y = y.try_into()?;
		let z = z.try_into()?;
		Ok(Self::new(x, y, z))
	}
}

impl ops::Mul<SmallDelta> for Rotation {
	type Output = SmallDelta;

	fn mul(self, rhs: SmallDelta) -> Self::Output {
		let SmallDelta { x, y, z } = rhs;
		// Apply angle
		let (x, y, z) = match self.get() & 3 {
			0 => (x, y, z),
			1 => (z, y, -x),
			2 => (-x, y, -z),
			3 => (-z, y, x),
			_ => unreachable!(),
		};
		// Apply direction
		let (x, y, z) = match self.get() >> 2 {
			0 => (x, y, z),
			1 => (-x, -y, z),
			2 => (y, -x, z),
			3 => (-y, x, z),
			4 => (x, -z, y),
			5 => (-x, -z, -y),
			_ => unreachable!(),
		};
		SmallDelta::new(x, y, z)
	}
}

impl ops::Neg for SmallDelta {
	type Output = SmallDelta;

	fn neg(self) -> Self::Output {
		Self::new(-self.x, -self.y, -self.z)
	}
}

impl From<(i8, i8, i8)> for SmallDelta {
	fn from(tuple: (i8, i8, i8)) -> Self {
		Self::new(tuple.0.into(), tuple.1.into(), tuple.2.into())
	}
}

impl From<SmallDelta> for (i8, i8, i8) {
	fn from(delta: SmallDelta) -> Self {
		(delta.x, delta.y, delta.z)
	}
}

impl From<SmallDelta> for Delta {
	fn from(delta: SmallDelta) -> Self {
		Self::from(<(i8, i8, i8)>::from(delta))
	}
}

impl TryFrom<SmallDelta> for Position {
	type Error = <u8 as TryFrom<i16>>::Error;

	fn try_from(delta: SmallDelta) -> Result<Self, Self::Error> {
		Ok(Self::new(
			delta.x.try_into()?,
			delta.y.try_into()?,
			delta.z.try_into()?,
		))
	}
}

impl From<SmallDelta> for Vector3 {
	fn from(delta: SmallDelta) -> Self {
		Self::new(delta.x.into(), delta.y.into(), delta.z.into())
	}
}

impl TryFrom<Vector3> for SmallDelta {
	type Error = <i16 as TryFrom<isize>>::Error;

	fn try_from(vector: Vector3) -> Result<Self, Self::Error> {
		let (x, y, z) = (vector.x as isize, vector.y as isize, vector.z as isize);
		Ok(Self::new(x.try_into()?, y.try_into()?, z.try_into()?))
	}
}

impl ToVariant for SmallDelta {
	fn to_variant(&self) -> Variant {
		Vector3::from(*self).to_variant()
	}
}
