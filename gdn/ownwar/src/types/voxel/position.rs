use core::convert::{TryFrom, TryInto};
use core::fmt;
use gdnative::core_types::{ToVariant, Variant, Vector3};

/// A 3D coordinate representing the location of a block.
#[derive(Clone, Copy, Eq, PartialEq, Hash)]
pub struct Position {
	pub x: u8,
	pub y: u8,
	pub z: u8,
}

impl Position {
	/// The origin position
	pub const ZERO: Self = Self::new(0, 0, 0);

	/// Create a new position.
	pub const fn new(x: u8, y: u8, z: u8) -> Self {
		Self { x, y, z }
	}

	/// Return the position where each component is the minimum of each position.
	pub fn min(self, rhs: Self) -> Self {
		Self::new(self.x.min(rhs.x), self.y.min(rhs.y), self.z.min(rhs.z))
	}

	/// Return the position where each component is the maximum of each position.
	pub fn max(self, rhs: Self) -> Self {
		Self::new(self.x.max(rhs.x), self.y.max(rhs.y), self.z.max(rhs.z))
	}
}

impl fmt::Debug for Position {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		write!(f, "({}, {}, {})", self.x, self.y, self.z)
	}
}

impl fmt::Display for Position {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		fmt::Debug::fmt(self, f)
	}
}

impl From<Position> for (usize, usize, usize) {
	fn from(position: Position) -> Self {
		(position.x.into(), position.y.into(), position.z.into())
	}
}

impl From<Position> for (isize, isize, isize) {
	fn from(position: Position) -> Self {
		(position.x.into(), position.y.into(), position.z.into())
	}
}

impl From<Position> for (u32, u32, u32) {
	fn from(position: Position) -> Self {
		(position.x.into(), position.y.into(), position.z.into())
	}
}

impl From<Position> for (i16, i16, i16) {
	fn from(position: Position) -> Self {
		(position.x.into(), position.y.into(), position.z.into())
	}
}

impl From<Position> for (u8, u8, u8) {
	fn from(position: Position) -> Self {
		(position.x, position.y, position.z)
	}
}

impl From<(u8, u8, u8)> for Position {
	fn from(tuple: (u8, u8, u8)) -> Self {
		Self::new(tuple.0, tuple.1, tuple.2)
	}
}

impl From<Position> for Vector3 {
	fn from(position: Position) -> Self {
		Self::new(
			f32::from(position.x),
			f32::from(position.y),
			f32::from(position.z),
		)
	}
}

impl TryFrom<Vector3> for Position {
	type Error = <i16 as TryFrom<isize>>::Error;

	fn try_from(vector: Vector3) -> Result<Self, Self::Error> {
		let (x, y, z) = (vector.x as isize, vector.y as isize, vector.z as isize);
		Ok(Self::new(x.try_into()?, y.try_into()?, z.try_into()?))
	}
}

impl ToVariant for Position {
	fn to_variant(&self) -> Variant {
		Vector3::from(*self).to_variant()
	}
}
