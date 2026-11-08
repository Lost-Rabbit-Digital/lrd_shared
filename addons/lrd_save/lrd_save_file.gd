## Crash-safe JSON save files: atomic writes and a backup to fall back on.
##
## A plain `FileAccess.open(path, WRITE)` truncates the save first, so a crash,
## a full disk or a power cut mid-write leaves the player with an empty or half
## file. Here a write goes to `<path>.tmp`, is read back and parsed, the current
## save is copied to `<path>.bak`, and only then is the temp file renamed over
## the save. The save itself is never moved aside, so at every step the save or
## its backup holds a complete copy. A read that finds the save missing or
## corrupt falls back to the backup.
##
## Under a test runner or harness, `user://` paths are redirected the way
## `LRDUserPaths` (from lrd_run_log) decides, when that add-on is in the
## project; see [method resolve_path].
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

## The steps of [method write_json], as passed to the test seam [member fault].
const STEP_OPEN_TMP: StringName = &"open_tmp"
const STEP_WRITE_TMP: StringName = &"write_tmp"
const STEP_VERIFY_TMP: StringName = &"verify_tmp"
const STEP_BACKUP: StringName = &"backup"
const STEP_REPLACE: StringName = &"replace"

## True when the most recent [method read_json] had to use the backup.
static var last_read_used_backup: bool = false

## The global class [method resolve_path] defers to. A test hook: games leave it.
static var user_paths_class: StringName = &"LRDUserPaths"

## Test seam for [method write_json]. When valid, it is called as
## `fault.call(step, path)` just before each step (the `STEP_*` constants), and
## a non-OK return makes that step fail with that error. It may touch the disk
## first, to stage a half-finished step. Never set it in a game.
static var fault: Callable = Callable()

# The LRDUserPaths script, once looked up (null when the add-on is absent).
static var _user_paths: Script = null
static var _user_paths_looked_up: bool = false


## The path actually used for [param path]. Every public function here resolves
## its paths through this, and so does [LRDSaveSlots].
##
## When lrd_run_log's `LRDUserPaths` is in the project, its `resolve()` decides:
## under a test runner or harness a `user://` path moves under its test root, so
## tests and bots never touch the player's saves. It is found by class name at
## runtime, so lrd_save works without lrd_run_log; then paths are used as given.
## Resolving twice is harmless.
static func resolve_path(path: String) -> String:
	var user_paths: Script = _user_paths_script()
	if user_paths == null:
		return path
	return str(user_paths.call(&"resolve", path))


## Test hook: forget the cached `LRDUserPaths` lookup.
static func reset_path_resolution_for_tests() -> void:
	_user_paths = null
	_user_paths_looked_up = false


## Writes [param data] as JSON to [param path] atomically. Returns OK, or the
## error that stopped it.
##
## On any failure the save at [param path] keeps its previous contents (or stays
## absent) and no temp file is left behind. The backup is refreshed from the
## previous save just before the swap, and only when that save parses, so a
## corrupt save never replaces a good backup.
##
## Not covered: after the file is closed the OS may still hold the data in its
## cache (Godot exposes no fsync), so a power cut right after a write can lose
## that write. The previous save or its backup then remains.
static func write_json(path: String, data: Variant, indent: String = "\t") -> Error:
	path = resolve_path(path)
	var text: String = JSON.stringify(data, indent)
	var dir: String = path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		var made: Error = DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return made
	var tmp: String = path + TMP_SUFFIX
	var file: FileAccess = null
	var opened: Error = _step(STEP_OPEN_TMP, path)
	if opened == OK:
		file = FileAccess.open(tmp, FileAccess.WRITE)
		if file == null:
			opened = FileAccess.get_open_error()
			opened = FAILED if opened == OK else opened
	if opened != OK:
		_discard(tmp)
		return opened
	var written: Error = _step(STEP_WRITE_TMP, path)
	if written == OK and not file.store_string(text):
		written = ERR_FILE_CANT_WRITE
	file.flush()
	if written == OK:
		written = file.get_error()
	file.close()
	if written != OK:
		_discard(tmp)
		return written
	# Read it back before trusting it: a short write is caught here, not on load.
	var verified: Error = _step(STEP_VERIFY_TMP, path)
	if verified == OK and _parse(FileAccess.get_file_as_string(tmp)) == null and text != "null":
		verified = ERR_FILE_CORRUPT
	if verified != OK:
		_discard(tmp)
		return verified
	# Copy, never move, the current save to the backup: the save stays where it
	# is until the rename below replaces it in one step.
	var bak: String = path + BAK_SUFFIX
	var backed_up: bool = false
	if _read(path) != null:
		var copied: Error = _step(STEP_BACKUP, path)
		if copied == OK:
			copied = DirAccess.copy_absolute(path, bak)
		if copied != OK:
			_discard(tmp)
			return copied
		backed_up = true
	var replaced: Error = _step(STEP_REPLACE, path)
	if replaced == OK:
		replaced = DirAccess.rename_absolute(tmp, path)
	if replaced != OK:
		# A rename that removed the save before failing (it is remove-then-move
		# on some platforms) must not leave it gone: restore the copy just taken.
		if backed_up and not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path):
			DirAccess.copy_absolute(bak, path)
		_discard(tmp)
	return replaced


## Reads and parses [param path], falling back to its backup when the save is
## missing or doesn't parse. Returns null when neither is usable.
static func read_json(path: String) -> Variant:
	path = resolve_path(path)
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
	path = resolve_path(path)
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + BAK_SUFFIX)


## Removes a save, its backup and any stray temp file.
static func remove(path: String) -> void:
	path = resolve_path(path)
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
	legacy_path = resolve_path(legacy_path)
	new_path = resolve_path(new_path)
	if legacy_path == new_path or exists(new_path) or not FileAccess.file_exists(legacy_path):
		return false
	var legacy: Variant = _read(legacy_path)
	if legacy == null:
		return false
	if write_json(new_path, legacy) != OK or not FileAccess.file_exists(new_path):
		return false
	DirAccess.remove_absolute(legacy_path)
	return true


static func _step(step: StringName, path: String) -> Error:
	if not fault.is_valid():
		return OK
	return fault.call(step, path)


static func _discard(tmp: String) -> void:
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)


static func _user_paths_script() -> Script:
	if _user_paths_looked_up:
		return _user_paths
	_user_paths_looked_up = true
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(str(entry.get("class", ""))) != user_paths_class:
			continue
		var script: Script = load(str(entry.get("path", ""))) as Script
		if script == null:
			break
		for method: Dictionary in script.get_script_method_list():
			if method.get("name", "") == "resolve":
				_user_paths = script
		break
	return _user_paths


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
