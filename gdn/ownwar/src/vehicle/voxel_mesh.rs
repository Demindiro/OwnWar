use crate::block;
use crate::util::convert_vec;
use euclid::{UnknownUnit, Vector3D};
use gdnative::api::{ArrayMesh, Material, Mesh, Resource, SpatialMaterial};
use gdnative::prelude::*;
use lazy_static::lazy_static;
use std::collections::{hash_map::Entry, HashMap};
use std::num::NonZeroU16;
use std::sync::{Arc, RwLock};

type Voxel = Vector3D<u8, UnknownUnit>;

lazy_static! {
	static ref MATERIAL_CACHE: RwLock<HashMap<(u8, u8, u8), Ref<SpatialMaterial>>> =
		RwLock::new(HashMap::new());
	static ref SUBMESH_CACHE: RwLock<HashMap<(NonZeroU16, Voxel, u8, u8), SubMesh>> =
		RwLock::new(HashMap::new());
}

#[derive(NativeClass)]
#[inherit(ArrayMesh)]
pub(crate) struct VoxelMesh {
	#[property]
	dirty: bool,
	material_to_meshes_map: HashMap<Ref<SpatialMaterial>, (Vec<SubMesh>, bool)>,
	remove_list_positions: Vec<Voxel>,
}

#[derive(Clone)]
struct SubMesh {
	array: Arc<Vec<block::MeshPoint>>,
	//array: VariantArray,
	coordinate: Voxel,
}

#[methods]
impl VoxelMesh {
	pub(super) fn new(_owner: &ArrayMesh) -> Self {
		Self {
			dirty: false,
			material_to_meshes_map: HashMap::new(),
			remove_list_positions: Vec::new(),
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

	pub(super) fn add_block(
		&mut self,
		block: &block::Block,
		color: Color,
		coordinate: Voxel,
		rotation: u8,
	) {
		let material = Self::get_material(color);

		if let Some((_, mesh_arrays)) = block.mesh_arrays() {
			for (i, array) in mesh_arrays.iter().enumerate() {
				let sm = Self::get_submesh(block.id, coordinate, rotation, i as u8, array);
				match self.material_to_meshes_map.entry(material.clone()) {
					Entry::Occupied(mut e) => {
						let e = e.get_mut();
						e.0.push(sm);
						e.1 = true;
					}
					Entry::Vacant(e) => {
						e.insert((vec![sm], true));
					}
				}
				self.dirty = true
			}
		}
	}

	pub(super) fn remove_block(&mut self, coordinate: Voxel) {
		self.remove_list_positions.push(coordinate);
		self.dirty = true
	}

	#[export]
	pub(super) fn generate(&mut self, owner: &ArrayMesh) {
		let mut remove_materials = Vec::new();
		for (material, (list, array_dirty)) in self.material_to_meshes_map.iter_mut() {
			for i in (0..list.len()).rev() {
				let sm = &list[i];
				if self.remove_list_positions.contains(&sm.coordinate) {
					list.swap_remove(i);
					*array_dirty = true;
				}
			}

			if list.is_empty() {
				Self::remove_surface_array(owner, material.clone().upcast());
				remove_materials.push(material.clone())
			} else if *array_dirty {
				Self::remove_surface_array(owner, material.clone().upcast());
				let mut vertices = TypedArray::<Vector3>::new();
				let mut normals = TypedArray::<Vector3>::new();

				{
					let mut len = 0;
					for sm in list.iter() {
						len += sm.array.len() as i32;
					}
					vertices.resize(len);
					normals.resize(len);
					let mut verts = vertices.write();
					let mut norms = normals.write();
					let mut i = 0;
					for sm in list.iter() {
						for point in sm.array.iter() {
							verts[i] = point.vertex;
							norms[i] = point.normal;
							i += 1;
						}
					}
				}

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
				owner.surface_set_material(index, material);

				*array_dirty = false;
			}
		}
		for material in remove_materials {
			self.material_to_meshes_map.remove(&material);
		}
		self.remove_list_positions.clear();
		self.dirty = false;
	}

	pub(super) fn dirty(&self) -> bool {
		self.dirty
	}

	fn remove_surface_array(owner: &ArrayMesh, material: Ref<Material>) {
		for i in 0..owner.get_surface_count() {
			if material == owner.surface_get_material(i).unwrap() {
				owner.surface_remove(i);
				break;
			}
		}
	}

	fn get_material(color: Color) -> Ref<SpatialMaterial> {
		let key = (
			(color.r * 255.0) as u8,
			(color.g * 255.0) as u8,
			(color.b * 255.0) as u8,
		);
		let cache = MATERIAL_CACHE.read().unwrap();
		if let Some(mat) = cache.get(&key) {
			mat.clone()
		} else {
			drop(cache);
			let mat = Ref::<SpatialMaterial, Unique>::new();
			mat.set_albedo(color);
			let mat = mat.into_shared();
			MATERIAL_CACHE.write().unwrap().insert(key, mat.clone());
			mat
		}
	}

	fn get_submesh(
		id: NonZeroU16,
		coordinate: Voxel,
		rotation: u8,
		index: u8,
		array: &Vec<block::MeshPoint>,
	) -> SubMesh {
		let key = (id, coordinate, rotation, index);
		let cache = SUBMESH_CACHE.read().unwrap();
		if let Some(sm) = cache.get(&key) {
			sm.clone()
		} else {
			drop(cache);
			let basis = block::Block::rotation_to_basis(rotation);
			let position = convert_vec(coordinate) * block::SCALE;
			let mut a = Vec::with_capacity(array.len());
			for point in array.iter() {
				a.push(block::MeshPoint {
					vertex: basis.xform(point.vertex) + position,
					normal: basis.xform(point.normal),
					uv: point.uv,
				})
			}
			let sm = SubMesh::new(a, coordinate);
			SUBMESH_CACHE.write().unwrap().insert(key, sm.clone());
			sm
		}
	}
}

impl SubMesh {
	fn new(array: Vec<block::MeshPoint>, coordinate: Voxel) -> Self {
		Self {
			array: Arc::new(array),
			coordinate,
		}
	}
}
