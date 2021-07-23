use super::*;
use core::convert::{TryFrom, TryInto};
use core::mem;
use core::num::NonZeroU16;
use core::slice;
use gdnative::prelude::*;
use std::io;

/// Dummy value to ensure data is correctly transmitted. Only used for debugging
/// purposes.
const _CANARY: &[u8; 4] = &[102, 117, 99, 107];

impl super::Body {
	/// Serialize the body for transmission over a network.
	pub(in super::super) fn serialize(&self, out: &mut impl io::Write) -> io::Result<()> {
		// Serialize AABB
		out.write_all(&[self.offset.x, self.offset.y, self.offset.z])?;
		out.write_all(&[self.end().x, self.end().y, self.end().z])?;

		// Serialize block ids & health
		for blk in self.blocks.values() {
			out.write_all(&blk.id.map(NonZeroU16::get).unwrap_or(0).to_le_bytes())?;
			out.write_all(&blk.health.map(NonZeroU16::get).unwrap_or(0).to_le_bytes())?;
		}

		// Serialize block rotations
		for rot in self.rotations.iter() {
			out.write_all(&[rot.get()])?;
		}

		// Serialize block colors
		out.write_all(&self.colors)?;

		// Serialize multiblock health
		out.write_all(
			&u16::try_from(self.multi_blocks.len())
				.unwrap()
				.to_le_bytes(),
		)?;
		for mb in self.multi_blocks.iter() {
			out.write_all(
				&mb.as_ref()
					.map(|mb| mb.health.get())
					.unwrap_or(0)
					.to_le_bytes(),
			)?;
		}

		// Serialize bodies
		out.write_all(&u8::try_from(self.children.len()).unwrap().to_le_bytes())?;
		for body in self.children.iter() {
			body.serialize(out)?;
		}

		if !self.is_destroyed() {
			// If alive, serialize position & velocity
			// If not alive, just skip. The receiving end can figure out whether this data
			// exists or not by checking if the current cost / alive blocks is > 0.
			let (tr, mut rot) = self.position();
			let lv = self.linear_velocity();
			let av = self.angular_velocity();
			if rot.r < 0.0 {
				rot = Quat::quaternion(-rot.i, -rot.j, -rot.k, -rot.r);
			}
			Self::serialize_vector3(out, tr)?;
			Self::serialize_vector3(out, Vector3::new(rot.i, rot.j, rot.k))?;
			Self::serialize_vector3(out, lv)?;
			Self::serialize_vector3(out, av)?;
		}

		Ok(())
	}

	/// Create a body by deserializing the given data.
	pub(in super::super) fn deserialize(
		in_: &mut impl io::Read,
		shared: &mut vehicle::Shared,
	) -> io::Result<Self> {
		let mut buf = [0; 3];
		in_.read_exact(&mut buf)?;
		let offset = voxel::Position::new(buf[0], buf[1], buf[2]);
		in_.read_exact(&mut buf)?;
		let end = voxel::Position::new(buf[0], buf[1], buf[2]);

		// Get the ID & health of each block
		let mut blocks = voxel::Grid::new_uninit(end);
		let count = blocks.len();
		for blk in blocks.values_mut() {
			let mut buf = [0; mem::size_of::<Option<NonZeroU16>>()];
			in_.read_exact(&mut buf)?;
			let id = NonZeroU16::new(u16::from_le_bytes(buf));
			in_.read_exact(&mut buf)?;
			let health = NonZeroU16::new(u16::from_le_bytes(buf));
			blk.write(Voxel { id, health });
		}
		// SAFETY: all elements have been initialized
		let blocks = unsafe { blocks.assume_init() };

		// Get the rotations
		let mut rotations = Box::new_uninit_slice(count.try_into().unwrap());
		for e in rotations.iter_mut() {
			let mut buf = [0; 1];
			in_.read_exact(&mut buf)?;
			e.write(Rotation::new(buf[0]).expect("Invalid rotation"));
		}
		// SAFETY: all elements have been initialized
		let rotations = unsafe { rotations.assume_init() };

		// Get the colors
		let mut colors = Box::new_uninit_slice(count.try_into().unwrap());
		for e in colors.iter_mut() {
			let mut buf = [0; 1];
			in_.read_exact(&mut buf)?;
			e.write(buf[0]);
		}
		// SAFETY: all elements have been initialized
		let colors = unsafe { colors.assume_init() };

		// Get the multiblock's health.
		let mut count = [0; 2];
		in_.read_exact(&mut count)?;
		let count = u16::from_le_bytes(count);
		let mut multi_blocks = Vec::with_capacity(count.into());
		for _ in 0..count {
			let mut health = [0; 4];
			in_.read_exact(&mut health)?;
			let health = NonZeroU32::new(u32::from_le_bytes(health));
			multi_blocks.push(health.map(|health| MultiBlock {
				health,
				server_node: None,
				#[cfg(not(feature = "server"))]
				client_node: None,
				reverse_indices: Box::new([]),
				#[cfg(not(feature = "server"))]
				interpolation_state_index: u16::MAX,
				base_position: voxel::Position::new(u8::MAX, u8::MAX, u8::MAX),
				rotation: Rotation::new(0).unwrap(),

				weapon_index: u16::MAX,
				turret_index: u16::MAX,
				movement_index: u16::MAX,
				steppable_index: u16::MAX,
				saveable_index: u16::MAX,
				temporary_index: u16::MAX,
				permanent_index: u16::MAX,

				anchor_body_index: None,
			}));
		}

		// Deserialize the children.
		let mut count = 0;
		in_.read_exact(slice::from_mut(&mut count))?;
		let mut children = Vec::with_capacity(count.into());
		for _ in 0..count {
			children.push(Self::deserialize(in_, shared)?);
		}

		let mut slf = Self {
			offset,

			node: None,
			#[cfg(not(feature = "server"))]
			voxel_mesh: Some(Self::create_voxel_mesh()),
			#[cfg(not(feature = "server"))]
			voxel_mesh_instance: None,
			collision_shape: Self::create_collision_shape(),
			collision_shape_instance: None,

			#[cfg(not(feature = "server"))]
			interpolation_states: Vec::new(),
			#[cfg(not(feature = "server"))]
			interpolation_state_dirty: true,

			blocks,
			connections_x: (end - voxel::Delta::X).map(|e| voxel::BitGrid::new(e)).ok(),
			connections_y: (end - voxel::Delta::Y).map(|e| voxel::BitGrid::new(e)).ok(),
			connections_z: (end - voxel::Delta::Z).map(|e| voxel::BitGrid::new(e)).ok(),
			multi_blocks,
			rotations,
			colors,

			center_of_mass: Vector3::zero(),
			mass: 0.0,
			cost: 0,
			max_cost: 0,

			#[cfg(debug_assertions)]
			debug_hit_points: Cell::new(Vec::new()),

			damage_events: Vec::new(),

			children,

			parent_anchors: Vec::new(),

			collider_start_point: voxel::Position::ZERO,
			collider_end_point: end,
		};

		slf.create_godot_nodes();
		slf.correct_mass(); // TODO should be done afterwards
		slf.resize_collider(slf.collider_start_point, slf.collider_end_point);
		slf.correct_collider_size();

		for pos in iter_3d_inclusive((0, 0, 0), slf.end().into()).map(voxel::Position::from) {
			slf.init_block(shared, pos);
		}

		slf.setup_connection_bitmaps();

		if !slf.is_destroyed() {
			//slf.correct_mass();
			slf.update_node_mass();

			// If alive, get & apply position & velocity
			let tr = Self::deserialize_vector3(in_)?;
			let rot = Self::deserialize_vector3(in_)?;
			let w = (1.0 - rot.square_length()).max(0.0).sqrt();
			let rot = Quat::quaternion(rot.x, rot.y, rot.z, w);
			let lv = Self::deserialize_vector3(in_)?;
			let av = Self::deserialize_vector3(in_)?;

			slf.set_position(tr, rot);
			slf.set_linear_velocity(lv);
			slf.set_angular_velocity(av);
		} else {
			unsafe { slf.node.take().map(|n| n.assume_unique().queue_free()) };
		}

		Ok(slf)
	}
}
