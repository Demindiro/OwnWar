use super::*;
use core::mem::{self, MaybeUninit};
use core::ops::{Index, IndexMut};
use core::ptr::{self, drop_in_place};
use std::alloc::{handle_alloc_error, Allocator, Global, Layout};

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
	#[must_use]
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
	#[must_use]
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
	#[must_use]
	pub fn get(&self, position: Position) -> Option<&T> {
		self.is_in_range(position).then(|| unsafe {
			// SAFETY: the position is in range.
			let offt = self.get_index(position);
			&*self.ptr.as_ptr().add(offt)
		})
	}

	/// Return an element at the given position.
	#[must_use]
	pub fn get_mut(&mut self, position: Position) -> Option<&mut T> {
		self.is_in_range(position).then(|| unsafe {
			// SAFETY: the position is in range and not borrowed yet.
			let offt = self.get_index(position);
			&mut *self.ptr.as_ptr().add(offt)
		})
	}

	/// Try to set the element at the given position.
	///
	/// Returns the old element if the position is in range.
	#[allow(dead_code)]
	pub fn set(&mut self, position: Position, value: T) -> Option<T> {
		self.is_in_range(position).then(|| unsafe {
			// SAFETY: the position is in range and not borrowed yet.
			let offt = self.get_index(position);
			let elem = &mut *self.ptr.as_ptr().add(offt);
			mem::replace(elem, value)
		})
	}

	/// Return the total amount of elements in this grid.
	#[must_use]
	pub fn len(&self) -> usize {
		let (x, y, z): (usize, _, _) = self.end.into();
		(x + 1) * (y + 1) * (z + 1)
	}

	/// Return the total amount of elements in this grid as a `u32`.
	#[must_use]
	pub fn len_u32(&self) -> u32 {
		let (x, y, z): (u32, _, _) = self.end.into();
		(x + 1) * (y + 1) * (z + 1)
	}

	/// Return the end/top point of this grid.
	#[must_use]
	pub fn end(&self) -> Position {
		self.end
	}

	/// Iterate all the elements in this grid.
	///
	/// The order of the elements is unspecified, but the same as `iter_mut`.
	#[must_use]
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
	#[must_use]
	pub fn values_mut<'a>(&'a mut self) -> ValuesMut<'a, T, A> {
		let size = self.len_u32();
		ValuesMut {
			grid: self,
			index: 0,
			size,
		}
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
