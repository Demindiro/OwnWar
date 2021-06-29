impl super::Body {
	/// Save the current state of the body and its children and marks it as predicted.
	///
	/// # Panics
	///
	/// Panics if the index is out of range.
	pub fn save_state(&mut self, index: usize) {
		if !self.is_destroyed() {
			let (tr, rot) = self.position();
			let lv = self.linear_velocity();
			let av = self.angular_velocity();
			let ps = &mut self.past_state[index];
			ps.translation = tr;
			ps.rotation = rot;
			ps.linear_velocity = lv;
			ps.angular_velocity = av;
			self.children_mut().for_each(|b| b.save_state(index));
		}
	}

	/// Rollback to a previous state. Does nothing if the input is predicted.
	///
	/// # Panics
	///
	/// Panics if the index is out of range.
	pub fn rollback(&mut self, index: usize) {
		if !self.is_destroyed() {
			let ps = self.past_state[index];
			if !ps.predicted {
				self.set_position(ps.translation, ps.rotation);
				self.set_linear_velocity(ps.linear_velocity);
				self.set_angular_velocity(ps.angular_velocity);
				self.children_mut().for_each(|b| b.rollback(index));
			}
		}
	}

	/// Save the current state as past state. Does nothing if the state is authoritative
	/// (i.e. from the server & not predicted).
	///
	/// # Panics
	///
	/// Panics if the index is out of range.
	pub fn rollback_save(&mut self, index: usize) {
		if !self.is_destroyed() {
			let ps = self.past_state[index];
			if ps.predicted {
				self.save_state(index);
			}
		}
	}
}
