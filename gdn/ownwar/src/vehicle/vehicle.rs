//!
//! A vehicle consists of multiple [`Body`]s. It takes care of handling client input and
//! synchronization with the server.

pub mod gd {
	//! The Godot exposed side of the Vehicle object. This is separate to decouple annoying
	//! Godot implementation details from everything else.
	//!
	//! Note that it keeps client-only methods even if configured for servers to reduce the
	//! risk of unexpected "Method not found" bugs in GDScript. These methods will return
	//! a default value when queried.

	use super::*;
	use gdnative::api::{File, Node, Reference, VehicleBody};
	use gdnative::prelude::*;

	#[derive(NativeClass)]
	#[inherit(Reference)]
	#[register_with(Self::register)]
	pub struct Vehicle {
		vehicle: super::Vehicle,
		last_hit_position: Vector3,
		controller: super::Controller,
	}

	macro_rules! controller_input {
		($builder:ident, $get:ident, $set:ident, $type:ty) => {
			fn $get(s: &Vehicle, _: TRef<Reference>) -> $type {
				s.controller.$get()
			}
			fn $set(s: &mut Vehicle, _: TRef<Reference>, value: $type) {
				s.controller.$set(value);
			}
			$builder
				.add_property(stringify!($get))
				.with_getter(&$get)
				.with_setter(&$set)
				.done();
		};
	}

	#[methods]
	impl Vehicle {
		fn register(builder: &ClassBuilder<Self>) {
			controller_input!(builder, turn_left, set_turn_left, bool);
			controller_input!(builder, turn_right, set_turn_right, bool);
			controller_input!(builder, pitch_up, set_pitch_up, bool);
			controller_input!(builder, pitch_down, set_pitch_down, bool);
			controller_input!(builder, move_forward, set_move_forward, bool);
			controller_input!(builder, move_back, set_move_back, bool);
			controller_input!(builder, fire, set_fire, bool);
			controller_input!(builder, flip, set_flip, bool);
			controller_input!(builder, aim_at, set_aim_at, Vector3);
		}

		fn new(_: TRef<Reference>) -> Self {
			Self {
				vehicle: super::Vehicle {
					max_cost: 0,
					shared: super::Shared {
						weapons: Vec::new(),
						turrets: Vec::new(),
						movement: Vec::new(),
						saveable: Vec::new(),
						steppable: Vec::new(),
						temporary: Vec::new(),
						permanent: Vec::new(),
						team: 0,
						team_color: Color::rgb(0.0, 0.0, 0.0),
						colors: Box::new([]),
					},

					delay_until_next_fire: Cell::new(0),
					next_weapon: Cell::new(0),
					weapon_fire_volley: false,

					flipping_timeout: Cell::new(0),

					controller: super::Controller::default(),

					main_body: None,

					last_processed_packet_index: Cell::new(0),

					mode: super::VehicleMode::RemotePuppet,
				},
				last_hit_position: Vector3::zero(),
				controller: super::Controller::default(),
			}
		}

		/// Apply damage events. This should be called before `step`
		///
		/// Returns `true` if the body was destroyed.
		#[export]
		fn apply_damage(&mut self, _: TRef<Reference>) -> bool {
			self.vehicle.apply_damage()
		}

		#[export]
		fn step(&mut self, _: TRef<Reference>, delta: f32) -> bool {
			self.vehicle.step(Self::delta_to_virt(delta))
		}

		#[export]
		fn visual_step(&mut self, _: TRef<Reference>, delta: f32) {
			#[cfg(not(feature = "server"))]
			self.vehicle.visual_step(delta);
			#[cfg(feature = "server")]
			let _ = delta;
		}

		#[export]
		fn apply_input(&mut self, _: TRef<Reference>, bitmap: u16, aim_at: Vector3) {
			if !self.vehicle.mode.is_master() {
				// Override input, otherwise ignore and use our own.
				self.controller = super::Controller::new(bitmap, aim_at);
			}
			self.vehicle.apply_input(self.controller);
		}

		/// Process input. Should be preceded by `apply_input`.
		#[export]
		fn process_input(&self, _: TRef<Reference>, delta: f32) {
			self.vehicle.process_input(Self::delta_to_virt(delta))
		}

		#[export]
		fn load_from_data(
			&mut self,
			_: TRef<Reference>,
			data: TypedArray<u8>,
			team: Team,
			team_color: Color,
			transform: Transform,
			is_local: bool,
			is_master: bool,
			id: u16,
		) -> Option<GodotString> {
			let rot = transform.basis.to_quat();

			let data = match serialize::load(&data.read()[..]) {
				Err(e) => return Some(format!("{}", e).into()),
				Ok(d) => d,
			};

			self.vehicle = match super::Vehicle::new(
				&data,
				transform.origin,
				rot,
				team,
				team_color,
				is_local,
				is_master,
			) {
				Err(e) => return Some(format!("{}", e).into()),
				Ok(d) => d,
			};

			Self::set_meta(
				self.vehicle.main_body.as_mut().unwrap(),
				TypedArray::new(),
				id,
				team,
			);

			None
		}

		#[export]
		fn load_from_file(
			&mut self,
			owner: TRef<Reference>,
			path: GodotString,
			team: Team,
			team_color: Color,
			transform: Transform,
			is_local: bool,
			is_master: bool,
			id: u16,
		) -> Option<GodotString> {
			let file = File::new();
			if file
				.open_compressed(path.clone(), File::READ, File::COMPRESSION_GZIP)
				.is_err()
			{
				let err = file.open(path, File::READ);
				if let Err(err) = err {
					return Some(GodotString::from(format!("Failed to open file: {:?}", err)));
				}
			}
			let data = file.get_buffer(file.get_len());
			self.load_from_data(
				owner, data, team, team_color, transform, is_local, is_master, id,
			)
		}

		fn delta_to_virt(delta: f32) -> VirtualTicks {
			(delta * VIRTUAL_TICKS_PER_SECOND as f32) as VirtualTicks
		}

		#[export]
		fn spawn(&self, _: TRef<Reference>, scene: Ref<Node>, reset_position: bool) {
			unsafe {
				let vehicles = scene.assume_safe().get("vehicles");
				assert!(!vehicles.is_nil(), "No vehicles list");
				let body = self.vehicle.body(&[]).unwrap();
				let (tr, pos) = body.position();
				body.iter_all_bodies(&mut |b| {
					if let Some(b) = b.node() {
						b.assume_safe()
							.set_meta("ownwar_vehicle_list", vehicles.clone());
					}
				});
				scene
					.assume_safe()
					.add_child(self.vehicle.body(&[]).unwrap().node().unwrap(), true);
				if reset_position {
					body.iter_all_bodies(&mut |b| {
						// TODO use proper offsets so that bodies don't "fly" into position.
						b.set_position(tr, pos);
					});
				}
			};
		}

		#[export]
		fn get_aabb(&self, _: TRef<Reference>) -> Aabb {
			self.vehicle.aabb().into()
		}

		#[export]
		fn get_visual_origin(&self, _: TRef<Reference>) -> Vector3 {
			#[cfg(not(feature = "server"))]
			{
				self.vehicle.body(&[]).unwrap().visual_origin()
			}
			#[cfg(feature = "server")]
			{
				Vector3::zero()
			}
		}

		#[export]
		fn max_cost(&self, _: TRef<Reference>) -> u32 {
			self.vehicle.max_cost
		}

		#[export]
		fn get_cost(&self, _: TRef<Reference>) -> u32 {
			let mut cost = 0;
			self.vehicle
				.body(&[])
				.unwrap()
				.iter_all_bodies(&mut |b| cost += b.cost());
			cost
		}

		#[export]
		fn get_last_hit_position(&self, _: TRef<Reference>) -> Vector3 {
			self.last_hit_position
		}

		#[export]
		fn get_center_of_mass(&self, _: TRef<Reference>, body: TypedArray<u8>) -> Vector3 {
			if let Some(body) = self.vehicle.body(&body.read()[..]) {
				body.center_of_mass() * block::SCALE
			} else {
				godot_error!("No body with the ID {:?}", body);
				Vector3::zero()
			}
		}

		#[export]
		fn raycast(
			&self,
			_: TRef<Reference>,
			body: TypedArray<u8>,
			origin: Vector3,
			direction: Vector3,
		) -> Option<Vector3> {
			if let Some(body) = self.vehicle.body(&body.read()[..]) {
				body.raycast(origin, direction)
			} else {
				godot_error!("No body with the ID {:?}", body);
				None
			}
		}

		#[export]
		fn apply_ray_damage(
			&mut self,
			_: TRef<Reference>,
			body: TypedArray<u8>,
			origin: Vector3,
			direction: Vector3,
			damage: u32,
		) -> u32 {
			// TODO we should precalculate the amount of damage that will be applied so we
			// potentially consume all damage without actually applying all of it.
			if let Some(body) = self.vehicle.body_mut(&body.read()[..]) {
				let (origin, direction) = body.global_to_voxel_space(origin, direction);
				self.last_hit_position = origin;
				body.add_damage_event(DamageEvent::Ray {
					origin,
					direction,
					damage,
				});
				0
			} else {
				godot_error!("No body with the ID {:?}", body);
				damage
			}
		}

		#[export]
		fn apply_explosion_damage(
			&mut self,
			_: TRef<Reference>,
			body: TypedArray<u8>,
			origin: Vector3,
			radius: i8,
			damage: u32,
		) -> u32 {
			if let Some(body) = self.vehicle.body_mut(&body.read()[..]) {
				let (origin, _) = body.global_to_voxel_space(origin, Vector3::zero());
				body.add_damage_event(DamageEvent::Explosion {
					origin,
					radius,
					damage,
				});
				0
			} else {
				godot_error!("No body with the ID {:?}", body);
				damage
			}
		}

		#[export]
		fn get_node(&self, _: TRef<Reference>) -> Ref<VehicleBody> {
			self.vehicle.body(&[]).unwrap().node().unwrap().clone()
		}

		/// Map a global voxel coordinate to a local translation, accounting for center of mass &
		/// scale.
		#[export]
		fn voxel_to_translation(
			&self,
			_: TRef<Reference>,
			body: TypedArray<u8>,
			coordinate: Vector3,
		) -> Option<Vector3> {
			self.vehicle
				.body(&body.read()[..])
				.map(|b| b.voxel_to_translation(coordinate))
		}

		/// Destroy all the bodies on this vehicle.
		#[export]
		fn destroy(&mut self, _: TRef<Reference>) {
			self.vehicle.destroy();
		}

		/// Return the team color
		#[export]
		fn get_team_color(&self, _: TRef<Reference>) -> Color {
			self.vehicle.shared.team_color
		}

		/// Create two packets: one with data that *must* arrive *in order* and one with data
		/// that does not need to arrive.
		#[export]
		fn create_packet(&self, _: TRef<Reference>) -> VariantArray {
			let (mut reliable, mut unreliable) = (TypedArray::<u8>::new(), TypedArray::<u8>::new());
			let size = 1024; // 1 KiB should be more than plenty
			reliable.resize(size);
			unreliable.resize(size);
			let (mut rel, mut unrel) = (reliable.write(), unreliable.write());
			let (mut r, mut u) = (&mut rel[..], &mut unrel[..]);
			self.vehicle
				.create_packet(&mut r, &mut u)
				.expect("Failed to create packet");
			let (r, u) = (r.len(), u.len());
			drop((rel, unrel));
			reliable.resize(size - r as i32);
			unreliable.resize(size - u as i32);
			let arr = VariantArray::new();
			arr.push(reliable.to_owned());
			arr.push(unreliable.to_owned());
			arr.into_shared()
		}

		/// Process a packet with temporary data. This data includes inputs & physics state.
		#[export]
		fn process_temporary_packet(&mut self, _: TRef<Reference>, data: TypedArray<u8>) {
			self.vehicle
				.process_temporary_packet(&mut &data.read()[..])
				.expect("Failed to process temporary data")
		}

		/// Process a packet with permanent data. This data includes damage events.
		///
		/// This returns `true` if the vehicle is destroyed.
		#[export]
		fn process_permanent_packet(&mut self, _: TRef<Reference>, data: TypedArray<u8>) -> bool {
			let data = &data.read()[..];
			#[cfg(debug_assertions)]
			let mut data = {
				struct PanicReader<'a>(&'a [u8]);

				impl io::Read for PanicReader<'_> {
					fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
						assert!(self.0.len() >= buf.len(), "Not enough data to write");
						buf.copy_from_slice(&self.0[..buf.len()]);
						self.0 = &self.0[buf.len()..];
						Ok(buf.len())
					}
				}

				PanicReader(data)
			};
			#[cfg(not(debug_assertions))]
			let mut data = data;
			self.vehicle
				.process_permanent_packet(&mut data)
				.expect("Failed to process permanent data")
		}

		/// Serialize the vehicle's state for synchronization over a network.
		#[export]
		fn serialize(&self, _: TRef<Reference>) -> TypedArray<u8> {
			let mut data = TypedArray::<u8>::new();
			let size = 1 << 16; // 64 KiB should be plenty
			data.resize(size);
			let len = {
				let mut d = &mut data.write()[..];
				self.vehicle
					.serialize(&mut d)
					.expect("Failed to serialize vehicle");
				size - d.len() as i32
			};
			data.resize(len);
			data
		}

		/// Deserialize a vehicle's state. This will create a new vehicle structure.
		#[export]
		fn deserialize(
			&mut self,
			_: TRef<Reference>,
			data: TypedArray<u8>,
			id: u16,
			team_color: Color,
			is_local: bool,
			is_master: bool,
		) -> i32 {
			let mut d = &data.read()[..];
			self.vehicle =
				match super::Vehicle::deserialize(&mut d, team_color, is_local, is_master) {
					Ok(v) => v,
					Err(e) => {
						godot_error!("Failed to deserialize vehicle: {:?}", e);
						return 1;
					}
				};
			Self::set_meta(
				self.vehicle.main_body.as_mut().unwrap(),
				TypedArray::new(),
				id,
				self.vehicle.shared.team,
			);
			0
		}

		/// Return the controller bitmap
		#[export]
		fn get_controller_bitmap(&self, _: TRef<Reference>) -> u16 {
			self.controller.bitmap
		}

		/// Set meta variables so other nodes can figure out which vehicle each body belongs to.
		fn set_meta(
			body: &mut super::Body,
			index_stack: TypedArray<u8>,
			vehicle_id: u16,
			team: super::Team,
		) {
			if let Some(node) = body.node() {
				let node = unsafe { node.assume_safe() };
				node.set_meta("ownwar_body_index", Variant::from_byte_array(&index_stack));
				node.set_meta("ownwar_vehicle_index", Variant::from_u64(vehicle_id.into()));
				node.set_meta("ownwar_vehicle_team", Variant::from_u64(team.into()));
				node.set_name(format!(
					"OwnWar VehicleBody {}.{:?}",
					vehicle_id,
					&index_stack.read()[..]
				));
				for (i, body) in body.children_mut().enumerate() {
					let mut index_stack = index_stack.clone();
					index_stack.push(i.try_into().unwrap());
					Self::set_meta(body, index_stack, vehicle_id, team);
				}
			}
		}
	}
}

use super::*;
use crate::block;
use crate::editor::data;
use crate::editor::serialize;
use crate::types::*;
use core::cell::Cell;
use core::convert::{TryFrom, TryInto};
use core::fmt;
use core::mem;
use gdnative::prelude::*;
use std::io;

type Team = u8;

/// Representation of a "virtual" tick.
///
/// A single real tick always spans one or more virtual ticks.
type VirtualTicks = u16;

/// The amount of "virtual" ticks per second.
const VIRTUAL_TICKS_PER_SECOND: VirtualTicks = 256;

/// Structures shared between all bodies.
pub(super) struct Shared {
	/// All the weapons of the vehicle.
	pub weapons: Vec<Option<Ref<Spatial>>>,
	/// All parts that aim towards the cursor.
	pub turrets: Vec<Option<Ref<Spatial>>>,
	/// All the movement parts of the vehicle.
	pub movement: Vec<Option<Ref<Spatial>>>,
	/// All blocks with saveable state.
	pub saveable: Vec<Option<Ref<Spatial>>>,
	/// All blocks with temporary state each frame.
	pub temporary: Vec<Option<Ref<Spatial>>>,
	/// All blocks with permanent state each frame.
	pub permanent: Vec<Option<Ref<Spatial>>>,
	/// All blocks that need to be updated every step.
	pub steppable: Vec<Option<Ref<Spatial>>>,
	/// The team ID of the vehicle.
	pub team: Team,
	/// The team color.
	pub team_color: Color,
	/// The color palette.
	pub colors: Box<[color::RGB8]>,
}

/// Enum indicating how a vehicle should be processed
enum VehicleMode {
	/// The vehicle is remote and this instance has no authority over it.
	RemotePuppet,
	/// The vehicle is remote but this instance can apply inputs to it.
	RemoteMaster,
	/// The vehicle is local but this instance takes inputs remotely.
	LocalPuppet,
	/// The vehicle is local and takes inputs locally.
	LocalMaster,
}

impl VehicleMode {
	const fn new(is_local: bool, is_master: bool) -> Self {
		match (is_local, is_master) {
			(false, false) => Self::RemotePuppet,
			(false, true) => Self::RemoteMaster,
			(true, false) => Self::LocalPuppet,
			(true, true) => Self::LocalMaster,
		}
	}

	const fn is_local(&self) -> bool {
		match self {
			Self::RemotePuppet | Self::RemoteMaster => false,
			Self::LocalPuppet | Self::LocalMaster => true,
		}
	}

	const fn is_master(&self) -> bool {
		match self {
			Self::RemotePuppet | Self::LocalPuppet => false,
			Self::RemoteMaster | Self::LocalMaster => true,
		}
	}
}

/// Representation of a vehicle.
pub struct Vehicle {
	/// Enum indicating how the vehicle should be processed
	mode: VehicleMode,

	max_cost: u32,
	shared: Shared,

	delay_until_next_fire: Cell<VirtualTicks>,
	next_weapon: Cell<u16>,
	weapon_fire_volley: bool,

	flipping_timeout: Cell<VirtualTicks>,

	/// The main body of this vehicle. It is an option because Godot
	main_body: Option<Body>,

	/// The current input applied by the body.
	controller: Controller,

	/// Index used to prevent state from older packets overwriting newer state.
	///
	/// For clients, this is the index of the last processed packet.
	/// For servers, this is the index of the packet to be sent.
	last_processed_packet_index: Cell<u16>,
}

#[derive(Debug)]
enum ProcessPacketError {}

/// Enum returned if Vehicle::new fails.
#[derive(Debug)]
pub(crate) enum NewVehicleError {
	/// An error occured while initializing the bodies.
	InitBodiesError(body::InitError),
	/// The vehicle has multiple incompatible weapons.
	IncompatibleWeaponTypes,
	/// The type of weapon isn't known.
	UnknownWeaponType,
}

impl fmt::Display for NewVehicleError {
	fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
		match self {
			Self::InitBodiesError(e) => e.fmt(f),
			Self::IncompatibleWeaponTypes => "Multiple incompatible weapons are present".fmt(f),
			Self::UnknownWeaponType => "The weapon type is not recognized (bug?)".fmt(f),
		}
	}
}

impl Vehicle {
	/// Create a new vehicle from the given data. The state adds extra info such as which blocks
	/// are damaged / destroyed, ...
	pub(crate) fn new(
		data: &data::Vehicle,
		translation: Vector3,
		rotation: Quat,
		team: Team,
		team_color: Color,
		is_local: bool,
		is_master: bool,
	) -> Result<Self, NewVehicleError> {
		let mut bodies = Vec::with_capacity(data.layer_count().into());

		let mut shared = Shared {
			weapons: Vec::new(),
			turrets: Vec::new(),
			movement: Vec::new(),
			saveable: Vec::new(),
			steppable: Vec::new(),
			temporary: Vec::new(),
			permanent: Vec::new(),
			team,
			team_color,
			colors: data.iter_colors().copied().collect(),
		};
		assert!(
			shared.colors.len() < 256,
			"Too many colors for serialization"
		);

		// Create bodies
		for layer in data.iter_layers() {
			if let Some(aabb) = layer.aabb() {
				let mut body = Body::new(aabb);
				for (&pos, block) in layer.iter_blocks() {
					let pos = voxel::Position::new(pos.x, pos.y, pos.z);
					body.add_block(&mut shared, pos, block.rotation, block.id, block.color);
				}
				bodies.push(Some(body));
			}
		}

		// Initialize bodies
		let mut main_body =
			Body::init_all(&mut bodies, &mut shared).map_err(NewVehicleError::InitBodiesError)?;
		let mut max_cost = 0;
		main_body.iter_all_bodies(&mut |b| max_cost += b.max_cost());

		let weapon_fire_volley = Self::init_weapons(&shared.weapons)?;

		// Set the positions of the bodies such that the main body is centered at the translation
		// location.
		let pos = main_body.position().0;
		main_body.iter_all_bodies_mut(&mut |body: &mut Body| {
			let (tr, _) = body.position();
			body.set_position(
				// TODO I don't understand why inverse is needed. Someone explain it to me please.
				rotation.inverse().transform_vector3d(tr - pos) + translation,
				rotation,
			);
		});

		Ok(Self {
			mode: VehicleMode::new(is_local, is_master),

			max_cost,
			shared,

			delay_until_next_fire: Cell::new(0),
			next_weapon: Cell::new(0),
			weapon_fire_volley,

			flipping_timeout: Cell::new(0),

			main_body: Some(main_body),

			controller: Controller::default(),

			last_processed_packet_index: Cell::new(0),
		})
	}

	/// Apply damage. This should be called before `step`
	///
	/// Returns `true` if the body was destroyed.
	#[must_use]
	fn apply_damage(&mut self) -> bool {
		self.main_body
			.as_mut()
			.unwrap()
			.apply_damage(&mut self.shared)
	}

	/// Advance the simulation.
	fn step(&mut self, delta: VirtualTicks) -> bool {
		// Step bodies
		self.main_body.as_mut().unwrap().step();

		// Step all dynamic blocks.
		for block in self.shared.steppable.iter().filter_map(Option::as_ref) {
			unsafe {
				block
					.assume_safe()
					.call("step", &[Variant::from_u64(delta.into())]);
			}
		}

		false
	}

	#[cfg(not(feature = "server"))]
	fn visual_step(&mut self, delta: f32) {
		self.main_body.as_mut().unwrap().visual_step(delta);
	}

	/// Apply client input. Should only be used for the local client.
	fn apply_input(&mut self, controller: Controller) {
		self.controller = controller;
	}

	/// Process client input. This must be called only once per frame.
	fn process_input(&self, delta: VirtualTicks) {
		let controller = &self.controller;

		// Terrain
		const MASK: i64 = 1 << 7;

		// Check if we should & can flip.
		if controller.flip() {
			let mb = self.main_body.as_ref().unwrap();
			let space = unsafe {
				mb.node()
					.unwrap()
					.assume_safe()
					.get_world()
					.expect("No world")
					.assume_safe()
					.direct_space_state()
					.unwrap()
					.assume_safe()
			};
			let mut can_flip = false;
			mb.iter_all_bodies(&mut |b| {
				if can_flip {
					return;
				}
				if !b.is_destroyed() {
					let (tr, _) = b.position();
					let result = space.intersect_ray(
						tr,
						tr - Vector3::new(0.0, 2.0, 0.0),
						VariantArray::new_shared(),
						MASK,
						true,
						false,
					);
					if !result.is_empty() {
						can_flip = true;
					}
				}
			});
			if can_flip {
				self.flipping_timeout.set(VIRTUAL_TICKS_PER_SECOND);
			}
		}

		// Check first if we are flipping, since this overrides all other inputs.
		if self.flipping_timeout.get() > 0 {
			let mb = self.main_body.as_ref().unwrap();
			let space = unsafe {
				mb.node()
					.unwrap()
					.assume_safe()
					.get_world()
					.expect("No world")
					.assume_safe()
					.direct_space_state()
					.unwrap()
					.assume_safe()
			};
			let mut vel_up = 0.0;

			// Determine if we should go upwards
			mb.iter_all_bodies(&mut |b| {
				if vel_up != 0.0 {
					return;
				}
				if !b.is_destroyed() {
					let (tr, _) = b.position();
					let result = space.intersect_ray(
						tr,
						tr - Vector3::new(0.0, 2.0, 0.0),
						VariantArray::new_shared(),
						MASK,
						true,
						false,
					);
					if !result.is_empty() {
						vel_up = 2.0;
					}
				}
			});

			// Move the bodies
			mb.iter_all_bodies(&mut |b| {
				if let Some(node) = b.node() {
					//let (tr, rot) = b.position();
					let trf = unsafe { node.assume_safe().global_transform() };

					let xz = trf.basis.z();
					let xz = Vector3::new(xz.x, 0.0, xz.z).normalize() * 2.0;
					let mut vel = Vector3::new(0.0, vel_up, 0.0);
					vel += xz * f32::from(u8::from(controller.move_forward()));
					vel -= xz * f32::from(u8::from(controller.move_back()));
					b.set_linear_velocity(vel);

					let mut rot_diff = trf.basis.inverted().to_euler() * core::f32::consts::PI;
					rot_diff.y = 0.0;
					rot_diff.y += f32::from(u8::from(controller.turn_left()));
					rot_diff.y -= f32::from(u8::from(controller.turn_right()));
					b.set_angular_velocity(rot_diff);
				}
			});
			self.flipping_timeout
				.set(self.flipping_timeout.get().checked_sub(delta).unwrap_or(0));
			return;
		}

		let mut delay = self
			.delay_until_next_fire
			.get()
			.checked_sub(delta)
			.unwrap_or(0);
		let mut next = self.next_weapon.get();

		// Check if weapons need & can be fired.
		// Only do this on local vehicles, as actual firing events & projectiles are handled
		// separately.
		if self.mode.is_local() {
			let weapon_count = self
				.shared
				.weapons
				.iter()
				.filter_map(Option::as_ref)
				.count();
			if controller.fire() && weapon_count > 0 {
				if delay == 0 {
					let prev_index = next;
					if self.weapon_fire_volley {
						// Fire multiple weapons at once.
						let mut count = 4;
						while {
							if self.fire_weapon(next) {
								count -= 1;
							}
							next += 1;
							if usize::from(next) >= self.shared.weapons.len() {
								next = 0;
							}
							count > 0 && next != prev_index
						} {}
						delay += VIRTUAL_TICKS_PER_SECOND * 4;
					} else {
						// Fire one weapon at a time.
						let d =
							VIRTUAL_TICKS_PER_SECOND / u16::try_from(weapon_count.min(4)).unwrap();
						while {
							next += 1;
							if usize::from(next) >= self.shared.weapons.len() {
								next = 0;
							}
							if self.fire_weapon(next) {
								delay += d;
								false
							} else {
								next != prev_index
							}
						} {}
					}
				}
			}
		}

		self.delay_until_next_fire.set(delay);
		self.next_weapon.set(next);

		// Aim the weapons
		for turret in self.shared.turrets.iter().filter_map(Option::as_ref) {
			unsafe {
				let turret = turret.assume_safe();
				turret.call("aim_at", &[Variant::from_vector3(&controller.aim_at())]);
			}
		}

		// Apply movement
		for mov in self.shared.movement.iter().filter_map(Option::as_ref) {
			unsafe {
				let mov = mov.assume_safe();
				let (mut fwd, mut yaw, mut pitch, roll) = (0.0, 0.0, 0.0, 0.0);
				fwd += f32::from(u8::from(controller.move_forward()));
				fwd -= f32::from(u8::from(controller.move_back()));
				yaw += f32::from(u8::from(controller.turn_left()));
				yaw -= f32::from(u8::from(controller.turn_right()));
				pitch += f32::from(u8::from(controller.pitch_up()));
				pitch -= f32::from(u8::from(controller.pitch_down()));
				mov.call(
					"drive",
					&[
						Variant::from_f64(fwd.into()),
						Variant::from_f64(yaw.into()),
						Variant::from_f64(pitch.into()),
						Variant::from_f64(roll.into()),
					],
				);
			}
		}
	}

	/// Process & apply temporary data.
	fn process_temporary_packet(&mut self, packet: &mut impl io::Read) -> io::Result<()> {
		// Read index
		let mut index = [0; mem::size_of::<u16>()];
		packet.read_exact(&mut index)?;
		let index = u16::from_le_bytes(index);

		if self.last_processed_packet_index.get().wrapping_sub(index) < 0x5000 {
			// The packet is older than the state we currently have, so just discard it.
			return Ok(());
		}
		self.last_processed_packet_index.set(index);

		// Read controller input
		let mut bitmap = [0; mem::size_of::<u16>()];
		packet.read_exact(&mut bitmap)?;
		let bitmap = u16::from_le_bytes(bitmap);
		let aim_at = Body::deserialize_vector3(packet)?;
		self.controller = Controller::new(bitmap, aim_at);

		// Read physics state
		self.main_body
			.as_mut()
			.unwrap()
			.process_temporary_packet(packet)
	}

	/// Process a packet with permanent data. This data includes damage events.
	///
	/// This returns `true` if the vehicle is destroyed.
	#[must_use]
	fn process_permanent_packet(&mut self, packet: &mut impl io::Read) -> io::Result<bool> {
		self.main_body
			.as_mut()
			.unwrap()
			.process_permanent_packet(packet)?;
		Ok(self.apply_damage())
	}

	/// Create a packet with state data.
	///
	/// `permanent` is for data that *must* arrive *in order*
	/// `temporary` is for data that *may* be lost without lasting consequences.
	fn create_packet(
		&self,
		permanent: &mut impl io::Write,
		temporary: &mut impl io::Write,
	) -> io::Result<()> {
		// Write out the packet index
		temporary.write_all(&self.last_processed_packet_index.get().to_le_bytes())?;

		// Increment packet index.
		self.last_processed_packet_index
			.set(self.last_processed_packet_index.get().wrapping_add(1));

		// Write out the inputs
		temporary.write_all(&self.controller.bitmap.to_le_bytes())?;
		Body::serialize_vector3(temporary, self.controller.aim_at)?;

		// Write out physics state
		self.main_body
			.as_ref()
			.unwrap()
			.create_packet(permanent, temporary)
	}

	/// Attempt to fire a weapon. Returns `true` on success.
	#[must_use]
	fn fire_weapon(&self, index: u16) -> bool {
		self.shared.weapons[usize::from(index)]
			.map(|wp| unsafe { wp.assume_safe().call("fire", &[]).to_bool() })
			.unwrap_or(false)
	}

	/// Return the sum of all body AABBs in their default position.
	#[must_use]
	fn aabb(&self) -> voxel::AABB {
		let mb = self.main_body.as_ref().unwrap();
		let mut aabb = self.main_body.as_ref().unwrap().aabb();
		mb.iter_all_bodies(&mut |b| aabb = aabb.union(b.aabb()));
		aabb
	}

	/// Return a reference to the body at the given position.
	#[must_use]
	fn body(&self, path: &[u8]) -> Option<&Body> {
		let mut b = self.main_body.as_ref().unwrap();
		for &p in path {
			b = b.children().nth(p.into())?;
		}
		Some(b)
	}

	/// Return a mutable reference to the body at the given position.
	#[must_use]
	fn body_mut(&mut self, path: &[u8]) -> Option<&mut Body> {
		let mut b = self.main_body.as_mut().unwrap();
		for &p in path {
			b = b.children_mut().nth(p.into())?;
		}
		Some(b)
	}

	/// Destroy all the bodies on this vehicle.
	pub(crate) fn destroy(&mut self) {
		let mb = self.main_body.as_mut().expect("Already destroyed");
		#[cfg(not(feature = "server"))]
		mb.destroy(&mut self.shared, mb.center_of_mass());
		#[cfg(feature = "server")]
		mb.destroy(&mut self.shared);
	}

	/// Serialize the vehicle for transmission over a network.
	fn serialize(&self, out: &mut impl io::Write) -> io::Result<()> {
		// Serialize the last processed packet index
		out.write_all(&self.last_processed_packet_index.get().to_le_bytes())?;

		// Serialize the team
		out.write_all(&self.shared.team.to_le_bytes())?;

		// Serialize color palette
		out.write_all(
			&u8::try_from(self.shared.colors.len())
				.unwrap()
				.to_le_bytes(),
		)?;
		for clr in self.shared.colors.iter() {
			out.write_all(&[clr.r, clr.g, clr.b])?;
		}
		// Serialize bodies.
		self.body(&[]).expect("Destroyed").serialize(out)
	}

	/// Deserialize a vehicle.
	fn deserialize(
		in_: &mut impl io::Read,
		team_color: Color,
		is_local: bool,
		is_master: bool,
	) -> io::Result<Self> {
		// Get the last processed packet index
		let mut last_processed_packet_index = [0; 2];
		in_.read_exact(&mut last_processed_packet_index)?;
		let last_processed_packet_index =
			Cell::new(u16::from_le_bytes(last_processed_packet_index));

		// Get the team
		let mut team = [0; 1];
		in_.read_exact(&mut team)?;
		let team = u8::from_le_bytes(team);

		// Get the color palette
		let mut count = [0; 1];
		in_.read_exact(&mut count)?;
		let count = count[0];
		let mut colors = Box::new_uninit_slice(count.into());
		for clr in colors.iter_mut() {
			let mut buf = [0; 3];
			in_.read_exact(&mut buf)?;
			clr.write(color::RGB8::new(buf[0], buf[1], buf[2]));
		}
		// SAFETY: all elements have been initialized
		let colors = unsafe { colors.assume_init() };

		// Deserialize bodies
		let mut shared = Shared {
			weapons: Vec::new(),
			turrets: Vec::new(),
			movement: Vec::new(),
			saveable: Vec::new(),
			steppable: Vec::new(),
			temporary: Vec::new(),
			permanent: Vec::new(),
			team,
			team_color,
			colors,
		};
		let mut main_body = Body::deserialize(in_, &mut shared)?;

		main_body.init(&mut shared).unwrap();

		let mut max_cost = 0;
		main_body.iter_all_bodies(&mut |b| max_cost += b.max_cost());
		main_body.create_collision_exceptions();

		let weapon_fire_volley = Self::init_weapons(&shared.weapons).unwrap();

		Ok(Self {
			mode: VehicleMode::new(is_local, is_master),

			weapon_fire_volley,
			next_weapon: Cell::new(0),
			delay_until_next_fire: Cell::new(0),
			flipping_timeout: Cell::new(0),

			main_body: Some(main_body),
			shared,
			max_cost,

			controller: super::Controller::default(),

			last_processed_packet_index,
		})
	}

	/// Initialize weapon mechanism based on weapon type.
	fn init_weapons(weapons: &[Option<Ref<Spatial>>]) -> Result<bool, NewVehicleError> {
		// Make sure all weapons are of the same type.
		let mut weapon_type = None;
		for node in weapons.iter().filter_map(Option::as_ref) {
			let ty = unsafe { node.assume_safe().get("weapon_type").to_u64() };
			if let Some(wt) = weapon_type {
				let ty = match ty & 0xff00 {
					0x000 => false,
					0x100 => true,
					_ => return Err(NewVehicleError::UnknownWeaponType),
				};
				if ty != wt {
					return Err(NewVehicleError::IncompatibleWeaponTypes);
				}
			} else {
				weapon_type = match ty & 0xff00 {
					0x000 => Some(false),
					0x100 => Some(true),
					_ => return Err(NewVehicleError::UnknownWeaponType),
				};
			}
		}
		Ok(weapon_type.unwrap_or(false))
	}
}
