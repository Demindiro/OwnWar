use core::marker::PhantomData;
use core::ptr::NonNull;

pub struct Unique<T> {
	ptr: NonNull<T>,         // *const for variance
	_marker: PhantomData<T>, // For the drop checker
}

// Deriving Send and Sync is safe because we are the Unique owners
// of this data. It's like Unique<T> is "just" T.
unsafe impl<T: Send> Send for Unique<T> {}
unsafe impl<T: Sync> Sync for Unique<T> {}

impl<T> Unique<T> {
	pub fn new(ptr: NonNull<T>) -> Self {
		Unique {
			ptr,
			_marker: PhantomData,
		}
	}

	pub fn as_ptr(&self) -> *mut T {
		self.ptr.as_ptr()
	}

	pub fn as_non_null_ptr(&self) -> NonNull<T> {
		self.ptr
	}
}
