use super::*;
use crate::rotation::Rotation;
use core::convert::{TryFrom, TryInto};
use core::fmt;
use core::ops;
use gdnative::core_types::{ToVariant, Variant, Vector3};

/// A 3D offset or delta relative to a position
#[derive(Clone, Copy, PartialEq, Eq)]
pub struct Delta {
	pub x: i16,
	pub y: i16,
	pub z: i16,
}

impl Delta {
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
	pub const fn new(x: i16, y: i16, z: i16) -> Self {
		Self { x, y, z }
	}
}

impl fmt::Debug for Delta {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		write!(f, "({}, {}, {})", self.x, self.y, self.z)
	}
}

impl fmt::Display for Delta {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		fmt::Debug::fmt(self, f)
	}
}

impl ops::Sub<Position> for Position {
	type Output = Delta;

	fn sub(self, rhs: Self) -> Self::Output {
		let (x0, y0, z0): (i16, _, _) = self.into();
		let (x1, y1, z1): (i16, _, _) = rhs.into();
		Delta::new(x0 - x1, y0 - y1, z0 - z1)
	}
}

impl ops::Add<Delta> for Delta {
	type Output = Self;

	fn add(self, rhs: Self) -> Self::Output {
		Self::new(self.x + rhs.x, self.y + rhs.y, self.z + rhs.z)
	}
}

impl ops::Sub<Delta> for Delta {
	type Output = Self;

	fn sub(self, rhs: Self) -> Self::Output {
		Self::new(self.x - rhs.x, self.y - rhs.y, self.z - rhs.z)
	}
}

impl ops::Add<Delta> for Position {
	type Output = Result<Self, <i16 as TryInto<u8>>::Error>;

	fn add(self, rhs: Delta) -> Self::Output {
		let Delta { x, y, z } = Delta::from(self) + rhs;
		let x = x.try_into()?;
		let y = y.try_into()?;
		let z = z.try_into()?;
		Ok(Self::new(x, y, z))
	}
}

impl ops::Sub<Delta> for Position {
	type Output = Result<Self, <i16 as TryInto<u8>>::Error>;

	fn sub(self, rhs: Delta) -> Self::Output {
		let Delta { x, y, z } = Delta::from(self) - rhs;
		let x = x.try_into()?;
		let y = y.try_into()?;
		let z = z.try_into()?;
		Ok(Self::new(x, y, z))
	}
}

impl ops::Mul<Delta> for Rotation {
	type Output = Delta;

	fn mul(self, rhs: Delta) -> Self::Output {
		let Delta { x, y, z } = rhs;
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
		Delta::new(x, y, z)
	}
}

impl ops::Neg for Delta {
	type Output = Delta;

	fn neg(self) -> Self::Output {
		Self::new(-self.x, -self.y, -self.z)
	}
}

impl From<Position> for Delta {
	fn from(position: Position) -> Self {
		Self::new(position.x.into(), position.y.into(), position.z.into())
	}
}

impl From<(i16, i16, i16)> for Delta {
	fn from(tuple: (i16, i16, i16)) -> Self {
		Self::new(tuple.0, tuple.1, tuple.2)
	}
}

impl From<(i8, i8, i8)> for Delta {
	fn from(tuple: (i8, i8, i8)) -> Self {
		Self::new(tuple.0.into(), tuple.1.into(), tuple.2.into())
	}
}

impl TryFrom<Delta> for Position {
	type Error = <u8 as TryFrom<i16>>::Error;

	fn try_from(delta: Delta) -> Result<Self, Self::Error> {
		Ok(Self::new(
			delta.x.try_into()?,
			delta.y.try_into()?,
			delta.z.try_into()?,
		))
	}
}

impl From<Delta> for Vector3 {
	fn from(delta: Delta) -> Self {
		Self::new(delta.x.into(), delta.y.into(), delta.z.into())
	}
}

impl TryFrom<Vector3> for Delta {
	type Error = <i16 as TryFrom<isize>>::Error;

	fn try_from(vector: Vector3) -> Result<Self, Self::Error> {
		let (x, y, z) = (vector.x as isize, vector.y as isize, vector.z as isize);
		Ok(Self::new(x.try_into()?, y.try_into()?, z.try_into()?))
	}
}

impl ToVariant for Delta {
	fn to_variant(&self) -> Variant {
		Vector3::from(*self).to_variant()
	}
}
