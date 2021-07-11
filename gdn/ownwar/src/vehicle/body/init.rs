use super::*;
use crate::block;
use crate::util::*;
use gdnative::api::BoxShape;
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
	pub(super) fn init_block(&mut self, shared: &mut vehicle::Shared, position: Voxel) {
		let index = self.get_index(position).unwrap();

		let id = if let Some(id) = self.ids[index as usize] {
			id
		} else {
			return;
		};

		// Update cost
		let block = block::Block::get(id).expect("Invalid ID");
		let cost = block.cost.get() as u32;
		self.max_cost += cost;

		let hp = if let Some(hp) = self.health[index as usize] {
			self.cost += cost;
			hp
		} else {
			return;
		};

		// Get color
		#[cfg(not(feature = "server"))]
		let color = {
			let color = self.colors[index as usize];
			let color = shared.colors[usize::from(color)];
			Color::rgb(
				color.x as f32 / 255.0,
				color.y as f32 / 255.0,
				color.z as f32 / 255.0,
			)
		};

		#[cfg(feature = "server")]
		let _ = shared; // TODO

		let rotation = self.rotations[index as usize];

		let owner = unsafe { self.node.unwrap().assume_safe() };

		// Update voxel mesh
		#[cfg(not(feature = "server"))]
		self.voxel_mesh.as_ref().map(|vm| unsafe {
			vm.assume_safe().map_mut(|s, _| {
				s.add_block(block, color, position, rotation);
			})
		});

		if block.id == MAINFRAME_ID {
			if !self.parent_anchors.is_empty() {
				panic!("Body has two mainframes!"); // TODO
			}
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
				let origin = Vector3::new(
					position.x as f32 + 0.5,
					position.y as f32 + 0.5,
					position.z as f32 + 0.5,
				) * block::SCALE;
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
			self.health[index as usize] = Some(hp);
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

		let node = Ref::<VehicleBody, _>::new();
		node.set_as_toplevel(true);
		node.set_collision_layer(COLLISION_LAYER.into());
		node.set_collision_mask(COLLISION_MASK.into());

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
		let middle = (self.size().to_f32() + Vector3::one()) * block::SCALE / 2.0;
		unsafe {
			self.collision_shape_instance
				.unwrap()
				.assume_safe()
				.set_translation(
					middle - (self.center_of_mass() + Vector3::new(0.5, 0.5, 0.5)) * block::SCALE,
				);
			self.collision_shape.assume_safe().set_extents(middle);
		}

		for block in self.multi_blocks.iter_mut().filter_map(Option::as_mut) {
			block.init(self.offset, shared);
			if let Some(server_node) = block.server_node.as_ref() {
				let server_node = unsafe { server_node.assume_safe() };

				// Check if the block is an anchor
				if !server_node.get("anchor_index").is_nil() {
					let anchor_bodies = VariantArray::new();

					'find_mount: for mount in server_node
						.get("anchor_mounts")
						.to_vector3_array()
						.read()
						.iter()
					{
						let mount = convert_vec::<_, i16>(block.base_position)
							+ convert_vec(
								block
									.rotation
									.basis()
									.to_quat()
									.transform_vector3d(*mount)
									.round(),
							) + convert_vec(self.offset);
						let mount = mount.x.try_into().and_then(|x| {
							mount
								.y
								.try_into()
								.and_then(|y| mount.z.try_into().map(|z| Voxel::new(x, y, z)))
						});
						let mount = match mount {
							Ok(m) => m,
							Err(_) => continue,
						};

						for (k, b) in self.children.iter_mut().enumerate() {
							let k = u8::try_from(k).unwrap();
							let m = convert_vec::<_, i16>(mount) - convert_vec(b.offset);
							let m = m.x.try_into().and_then(|x| {
								m.y.try_into()
									.and_then(|y| m.z.try_into().map(|z| Voxel::new(x, y, z)))
							});
							let m = match m {
								Ok(m) => m,
								Err(_) => continue,
							};
							if let Ok(Some(_)) = b.try_get_block(m) {
								b.parent_anchors.push(m);
								if let Err(_) = block.set_anchored_body(k) {
									return Err(InitError::MultipleBodiesPerAnchor);
								}
								anchor_bodies.push(b.node);
								break 'find_mount;
							}
						}
					}

					server_node.set(
						"anchor_mounts_bodies",
						anchor_bodies.into_shared().to_variant(),
					);
				}
			}
		}

		// Initialize children
		for body in self.children.iter_mut() {
			body.init(shared)?;
		}

		// Setup node tree
		for body in self.children.iter_mut() {
			unsafe {
				self.node
					.unwrap()
					.assume_safe()
					.add_child(body.node.unwrap(), false);
			}
		}

		Ok(())
	}

	/// Prevent the bodies from colliding with each other. Should be called once on the main body
	/// after `Self::init`. This improves performance & avoids funky glitches.
	pub(in super::super) fn create_collision_exceptions(&mut self) {
		// TODO find a way to avoid a temporary buffer
		let mut nodes = Vec::new();
		self.iter_all_bodies(&mut |b| nodes.push(b.node().clone()));
		self.iter_all_bodies(&mut |b| {
			nodes.iter().for_each(|a| unsafe {
				if a != b.node() {
					b.node().assume_safe().add_collision_exception_with(a);
				}
			})
		});
	}
}
