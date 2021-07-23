#![cfg_attr(feature = "server", allow(dead_code))]

pub mod data;
pub mod serialize;

#[cfg(not(feature = "server"))]
mod godot {

	const DEBUG_CAMERA_RAY: bool = false;

	use super::data::{Vehicle, VehicleError};
	use crate::block;
	use crate::rotation::*;
	use crate::types::*;
	use crate::util::VoxelRaycast;
	use crate::vehicle::{self, VoxelMesh};
	use fxhash::{FxHashMap, FxHashSet};
	use gdnative::api::{Camera, File, PackedScene, Spatial};
	use gdnative::nativescript::property::Usage;
	use gdnative::prelude::*;
	#[cfg(debug_assertions)]
	use std::cell::Cell;
	use std::convert::TryInto;
	use std::mem;
	use std::num::NonZeroU16;

	const GRID_SIZE: u8 = 37;
	const MAIN_MENU: &str = "res://start_menu/main.tscn";

	#[derive(NativeClass)]
	#[inherit(Node)]
	#[register_with(Self::register)]
	pub(super) struct Editor {
		#[property]
		test_map: Option<Ref<PackedScene>>,

		#[property]
		camera_path: NodePath,

		#[property]
		data_path: String,

		rotation: Rotation,
		#[property]
		mirror: bool,
		#[property]
		snap_face: bool,
		map_rotation: bool,
		selected_block: NonZeroU16,
		#[property]
		selected_layer: u8,
		#[property]
		selected_color: u8,
		edit_mode: bool,

		camera: Option<Ref<Camera>>,

		data: Vehicle,

		layers: Vec<(
			Instance<VoxelMesh, Shared>,
			FxHashMap<voxel::Position, Ref<Spatial>>,
		)>,
		outline: (Instance<VoxelMesh, Shared>, FxHashSet<voxel::Position>),

		focused_window: Window,

		#[cfg(debug_assertions)]
		debug_points: Cell<Vec<voxel::Position>>,
	}

	enum RayResult {
		InsideGrid {
			position: voxel::Position,
			normal: voxel::Delta,
		},
		OutsideGrid {
			position: voxel::Delta,
			normal: voxel::Delta,
		},
		Collides {
			position: voxel::Position,
			normal: voxel::Delta,
		},
		NoCollision,
	}

	#[derive(Clone, Copy, PartialEq)]
	enum Window {
		None,
		Panes,
		Inventory,
		ColorPicker,
	}

	impl Window {
		fn as_str(&self) -> &str {
			use Window::*;
			match self {
				None => "None",
				Panes => "Panes",
				Inventory => "Inventory",
				ColorPicker => "Color picker",
			}
		}
	}

	#[methods]
	impl Editor {
		fn register(builder: &ClassBuilder<Self>) {
			let new_signal = |name, args: &[&str]| {
				let mut s_args = Vec::with_capacity(args.len());
				for a in args {
					s_args.push(SignalArgument {
						name: a,
						default: Variant::default(),
						export_info: ExportInfo::new(VariantType::Nil),
						usage: Usage::empty(),
					});
				}
				builder.add_signal(Signal {
					name,
					args: &s_args,
				});
			};
			new_signal("block_placed", &["block", "position"]);
			new_signal("block_removed", &["block", "position"]);
			new_signal("add_editor_node", &["node"]);

			new_signal("vehicle_moved", &["position"]);
			new_signal("vehicle_rotated", &["center"]);
			new_signal("toggled_edit_mode", &["enable"]);

			new_signal("play_place_effect", &[]);
			new_signal("play_remove_effect", &[]);
			new_signal("play_fail_effect", &[]);
			new_signal("play_rotate_effect", &[]);
			new_signal("play_click_effect", &[]);

			new_signal("ghost_position", &["position"]);
			new_signal("ghost_rotation", &["rotation"]);
			new_signal("ghost_normal", &["normal"]);
			new_signal("ghost_block", &["block"]);
			new_signal("ghost_color", &["color"]);
			new_signal("ghost_visible", &["visible"]);
			new_signal("ghost_valid", &["valid"]);

			new_signal("error", &["message"]);

			new_signal("add_voxel_mesh", &["mesh"]);
			new_signal("remove_voxel_mesh", &["index"]);

			new_signal("add_layer", &["name"]);
			new_signal("rename_layer", &["index", "name"]);
			new_signal("remove_layer", &["index"]);
			new_signal("select_layer", &["index"]);

			new_signal("add_color", &["color"]);
			new_signal("change_color", &["index", "color"]);
			new_signal("remove_color", &["index"]);

			new_signal("add_outline_voxel_mesh", &["mesh"]);
			new_signal("remove_outline_voxel_mesh", &["mesh"]);
			new_signal("add_outline_node", &["position", "rotation", "node"]);
			new_signal("remove_outline_node", &["position"]);

			new_signal("toggled_mirror", &["enable"]);
			new_signal("toggled_handling_input", &["enable"]);
			new_signal("toggled_snap_faces", &["enable"]);
			new_signal("toggled_map_rotations", &["enable"]);

			new_signal("open_window", &["name"]);

			builder
				.add_property("selected_block")
				.with_getter(Self::gd_selected_block)
				.with_setter(Self::gd_set_selected_block)
				.done();

			builder
				.add_property("edit_mode")
				.with_getter(Self::edit_mode)
				.with_setter(Self::set_edit_mode)
				.done();

			builder
				.add_property("rotation")
				.with_getter(Self::gd_get_rotation)
				.with_setter(Self::gd_set_rotation)
				.done();
		}

		fn new(_owner: TRef<Node>) -> Self {
			Self {
				test_map: None,

				camera_path: NodePath::from_str(""),
				camera: None,

				data: Vehicle::new(),
				data_path: String::new(),

				mirror: false,
				rotation: Rotation::default(),
				snap_face: true,
				map_rotation: true,
				selected_block: NonZeroU16::new(13).unwrap(), // Standard cube
				selected_layer: 0,
				selected_color: 0,
				edit_mode: true,

				outline: (Instance::new().into_shared(), FxHashSet::default()),
				layers: Vec::new(),

				focused_window: Window::None,

				#[cfg(debug_assertions)]
				debug_points: Cell::new(Vec::new()),
			}
		}

		#[export]
		fn _ready(&mut self, owner: TRef<Node>) {
			// Add the current voxel mesh in case later code removes it
			owner.emit_signal(
				"add_outline_voxel_mesh",
				&[self.outline.0.clone().to_variant()],
			);
			if self.load_vehicle(owner, self.data_path.clone()) == -1 {
				// Create the bare minimum to prevent errors
				self.add_layer(owner);
				self.add_color(owner, Color::rgb(1.0, 1.0, 1.0));
			}
			if let None = self.test_map {
				godot_error!("test_map is not set");
			}
			// TODO why is Clone not implemented for NodePath?
			if let Some(node) = owner.get_node(self.camera_path.to_godot_string()) {
				unsafe {
					let node = node.assume_safe();
					if let Some(node) = node.cast::<Camera>() {
						self.camera = Some(node.claim());
					} else {
						godot_error!("Camera node is not of type Camera {}", node.get_class());
					}
				}
			} else {
				godot_error!("Failed to get camera node from {:?}", self.camera_path);
			}
			owner.emit_signal("ghost_block", &[self.selected_block.get().to_variant()]);
			self.enable_mirror(owner, self.mirror);
			// Dirty, but it works so *shrug*
			// This is in case I forget to disable any of the windows in the editor again
			// (godot pls editor-only visibility)
			self.focused_window = Window::Panes;
			self.focus_window(owner, Window::None);
		}

		#[export]
		#[profiled(tag = "Input handling")]
		fn _unhandled_input(&mut self, owner: TRef<Node>, event: Ref<InputEvent>) {
			let event = unsafe { event.assume_safe() };
			let pressed = |name, repeat| event.is_action_pressed(name, repeat);
			if pressed("ui_cancel", false) {
				let window = if self.focused_window == Window::None {
					Window::Panes
				} else {
					Window::None
				};
				self.focus_window(owner, window);
			} else if pressed("editor_place_block", true) {
				match self.place_block(owner) {
					Ok((pos, _)) => {
						let id = self.selected_block.get().to_variant();
						owner.emit_signal("block_placed", &[id, pos.to_variant()]);
						owner.emit_signal("play_place_effect", &[]);
					}
					Err(e) => Self::emit_error(owner, e),
				}
			} else if pressed("editor_remove_block", true) {
				match self.remove_block(owner) {
					Ok((pos, id, _)) => {
						let id = id.get().to_variant();
						owner.emit_signal("block_removed", &[id, pos.to_variant()]);
						owner.emit_signal("play_remove_effect", &[]);
					}
					Err(e) => Self::emit_error(owner, e),
				}
			} else if pressed("editor_open_inventory", false) {
				self.focus_or_hide_window(owner, Window::Inventory);
			} else if pressed("editor_open_colorpicker", false) {
				self.focus_or_hide_window(owner, Window::ColorPicker);
			} else if pressed("editor_rotate_up", true) {
				self.rotate_ghost(owner, 1);
			} else if pressed("editor_rotate_down", true) {
				self.rotate_ghost(owner, -1);
			} else if pressed("editor_toggle_mirror", false) {
				self.enable_mirror(owner, !self.mirror);
			} else if pressed("editor_goto_test_map", false) {
				unsafe {
					owner.call_deferred("goto_test_scene", &[]);
				}
			} else if pressed("editor_vehicle_left", true) {
				self.move_vehicle(owner, voxel::Delta::X);
			} else if pressed("editor_vehicle_right", true) {
				self.move_vehicle(owner, -voxel::Delta::X);
			} else if pressed("editor_vehicle_up", true) {
				self.move_vehicle(owner, voxel::Delta::Y);
			} else if pressed("editor_vehicle_down", true) {
				self.move_vehicle(owner, -voxel::Delta::Y);
			} else if pressed("editor_vehicle_forward", true) {
				self.move_vehicle(owner, voxel::Delta::Z);
			} else if pressed("editor_vehicle_back", true) {
				self.move_vehicle(owner, -voxel::Delta::Z);
			} else if pressed("editor_vehicle_rotate", true) {
				self.rotate_vehicle(owner);
			} else if pressed("editor_toggle_snap_faces", false) {
				self.set_snap_faces(owner, !self.snap_face);
			} else if pressed("editor_toggle_rotation_mapping", false) {
				self.set_map_rotations(owner, !self.map_rotation);
			} else if pressed("editor_layer_next", false) {
				self.select_layer(owner, (self.selected_layer + 23) % self.data.layer_count())
			} else if pressed("editor_layer_previous", false) {
				self.select_layer(owner, (self.selected_layer + 1) % self.data.layer_count())
			} else {
				return;
			}
			unsafe {
				owner
					.get_tree()
					.expect("Node is not in tree")
					.assume_safe()
					.set_input_as_handled();
			}
		}

		#[export]
		fn _exit_tree(&self, owner: TRef<Node>) {
			self.save_vehicle(owner);
		}

		#[export]
		fn _process(&mut self, owner: TRef<Node>, _delta: f32) {
			let signal = |position: voxel::Delta, normal: voxel::Delta, valid: bool| {
				owner.emit_signal("ghost_position", &[position.to_variant()]);
				owner.emit_signal("ghost_normal", &[normal.to_variant()]);
				owner.emit_signal("ghost_valid", &[valid.to_variant()]);
				true
			};
			let visible = match self.place_block_orientation_from_camera() {
				RayResult::InsideGrid { position, normal } => signal(position.into(), normal, true),
				RayResult::OutsideGrid { position, normal } => signal(position, normal, false),
				RayResult::Collides { position, normal } => signal(position.into(), normal, false),
				RayResult::NoCollision => false,
			};

			owner.emit_signal("ghost_visible", &[visible.to_variant()]);
			if self.snap_face {
				self.snap_ghost(owner);
			}
		}

		#[export]
		fn save_vehicle(&self, _owner: TRef<Node>) {
			let data = super::serialize::save(&self.data).expect("Failed to serialize vehicle");
			let file = File::new();
			// TODO handle error properly
			file.open(self.data_path.clone(), File::WRITE)
				.expect(&format!("Failed to open {}", self.data_path));
			file.store_buffer(TypedArray::from_vec(data));
		}

		#[export]
		fn edit_mode(&self, _owner: TRef<Node>) -> bool {
			self.edit_mode
		}

		#[export]
		fn set_edit_mode(&mut self, owner: TRef<Node>, enable: bool) {
			self.edit_mode = enable;
			owner.emit_signal("toggled_edit_mode", &[enable.to_variant()]);
		}

		#[export]
		/// FIXME return a Result<(), GodotError> whenever possible
		fn load_vehicle(&mut self, owner: TRef<Node>, path: String) -> i64 {
			let file = File::new();
			// Try compressed first due to revision 0 files using this API
			let result = file
				.open_compressed(&path, File::READ, File::COMPRESSION_GZIP)
				.or_else(|_| file.open(&path, File::READ));
			if let Ok(_) = result {
				let data = file
					.get_buffer(file.get_len())
					.read()
					.iter()
					.copied()
					.collect::<Box<[_]>>();
				file.close();
				self.data = super::serialize::load(&data).expect("Failed to deserialize data");
				for layer in self.data.iter_layers() {
					for (&pos, block) in layer.iter_blocks() {
						let id = block.id.get().to_variant();
						owner.emit_signal("block_placed", &[id, pos.to_variant()]);
					}
				}
				self.refresh_meshes(owner);
				if self.data.layer_count() == 0 {
					// Ensure that there is at least one layer
					self.add_layer(owner);
				}
				for layer in self.data.iter_layers() {
					owner.emit_signal("add_layer", &[layer.name.to_variant()]);
				}
				if self.data.color_count() == 0 {
					// Ensure that there is at least one color
					self.add_color(owner, Color::rgb(1.0, 1.0, 1.0));
				}
				for color in self.data.iter_colors() {
					owner.emit_signal("add_color", &[color.to_variant()]);
				}
				0
			} else {
				-1
			}
		}

		#[export]
		fn set_mirror(&mut self, owner: TRef<Node>, enable: bool) {
			self.enable_mirror(owner, enable);
		}

		#[export]
		fn goto_test_scene(&self, owner: TRef<Node>) {
			if owner.is_queued_for_deletion() {
				// This function has most likely already been called
				return;
			}

			// Make sure the vehicle is valid before going to the test map.
			let vehicle = vehicle::Vehicle::new(
				&self.data,
				Vector3::zero(),
				Quat::identity(),
				0,
				Color::rgba(0.0, 0.0, 0.0, 0.0),
				false,
				false,
			);
			match vehicle {
				Ok(mut v) => v.destroy(),
				Err(e) => {
					Self::emit_error(owner, format!("Can't go to test map: {}", e));
					return;
				}
			}

			unsafe {
				let node = self
					.test_map
					.as_ref()
					.expect("Test map is not set")
					.assume_safe()
					.instance(0)
					.expect("Failed to instance test map")
					.assume_safe();
				node.set("vehicle_path", &self.data_path);
				let node = node.claim();
				owner.queue_free();
				let tree = owner.get_tree().expect("Node not in tree").assume_safe();
				let root = tree.root().expect("Failed to get tree root").assume_safe();
				root.remove_child(owner);
				root.add_child(node.clone(), false);
				tree.set_current_scene(node);
			}
		}

		#[export]
		fn hide_windows(&mut self, owner: TRef<Node>) {
			self.focus_window(owner, Window::None);
		}

		#[export]
		fn select_block(&mut self, owner: TRef<Node>, id: u16) {
			if let Some(id) = NonZeroU16::new(id) {
				self.selected_block = id;
				owner.emit_signal("ghost_block", &[id.get().to_variant()]);
			} else {
				godot_error!("Attempt to pick block ID 0");
			}
		}

		#[export]
		fn add_color(&mut self, owner: TRef<Node>, color: Color) -> Option<u8> {
			let color = color::RGB8::lossy_from_color(color);
			match self.data.add_color(color) {
				Ok(i) => {
					owner.emit_signal("add_color", &[color.to_variant()]);
					Some(i)
				}
				Err(e) => {
					use super::data::VehicleError::*;
					let e = match e {
						ColorOutOfBounds => "maximum colors exceeded",
						_ => panic!("Unhandled add_color() error"),
					};
					Self::emit_error(owner, format!("Failed to add color: {}", e));
					None
				}
			}
		}

		#[export]
		fn remove_color(&mut self, owner: TRef<Node>, index: u8) {
			if let Err(e) = self.data.remove_color(index) {
				use super::data::VehicleError::*;
				let e = match e {
					ColorOutOfBounds => "index out of bounds",
					OnlyColor => "must have at least one color",
					_ => panic!("Unhandled remove_color() error"),
				};
				Self::emit_error(owner, format!("Failed to remove color: {}", e));
			} else {
				let change_index = if index == self.selected_color {
					Some(0)
				} else if self.selected_color > index {
					Some(self.selected_color - 1)
				} else {
					None
				};
				if let Some(index) = change_index {
					self.selected_color = index;
					let color = self.data.get_color(index).expect("Failed to get color");
					owner.emit_signal("ghost_color", &[color.to_variant()]);
				}
				owner.emit_signal("remove_color", &[index.to_variant()]);
				// TODO this is terribly inefficient
				self.refresh_meshes(owner);
			}
		}

		#[export]
		fn select_color(&mut self, owner: TRef<Node>, index: u8) {
			match self.data.get_color(index) {
				Ok(color) => {
					self.selected_color = index;
					owner.emit_signal("ghost_color", &[Color::from(color).to_variant()]);
				}
				Err(_) => Self::emit_error(owner, "Color doesn't exist"),
			}
		}

		#[export]
		fn change_color(&mut self, owner: TRef<Node>, index: u8, color: Color) {
			let color = color::RGB8::lossy_from_color(color);
			match self.data.change_color(index, color) {
				Ok(_) => {
					let color = color.to_variant();
					owner.emit_signal("change_color", &[index.to_variant(), color.clone()]);
					if index == self.selected_color {
						owner.emit_signal("ghost_color", &[color]);
					}
					// TODO this is terribly inefficient
					self.refresh_meshes(owner);
				}
				Err(_) => Self::emit_error(owner, "Color is out of bounds"),
			}
		}

		#[export]
		fn add_layer(&mut self, owner: TRef<Node>) {
			let name = "New layer";
			match self.data.add_layer() {
				Ok(i) => {
					let mesh = Instance::<VoxelMesh, _>::new().into_shared();
					owner.emit_signal("add_voxel_mesh", &[mesh.base().to_variant()]);
					self.layers.push((mesh, FxHashMap::default()));
					self.data
						.set_layer_name(i, name)
						.expect("Failed to set layer name");
					owner.emit_signal("add_layer", &[name.to_variant()]);
				}
				Err(e) => {
					use VehicleError::*;
					let e = match e {
						LayerOutOfBounds => "maximum layers exceeded",
						_ => panic!("Unhandled add_layer() error"),
					};
					Self::emit_error(owner, format!("Failed to add layer: {}", e));
				}
			}
		}

		#[export]
		fn remove_layer(&mut self, owner: TRef<Node>, index: u8) {
			if self.layers.len() <= 1 {
				Self::emit_error(owner, "Refusing to remove only layer");
			} else if let Err(e) = self.data.remove_layer(index, false) {
				use VehicleError::*;
				let e = match e {
					LayerOutOfBounds => "Layer doesn't exist",
					HasBlocks => "Layer still has blocks",
					_ => panic!("Unhandled remove_layer() error"),
				};
				Self::emit_error(owner, e);
			} else {
				owner.emit_signal("remove_layer", &[index.to_variant()]);
			}
		}

		#[export]
		fn rename_layer(&mut self, owner: TRef<Node>, index: u8, name: String) {
			match self.data.set_layer_name(index, name.clone()) {
				Ok(_) => {
					owner.emit_signal("rename_layer", &[index.to_variant(), name.to_variant()]);
				}
				Err(e) => {
					use VehicleError::*;
					let e = match e {
						LayerOutOfBounds => "layer doesn't exist",
						_ => panic!("Unhandled set_layer_name() error"),
					};
					Self::emit_error(owner, format!("Failed to rename layer: {}", e));
				}
			}
		}

		#[export]
		fn select_layer(&mut self, owner: TRef<Node>, index: u8) {
			if self.selected_layer == index {
				return;
			}
			if let Some((mesh, nodes)) = self.layers.get_mut(index as usize) {
				fn set_nodes_alpha(nodes: &FxHashMap<voxel::Position, Ref<Spatial>>, enable: bool) {
					for node in nodes.values() {
						unsafe {
							let node = node.assume_safe();
							if node.has_method("set_transparent") {
								node.call("set_transparent", &[enable.to_variant()]);
							}
						}
					}
				}
				unsafe {
					mesh.assume_safe()
						.map_mut(|mesh, _| mesh.set_transparent(false))
						.unwrap();
				}
				set_nodes_alpha(nodes, false);
				let (mesh, nodes) = &self.layers[self.selected_layer as usize];
				unsafe {
					mesh.assume_safe()
						.map_mut(|mesh, _| mesh.set_transparent(true))
						.unwrap();
				}
				set_nodes_alpha(nodes, true);
				self.selected_layer = index;
				owner.emit_signal("select_layer", &[index.to_variant()]);
				self.create_outline(owner);
			} else {
				Self::emit_error(owner, format!("Layer doesn't exist"));
			}
		}

		#[export]
		fn exit(&self, owner: TRef<Node>) {
			unsafe {
				let tree = owner.get_tree().expect("Not in tree").assume_safe();
				tree.change_scene(MAIN_MENU)
					.expect("Failed to go to main menu");
			}
		}

		#[export]
		fn set_snap_faces(&mut self, owner: TRef<Node>, enable: bool) {
			if self.snap_face != enable {
				self.snap_face = enable;
				owner.emit_signal("toggled_snap_faces", &[enable.to_variant()]);
			}
		}

		#[export]
		fn set_map_rotations(&mut self, owner: TRef<Node>, enable: bool) {
			if self.map_rotation != enable {
				self.map_rotation = enable;
				owner.emit_signal("toggled_map_rotations", &[enable.to_variant()]);
			}
		}

		#[export]
		#[cfg(debug_assertions)]
		fn debug_draw(&self, owner: TRef<Node>) {
			let debug = owner.get_node("/root/Debug").unwrap();
			let dhp = self.debug_points.replace(Vec::new());
			for point in &dhp {
				let point = Vector3::from(*point) + Vector3::new(0.5, 0.5, 0.5);
				unsafe {
					debug.assume_safe().call(
						"draw_point",
						&[
							point.to_variant(),
							Color::rgb(0.5, 1.0, 0.5).to_variant(),
							(0.25).to_variant(),
						],
					);
				}
			}
		}

		// cfg_attr doesn't work sadly, so this will do for now
		#[cfg(not(debug_assertions))]
		#[inline(always)]
		fn debug_draw(&self, _: TRef<Node>) {}
	}

	/// Methods that are not exposed to Godot
	impl Editor {
		fn place_block(
			&mut self,
			owner: TRef<Node>,
		) -> Result<(voxel::Position, Option<(voxel::Position, NonZeroU16)>), &str> {
			if !self.edit_mode {
				return Err("Enter edit mode to place blocks");
			}
			let pos = match self.place_block_orientation_from_camera() {
				RayResult::InsideGrid { position, .. } => position,
				RayResult::OutsideGrid { .. } | RayResult::NoCollision => {
					return Err("Location is outside grid")
				}
				RayResult::Collides { .. } => return Err("Location is already occupied"),
			};
			let layer = self.selected_layer;
			let color = self.selected_color;
			self.add_block(owner, self.selected_block, layer, pos, self.rotation, color)?;
			let mirror = if self.mirror {
				Self::get_mirror_orientation(pos, self.rotation, self.selected_block)
					.map(|(pos, rot, id)| {
						self.add_block(owner, id, layer, pos, rot, color)
							.map(|_| (pos, id))
							.ok()
					})
					.flatten()
			} else {
				None
			};
			self.create_outline(owner);
			Ok((pos, mirror))
		}

		fn remove_block(
			&mut self,
			owner: TRef<Node>,
		) -> Result<
			(
				voxel::Position,
				NonZeroU16,
				Option<(voxel::Position, NonZeroU16)>,
			),
			&str,
		> {
			if !self.edit_mode {
				return Err("Enter edit mode to remove blocks");
			}
			let (pos, _, _) = self.raycast_from_camera();
			if let Ok(pos) = pos.try_into() {
				let gs = GRID_SIZE - 1;
				let grid_aabb =
					voxel::AABB::new(voxel::Position::ZERO, voxel::Position::new(gs, gs, gs));
				if grid_aabb.has_point(pos) {
					let (pos, id) = self.delete_block(owner, self.selected_layer, pos)?;
					let mirror = if self.mirror {
						Self::get_mirror_orientation(pos, self.rotation, id)
							.map(|(pos, _, _)| {
								self.delete_block(owner, self.selected_layer, pos)
									.map(|_| (pos, id))
									.ok()
							})
							.flatten()
					} else {
						None
					};
					self.create_outline(owner);
					Ok((pos, id, mirror))
				} else {
					Err("Location is outside grid")
				}
			} else {
				Err("Location is outside grid")
			}
		}

		fn add_block(
			&mut self,
			owner: TRef<Node>,
			id: NonZeroU16,
			layer: u8,
			position: voxel::Position,
			rotation: Rotation,
			color: u8,
		) -> Result<(), &'static str> {
			if position.x >= GRID_SIZE || position.y >= GRID_SIZE || position.z >= GRID_SIZE {
				return Err("Location is outside grid");
			}
			let block = block::Block::get(id).ok_or("Block doesn't exist")?;
			if let Err(e) = self.data.add_block(layer, position, id, rotation, color) {
				use super::data::VehicleError::*;
				return match e {
					PositionOccupied => Err("Location is already occupied"),
					_ => panic!("Unhandled add_block() error"),
				};
			}
			let (mesh, nodes) = self
				.layers
				.get_mut(layer as usize)
				.ok_or("Layer doesn't exist")?;
			let color = self
				.data
				.get_color(color)
				.map_err(|_| "Failed to get color")?;
			unsafe {
				mesh.assume_safe()
					.map_mut(|mesh, mesh_owner| {
						mesh.add_block(block, color, position, rotation);
						mesh.generate(&mesh_owner)
					})
					.unwrap();
			}
			Self::add_editor_node(owner, block, position, rotation, color, nodes);
			Ok(())
		}

		fn delete_block(
			&mut self,
			_: TRef<Node>,
			layer: u8,
			position: voxel::Position,
		) -> Result<(voxel::Position, NonZeroU16), &'static str> {
			match self.data.remove_block(layer, position) {
				Err(_) => {
					panic!("Unhandled remove_block() error");
				}
				Ok(Some((block, pos))) => {
					let (mesh, nodes) = &mut self
						.layers
						.get_mut(layer as usize)
						.expect("Layer index out of bounds");
					unsafe {
						mesh.assume_safe()
							.map_mut(|s, o| {
								s.remove_block(pos);
								s.generate(&o);
							})
							.unwrap();
					}
					if let Some(node) = nodes.remove(&pos) {
						unsafe { node.assume_safe().queue_free() }
					}
					Ok((pos, block.id))
				}
				Ok(None) => Err("No block at location"),
			}
		}

		fn add_editor_node(
			owner: TRef<Node>,
			block: &block::Block,
			position: voxel::Position,
			rotation: Rotation,
			color: color::RGB8,
			nodes: &mut FxHashMap<voxel::Position, Ref<Spatial>>,
		) {
			if let Some(node) = block.editor_node {
				let node = unsafe {
					node.assume_safe()
						.duplicate(7)
						.expect("Failed to duplicate node")
						.assume_safe()
						.cast::<Spatial>()
						.expect("Failed to cast node")
				};
				node.set_transform(Transform {
					origin: position.into(),
					basis: rotation.basis().scaled(&Vector3::new(4.0, 4.0, 4.0)),
				});
				node.set("team_color", crate::constants::ALLY_COLOR.to_variant());
				if node.has_method("set_color") {
					unsafe {
						node.call("set_color", &[color.to_variant()]);
					}
				}
				let node = node.claim();
				nodes.insert(position, node.clone());
				owner.emit_signal("add_editor_node", &[node.to_variant()]);
			}
		}

		fn get_mirror_orientation(
			position: voxel::Position,
			rotation: Rotation,
			id: NonZeroU16,
		) -> Option<(voxel::Position, Rotation, NonZeroU16)> {
			let mut pos = position;
			pos.x = (GRID_SIZE - 1) - pos.x;
			let block = block::Block::get(id).expect("Failed to get block");
			let id = block.mirror_block().id;
			let rotation = block.mirror_rotation(rotation);
			Some((pos, rotation, id))
		}

		fn place_block_orientation_from_camera(&self) -> RayResult {
			let (position, normal, collided) = self.raycast_from_camera();
			if collided || (position.y == -1 && normal == voxel::Delta::Y) {
				if let Ok(position) = (position + normal).try_into() {
					let gs = GRID_SIZE - 1;
					let grid_aabb =
						voxel::AABB::new(voxel::Position::ZERO, voxel::Position::new(gs, gs, gs));
					if grid_aabb.has_point(position) {
						if self.data.has_block_at(position) {
							RayResult::Collides { position, normal }
						} else {
							RayResult::InsideGrid { position, normal }
						}
					} else {
						let position = position.into();
						RayResult::OutsideGrid { position, normal }
					}
				} else {
					let position = position + normal;
					RayResult::OutsideGrid { position, normal }
				}
			} else {
				RayResult::NoCollision
			}
		}

		fn raycast_from_camera(&self) -> (voxel::Delta, voxel::Delta, bool) {
			let (start, direction) = unsafe {
				let cam = self.camera.expect("Camera is None").assume_safe();
				(cam.translation(), -cam.transform().basis.z())
			};
			let gs = GRID_SIZE - 1;
			let mut ray = VoxelRaycast::start(
				start,
				direction,
				voxel::AABB::new(voxel::Position::ZERO, voxel::Position::new(gs, gs, gs)),
			);
			let mut final_pos = None;
			let mut collided = false;
			for (pos, norm) in &mut ray {
				final_pos = Some((pos, norm));
				let pos = (pos.x.try_into(), pos.y.try_into(), pos.z.try_into());
				if let (Ok(x), Ok(y), Ok(z)) = pos {
					if DEBUG_CAMERA_RAY {
						self.debug_add_point(voxel::Position::new(x, y, z));
					}
					// TODO maybe let the user switch between the two modes?
					if self.data.has_block_at(voxel::Position::new(x, y, z)) {
						collided = true;
						break;
					}
				}
			}
			if DEBUG_CAMERA_RAY {
				if let Some((p, n)) = final_pos {
					godot_print!("{}", collided);
					godot_print!("{} {} {}", p.x, p.y, p.z);
					godot_print!("{} {} {}", n.x, n.y, n.z);
					godot_print!("{} {} {}", ray.voxel().x, ray.voxel().y, ray.voxel().z);
					godot_print!("{} {} {}", ray.normal().x, ray.normal().y, ray.normal().z);
				}
			}
			if collided {
				let (p, n) = final_pos.unwrap();
				(p, n, true)
			} else {
				(ray.voxel(), ray.normal(), false)
			}
		}

		fn emit_error<T: AsRef<str>>(owner: TRef<Node>, message: T) {
			owner.emit_signal("error", &[Variant::from_str(message)]);
			owner.emit_signal("play_fail_effect", &[]);
		}

		fn clear_meshes(&mut self, owner: TRef<Node>) {
			let layers = mem::replace(&mut self.layers, Vec::new());
			for (mesh, blocks) in layers {
				owner.emit_signal("remove_voxel_mesh", &[mesh.to_variant()]);
				for block in blocks.into_values() {
					unsafe {
						block.assume_safe().queue_free();
					}
				}
			}
			let (mesh, blocks) = mem::replace(
				&mut self.outline,
				(Instance::new().into_shared(), FxHashSet::default()),
			);
			owner.emit_signal("remove_outline_voxel_mesh", &[mesh.to_variant()]);
			for position in blocks {
				owner.emit_signal("remove_outline_node", &[position.to_variant()]);
			}
			owner.emit_signal(
				"add_outline_voxel_mesh",
				&[self.outline.0.clone().to_variant()],
			);
		}

		fn rotate_ghost(&mut self, owner: TRef<Node>, amount: i32) {
			let amount = amount.rem_euclid(24) as u8;
			self.rotation = Rotation::new((self.rotation.get() + amount) % 24).unwrap();
			if self.snap_face {
				self.snap_ghost(owner);
			} else {
				owner.emit_signal("ghost_rotation", &[self.rotation.get().to_variant()]);
			}
			self.map_rotation();
			owner.emit_signal("play_rotate_effect", &[]);
		}

		fn snap_ghost(&mut self, owner: TRef<Node>) {
			let (_, normal, _) = self.raycast_from_camera();
			if normal.x == 0 && normal.y == 0 && normal.z == 0 {
				return; // Ray didn't collide with anything
			}
			let normal = (normal.x, normal.y, normal.z);
			self.rotation = self.rotation.snap_to_direction(normal).unwrap();
			self.map_rotation();
			owner.emit_signal("ghost_rotation", &[self.rotation.get().to_variant()]);
		}

		fn map_rotation(&mut self) {
			if self.map_rotation {
				let block = block::Block::get(self.selected_block).expect("Failed to get block");
				if let Some(map) = block.alternate_rotation_map {
					self.rotation = map[self.rotation.get() as usize];
				}
			}
		}

		fn enable_mirror(&mut self, owner: TRef<Node>, enable: bool) {
			if self.mirror != enable {
				self.mirror = enable;
				owner.emit_signal("toggled_mirror", &[enable.to_variant()]);
			}
		}

		fn focus_window(&mut self, owner: TRef<Node>, window: Window) {
			if self.focused_window == window {
				return; // Save some cycles
			}
			self.focused_window = window;
			owner.emit_signal("open_window", &[window.as_str().to_variant()]);
			owner.emit_signal(
				"toggled_handling_input",
				&[(window == Window::None).to_variant()],
			);
		}

		fn focus_or_hide_window(&mut self, owner: TRef<Node>, window: Window) {
			let window = if self.focused_window == window {
				Window::None
			} else {
				window
			};
			self.focus_window(owner, window);
		}

		#[profiled(tag = "Move vehicle")]
		fn move_vehicle(&mut self, owner: TRef<Node>, by: voxel::Delta) {
			if let Some(aabb) = self.data.aabb() {
				if let (Ok(s), Ok(e)) = (aabb.start + by, aabb.end + by) {
					let aabb = voxel::AABB::new(s, e);
					let gs = GRID_SIZE - 1;
					let grid_aabb =
						voxel::AABB::new(voxel::Position::ZERO, voxel::Position::new(gs, gs, gs));
					if grid_aabb.encloses(aabb) {
						self.data
							.move_all_blocks(by)
							.expect("Failed to move vehicle");
						self.refresh_meshes(owner);
					} else {
						Self::emit_error(owner, "Can't move vehicle outside grid");
					}
				} else {
					Self::emit_error(owner, "Can't move vehicle outside grid");
				}
			}
		}

		#[profiled(tag = "Rotate vehicle")]
		fn rotate_vehicle(&mut self, owner: TRef<Node>) {
			match self.data.rotate_all_blocks(GRID_SIZE) {
				Ok(()) => self.refresh_meshes(owner),
				Err(e) => {
					// TODO use Display trait
					Self::emit_error(owner, format!("Failed to rotate vehicle: {:?}", e));
				}
			}
		}

		fn refresh_meshes(&mut self, owner: TRef<Node>) {
			self.clear_meshes(owner);
			for layer in self.data.iter_layers() {
				let mesh = Instance::<VoxelMesh, _>::new();
				let mut nodes = FxHashMap::default();
				mesh.map_mut(|mesh, mesh_owner| {
					for (&position, block) in layer.iter_blocks() {
						let rotation = block.rotation;
						let color = self
							.data
							.get_color(block.color)
							.expect("Failed to get color");
						let block = block::Block::get(block.id).expect("Block not found");
						mesh.add_block(block, color, position, rotation);
						Self::add_editor_node(owner, block, position, rotation, color, &mut nodes);
					}
					mesh.generate(&mesh_owner)
				})
				.unwrap();
				let mesh = mesh.into_shared();
				owner.emit_signal("add_voxel_mesh", &[mesh.clone().to_variant()]);
				self.layers.push((mesh, nodes));
			}
			self.create_outline(owner);
		}

		#[profiled(tag = "Create outline")]
		fn create_outline(&mut self, owner: TRef<Node>) {
			// Create current (do it now so we can get a unique reference to mesh without unsafe)
			let mesh = Instance::new();
			let mut node_positions = FxHashSet::default();
			let mut nodes = Vec::new();

			mesh.map_mut(|mesh: &mut VoxelMesh, mesh_owner| {
				for (&position, block) in self
					.data
					.disconnected_blocks(self.selected_layer)
					.expect("Failed to get disconnected blocks in layer")
				{
					let rotation = block.rotation;
					let block = block::Block::get(block.id).expect("Failed to get block");
					mesh.add_block(block, color::RGB8::WHITE, position, rotation);
					if let Some(node) = block.editor_node {
						nodes.push((position, (rotation, node.clone())));
						node_positions.insert(position);
					}
				}
				mesh.generate(&mesh_owner);
			})
			.unwrap();

			// Clear previous
			{
				let (mesh, nodes) =
					mem::replace(&mut self.outline, (mesh.into_shared(), node_positions));
				owner.emit_signal("remove_outline_voxel_mesh", &[mesh.to_variant()]);
				for position in nodes.into_iter() {
					owner.emit_signal("remove_outline_node", &[position.to_variant()]);
				}
			}

			// Emit add signals (emit remove signals first to prevent unexpected behavior)
			owner.emit_signal(
				"add_outline_voxel_mesh",
				&[self.outline.0.clone().to_variant()],
			);
			for (pos, (rot, node)) in nodes {
				let pos = pos.to_variant();
				let rot = rot.get().to_variant();
				owner.emit_signal("add_outline_node", &[pos, rot, node.to_variant()]);
			}
		}

		#[cfg(debug_assertions)]
		fn debug_add_point(&self, point: voxel::Position) {
			let mut v = self.debug_points.replace(Vec::new());
			v.push(point);
			self.debug_points.set(v);
		}

		#[cfg(not(debug_assertions))]
		#[inline(always)]
		fn debug_add_point(&self, point: voxel::Position) {
			let _ = point;
		}
	}

	/// Methods specifically for Godot
	impl Editor {
		fn gd_selected_block(&self, _owner: TRef<Node>) -> u16 {
			self.selected_block.get()
		}

		fn gd_set_selected_block(&mut self, _owner: TRef<Node>, id: u16) {
			if let Ok(id) = id.try_into() {
				self.selected_block = id;
			} else {
				godot_error!("Block ID {} is not valid", id);
			}
		}

		fn gd_get_rotation(&self, _owner: TRef<Node>) -> u8 {
			self.rotation.get()
		}

		fn gd_set_rotation(&mut self, _owner: TRef<Node>, rotation: u8) {
			if let Ok(v) = Rotation::new(rotation) {
				self.rotation = v;
			} else {
				godot_error!("Rotation is out of bounds");
			}
		}
	}

	/// This is to make sure we don't leak any resources (looking at you, Node -_-)
	impl Drop for Editor {
		fn drop(&mut self) {
			// TODO actually, let's don't, godot pls reference counted objects when?
			/*
			for (_, nodes) in self.layers.iter_mut() {
				for (_, node) in nodes.iter_mut() {
					unsafe { node.assume_safe().queue_free() }
				}
			}
			*/
		}
	}

	#[derive(NativeClass)]
	#[inherit(Reference)]
	pub(super) struct VehicleData /*<'a>*/ {
		data: Vehicle,
		// FIXME find a way to get lifetimes to work with iterators
		// For now, just return a big dump of data and let GDScript go figure
		//layer_iter: Option<Box<dyn Iterator<Item = &'a super::data::Layer> + 'a>>,
		//block_iter: Option<Box<dyn Iterator<Item = &'a super::data::Block> + 'a>>,
	}

	/// A class to load vehicle data from GDScript
	///
	/// It's intended to be used as an iterator (à la `for block in vehicle_data: ...`)
	#[methods]
	impl VehicleData {
		fn new(_owner: TRef<Reference>) -> Self {
			Self {
				data: Vehicle::new(),
			}
		}

		#[export]
		fn load_data(&mut self, _owner: TRef<Reference>, data: TypedArray<u8>) -> i64 {
			self.data = super::serialize::load(data.read().as_slice())
				.expect("Failed to decode vehicle data");
			0
		}

		#[export]
		fn load_file(&mut self, _owner: TRef<Reference>, path: GodotString) -> i64 {
			let file = File::new();
			file.open(path, File::READ).expect("Failed to open file");
			let data = file.get_buffer(file.get_len());
			self.data = super::serialize::load(data.read().as_slice())
				.expect("Failed to decode vehicle data");
			0
		}

		#[export]
		fn get_colors(&self, _owner: TRef<Reference>) -> TypedArray<Color> {
			let mut arr = TypedArray::new();
			arr.resize(self.data.color_count() as i32);
			let mut w = arr.write();
			for (w, c) in w.iter_mut().zip(self.data.iter_colors().copied()) {
				*w = c.into();
			}
			drop(w);
			arr
		}

		#[export]
		fn get_layer_count(&self, _owner: TRef<Reference>) -> u8 {
			self.data.layer_count()
		}

		#[export]
		/// Format:
		/// xxxxxxxx | XXXXXXXX | YYYYYYYY | ZZZZZZZZ
		/// xxxRRRRR | CCCCCCCC | IIIIIIII | IIIIIIII
		/// XYZ = position
		/// R = rotation
		/// C = color index
		/// I = ID
		/// Yes, It's terrible. Lifetimes pls
		fn get_blocks_in_layer(&self, _owner: TRef<Reference>, index: u8) -> TypedArray<i32> {
			let layer = self.data.get_layer(index).unwrap();
			let mut arr = TypedArray::new();
			arr.resize(layer.block_count() as i32 * 2);
			let mut w = arr.write();
			for (i, (p, b)) in layer.iter_blocks().enumerate() {
				w[i * 2] = ((p.x as i32) << 16) | ((p.y as i32) << 8) | (p.z as i32);
				w[i * 2 + 1] = ((b.rotation.get() as i32) << 24)
					| ((b.color as i32) << 16)
					| (b.id.get() as i32);
			}
			drop(w);
			arr
		}

		#[export]
		fn get_layer_aabb(&self, _: TRef<Reference>, index: u8) -> Option<Aabb> {
			self.data
				.get_layer(index)
				.unwrap()
				.aabb()
				.map(voxel::AABB::into)
		}
	}
}

pub(crate) fn init(handle: gdnative::nativescript::InitHandle) {
	#[cfg(not(feature = "server"))]
	handle.add_class::<godot::Editor>();
	#[cfg(not(feature = "server"))]
	handle.add_class::<godot::VehicleData>();
	#[cfg(feature = "server")]
	let _ = handle;
}
