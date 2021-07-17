use core::iter::repeat;

pub struct BitArray(Box<[u8]>, usize);

impl BitArray {
	pub fn new(size: usize) -> Self {
		let real_size = if size % 8 == 0 {
			size / 8
		} else {
			size / 8 + 1
		};
		Self(repeat(0).take(real_size).collect(), size)
	}

	pub fn get(&self, i: usize) -> Option<bool> {
		if i < self.len() {
			let mask = 1 << (i % 8);
			Some(self.0[i / 8] & mask != 0)
		} else {
			None
		}
	}

	pub fn set(&mut self, i: usize, value: bool) -> Result<(), ()> {
		if i < self.len() {
			let mask = 1 << (i % 8);
			if value {
				self.0[i / 8] |= mask
			} else {
				self.0[i / 8] &= !mask;
			}
			Ok(())
		} else {
			Err(())
		}
	}

	pub fn len(&self) -> usize {
		self.1
	}
}
