/// A bit array with exactly 256 bits.
pub struct BitArray256(u128, u128);

impl BitArray256 {
	/// Create a new bit array with no bits set.
	#[must_use]
	#[inline]
	pub fn new() -> Self {
		Self(0, 0)
	}

	/// Check whether a bit is set.
	#[must_use]
	#[inline]
	pub fn get(&self, bit: u8) -> bool {
		if bit > 0x7f {
			self.1 & (1 << (bit - 0x80)) > 0
		} else {
			self.0 & (1 << bit) > 0
		}
	}

	/// Set the value of a bit
	#[inline]
	pub fn set(&mut self, bit: u8, on: bool) {
		if bit > 0x7f {
			self.1 &= !(1 << (bit - 0x80));
			self.1 |= u128::from(on) << (bit - 0x80);
		} else {
			self.0 &= !(1 << bit);
			self.0 |= u128::from(on) << bit;
		}
	}
}
