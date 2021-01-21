# Copyright (c) 2020 David Hoppenbrouwers
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


class_name Util


static func enum_to_str(p_enum: Dictionary, value: int) -> String:
	for k in p_enum:
		if value == p_enum[k]:
			return k
	assert(false)
	return ""


static func enum_mask_to_str(p_enum: Dictionary, value: int, separator := ", ") -> String:
	if value == 0:
		for k in p_enum:
			if p_enum[k] == 0:
				return k
		return ""
	else:
		var s = PoolStringArray()
		for k in p_enum:
			if value & p_enum[k]:
				s.append(k)
		return s.join(separator)


static func join_arrays(arrays: Array):
	var m := []
	var l := 0
	for a in arrays:
		assert(a is Array)
		l += len(a)
	m.resize(l)
	var i := 0
	for a in arrays:
		for e in a:
			m[i] = e
			i += 1
	return m


static func get_children_recursive(node: Node) -> Array:
	assert(node != null)
	var children := [node.get_children()]
	for child in children[0]:
		children.append(get_children_recursive(child))
	return join_arrays(children)


static func read_file_text(path: String) -> String:
	var file := File.new()
	var e := file.open(path, File.READ)
	var text: String
	if e == OK:
		text = file.get_as_text()
	return text


static func write_file_text(path: String, text: String, write_to_backup := false) -> bool:
	var bk_path := path if not write_to_backup else path + "~"
	var file := File.new()
	var e := file.open(bk_path, File.WRITE)
	if e == OK:
		file.store_string(text)
		file.close()
		if write_to_backup:
			e = rename_file(bk_path, path)
		return true
	else:
		return false


static func version_str_to_vector(version: String) -> Vector3:
	var a := version.split(".")
	assert(len(a) == 3)
	assert(a[0].is_valid_integer() and a[1].is_valid_integer() and a[2].is_valid_integer())
	return Vector3(int(a[0]), int(a[1]), int(a[2]))


static func version_vector_to_str(version: Vector3) -> String:
	assert(version.x == floor(version.x) and \
			version.y == floor(version.y) and \
			version.z == floor(version.z))
	return "%d.%d.%d" % [version.x, version.y, version.z]


static func iterate_dir(path: String, extension = null) -> PoolStringArray:
	assert(extension == null or extension is String)

	var dir := Directory.new()
	var e := dir.open(path)
	if e != OK:
		return PoolStringArray()

	e = dir.list_dir_begin(true)
	if e != OK:
		return PoolStringArray()

	var file_paths := PoolStringArray()
	while true:
		var file := dir.get_next()
		if file == "":
			break
		if not dir.current_is_dir():
			if extension == null or file.get_extension() == extension:
				file_paths.append(file)

	return file_paths


static func iterate_dir_recursive(path: String, extension = null) -> Array:
	assert(extension == null or extension is String)
	var file_paths: Array

	var dir := Directory.new()
	var e := dir.open(path)
	if e != OK:
		return file_paths

	e = dir.list_dir_begin(true)
	if e != OK:
		return file_paths

	file_paths = []
	while true:
		var file := dir.get_next()
		if file == "":
			break
		if dir.current_is_dir():
			var r := iterate_dir_recursive(path.plus_file(file), extension)
			if r != null:
				file_paths += r
		elif extension == null or file.get_extension() == extension:
			file_paths.append(path.plus_file(file))

	return file_paths


static func rename_file(from: String, to: String) -> int:
	var dir := Directory.new()
	return dir.rename(from, to)


static func create_dirs(path: String) -> int:
	var dir := Directory.new()
	return dir.make_dir_recursive(path)


static func free_children(node: Node, queue := false) -> void:
	if queue:
		for child in node.get_children():
			child.queue_free()
	else:
		for child in node.get_children():
			child.free()


# A non-retarded alternative to the default Rigidbody.add_force. This function
# only takes global vectors instead of the Satanic mix between a local position
# and a global orientation. The parameter order is also consistent with
# add_impulse.
static func add_force(body: RigidBody, position: Vector3, force: Vector3) -> void:
	body.add_force(force, position - body.global_transform.origin)


# Ditto
static func add_impulse(body: RigidBody, position: Vector3, impulse: Vector3) -> void:
	body.apply_impulse(position - body.global_transform.origin, impulse)


static func sum(array):
	var sum = null
	for e in array:
		sum = e if sum == null else sum + e
	return sum


static func round_res(num: float, resolution: float) -> float:
	return round(num * resolution) / resolution


static func get_aligned_basis(up: Vector3) -> Basis:
	var right := Vector3(up.y, -up.x, 0).normalized()
	var forward := right.cross(up)
	return Basis(right, up, forward)


static func split_int(s: String, delim := ",") -> PoolIntArray:
	var c := s.split(delim)
	var a := PoolIntArray()
	a.resize(len(c))
	var i := 0
	while i < len(a):
		a[i] = int(c[i])
		i += 1
	return a


static func decode_vec3i(s: String, delim := ",") -> PoolIntArray:
	var a := split_int(s, delim)
	assert(len(a) == 3)
	return a


static func decode_color(s: String, delim := ",") -> Color:
	var a := s.split_floats(delim)
	assert(len(a) == 4)
	return Color(a[0], a[1], a[2], a[3])


static func is_vec3_approx_eq(a: Vector3, b: Vector3, epsilon: float) -> bool:
	return abs(a.x - b.x) < epsilon and \
			abs(a.y - b.y) < epsilon and \
			abs(a.z - b.z) < epsilon


# This comparison function does not care about "relative" size and thus _does_
# determine 8.74134e-08 is ~= to -8.74425e-08 (unlike what the builtin seems to
# do? See is_equal_approx_ratio in core/math/math_funcs.h)
static func is_basis_approx_eq(a: Basis, b: Basis, epsilon: float) -> bool:
	return is_vec3_approx_eq(a.x, b.x, epsilon) and \
			is_vec3_approx_eq(a.y, b.y, epsilon) and \
			is_vec3_approx_eq(a.z, b.z, epsilon)


static func is_transform_approx_eq(a: Transform, b: Transform,
		epsilon_basis: float, epsilon_origin: float) -> bool:
	return is_basis_approx_eq(a.basis, b.basis, epsilon_basis) and \
			is_vec3_approx_eq(a.origin, b.origin, epsilon_origin)


static func get_script_dir(object: Object) -> String:
	return object.get_script().get_path().get_base_dir()


static func humanize_file_name(name: String) -> String:
	var ext_index := name.find_last(".")
	if ext_index < 0:
		ext_index = len(name)
	return name.substr(0, ext_index).replace("_", " ").capitalize()


static func filenamize_human_name(name: String) -> String:
	return name.replace(" ", "_").to_lower()


# Just a connect but with an assert appended
static func assert_connect(from: Object, p_signal: String, to: Object,
	method: String, arguments := []) -> void:
	var e := from.connect(p_signal, to, method, arguments)
	assert(e == OK)


const Math_SQRT12 := 0.7071067811865475244008443621048490
const epsilon := 0.01
const epsilon2 := 0.1
# TODO: make a PR to expose the built-in equivalent to GDScript
static func get_rotation_axis_angle(basis: Basis) -> Plane:
	# Basis::get_rotation_axis_angle
	var m := basis.orthonormalized()
	var det := m.determinant()
	if det < 0:
		m = m.scaled(Vector3(-1, -1, -1))

	# Basis::get_axis_angle
	var angle: float
	var x: float
	var y: float
	var z: float

	if abs(basis.y.x - basis.x.y) < epsilon and \
		abs(basis.z.x - basis.x.z) < epsilon and \
		abs(basis.z.y - basis.y.z) < epsilon:
		# singularity found
		if abs(basis.y.x + basis.x.y) < epsilon2 and \
			 abs(basis.z.x + basis.x.z) < epsilon2 and \
			 abs(basis.z.y + basis.y.z) < epsilon2 and \
			 abs(basis.x.x + basis.y.y + basis.z.z - 3) < epsilon2:
			return Plane(0, 1, 0, 0)
		angle = PI
		var xx := (basis.x.x + 1) / 2
		var yy := (basis.y.y + 1) / 2
		var zz := (basis.z.z + 1) / 2
		var xy := (basis.y.x + basis.x.y) / 4
		var xz := (basis.z.x + basis.x.z) / 4
		var yz := (basis.z.y + basis.y.z) / 4
		if xx > yy and xx > zz:
			if xx < epsilon:
				x = 0
				y = Math_SQRT12
				z = Math_SQRT12
			else:
				x = sqrt(xx)
				y = xy / x
				z = xz / x
		elif yy > zz:
			if yy < epsilon:
				x = Math_SQRT12
				y = 0
				z = Math_SQRT12
			else:
				y = sqrt(yy)
				x = xy / y
				z = yz / y
		else:
			if zz < epsilon:
				x = Math_SQRT12
				y = Math_SQRT12
				z = 0
			else:
				z = sqrt(zz)
				x = xz / z
				y = yz / z
		return Plane(x, y, z, angle)
	var s := sqrt(
		(basis.y.z - basis.z.y) * (basis.y.z - basis.z.y) + \
		(basis.z.x - basis.x.z) * (basis.z.x - basis.x.z) + \
		(basis.x.y - basis.y.x) * (basis.x.y - basis.y.x)
	)

	angle = acos((basis.x.x + basis.y.y + basis.z.z - 1) / 2)
	if angle < 0:
		s = -s
	x = (basis.z.y - basis.y.z) / s
	y = (basis.x.z - basis.z.x) / s
	z = (basis.y.x - basis.x.y) / s

	return Plane(x, y, z, angle)


# Same as above except without the redundant axis calcs
static func get_rotation_angle(basis: Basis) -> float:
	var m := basis.orthonormalized()
	var det := m.determinant()
	if det < 0:
		m = m.scaled(Vector3(-1, -1, -1))

	if abs(basis.y.x - basis.x.y) < epsilon and \
		abs(basis.z.x - basis.x.z) < epsilon and \
		abs(basis.z.y - basis.y.z) < epsilon:
		if abs(basis.y.x + basis.x.y) < epsilon2 and \
			 abs(basis.z.x + basis.x.z) < epsilon2 and \
			 abs(basis.z.y + basis.y.z) < epsilon2 and \
			 abs(basis.x.x + basis.y.y + basis.z.z - 3) < epsilon2:
			return 0.0
		return PI
	return acos((basis.x.x + basis.y.y + basis.z.z - 1) / 2)
