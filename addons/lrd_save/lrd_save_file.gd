## Crash-safe JSON save files: atomic writes and a backup to fall back on.
##
## A plain `FileAccess.open(path, WRITE)` truncates the save first, so a crash,
## a full disk or a power cut mid-write leaves the player with an empty or half
## file. Here a write goes to `<path>.tmp`, is read back and parsed, and only then
## replaces the save, keeping the previous one as `<path>.bak`. A read that finds
## the save missing or corrupt falls back to the backup.
##
## Combines practice that lived in one game each: atomic writes (Starbrew
## Station's UnifiedSaveService), a backup fallback (Bikini Heaven) and adopting
## pre-slot legacy files (Fragile Frontier's JsonFileUtils).
##
## JSON has one number type, so every number reads back as a [float]: cast with
## `int()` where a whole number is meant.
class_name LRDSaveFile
extends RefCounted

const TMP_SUFFIX: String = ".tmp"
const BAK_SUFFIX: String = ".bak"

## True when the most recent [method read_json] had to use the backup.
static var last_read_used_backup: bool = false


## Writes [param data] as JSON to [param path] atomically. Returns OK, or the
## error that stopped it; on any failure the existing save is untouched.
static func write_json(path: String, data: Variant, indent: String = "\t") -> Error:
	var text: String = JSON.stringify(data, indent)
	var dir: String = path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		var made: Error = DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return made
	var tmp: String = path + TMP_SUFFIX
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(tmp)
		return write_error
	# Read it back before trusting it: a short write is caught here, not on load.
	if _parse(FileAccess.get_file_as_string(tmp)) == null and text != "null":
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CORRUPT
	var bak: String = path + BAK_SUFFIX
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		var backed_up: Error = DirAccess.rename_absolute(path, bak)
		if backed_up != OK:
			DirAccess.remove_absolute(tmp)
			return backed_up
	return DirAccess.rename_absolute(tmp, path)


## Reads and parses [param path], falling back to its backup when the save is
## missing or doesn't parse. Returns null when neither is usable.
static func read_json(path: String) -> Variant:
	last_read_used_backup = false
	var data: Variant = _read(path)
	if data != null:
		return data
	var backup: Variant = _read(path + BAK_SUFFIX)
	if backup != null:
		last_read_used_backup = true
		push_warning("LRDSaveFile: '%s' was missing or corrupt; loaded its backup" % path)
	return backup


## [method read_json], or [param default_value] when nothing usable exists.
static func read_json_or(path: String, default_value: Variant) -> Variant:
	var data: Variant = read_json(path)
	return default_value if data == null else data


## Whether a save (or its backup) exists at [param path].
static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + BAK_SUFFIX)


## Removes a save, its backup and any stray temp file.
static func remove(path: String) -> void:
	for candidate: String in [path, path + BAK_SUFFIX, path + TMP_SUFFIX]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


## Moves a pre-slot, install-wide file into its per-slot home, once.
##
## No-op when [param new_path] already exists (done) or [param legacy_path]
## doesn't (nothing to move). The legacy file is removed only after the new one
## is confirmed on disk, so a failed write can never lose it. Returns true when
## a migration happened.
static func migrate_legacy_file(legacy_path: String, new_path: String) -> bool:
	if legacy_path == new_path or exists(new_path) or not FileAccess.file_exists(legacy_path):
		return false
	var legacy: Variant = _read(legacy_path)
	if legacy == null:
		return false
	if write_json(new_path, legacy) != OK or not FileAccess.file_exists(new_path):
		return false
	DirAccess.remove_absolute(legacy_path)
	return true


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return _parse(FileAccess.get_file_as_string(path))


static func _parse(text: String) -> Variant:
	if text.strip_edges() == "":
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data
