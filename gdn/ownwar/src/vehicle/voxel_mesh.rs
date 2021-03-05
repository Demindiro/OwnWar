use crate::util::convert_vec;
use euclid::{UnknownUnit, Vector3D};
use gdnative::api::{ArrayMesh, Material, Mesh, Resource, SpatialMaterial};
use gdnative::prelude::*;
use std::collections::{hash_map::Entry, HashMap};

type Voxel = Vector3D<u8, UnknownUnit>;

const BLOCK_SCALE: f32 = 0.25;

static mut MATERIAL_CACHE: Option<HashMap<(u8, u8, u8), Ref<SpatialMaterial>>> = None;
// TODO ask for implementation of Hash and Eq for TypedArray
// TODO we can do this more efficiently by storing an ID + Position + rotation instead
// That way we only need to hash and compare 6 bytes instead of an arbitrarily large amount of data
//static mut VECTOR3_ARRAY_CACHE: Option<HashSet<TypedArray<Vector3>>> = None;
static mut VECTOR3_ARRAY_CACHE: Option<Dictionary<Unique>> = None;

#[derive(NativeClass)]
#[inherit(ArrayMesh)]
pub(super) struct VoxelMesh {
	#[property]
	dirty: bool,
	material_to_meshes_map: HashMap<Ref<SpatialMaterial>, (Vec<SubMesh>, bool)>,
	remove_list_positions: Vec<Voxel>,
}

#[derive(Debug)]
struct SubMesh {
	array: VariantArray,
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
			self.add_block(block.assume_safe(), color, v, rotation);
		}
	}

	pub(super) fn add_block(
		&mut self,
		block: TRef<Resource>,
		color: Color,
		coordinate: Voxel,
		rotation: u8,
	) {
		let arrays = unsafe { block.call("get_mesh_arrays", &[]).try_to_array().unwrap() };
		for array in arrays.iter() {
			let array = array.try_to_array().unwrap();

			let material = Self::get_material(color);

			let basis = unsafe {
				block
					.call("rotation_to_basis", &[Variant::from_u64(rotation as u64)])
					.try_to_basis()
					.unwrap()
			};
			let position = Vector3::new(
				coordinate.x as f32,
				coordinate.y as f32,
				coordinate.z as f32,
			) * BLOCK_SCALE;
			let mut vertices = array
				.get(ArrayMesh::ARRAY_VERTEX as i32)
				.try_to_vector3_array()
				.unwrap();
			let mut normals = array
				.get(ArrayMesh::ARRAY_NORMAL as i32)
				.try_to_vector3_array()
				.unwrap();
			let mut verts = vertices.write();
			let mut norms = normals.write();
			for i in 0..verts.len() {
				verts[i] = basis.xform(verts[i]) + position;
				norms[i] = basis.xform(norms[i]);
			}
			drop(verts);
			drop(norms);
			array.set(
				ArrayMesh::ARRAY_VERTEX as i32,
				Self::get_cached_vector3_array(vertices),
			);
			array.set(
				ArrayMesh::ARRAY_NORMAL as i32,
				Self::get_cached_vector3_array(normals),
			);

			let sm = SubMesh::new(array, coordinate);
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
				let mut indices = TypedArray::<i32>::new();

				for sm in list {
					let offset = vertices.len() as i32;
					let verts = sm
						.array
						.get(Mesh::ARRAY_VERTEX as i32)
						.try_to_vector3_array()
						.unwrap()
						.clone();
					let norms = sm
						.array
						.get(Mesh::ARRAY_NORMAL as i32)
						.try_to_vector3_array()
						.unwrap()
						.clone();
					let mut inds = sm
						.array
						.get(Mesh::ARRAY_INDEX as i32)
						.try_to_int32_array()
						.unwrap()
						// I know it's CoW, but that may change in Godot 4 so let's avoid surprises
						.clone();
					for j in 0..inds.len() {
						inds.set(j, inds.get(j) + offset);
					}
					vertices.append(&verts);
					normals.append(&norms);
					indices.append(&inds);
				}

				let array = VariantArray::new();
				array.resize(ArrayMesh::ARRAY_MAX as i32);
				array.set(ArrayMesh::ARRAY_VERTEX as i32, vertices);
				array.set(ArrayMesh::ARRAY_NORMAL as i32, normals);
				array.set(ArrayMesh::ARRAY_INDEX as i32, indices);
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
		let cache = unsafe {
			if let Some(ref mut cache) = MATERIAL_CACHE {
				cache
			} else {
				MATERIAL_CACHE = Some(HashMap::new());
				MATERIAL_CACHE.as_mut().unwrap()
			}
		};
		let key = (
			(color.r * 255.0) as u8,
			(color.g * 255.0) as u8,
			(color.b * 255.0) as u8,
		);
		cache
			.entry(key)
			.or_insert_with(|| {
				let material = Ref::<SpatialMaterial, Unique>::new();
				material.set_albedo(color);
				material.into_shared()
			})
			.clone()
	}

	fn get_cached_vector3_array(array: TypedArray<Vector3>) -> TypedArray<Vector3> {
		let cache = unsafe {
			if let Some(ref mut cache) = VECTOR3_ARRAY_CACHE {
				cache
			} else {
				VECTOR3_ARRAY_CACHE = Some(Dictionary::new());
				VECTOR3_ARRAY_CACHE.as_mut().unwrap()
			}
		};
		if let Some(array) = cache
			.get(Variant::from_vector3_array(&array))
			.try_to_vector3_array()
		{
			array
		} else {
			cache.insert(
				Variant::from_vector3_array(&array),
				Variant::from_vector3_array(&array),
			);
			array
		}
	}
}

impl SubMesh {
	fn new(array: VariantArray, coordinate: Voxel) -> Self {
		Self { array, coordinate }
	}
}
