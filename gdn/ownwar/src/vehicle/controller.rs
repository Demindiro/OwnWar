use gdnative::prelude::Vector3;

/// Inputs applied by a client.
#[derive(Clone, Copy)]
pub struct Controller {
	pub bitmap: u16,
	pub aim_at: Vector3,
}

macro_rules! command {
	($cmd:ident, $set_cmd:ident, $bit:literal) => {
		#[must_use]
		pub fn $cmd(&self) -> bool {
			self.bitmap & (1 << $bit) > 0
		}

		pub fn $set_cmd(&mut self, enable: bool) {
			self.bitmap &= !(1 << $bit);
			self.bitmap |= (u16::from(enable) << $bit);
		}
	};
}

impl Controller {
	pub const fn new(bitmap: u16, aim_at: Vector3) -> Self {
		Self { bitmap, aim_at }
	}

	command!(turn_left, set_turn_left, 0);
	command!(turn_right, set_turn_right, 1);
	command!(pitch_up, set_pitch_up, 2);
	command!(pitch_down, set_pitch_down, 3);
	command!(move_forward, set_move_forward, 4);
	command!(move_back, set_move_back, 5);
	command!(fire, set_fire, 6);
	command!(flip, set_flip, 7);

	/// The point at which to aim the guns
	pub fn aim_at(&self) -> Vector3 {
		self.aim_at
	}

	/// Set the point at which to aim the guns
	pub fn set_aim_at(&mut self, point: Vector3) {
		self.aim_at = point;
	}
}

impl Default for Controller {
	fn default() -> Self {
		Self::new(0, Vector3::default())
	}
}
