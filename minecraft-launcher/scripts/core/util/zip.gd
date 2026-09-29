class_name ZipArchive
extends RefCounted
## Минимальный читатель ZIP-архивов (нужен для .mrpack и JRE-архивов).
## Работает через FileAccess + PackedByteArray.decompress_dynamic(), поэтому
## не зависит от наличия ZIPReader в сборке движка.

const SIG_EOCD := 0x06054b50
const SIG_CENTRAL := 0x02014b50
const SIG_LOCAL := 0x04034b50

var _file: FileAccess = null
var _entries := {}

func open(path: String) -> bool:
	close()
	_file = FileAccess.open(path, FileAccess.READ)
	if _file == null:
		return false
	_file.big_endian = false
	return _load_central_directory()

func close() -> void:
	if _file != null:
		_file.close()
		_file = null
	_entries.clear()

func is_open() -> bool:
	return _file != null

func names() -> Array:
	return _entries.keys()

func has(name: String) -> bool:
	return _entries.has(name)

func entry_count() -> int:
	return _entries.size()

func uncompressed_size(name: String) -> int:
	if not _entries.has(name):
		return 0
	return int(_entries[name]["size"])

func read(name: String) -> PackedByteArray:
	if not _entries.has(name):
		return PackedByteArray()
	var e: Dictionary = _entries[name]
	var offset := int(e["offset"])
	_file.seek(offset)
	var head: PackedByteArray = _file.get_buffer(30)
	if head.size() < 30 or _u32(head, 0) != SIG_LOCAL:
		return PackedByteArray()
	var name_len := _u16(head, 26)
	var extra_len := _u16(head, 28)
	_file.seek(offset + 30 + name_len + extra_len)
	var comp: PackedByteArray = _file.get_buffer(int(e["comp_size"]))
	if int(e["method"]) == 0:
		return comp
	return _inflate(comp, int(e["size"]))

## Распаковывает архив (или только файлы с заданным префиксом) в каталог.
## strip_prefix = true убирает префикс из пути назначения (нужно для overrides/).
func extract_all(dest: String, only_prefix := "", strip_prefix := false) -> bool:
	var abs := ProjectSettings.globalize_path(dest)
	for key in _entries:
		var name := String(key)
		if only_prefix != "" and not name.begins_with(only_prefix):
			continue
		var rel := name
		if strip_prefix and only_prefix != "":
			rel = name.substr(only_prefix.length())
		if rel == "" or rel == "/":
			continue
		var out_path := abs.path_join(rel)
		if name.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(out_path)
			continue
		var data := read(name)
		DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f == null:
			push_warning("Aurora: не удалось распаковать %s" % name)
			continue
		f.store_buffer(data)
		f.close()
	return true

# ------------------------------------------------------------- внутреннее ----
func _load_central_directory() -> bool:
	var length := _file.get_length()
	if length < 22:
		return false
	var scan := mini(length, 66000)
	_file.seek(length - scan)
	var tail: PackedByteArray = _file.get_buffer(scan)
	if tail.size() < 22:
		return false
	var eocd := -1
	for i in range(tail.size() - 22, -1, -1):
		if tail[i] == 0x50 and tail[i + 1] == 0x4b and tail[i + 2] == 0x05 and tail[i + 3] == 0x06:
			eocd = i
			break
	if eocd < 0:
		push_warning("Aurora: ZIP без центрального каталога")
		return false
	var cd_size := _u32(tail, eocd + 16)
	var cd_offset := _u32(tail, eocd + 20)
	var pos := cd_offset
	if cd_size <= 0 or pos >= length:
		pos = length - scan + eocd - cd_size
	if pos < 0:
		pos = 0
	_file.seek(pos)
	var remaining := cd_size
	while remaining >= 46:
		var head: PackedByteArray = _file.get_buffer(46)
		if head.size() < 46 or _u32(head, 0) != SIG_CENTRAL:
			break
		var method := _u16(head, 10)
		var comp_size := _u32(head, 20)
		var size := _u32(head, 24)
		var name_len := _u16(head, 28)
		var extra_len := _u16(head, 30)
		var comment_len := _u16(head, 32)
		var local_offset := _u32(head, 42)
		var name_bytes: PackedByteArray = _file.get_buffer(name_len)
		_file.seek(_file.get_position() + extra_len + comment_len)
		var name := name_bytes.get_string_from_utf8()
		_entries[name] = {"offset": local_offset, "comp_size": comp_size, "size": size, "method": method}
		remaining -= 46 + name_len + extra_len + comment_len
	return _entries.size() > 0

func _inflate(data: PackedByteArray, expected: int) -> PackedByteArray:
	var hint := maxi(expected, data.size() * 4)
	hint = maxi(hint, 1 << 16)
	var attempts := 0
	while attempts < 8:
		var out: PackedByteArray = data.decompress_dynamic(hint, COMPRESSION_DEFLATE)
		if out.size() > 0:
			return out
		hint *= 4
		attempts += 1
	push_warning("Aurora: не удалось распаковать deflate-поток")
	return PackedByteArray()

func _u16(buf: PackedByteArray, offset: int) -> int:
	if offset + 1 >= buf.size():
		return 0
	return int(buf[offset]) | (int(buf[offset + 1]) << 8)

func _u32(buf: PackedByteArray, offset: int) -> int:
	if offset + 3 >= buf.size():
		return 0
	return int(buf[offset]) | (int(buf[offset + 1]) << 8) | (int(buf[offset + 2]) << 16) | (int(buf[offset + 3]) << 24)
