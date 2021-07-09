use super::*;
use core::convert::{TryInto, TryFrom};
use core::mem;
use core::num::NonZeroU16;
use core::slice;
use std::io;
use euclid::Vector3D;
use gdnative::prelude::*;
use gdnative::api::OS;

/// Dummy value to ensure data is correctly transmitted. Only used for debugging
/// purposes.
const _CANARY: &[u8; 4] = &[102, 117, 99, 107];

impl super::Body {
	/// Serialize the body for transmission over a network.
	pub(in super::super) fn serialize(&self, out: &mut impl io::Write) -> io::Result<()> {
		// Serialize AABB
		out.write_all(&[self.offset.x, self.offset.y, self.offset.z])?;
		out.write_all(&[self.size.x, self.size.y, self.size.z])?;

		// Serialize block ids
		for id in self.ids.iter() {
			out.write_all(&id.map(NonZeroU16::get).unwrap_or(0).to_le_bytes())?;
		}

		// Serialize health
		for health in self.health.iter() {
			out.write_all(&health.map(NonZeroU16::get).unwrap_or(0).to_le_bytes())?;
		}

		// Serialize block rotations
		for rot in self.rotations.iter() {
			out.write_all(&[rot.get()])?;
		}

		// Serialize block colors
		out.write_all(&self.colors)?;

		// Serialize multiblock health
		out.write_all(&u16::try_from(self.multi_blocks.len()).unwrap().to_le_bytes())?;
		for mb in self.multi_blocks.iter() {
			out.write_all(&mb.as_ref().map(|mb| mb.health.get()).unwrap_or(0).to_le_bytes())?;
		}

		// Serialize bodies
		out.write_all(&u8::try_from(self.children.len()).unwrap().to_le_bytes())?;
		for body in self.children.iter() {
			body.serialize(out)?;
		}

		// Serialize position & velocity
		let (tr, mut rot) = self.position();
		let lv = self.linear_velocity();
		let av = self.angular_velocity();
		if rot.r < 0.0 {
			rot = Quat::quaternion(-rot.i, -rot.j, -rot.k, -rot.r);
		}
		Self::serialize_vector3(out, tr)?;
		Self::serialize_vector3(out, Vector3D::new(rot.i, rot.j, rot.k))?;
		Self::serialize_vector3(out, lv)?;
		Self::serialize_vector3(out, av)?;

		Ok(())
	}

	/// Create a body by deserializing the given data.
	pub(in super::super) fn deserialize(in_: &mut impl io::Read, shared: &mut vehicle::Shared, visible: bool) -> io::Result<Self> {
		let mut buf = [0; 3];
		in_.read_exact(&mut buf)?;
		let offset = Voxel::new(buf[0], buf[1], buf[2]);
		in_.read_exact(&mut buf)?;
		let size = Voxel::new(buf[0], buf[1], buf[2]);

		let count = convert_vec::<_, usize>(size) + Vector3D::one();
		let count = count.x * count.y * count.z;

		// Get the IDs
		let mut ids = Box::new_uninit_slice(count);
		for id in ids.iter_mut() {
			let mut buf = [0; mem::size_of::<Option<NonZeroU16>>()];
			in_.read_exact(&mut buf)?;
			id.write(NonZeroU16::new(u16::from_le_bytes(buf)));
		}
		// SAFETY: all elements have been initialized
		let ids = unsafe { ids.assume_init() };

		// Get the health
		let mut health = Box::new_uninit_slice(count);
		for health in health.iter_mut() {
			let mut buf = [0; mem::size_of::<Option<NonZeroU16>>()];
			in_.read_exact(&mut buf)?;
			health.write(NonZeroU16::new(u16::from_le_bytes(buf)));
		}
		// SAFETY: all elements have been initialized
		let health = unsafe { health.assume_init() };

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
				client_node: None,
				reverse_indices: Box::new([]),
				interpolation_state_index: u16::MAX,
				base_position: Voxel::new(u8::MAX, u8::MAX, u8::MAX),
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
			children.push(Self::deserialize(in_, shared, visible)?);
		}

		let mut slf = Self {
			offset,
			size,
			
			node: None,
			voxel_mesh: visible.then(Self::create_voxel_mesh),
			voxel_mesh_instance: None,
			collision_shape: Self::create_collision_shape(),
			collision_shape_instance: None,

			interpolation_states: Vec::new(),
			interpolation_state_dirty: true,

			ids,
			health,
			multi_blocks,
			rotations,
			colors,

			center_of_mass: Vector3D::zero(),
			total_mass: 0.0,
			cost: 0,
			max_cost: 0,

			last_hit_position: Vector3::zero(),
			#[cfg(debug_assertions)]
			debug_hit_points: Cell::new(Vec::new()),

			damage_events: Vec::new(),

			children,

			parent_anchors: Vec::new(),
		};

		slf.create_godot_nodes();
		slf.correct_mass();

		for z in 0..=size.z {
			for y in 0..=size.y {
				for x in 0..=size.x {
					let pos = Voxel::new(x, y, z);
					slf.init_block(shared, pos);
				}
			}
		}

		// Get & apply position & velocity
		let tr = Self::deserialize_vector3(in_)?;
		let rot = Self::deserialize_vector3(in_)?;
		let w = (1.0 - rot.square_length()).max(0.0).sqrt();
		let rot = Quat::quaternion(rot.x, rot.y, rot.z, w);
		let lv = Self::deserialize_vector3(in_)?;
		let av = Self::deserialize_vector3(in_)?;

		slf.set_position(tr, rot);
		slf.set_linear_velocity(lv);
		slf.set_angular_velocity(av);

		Ok(slf)
	}
}
