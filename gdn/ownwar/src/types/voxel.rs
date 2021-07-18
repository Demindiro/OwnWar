use super::Unique;
use crate::rotation::Rotation;
use core::convert::{TryFrom, TryInto};
use core::fmt;
use core::mem::{self, MaybeUninit};
use core::ops;
use core::ops::{Index, IndexMut};
use core::ptr::{self, drop_in_place};
use gdnative::core_types::{Aabb, ToVariant, Variant, Vector3};
use std::alloc::{handle_alloc_error, Allocator, Global, Layout};

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

/// A voxel AABB.
#[derive(Clone, Copy)]
pub struct AABB {
	/// The start position of this AABB. It's components _must_ be smaller or equal to that of
	/// `end`.
	pub start: Position,
	/// The end position of this AABB. It's components _must_ be larger or equal to that of `start`.
	pub end: Position,
}

impl AABB {
	/// Create a new AABB from two corner points.
	#[must_use]
	pub fn new(a: Position, b: Position) -> Self {
		let (start, end) = (a.min(b), a.max(b));
		Self { start, end }
	}

	/// Expand the AABB to include the given point.
	#[must_use]
	pub fn expand(&self, point: Position) -> Self {
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
	pub fn has_point(&self, point: Position) -> bool {
		self.start.max(point) == point && self.end.min(point) == point
	}

	/// Return the size of this AABB.
	pub fn size(&self) -> Delta {
		self.end - self.start + Delta::ONE
	}
}

impl fmt::Debug for AABB {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		write!(f, "({}, {})", self.start, self.end)
	}
}

impl fmt::Display for AABB {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		fmt::Debug::fmt(self, f)
	}
}

impl From<AABB> for Aabb {
	fn from(aabb: AABB) -> Self {
		Aabb {
			position: aabb.start.into(),
			size: aabb.size().into(),
		}
	}
}

impl ToVariant for AABB {
	fn to_variant(&self) -> Variant {
		Aabb::from(*self).to_variant()
	}
}

/// A 3D grid of values
pub struct Grid<T, A = Global>
where
	A: Allocator,
{
	/// The size, including the final position.
	/// i.e. an `end` of `(0, 0, 0)` is size `(1, 1, 1)`.
	end: Position,
	/// The values. A raw pointer is used to avoid a redundant length value.
	ptr: Unique<T>,
	/// The allocator used.
	allocator: A,
}

impl<T> Grid<T, Global>
where
	T: Default,
{
	/// Create a new grid with the given top/end corner.
	pub fn new(end: Position) -> Self {
		Self::new_in(end, Global)
	}
}

impl<T, A> Grid<T, A>
where
	A: Allocator,
	T: Default,
{
	/// Create a new grid with the given top/end corner.
	pub fn new_in(end: Position, allocator: A) -> Self {
		let mut slf = Self::new_uninit_in(end, allocator);
		slf.values_mut().for_each(|v| {
			v.write(T::default());
		});
		// SAFETY: all elements have been initialized.
		unsafe { slf.assume_init() }
	}
}

impl<T> Grid<T, Global> {
	/// Create a new grid with the given top/end corner where all the elements are unintialized.
	pub fn new_uninit(end: Position) -> Grid<MaybeUninit<T>, Global> {
		Self::new_uninit_in(end, Global)
	}
}

impl<T, A> Grid<T, A>
where
	A: Allocator,
{
	/// Create a new grid with the given top/end corner where all the elements are unintialized.
	pub fn new_uninit_in(end: Position, allocator: A) -> Grid<MaybeUninit<T>, A> {
		let (x, y, z): (usize, _, _) = end.into();
		let size = (x + 1) * (y + 1) * (z + 1);
		let layout = Layout::new::<MaybeUninit<T>>().repeat(size).unwrap().0;
		let ptr = match allocator.allocate(layout) {
			Ok(v) => Unique::new(v.as_non_null_ptr().cast()),
			Err(_) => handle_alloc_error(layout),
		};
		Grid {
			end,
			ptr,
			allocator,
		}
	}
}

impl<T, A> Grid<T, A>
where
	A: Allocator,
{
	/// Return an element at the given position.
	pub fn get(&self, position: Position) -> Option<&T> {
		let (x, y, z) = <(usize, usize, usize)>::from(position);
		let (sx, sy, sz) = <(usize, usize, usize)>::from(self.end);
		(x <= sx && y <= sy && z <= sz).then(|| unsafe {
			// SAFETY: the position is in range.
			let offt = (sy + 1) * (sz + 1) * x + (sz + 1) * y + z;
			&*self.ptr.as_ptr().add(offt)
		})
	}

	/// Return an element at the given position.
	pub fn get_mut(&mut self, position: Position) -> Option<&mut T> {
		let (x, y, z) = <(usize, usize, usize)>::from(position);
		let (sx, sy, sz) = <(usize, usize, usize)>::from(self.end);
		(x <= sx && y <= sy && z <= sz).then(|| unsafe {
			// SAFETY: the position is in range and not borrowed yet.
			let offt = (sy + 1) * (sz + 1) * x + (sz + 1) * y + z;
			&mut *self.ptr.as_ptr().add(offt)
		})
	}

	/// Try to set the element at the given position.
	///
	/// Returns the old element if the position is in range.
	#[allow(dead_code)]
	pub fn set(&mut self, position: Position, value: T) -> Option<T> {
		let (x, y, z) = <(usize, usize, usize)>::from(position);
		let (sx, sy, sz) = <(usize, usize, usize)>::from(self.end);
		(x <= sx && y <= sy && z <= sz).then(|| unsafe {
			// SAFETY: the position is in range and not borrowed yet.
			let offt = (sy + 1) * (sz + 1) * x + (sz + 1) * y + z;
			let elem = &mut *self.ptr.as_ptr().add(offt);
			mem::replace(elem, value)
		})
	}

	/// Return the total amount of elements in this grid.
	pub fn len(&self) -> usize {
		let (x, y, z): (usize, _, _) = self.end.into();
		(x + 1) * (y + 1) * (z + 1)
	}

	/// Return the total amount of elements in this grid as a `u32`.
	pub fn len_u32(&self) -> u32 {
		let (x, y, z): (u32, _, _) = self.end.into();
		(x + 1) * (y + 1) * (z + 1)
	}

	/// Return the end/top point of this grid.
	pub fn end(&self) -> Position {
		self.end
	}

	/// Iterate all the elements in this grid.
	///
	/// The order of the elements is unspecified, but the same as `iter_mut`.
	pub fn values<'a>(&'a self) -> Values<'a, T, A> {
		Values {
			grid: self,
			index: 0,
			size: self.len_u32(),
		}
	}

	/// Iterate all the elements in this grid.
	///
	/// The order of the elements is unspecified, but the same as `iter`.
	pub fn values_mut<'a>(&'a mut self) -> ValuesMut<'a, T, A> {
		let size = self.len_u32();
		ValuesMut {
			grid: self,
			index: 0,
			size,
		}
	}
}

impl<T, A> Grid<MaybeUninit<T>, A>
where
	A: Allocator,
{
	/// Return a grid where all the elements are assumed to be initialized.
	///
	/// # Safety
	///
	/// All the elements must be initialized.
	pub unsafe fn assume_init(self) -> Grid<T, A> {
		let end = self.end;
		let ptr = self.ptr.as_non_null_ptr();
		// TODO this doesn't look sound. Should be checked.
		let allocator = ptr::read(&self.allocator);
		mem::forget(self);
		let ptr = Unique::new(ptr.cast());
		Grid {
			end,
			ptr,
			allocator,
		}
	}
}

impl<T, A> Index<Position> for Grid<T, A>
where
	A: Allocator,
{
	type Output = T;

	fn index(&self, position: Position) -> &Self::Output {
		self.get(position).expect("position is out of range")
	}
}

impl<T, A> IndexMut<Position> for Grid<T, A>
where
	A: Allocator,
{
	fn index_mut(&mut self, position: Position) -> &mut Self::Output {
		self.get_mut(position).expect("position is out of range")
	}
}

impl<T, A> Drop for Grid<T, A>
where
	A: Allocator,
{
	fn drop(&mut self) {
		for i in 0..self.len() {
			// SAFETY: all elements are initialized.
			unsafe {
				let elem = self.ptr.as_ptr().add(i);
				drop_in_place(elem);
			}
		}
		let layout = Layout::new::<T>().repeat(self.len()).unwrap().0;
		// SAFETY: we did allocate this memory originally and didn't deallocate it yet.
		unsafe {
			self.allocator
				.deallocate(self.ptr.as_non_null_ptr().cast(), layout);
		}
	}
}

/// Iterator over the elements of a grid.
pub struct Values<'a, T, A>
where
	A: Allocator,
{
	/// The grid itself
	grid: &'a Grid<T, A>,
	/// The current index
	index: u32,
	/// The cached total size of the grid.
	size: u32,
}

impl<'a, T, A> Iterator for Values<'a, T, A>
where
	A: Allocator,
{
	type Item = &'a T;

	fn next(&mut self) -> Option<Self::Item> {
		(self.index < self.size).then(|| {
			let offt = self.index as usize;
			self.index += 1;
			// SAFETY: the offset is in range.
			unsafe { &*self.grid.ptr.as_ptr().add(offt) }
		})
	}
}

/// Iterator over the elements of a grid.
pub struct ValuesMut<'a, T, A>
where
	A: Allocator,
{
	/// The grid itself
	grid: &'a mut Grid<T, A>,
	/// The current index
	index: u32,
	/// The cached total size of the grid.
	size: u32,
}

impl<'a, T, A> Iterator for ValuesMut<'a, T, A>
where
	A: Allocator,
{
	type Item = &'a mut T;

	fn next(&mut self) -> Option<Self::Item> {
		(self.index < self.size).then(|| {
			let offt = self.index as usize;
			self.index += 1;
			// SAFETY: the offset is in range.
			unsafe { &mut *self.grid.ptr.as_ptr().add(offt) }
		})
	}
}
