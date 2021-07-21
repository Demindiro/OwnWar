//! A 3D grid of boolean values.

use super::*;
use core::ops::Index;
use std::alloc::{handle_alloc_error, Allocator, Global, Layout};

pub struct BitGrid<A = Global>
where
	A: Allocator,
{
	/// The size, including the final position.
	/// i.e. an `end` of `(0, 0, 0)` is size `(1, 1, 1)`.
	end: Position,
	/// The values. A raw pointer is used to avoid a redundant length value.
	ptr: Unique<u8>,
	/// The allocator used.
	allocator: A,
	#[cfg(debug_assertions)]
	size: usize,
}

impl BitGrid<Global> {
	/// Create a new grid with the given top/end corner.
	pub fn new(end: Position) -> Self {
		Self::new_in(end, Global)
	}
}

impl<A> BitGrid<A>
where
	A: Allocator,
{
	/// Create a new grid with the given top/end corner.
	pub fn new_in(end: Position, allocator: A) -> Self {
		let (x, y, z): (usize, _, _) = end.into();
		let size = (x + 1) * (y + 1) * (z + 1);
		let size = ((size + 7) & !7) / 8; // Round up
		let layout = Layout::new::<u8>().repeat(size).unwrap().0;
		let ptr = match allocator.allocate_zeroed(layout) {
			Ok(v) => Unique::new(v.as_non_null_ptr()),
			Err(_) => handle_alloc_error(layout),
		};
		BitGrid {
			end,
			ptr,
			allocator,
			#[cfg(debug_assertions)]
			size,
		}
	}

	/// Return an element at the given position.
	pub fn get(&self, position: Position) -> Option<bool> {
		self.is_in_range(position).then(|| unsafe {
			// SAFETY: the position is in range.
			let offt = self.get_index(position);
			#[cfg(debug_assertions)]
			debug_assert!(offt / 8 < self.size);
			let val = *self.ptr.as_ptr().add(offt / 8);
			val & (1 << offt % 8) > 0
		})
	}

	/// Try to set the element at the given position.
	///
	/// Returns the old element if the position is in range.
	pub fn set(&mut self, position: Position, value: bool) -> Option<bool> {
		self.is_in_range(position).then(|| unsafe {
			// SAFETY: the position is in range.
			let offt = self.get_index(position);
			#[cfg(debug_assertions)]
			debug_assert!(offt / 8 < self.size);
			let elem = &mut *self.ptr.as_ptr().add(offt / 8);
			let prev = *elem & (1 << offt % 8) > 0;
			#[cfg(debug_assertions)]
			debug_assert_eq!(self.get(position).unwrap(), prev);
			*elem &= !(1 << offt % 8);
			*elem |= u8::from(value) << offt % 8;
			#[cfg(debug_assertions)]
			debug_assert_eq!(self.get(position).unwrap(), value);
			prev
		})
	}

	/// Return the total amount of elements in this grid.
	#[must_use]
	pub fn len(&self) -> usize {
		let (x, y, z): (usize, _, _) = self.end.into();
		(x + 1) * (y + 1) * (z + 1)
	}

	/// Map a position to an index.
	#[must_use]
	fn get_index(&self, position: Position) -> usize {
		let (x, y, z) = <(usize, usize, usize)>::from(position);
		let (_, sy, sz) = <(usize, usize, usize)>::from(self.end);
		((sy + 1) * x + y) * (sz + 1) + z
	}

	/// Check if the position is in range.
	#[must_use]
	fn is_in_range(&self, position: Position) -> bool {
		position.min(self.end) == position
	}
}

impl<A> Drop for BitGrid<A>
where
	A: Allocator,
{
	fn drop(&mut self) {
		let size = ((self.len() + 7) & !7) / 8;
		let layout = Layout::new::<u8>().repeat(size).unwrap().0;
		// SAFETY: we did allocate this memory originally and didn't deallocate it yet.
		unsafe {
			self.allocator
				.deallocate(self.ptr.as_non_null_ptr().cast(), layout);
		}
	}
}

impl<A> Index<Position> for BitGrid<A>
where
	A: Allocator,
{
	type Output = bool;

	fn index(&self, position: Position) -> &Self::Output {
		if self.get(position).expect("position is out of range") {
			&true
		} else {
			&false
		}
	}
}
