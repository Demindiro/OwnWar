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
