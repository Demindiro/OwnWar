#![feature(destructuring_assignment)]

#[cfg(not(feature = "server"))]
mod cull;

#[cfg(not(feature = "server"))]
use cull::*;
use gdnative::api::{Mesh, Node};
#[cfg(not(feature = "server"))]
use gdnative::api::{Engine, Object, VisualServer, World};
use gdnative::prelude::*;
#[cfg(not(feature = "server"))]
use lazy_static::lazy_static;
#[cfg(not(feature = "server"))]
use std::collections::HashMap;
#[cfg(not(feature = "server"))]
use std::sync::RwLock;

#[cfg(not(feature = "server"))]
const MULTIMESH_ALLOC_STEP: usize = 256;

#[cfg(not(feature = "server"))]
lazy_static! {
	static ref MULTI_MESHES: RwLock<State> = RwLock::new(State {
		id_counter: 0,
		no_color_map: HashMap::new(),
		color_map: HashMap::new(),
		enable_culling: false,
	});
	static ref MANAGERS: RwLock<Vec<Ref<Node>>> = RwLock::new(Vec::new());
	static ref EXITING: RwLock<bool> = RwLock::new(false);
}

type Layers = u32;

#[cfg(not(feature = "server"))]
struct NodeEntry {
	id: usize,
	node: Instance<BatchedMeshInstance, Shared>,
}

#[cfg(not(feature = "server"))]
struct MultiMeshEntry {
	instance_rid: Rid,
	multimesh_rid: Rid,
	visualserver_data: TypedArray<f32>,
	nodes: Vec<NodeEntry>,
}

#[cfg(not(feature = "server"))]
struct State {
	id_counter: usize,
	no_color_map: HashMap<(Ref<World>, Ref<Mesh>, Layers), MultiMeshEntry>,
	color_map: HashMap<(Ref<World>, Ref<Mesh>, Layers), MultiMeshEntry>,
	enable_culling: bool,
}

#[derive(NativeClass)]
#[inherit(Node)]
#[register_with(Self::register)]
struct BatchedMeshManager {}

#[derive(NativeClass)]
#[inherit(Spatial)]
#[register_with(Self::register)]
struct BatchedMeshInstance {
	#[property(before_set = "Self::remove_instance", after_set = "Self::add_instance")]
	mesh: Option<Ref<Mesh>>,
	#[cfg(not(feature = "server"))]
	id: Option<usize>,
	#[property(before_set = "Self::remove_instance", after_set = "Self::add_instance")]
	use_color: bool,
	#[property(before_set = "Self::remove_instance", after_set = "Self::add_instance")]
	layers: Layers,
	color: [u8; 4],
}

#[cfg(not(feature = "server"))]
#[cfg_attr(not(feature = "server"), methods)]
impl BatchedMeshManager {
	fn register(builder: &ClassBuilder<Self>) {
		builder.add_signal(Signal {
			name: "reload",
			args: &[],
		});
		builder
			.add_property("enable_culling")
			.with_getter(Self::gd_get_enable_culling)
			.with_setter(Self::gd_set_enable_culling)
			.done();
	}

	fn new(owner: TRef<Node>) -> Self {
		MANAGERS
			.write()
			.expect("Failed to write MANAGERS")
			.push(owner.claim());
		Self {}
	}

	#[export]
	fn _notification(&self, owner: TRef<Node>, what: i64) {
		if what == Object::NOTIFICATION_PREDELETE
			&& !*EXITING.read().expect("Failed to read EXITING")
		{
			let mut managers = MANAGERS.write().expect("Failed to write MANAGERS");
			let owner = owner.claim();
			let index = managers
				.iter()
				.position(|v| v == &owner)
				.expect("Failed to find manager");
			managers.swap_remove(index);
		}
	}

	#[export]
	fn _process(&self, owner: TRef<Node>, _delta: f32) {
		unsafe {
			owner.call_deferred("_update_transforms", &[]);
		}
	}

	#[export]
	#[profiled(tag = "Batcher/Update transforms")]
	fn _update_transforms(&self, owner: TRef<Node>) {
		let mut map = MULTI_MESHES.write().expect("Failed to read MULTI_MESHES");
		let enable_culling = map.enable_culling;
		let vs = unsafe { VisualServer::godot_singleton() };
		let frustum = unsafe {
			owner
				.get_tree()
				.expect("Not inside tree")
				.assume_safe()
				.root()
				.expect("Tree has no root")
				.assume_safe()
				.get_camera()
				.map(|c| c.assume_safe().get_frustum())
		};

		let (frustum, enable_culling) = if let Some(frustum) = frustum {
			let mut fr = [Plane::new(Vector3::zero(), 0.0); 6];
			for (i, e) in frustum.iter().enumerate() {
				fr[i] = e.try_to_plane().expect("Element is not a plane");
			}
			(Frustum::new(fr), enable_culling)
		} else if Engine::godot_singleton().is_editor_hint() {
			// godot pls gief camera
			(Frustum::new([Plane::new(Vector3::zero(), 0.0); 6]), false)
		} else {
			// There is no active camera, don't bother
			return;
		};

		for ((_, mesh, _), entry) in map.no_color_map.iter_mut() {
			let mut count = 0usize;
			let mut w = entry.visualserver_data.write();
			let aabb = unsafe { mesh.assume_safe().get_aabb() };
			for e in entry.nodes.iter() {
				unsafe {
					e.node
						.assume_safe()
						.map(|_, o| {
							let trf = o.global_transform();
							if !enable_culling || frustum.is_aabb_visible(aabb, trf) {
								for (k, &e) in transform_to_array(trf).iter().enumerate() {
									w[count * 12 + k] = e;
								}
								count += 1;
							}
						})
						.expect("Failed to borrow node");
				}
			}
			drop(w);
			vs.multimesh_set_visible_instances(entry.multimesh_rid, count as i64);
			vs.multimesh_set_as_bulk_array(entry.multimesh_rid, entry.visualserver_data.clone());
		}
		for ((_, mesh, _), entry) in map.color_map.iter_mut() {
			let mut count = 0usize;
			let mut w = entry.visualserver_data.write();
			let aabb = unsafe { mesh.assume_safe().get_aabb() };
			for e in entry.nodes.iter() {
				unsafe {
					e.node
						.assume_safe()
						.map(|s, o| {
							let trf = o.global_transform();
							if !enable_culling || frustum.is_aabb_visible(aabb, trf) {
								for (k, &e) in transform_to_array(trf).iter().enumerate() {
									w[count * 13 + k] = e;
								}
								// TODO is it always little endian?
								w[count * 13 + 12] = f32::from_le_bytes(s.color);
								count += 1;
							}
						})
						.expect("Failed to borrow node");
				}
			}
			drop(w);
			vs.multimesh_set_visible_instances(entry.multimesh_rid, count as i64);
			vs.multimesh_set_as_bulk_array(entry.multimesh_rid, entry.visualserver_data.clone());
		}
	}

	fn gd_get_enable_culling(&self, _owner: TRef<Node>) -> bool {
		MULTI_MESHES
			.read()
			.expect("Failed to read MULTI_MESHES")
			.enable_culling
	}

	fn gd_set_enable_culling(&mut self, _owner: TRef<Node>, enable: bool) {
		MULTI_MESHES
			.write()
			.expect("Failed to write MULTI_MESHES")
			.enable_culling = enable;
	}
}

#[cfg(feature = "server")]
#[cfg_attr(feature = "server", methods)]
impl BatchedMeshManager {
	fn register(builder: &ClassBuilder<Self>) {
		builder.add_signal(Signal {
			name: "reload",
			args: &[],
		});
		builder
			.add_property("enable_culling")
			.with_getter(Self::gd_get_enable_culling)
			.with_setter(Self::gd_set_enable_culling)
			.done();
	}

	fn new(_: TRef<Node>) -> Self {
		Self {}
	}

	fn gd_get_enable_culling(&self, _: TRef<Node>) -> bool {
		false
	}

	fn gd_set_enable_culling(&mut self, _: TRef<Node>, _: bool) {
	}
}

#[cfg(not(feature = "server"))]
#[cfg_attr(not(feature = "server"), methods)]
impl BatchedMeshInstance {
	fn register(builder: &ClassBuilder<Self>) {
		builder
			.add_property("color")
			.with_getter(Self::gd_get_color)
			.with_setter(Self::gd_set_color)
			.done();
	}

	fn new(_: TRef<Spatial>) -> Self {
		Self {
			mesh: None,
			id: None,
			use_color: false,
			layers: 1,
			color: [255; 4],
		}
	}

	#[export]
	fn _enter_tree(&mut self, owner: TRef<Spatial>) {
		debug_assert_eq!(self.id, None);
		if let Some(mesh) = &self.mesh {
			if self.visible(owner) {
				assert!(self.id.is_none(), "Instance is added more than once!");
				self.id = Some(add_instance(
					owner.get_world().expect("World is None"),
					mesh.clone(),
					self.layers,
					owner.cast_instance().unwrap().claim(),
					self.use_color,
				));
			}
		}
	}

	#[export]
	fn _exit_tree(&mut self, owner: TRef<Spatial>) {
		if let Some(id) = self.id {
			remove_instance(
				&owner.get_world().expect("World is None"),
				self.mesh.as_ref().expect("Mesh is None"),
				self.layers,
				id,
				self.use_color,
			);
			self.id = None;
		}
	}

	#[export]
	fn _notification(&mut self, owner: TRef<Spatial>, what: i64) {
		if what == Spatial::NOTIFICATION_VISIBILITY_CHANGED {
			if let Some(id) = self.id {
				remove_instance(
					&owner.get_world().expect("World is None"),
					self.mesh.as_ref().expect("Mesh is None"),
					self.layers,
					id,
					self.use_color,
				);
				self.id = None;
			}
			if let Some(mesh) = &self.mesh {
				if self.visible(owner) {
					self.id = Some(add_instance(
						owner.get_world().expect("World is None"),
						mesh.clone(),
						self.layers,
						owner.cast_instance().unwrap().claim(),
						self.use_color,
					));
				}
			}
		}
	}

	fn remove_instance(&mut self, owner: TRef<Spatial>) {
		if let Some(id) = self.id {
			let mesh = self.mesh.as_ref().expect("Mesh is None");
			let world = owner.get_world().expect("World is None");
			remove_instance(&world, &mesh, self.layers, id, self.use_color);
			self.id = None;
		}
	}

	fn add_instance(&mut self, owner: TRef<Spatial>) {
		if let Some(mesh) = &self.mesh {
			if self.visible(owner) {
				assert!(self.id.is_none(), "Instance is added more than once!");
				self.id = Some(add_instance(
					owner.get_world().expect("World is None"),
					mesh.clone(),
					self.layers,
					owner.cast_instance().unwrap().claim(),
					self.use_color,
				));
			}
		}
	}

	fn visible(&self, owner: TRef<Spatial>) -> bool {
		owner.is_inside_tree() && owner.is_visible_in_tree()
	}
}

#[cfg(feature = "server")]
#[cfg_attr(feature = "server", methods)]
impl BatchedMeshInstance {
	fn register(builder: &ClassBuilder<Self>) {
		builder
			.add_property("color")
			.with_getter(Self::gd_get_color)
			.with_setter(Self::gd_set_color)
			.done();
	}

	fn new(_: TRef<Spatial>) -> Self {
		Self {
			mesh: None,
			use_color: false,
			layers: 1,
			color: [255; 4],
		}
	}

	fn remove_instance(&mut self, _: TRef<Spatial>) {}

	fn add_instance(&mut self, _: TRef<Spatial>) {}
}

impl BatchedMeshInstance {
	fn gd_get_color(&self, _r: TRef<Spatial>) -> Color {
		let [r, g, b, a] = self.color;
		let (r, g, b, a) = (r as f32, g as f32, b as f32, a as f32);
		let (r, g, b, a) = (r / 255.0, g / 255.0, b / 255.0, a / 255.0);
		Color::rgba(r, g, b, a)
	}

	fn gd_set_color(&mut self, _: TRef<Spatial>, color: Color) {
		let Color { r, g, b, a } = color;
		let (r, g, b, a) = (r * 255.0, g * 255.0, b * 255.0, a * 255.0);
		let (r, g, b, a) = (r as u8, g as u8, b as u8, a as u8);
		self.color = [r, g, b, a];
	}
}

#[cfg(not(feature = "server"))]
fn add_instance(
	world: Ref<World>,
	mesh: Ref<Mesh>,
	layers: Layers,
	node: Instance<BatchedMeshInstance, Shared>,
	use_color: bool,
) -> usize {
	//prinln!("add_instance    {:?}, {:?}, {:?}, {:?}",

	let vs = unsafe { VisualServer::godot_singleton() };
	let mut map = MULTI_MESHES.write().expect("Failed to access MULTI_MESHES");
	let id = map.id_counter;
	map.id_counter += 1;

	let (map, instance_data_size, color_setting) = if use_color {
		(&mut map.color_map, 13, VisualServer::MULTIMESH_COLOR_8BIT)
	} else {
		(
			&mut map.no_color_map,
			12,
			VisualServer::MULTIMESH_COLOR_NONE,
		)
	};

	let scenario = unsafe { world.assume_safe().scenario() };

	let entry = map.entry((world, mesh.clone(), layers)).or_insert_with(|| {
		let mm_rid = vs.multimesh_create();
		let mesh_rid = unsafe { mesh.assume_safe().get_rid() };
		vs.multimesh_set_mesh(mm_rid, mesh_rid);
		vs.multimesh_allocate(
			mm_rid,
			MULTIMESH_ALLOC_STEP as i64,
			VisualServer::MULTIMESH_TRANSFORM_3D,
			color_setting,
			VisualServer::MULTIMESH_CUSTOM_DATA_NONE,
		);
		let inst_rid = vs.instance_create2(mm_rid, scenario);
		vs.instance_set_transform(
			inst_rid,
			Transform {
				basis: Basis::identity(),
				origin: Vector3::zero(),
			},
		);
		vs.instance_set_scenario(inst_rid, scenario);
		vs.instance_set_base(inst_rid, mm_rid);
		vs.instance_set_visible(inst_rid, true);
		vs.instance_set_layer_mask(inst_rid, layers.into());
		#[cfg(feature = "verbose")]
		godot_print!("Adding {:?} & {:?}", inst_rid, mm_rid);
		MultiMeshEntry {
			instance_rid: inst_rid,
			multimesh_rid: mm_rid,
			visualserver_data: TypedArray::new(),
			nodes: Vec::new(),
		}
	});

	entry.nodes.push(NodeEntry { id, node });

	let size = entry.visualserver_data.len() as usize / instance_data_size;
	if entry.nodes.len() > size {
		let new_size = size + MULTIMESH_ALLOC_STEP;
		entry
			.visualserver_data
			.resize((new_size * instance_data_size) as i32);
		let mut w = entry.visualserver_data.write();
		for i in size..new_size {
			let i = i as usize * instance_data_size;
			for k in 0..instance_data_size {
				w[i + k] = 0.0;
			}
			w[i] = 1.0;
			w[i + 5] = 1.0;
			w[i + 10] = 1.0;
		}
		drop(w);
		vs.multimesh_allocate(
			entry.multimesh_rid,
			new_size as i64,
			VisualServer::MULTIMESH_TRANSFORM_3D,
			color_setting,
			VisualServer::MULTIMESH_CUSTOM_DATA_NONE,
		);
		vs.multimesh_set_as_bulk_array(entry.multimesh_rid, entry.visualserver_data.clone());
	}

	id
}

#[cfg(not(feature = "server"))]
fn remove_instance(
	world: &Ref<World>,
	mesh: &Ref<Mesh>,
	layers: Layers,
	id: usize,
	uses_color: bool,
) {
	let vs = unsafe { VisualServer::godot_singleton() };
	let mut map = MULTI_MESHES.write().expect("Failed to access MULTI_MESHES");
	let map = if uses_color {
		&mut map.color_map
	} else {
		&mut map.no_color_map
	};
	// TODO find a way to do this without cloning
	let key = &(world.clone(), mesh.clone(), layers);
	let entry = map.get_mut(key).expect("Entry not found");
	let index = entry
		.nodes
		.binary_search_by(|e| e.id.cmp(&id))
		.expect("ID not found");
	entry.nodes.remove(index);
	if entry.nodes.len() == 0 {
		#[cfg(feature = "verbose")]
		godot_print!(
			"Removing {:?} & {:?}",
			entry.instance_rid,
			entry.multimesh_rid
		);
		vs.free_rid(entry.instance_rid);
		vs.free_rid(entry.multimesh_rid);
		map.remove(key);
	}
}

#[cfg(not(feature = "server"))]
fn transform_to_array(transform: Transform) -> [f32; 12] {
	let tb = transform.basis;
	let to = transform.origin;
	let (bx, by, bz) = (tb.x(), tb.y(), tb.z());
	[
		bx.x, by.x, bz.x, to.x, bx.y, by.y, bz.y, to.y, bx.z, by.z, bz.z, to.z,
	]
}

fn init(handle: InitHandle) {
	handle.add_tool_class::<BatchedMeshInstance>();
	handle.add_tool_class::<BatchedMeshManager>();
}

/*
fn terminate(_info: &gdnative::TerminateInfo) {
	{
		*EXITING.write().expect("Failed to write EXITING") = true;
	}
	let managers = MANAGERS.read().expect("Failed to read MANAGERS");
	for m in managers.iter() {
		unsafe {
			// godot pls (seriously what?)
			if m.assume_safe().has_signal("reload") {
				m.assume_safe().emit_signal("reload", &[]);
				m.assume_unique().free();
			}
		}
	}
}
*/

godot_init!(init);
