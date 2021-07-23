use super::*;
use core::fmt;
use gdnative::core_types::{Aabb, ToVariant, Variant};

/// A voxel AABB, but using `SmallDelta` for relative positioning.
#[derive(Clone, Copy)]
pub struct SmallAABB {
	/// The start position of this AABB. It's components _must_ be smaller or equal to that of
	/// `end`.
	pub start: SmallDelta,
	/// The end position of this AABB. It's components _must_ be larger or equal to that of `start`.
	pub end: SmallDelta,
}

impl SmallAABB {
	/// Create a new AABB from two corner points.
	#[must_use]
	pub fn new(a: SmallDelta, b: SmallDelta) -> Self {
		let (start, end) = (a.min(b), a.max(b));
		Self { start, end }
	}

	/// Expand the AABB to include the given point.
	#[must_use]
	pub fn expand(&self, point: SmallDelta) -> Self {
		Self::new(self.start.min(point), self.end.max(point))
	}

	/// Return the AABB that encompasses two other AABBs as tightly as possible.
	#[must_use]
	pub fn union(&self, rhs: Self) -> Self {
		Self::new(self.start.min(rhs.start), self.end.max(rhs.end))
	}

	/// Returns `true` if this AABB encloses another.
	#[must_use]
	pub fn encloses(&self, rhs: Self) -> bool {
		self.has_point(rhs.start) && self.has_point(rhs.end)
	}

	/// Returns `true` if this AABB has the given point
	#[must_use]
	pub fn has_point(&self, point: SmallDelta) -> bool {
		self.start.max(point) == point && self.end.min(point) == point
	}

	/// Return the size of this AABB.
	pub fn size(&self) -> Delta {
		Delta::from(self.end) - Delta::from(self.start) + Delta::ONE
	}
}

impl fmt::Debug for SmallAABB {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		write!(f, "({}, {})", self.start, self.end)
	}
}

impl fmt::Display for SmallAABB {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		fmt::Debug::fmt(self, f)
	}
}

impl From<SmallAABB> for Aabb {
	fn from(aabb: SmallAABB) -> Self {
		Aabb {
			position: aabb.start.into(),
			size: aabb.size().into(),
		}
	}
}

impl ToVariant for SmallAABB {
	fn to_variant(&self) -> Variant {
		Aabb::from(*self).to_variant()
	}
}
