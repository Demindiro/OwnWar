use super::*;
use crate::block;
use gdnative::api::{BoxShape, PhysicsMaterial};
use gdnative::prelude::*;

/// Helper functions for initializing new bodies & blocks.
impl super::Body {
	/// Initialize a block with extra data at the given index. This is used by `serialize` and
	/// `add_block` and is only meant for internal use.
	///
	/// It won't do anything if the health or ID is `None`.
	///
	/// # Panics
	///
	/// The position is out of range.
	pub(super) fn init_block(&mut self, shared: &mut vehicle::Shared, position: voxel::Position) {
		let index = self.get_index(position).unwrap();

		let id = if let Some(id) = self.blocks[position].id {
			id
		} else {
			return;
		};

		// Update cost
		let block = block::Block::get(id).expect("Invalid ID");
		let cost = block.cost.get() as u32;
		self.max_cost += cost;

		let hp = if let Some(hp) = self.blocks[position].health {
			self.cost += cost;
			hp
		} else {
			return;
		};

		// Get color
		#[cfg(not(feature = "server"))]
		let color = {
			let color = self.colors[index as usize];
			shared.colors[usize::from(color)]
		};

		#[cfg(feature = "server")]
		let _ = shared; // TODO

		let rotation = self.rotations[index as usize];

		let owner = unsafe { self.node.unwrap().assume_safe() };

		// Update voxel mesh
		#[cfg(not(feature = "server"))]
		self.voxel_mesh.as_ref().map(|vm| unsafe {
			vm.assume_safe()
				.map_mut(|s, _| s.add_block(block, color, position, rotation))
		});

		if block.id == MAINFRAME_ID {
			// Even if there are multiple mainframes it's fine, it'll be detected later.
			self.parent_anchors.push(position);
		}

		if block.is_multi_block() {
			assert_eq!(hp.get() & 0x8000, 0x8000);

			// Properly set up multiblock.
			let mb = self.multi_blocks[usize::from(hp.get() & 0x7fff)]
				.as_mut()
				.expect("No multiblock at location");
			mb.reverse_indices = Vec::from(&[position][..]).into_boxed_slice();
			mb.base_position = position;
			mb.rotation = rotation;

			// Initialize server & client node
			if let Some(server_node) = block.server_node {
				// Create transform
				let basis = rotation.basis();
				let origin = Vector3::from(position) * block::SCALE;
				let transform = Transform { basis, origin };

				// Initialize server node
				let server_node = {
					let server_node = unsafe {
						server_node
							.assume_safe()
							.duplicate(7)
							.unwrap()
							.assume_safe()
							.cast::<Spatial>()
							.unwrap()
					};
					server_node.set_name(format!("S {},{},{}", position.x, position.y, position.z));
					server_node.set_transform(transform);
					let server_node = server_node.claim();
					owner.add_child(server_node, false);
					mb.server_node = Some(server_node);
					server_node
				};
				#[cfg(feature = "server")]
				let _ = server_node;

				// Initialize client node
				#[cfg(not(feature = "server"))]
				let client_node = {
					let client_node = unsafe {
						block
							.client_node
							.unwrap()
							.assume_safe()
							.duplicate(7)
							.unwrap()
							.assume_safe()
							.cast::<Spatial>()
							.unwrap()
					};
					client_node.set_as_toplevel(true);
					client_node.set_name(format!("C {},{},{}", position.x, position.y, position.z));
					client_node.set_transform(transform);
					if client_node.has_method("set_color") {
						unsafe { client_node.call("set_color", &[color.to_variant()]) };
					}
					client_node.set("server_node", server_node);
					client_node.set("team_color", shared.team_color);
					let client_node = client_node.claim();
					owner.add_child(client_node, false);
					mb.client_node = Some(client_node);
					client_node
				};

				// Set up interpolation
				#[cfg(not(feature = "server"))]
				{
					let is = InterpolationState::new(server_node, client_node, transform);
					mb.interpolation_state_index =
						self.interpolation_states.len().try_into().unwrap();
					self.interpolation_states.push(Some(is));
				}
			}
		} else {
			assert_eq!(hp.get() & 0x8000, 0);
			self.blocks[position].health = Some(hp);
		}
	}

	/// Create the Godot nodes such as the collision shape, mesh instance ...
	///
	/// # Panics
	///
	/// Any of the nodes already exist.
	pub(super) fn create_godot_nodes(&mut self) {
		assert!(self.node.is_none(), "This will leak memory");
		assert!(
			self.collision_shape_instance.is_none(),
			"This will leak memory"
		);
		#[cfg(not(feature = "server"))]
		assert!(self.voxel_mesh_instance.is_none(), "This will leak memory");

		// Create physics material
		let mat = PhysicsMaterial::new();
		mat.set_friction(FRICTION.into());

		// Add physics body
		let node = Ref::<VehicleBody, _>::new();
		node.set_as_toplevel(true);
		node.set_collision_layer(COLLISION_LAYER.into());
		node.set_collision_mask(COLLISION_MASK.into());
		node.set_physics_material_override(mat);
		node.set_linear_damp(LINEAR_DAMPING.into());
		node.set_angular_damp(ANGULAR_DAMPING.into());

		// Add collision
		let collision_shape_instance = Ref::<CollisionShape, Unique>::new();
		collision_shape_instance.set_shape(self.collision_shape.clone());
		let collision_shape_instance = collision_shape_instance.into_shared();

		node.add_child(collision_shape_instance, true);

		let node = node.into_shared();

		// Add mesh
		#[cfg(not(feature = "server"))]
		if let Some(vm) = self.voxel_mesh.as_ref() {
			let voxel_mesh_instance = Ref::<MeshInstance, Unique>::new();
			voxel_mesh_instance.set_mesh(vm.base().clone());
			voxel_mesh_instance.set_as_toplevel(true);
			let voxel_mesh_instance = voxel_mesh_instance.into_shared();
			unsafe { node.assume_safe().add_child(voxel_mesh_instance, false) };

			// Add voxel mesh to interpolation list
			self.interpolation_states.push(Some(InterpolationState::new(
				// TODO I don't get why a plain upcast won't work
				unsafe { node.assume_safe().upcast::<Spatial>().claim() },
				unsafe {
					voxel_mesh_instance
						.assume_safe()
						.upcast::<Spatial>()
						.claim()
				},
				Transform {
					basis: Basis::identity(),
					origin: Vector3::zero(),
				},
			)));

			self.voxel_mesh_instance = Some(voxel_mesh_instance);
		};

		self.node = Some(node);
		self.collision_shape_instance = Some(collision_shape_instance);
	}

	/// Create a collision shape.
	pub(super) fn create_collision_shape() -> Ref<BoxShape, Shared> {
		Ref::<BoxShape, Unique>::new().into_shared()
	}

	/// Create a voxel mesh
	#[cfg(not(feature = "server"))]
	pub(super) fn create_voxel_mesh() -> Instance<VoxelMesh, Shared> {
		Instance::<VoxelMesh, Unique>::new().into_shared()
	}

	/// Initialize this body and its children.
	pub(in super::super) fn init(&mut self, shared: &mut vehicle::Shared) -> Result<(), InitError> {
		// Setup total cost, health ... & find special blocks.
		self.correct_mass();
		let middle = (Vector3::from(self.end()) + Vector3::one()) * block::SCALE * 0.5;
		unsafe {
			self.collision_shape_instance
				.unwrap()
				.assume_safe()
				.set_translation(Vector3::from(self.end()) * 0.5 * block::SCALE);
			self.collision_shape.assume_safe().set_extents(middle);
		}

		let offt = self.offset();
		for block in self.multi_blocks.iter_mut().filter_map(Option::as_mut) {
			block.init(self.offset, self.center_of_mass, shared);
			if let Some(server_node) = block.server_node.as_ref() {
				let server_node = unsafe { server_node.assume_safe() };

				// Check if the block is an anchor
				if !server_node.get("anchor_index").is_nil() {
					let mut anchor_body = None;

					for mount in server_node
						.get("anchor_mounts")
						.to_vector3_array()
						.read()
						.iter()
						.copied()
					{
						let mount = match voxel::Delta::try_from(mount) {
							Ok(m) => m,
							Err(e) => {
								godot_error!("Failed to convert mount: {:?}", e);
								continue;
							}
						};
						let delta = block.rotation * mount + offt;
						let mount = match block.base_position + delta {
							Ok(m) => m,
							Err(_) => continue,
						};
						for (k, b) in self.children.iter_mut().enumerate() {
							let k = u8::try_from(k).unwrap();
							let m = match mount - b.offset() {
								Ok(m) => m,
								Err(_) => continue,
							};
							if let Some(Some(_)) = b.blocks.get(m).map(|b| b.health) {
								b.parent_anchors.push(m);
								if let Err(_) = block.set_anchored_body(k) {
									return Err(InitError::MultipleBodiesPerAnchor);
								}
								anchor_body = Some(b.node);
							}
						}
					}

					server_node.set("anchor_mount_body", anchor_body.to_variant());
				}
			}
		}

		// Initialize children
		for body in self.children.iter_mut() {
			body.init(shared)?;
		}

		// Setup node tree
		for body in self.children.iter() {
			unsafe {
				if let Some(bn) = body.node.as_ref() {
					self.node.unwrap().assume_safe().add_child(bn, false);
				}
			}
		}

		Ok(())
	}

	/// Prevent the bodies from colliding with each other. Should be called once on the main body
	/// after `Self::init`. This improves performance & avoids funky glitches.
	pub(in super::super) fn create_collision_exceptions(&mut self) {
		// TODO find a way to avoid a temporary buffer
		let mut nodes = Vec::new();
		self.iter_all_bodies(&mut |b| {
			b.node.clone().map(|bn| nodes.push(bn));
		});
		self.iter_all_bodies(&mut |b| {
			nodes.iter().for_each(|a| unsafe {
				if let Some(b) = b.node.as_ref() {
					if a != b {
						b.assume_safe().add_collision_exception_with(a);
					}
				}
			})
		});
	}

	/// Setup interblock connection bitmaps
	pub(super) fn setup_connection_bitmaps(&mut self) {
		let end = self.blocks.end();

		// Create a per-block connection map.
		let mut connections = voxel::Grid::<block::MountSides>::new(end);
		for pos in iter_3d_inclusive((0, 0, 0), end.into()).map(voxel::Position::from) {
			if let Some(id) = self.blocks[pos].id {
				let blk = block::Block::get(id).unwrap();
				let rot = self.rotations[self.get_index(pos).unwrap()];
				for mount in blk.mount_points() {
					if let Ok(pos) = pos + rot * mount.position {
						 connections[pos] = rot * mount.sides;
					}
				}
			}
		}

		// Map X
		self.connections_x.as_mut().map(|map| {
			for x in 0..end.x {
				for y in 0..=end.y {
					for z in 0..=end.z {
						let pos = voxel::Position::new(x, y, z);
						let a = connections[pos];
						let b = connections[(pos + voxel::Delta::X).unwrap()];
						if a.can_connect(Direction::Right) && b.can_connect(Direction::Left) {
							map.set(pos, true);
						}
					}
				}
			}
		});
		// Map Y
		self.connections_y.as_mut().map(|map| {
			for x in 0..=end.x {
				for y in 0..end.y {
					for z in 0..=end.z {
						let pos = voxel::Position::new(x, y, z);
						let a = connections[pos];
						let b = connections[(pos + voxel::Delta::Y).unwrap()];
						if a.can_connect(Direction::Up) && b.can_connect(Direction::Down) {
							map.set(pos, true);
						}
					}
				}
			}
		});
		// Map Z
		self.connections_z.as_mut().map(|map| {
			for x in 0..=end.x {
				for y in 0..=end.y {
					for z in 0..end.z {
						let pos = voxel::Position::new(x, y, z);
						let a = connections[pos];
						let b = connections[(pos + voxel::Delta::Z).unwrap()];
						if a.can_connect(Direction::Forward) && b.can_connect(Direction::Back) {
							map.set(pos, true);
						}
					}
				}
			}
		});
	}
}
