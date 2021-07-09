use core::convert::TryFrom;
use std::io;
use gdnative::prelude::*;

impl super::Body {
	/// Write out data for a network packet
	///
	/// `permanent` is for data that *must* arrive *in order*
	/// `temporary` is for data that *may* be lost without lasting consequences.
	pub fn create_packet(&self, permanent: &mut impl io::Write, temporary: &mut impl io::Write) -> io::Result<()> {
		if !self.is_destroyed() {
			// Write temporary data
			temporary.write_all(&[1])?; // Flag indicating we're alive
			// FIXME
			let (tr, mut rot) = self.position();
			if rot.r < 0.0 {
				// ijk == xyz, r == w
				rot = euclid::Rotation3D::quaternion(-rot.i, -rot.j, -rot.k, -rot.r);
			}
			let lv = self.linear_velocity();
			let av = self.angular_velocity();

			Self::serialize_vector3(temporary, Vector3::new(rot.i, rot.j, rot.k))?;
			Self::serialize_vector3(temporary, tr)?;
			Self::serialize_vector3(temporary, lv)?;
			Self::serialize_vector3(temporary, av)?;

			// Write permanent data
	
			// Write the amount of damage events and the events themselves.
			let evt = u16::try_from(self.damage_events.len())
				.expect("Too many damage events to serialize!");
			permanent.write_all(&evt.to_le_bytes())?; 
			for evt in self.damage_events.iter() {
				evt.serialize(temporary)?;
			}

			// Write out data for children bodies.
			for b in self.children.iter() {
				b.create_packet(permanent, temporary)?;
			}

		} else {
			temporary.write_all(&[0])?; // Flag indicating we're dead
			// No flag is needed for permanent data since it's deterministic anyways
			// Checks for determinism may be added later, but it will be done separately anyways
			// as such checks will use a _lot_ of data.
		}

		Ok(())
	}

	/// Apply the temporary data inside a packet.
	pub fn process_temporary_packet(
		&mut self,
		packet: &mut impl io::Read,
	) -> io::Result<()> {
		let mut flag = [0; 1];
		packet.read_exact(&mut flag)?;

		if flag[0] == 1 {
			let v = Self::deserialize_vector3(packet)?;
			let rot = Quat::quaternion(v.x, v.y, v.z, (1.0 - v.square_length()).max(0.0).sqrt());
			let tr = Self::deserialize_vector3(packet)?;
			let lv = Self::deserialize_vector3(packet)?;
			let av = Self::deserialize_vector3(packet)?;

			self.set_position(tr, rot.inverse());
			self.set_linear_velocity(lv);
			self.set_angular_velocity(av);

			for b in self.children_mut() {
				b.process_temporary_packet(packet)?;
			}
		}

		Ok(())
	}
}
