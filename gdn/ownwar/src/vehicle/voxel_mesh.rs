use crate::block;
use crate::rotation::*;
use crate::util::convert_vec;
use euclid::{UnknownUnit, Vector3D};
use gdnative::api::{ArrayMesh, Material, Mesh, Resource, SpatialMaterial};
use gdnative::prelude::*;
use std::collections::{hash_map::Entry, HashMap};
use std::convert::TryInto;

type Voxel = Vector3D<u8, UnknownUnit>;

#[derive(NativeClass)]
#[inherit(ArrayMesh)]
pub(crate) struct VoxelMesh {
	#[property]
	dirty: bool,
	meshes: HashMap<(u8, u8, u8), (Ref<SpatialMaterial>, Vec<SubMesh>, bool)>,
	occlusion_map: HashMap<Voxel, OcclusionInfo>,
	remove_list_positions: Vec<Voxel>,
}

#[derive(Clone)]
struct SubMesh {
	face_vertices: Box<[Box<[block::MeshPoint]>; 6]>,
	global_vertices: Box<Box<[block::MeshPoint]>>,
	coordinate: Voxel,
}

struct OcclusionInfo {
	solid_faces: u8,
}

struct OcclusionResult(u8);

#[methods]
impl VoxelMesh {
	pub(crate) fn new(_owner: &ArrayMesh) -> Self {
		Self {
			dirty: false,
			meshes: HashMap::new(),
			remove_list_positions: Vec::new(),
			occlusion_map: HashMap::new(),
		}
	}

	#[export]
	fn add_block_gd(
		&mut self,
		_owner: &ArrayMesh,
		block: Ref<Resource>,
		color: Color,
		coordinate: Vector3,
		rotation: u8,
	) {
		let rotation = if let Ok(v) = Rotation::new(rotation) {
			v
		} else {
			godot_error!("Rotation is out of bounds");
			return;
		};
		unsafe {
			let v = convert_vec(coordinate);
			block
				.assume_safe()
				.cast_instance::<block::Block>()
				.unwrap()
				.map(|block, _| {
					self.add_block(block, color, v, rotation);
				})
				.unwrap();
		}
	}

	pub(crate) fn add_block(
		&mut self,
		block: &block::Block,
		color: Color,
		coordinate: Voxel,
		rotation: Rotation,
	) {
		if let Some((_, mesh_arrays)) = block.mesh_arrays() {
			let key = Self::color_to_tuple(color);
			for (i, array) in mesh_arrays.iter().enumerate() {
				let sm = Self::get_submesh(coordinate, rotation, i as u8, array, block);
				match self.meshes.entry(key) {
					Entry::Occupied(mut e) => {
						let e = e.get_mut();
						e.1.push(sm);
						e.2 = true;
					}
					Entry::Vacant(e) => {
						let material = Self::create_material(color);
						e.insert((material, vec![sm], true));
					}
				}
				self.dirty = true
			}
		}
		self.occlusion_map
			.insert(coordinate, OcclusionInfo::new(block, rotation));
	}

	pub(crate) fn remove_block(&mut self, coordinate: Voxel) {
		self.remove_list_positions.push(coordinate);
		self.occlusion_map.remove(&coordinate);
		self.dirty = true;
	}

	#[export]
	pub(crate) fn generate(&mut self, owner: &ArrayMesh) {
		let mut remove_colors = Vec::new();
		for (&color, (material, list, array_dirty)) in self.meshes.iter_mut() {
			for i in (0..list.len()).rev() {
				let sm = &list[i];
				if self.remove_list_positions.contains(&sm.coordinate) {
					list.swap_remove(i);
					*array_dirty = true;
				}
			}

			if list.is_empty() {
				Self::remove_surface_array(owner, material.clone().upcast());
				remove_colors.push(color);
			} else if *array_dirty || true {
				Self::remove_surface_array(owner, material.clone().upcast());
				let mut vertices = TypedArray::<Vector3>::new();
				let mut normals = TypedArray::<Vector3>::new();

				let len = {
					let mut len = 0;
					for sm in list.iter() {
						for fv in sm.face_vertices.iter() {
							len += fv.len() as i32;
						}
						len += sm.global_vertices.len() as i32;
					}
					vertices.resize(len);
					normals.resize(len);
					let mut verts = vertices.write();
					let mut norms = normals.write();
					let mut i = 0;
					for sm in list.iter() {
						let result = Self::occlusion_check(&self.occlusion_map, sm.coordinate);
						if result.0 != 0x3f {
							for (u, fv) in sm.face_vertices.iter().enumerate() {
								if result.0 & (1 << u) == 0 {
									for point in fv.iter() {
										verts[i] = point.vertex;
										norms[i] = point.normal;
										i += 1;
									}
								}
							}
							for point in sm.global_vertices.iter() {
								verts[i] = point.vertex;
								norms[i] = point.normal;
								i += 1;
							}
						}
					}
					i
				};

				vertices.resize(len as i32);
				normals.resize(len as i32);

				let array = VariantArray::new();
				array.resize(ArrayMesh::ARRAY_MAX as i32);
				array.set(ArrayMesh::ARRAY_VERTEX as i32, vertices);
				array.set(ArrayMesh::ARRAY_NORMAL as i32, normals);
				let index = owner.get_surface_count();
				owner.add_surface_from_arrays(
					Mesh::PRIMITIVE_TRIANGLES,
					array.into_shared(),
					VariantArray::new().into_shared(),
					31744,
				);
				owner.surface_set_material(index, material.clone());

				*array_dirty = false;
			}
		}
		for color in remove_colors {
			self.meshes.remove(&color);
		}
		self.remove_list_positions.clear();
		self.dirty = false;
	}

	pub(crate) fn dirty(&self) -> bool {
		self.dirty
	}

	fn occlusion_check(map: &HashMap<Voxel, OcclusionInfo>, pos: Voxel) -> OcclusionResult {
		let pos = convert_vec(pos);
		let mut result = 0;
		for dir in 0..6 {
			let dir = Direction::new(dir).unwrap();
			let pos = pos + dir.vector();
			let pos = pos.x.try_into().map(|x| {
				pos.y
					.try_into()
					.map(|y| pos.z.try_into().map(|z| Voxel::new(x, y, z)))
			});
			// Flatten doesn't work, so nested Ok()s it is!
			if let Ok(Ok(Ok(pos))) = pos {
				if map.get(&pos).map_or(false, |v| v.is_face_solid(dir)) {
					result |= 1 << dir.invert().get();
				}
			}
		}
		OcclusionResult(result)
	}

	fn remove_surface_array(owner: &ArrayMesh, material: Ref<Material>) {
		for i in 0..owner.get_surface_count() {
			if material == owner.surface_get_material(i).unwrap() {
				owner.surface_remove(i);
				break;
			}
		}
	}

	fn color_to_tuple(color: Color) -> (u8, u8, u8) {
		let c = (color.r * 255.0, color.g * 255.0, color.b * 255.0);
		(c.0 as u8, c.1 as u8, c.2 as u8)
	}

	fn tuple_to_color(color: (u8, u8, u8)) -> Color {
		let c = (color.0 as f32, color.1 as f32, color.2 as f32);
		Color::rgb(c.0 / 255.0, c.1 / 255.0, c.2 / 255.0)
	}

	fn create_material(color: Color) -> Ref<SpatialMaterial> {
		let mat = Ref::<SpatialMaterial, Unique>::new();
		mat.set_albedo(color);
		mat.set_roughness(0.4);
		mat.into_shared()
	}

	fn get_submesh(
		coordinate: Voxel,
		rotation: Rotation,
		index: u8,
		array: &Vec<block::MeshPoint>,
		block: &block::Block,
	) -> SubMesh {
		let basis = rotation.basis();
		let position = convert_vec(coordinate) * block::SCALE;
		let mut a = Vec::with_capacity(array.len());
		for point in array.iter() {
			a.push(block::MeshPoint {
				vertex: basis.xform(point.vertex) + position,
				normal: basis.xform(point.normal),
				uv: point.uv,
			})
		}
		SubMesh::new(block, index, a, coordinate, rotation)
	}

	pub fn set_transparent(&mut self, enable: bool) {
		for (&color, (material, _, _)) in self.meshes.iter() {
			unsafe {
				let mut color = Self::tuple_to_color(color);
				color.a = if enable {
					crate::constants::TRANSPARENT_BLOCK_ALPHA
				} else {
					1.0
				};
				let material = material.assume_safe();
				material.set_albedo(color);
				material.set_feature(SpatialMaterial::FEATURE_TRANSPARENT, enable);
				// BLEND_MODE_MIX causes flickering and BLEND_MODE_ADD looks bad, but
				// at least it doesn't flicker...
				material.set_blend_mode(if enable {
					SpatialMaterial::BLEND_MODE_ADD
				} else {
					SpatialMaterial::BLEND_MODE_MIX
				});
			}
		}
	}
}

impl SubMesh {
	fn new(
		block: &block::Block,
		index: u8,
		array: Vec<block::MeshPoint>,
		coordinate: Voxel,
		rotation: Rotation,
	) -> Self {
		let mut face_vertices = Vec::with_capacity(6);
		for _ in 0..6 {
			face_vertices.push(Vec::new().into_boxed_slice());
		}
		for i in 0..6 {
			let dir = Direction::new(i).unwrap();
			let indices = block.face_vertex_indices(index, dir, rotation);
			let mut verts = Vec::with_capacity(indices.len());
			for &i in indices.iter() {
				verts.push(array[i as usize]);
			}
			if verts.len() == 0 {
				continue;
			}
			let norm = (verts[1].vertex - verts[0].vertex).cross(verts[2].vertex - verts[0].vertex);
			let norm = norm.normalize();
			let norm = convert_vec::<_, i8>(norm);
			// TODO fix the norm rotation in block.rs instead of deriving it ourselves
			let dir = if dir.vector() != norm {
				//godot_print!("dir != norm  {}", rotation.get());
				//godot_print!("{:2} {:2} {:2} = {:2} {:2} {:2}", norm.x, norm.y, norm.z, dir.x, dir.y, dir.z);
				Direction::from_vector(norm).unwrap()
			} else {
				dir
			};
			//face_vertices.push(verts.into_boxed_slice());
			face_vertices[dir.get() as usize] = verts.into_boxed_slice();
		}
		let indices = block.global_vertex_indices(index);
		let mut verts = Vec::with_capacity(indices.len());
		for &i in indices.iter() {
			verts.push(array[i as usize]);
		}
		Self {
			face_vertices: Box::new(face_vertices.try_into().unwrap()),
			global_vertices: Box::new(verts.into_boxed_slice()),
			coordinate,
		}
	}
}

impl OcclusionInfo {
	fn new(block: &block::Block, rotation: Rotation) -> Self {
		Self {
			solid_faces: block.solid_faces_rotated(rotation),
		}
	}

	fn is_face_solid(&self, direction: Direction) -> bool {
		self.solid_faces & (1 << direction.get()) > 0
	}
}
