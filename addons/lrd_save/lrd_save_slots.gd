## Save slots: every per-save file routed through the active slot.
##
## A fixed `user://foo.json` is one file for the whole install, so a new game
## silently inherits the previous playthrough's state. Fragile Frontier shipped
## that twice (found lore and broken walls carried into fresh saves). Route
## every per-save file through [method path] instead.
##
## Generalised from Fragile Frontier's SaveSlotManager:
## - Lazy initialisation from every accessor, so an autoload that asks before
##   this one's owner has run `_ready()` still gets the right slot (playbook
##   GDT-32). The bug this prevents loaded every player's save from slot 0.
## - Slot metadata is a cache, reconciled with the files on disk on load.
## - [method new_game] clears the slot's save files and its derived files.
##
## Writes go through [LRDSaveFile], so they are atomic and keep a backup.
##
## Usage: own one instance in your save autoload.
##   var slots := LRDSaveSlots.new(3, PackedStringArray(["progress.json"]))
##   var path: String = slots.path("progress.json")
class_name LRDSaveSlots
extends RefCounted

signal slot_changed(slot: int)
signal metadata_changed(slot: int, metadata: Dictionary)

## Where slot folders live: `<save_dir>slot_<n>/<file>`. Under a test runner it
## is redirected like every other path; see [method LRDSaveFile.resolve_path].
var save_dir: String = "user://saves/"
## Number of slots.
var slot_count: int = 3
## Files whose presence means "this slot holds a save".
var save_files: PackedStringArray = PackedStringArray()
## Per-save files that aren't the save itself (unlocks, found lore...). Cleared
## by [method new_game] and [method delete_slot], but their presence alone
## doesn't make a slot non-empty.
var derived_files: PackedStringArray = PackedStringArray()

var _active: int = 0
var _metadata: Dictionary = {}  # slot (int) -> Dictionary
var _initialized: bool = false


func _init(
	slots: int = 3, files: PackedStringArray = PackedStringArray(), derived: PackedStringArray = PackedStringArray()
) -> void:
	slot_count = maxi(slots, 1)
	save_files = files
	derived_files = derived


## Loads the active slot and metadata if that hasn't happened. Idempotent; every
## public accessor calls it.
func ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	DirAccess.make_dir_recursive_absolute(_save_dir())
	_active = _load_active()
	var stored: Variant = LRDSaveFile.read_json(_metadata_path())
	_metadata = {}
	if stored is Dictionary:
		for key: Variant in stored:
			if str(key).is_valid_int() and stored[key] is Dictionary:
				_metadata[int(str(key))] = stored[key]
	reconcile_with_disk()


## The path of [param file] in [param slot] (the active slot by default), already
## redirected under a test runner, so it is safe to open directly.
func path(file: String, slot: int = -1) -> String:
	ensure_initialized()
	var index: int = _active if slot < 0 else slot
	return "%sslot_%d/%s" % [_save_dir(), index, file]


func active_slot() -> int:
	ensure_initialized()
	return _active


## Switches the active slot. Listeners reload on [signal slot_changed] rather
## than writing the outgoing slot's state into the incoming one.
func set_active_slot(slot: int) -> void:
	ensure_initialized()
	if slot < 0 or slot >= slot_count or slot == _active:
		return
	_active = slot
	LRDSaveFile.write_json(_active_path(), {"active": slot})
	slot_changed.emit(slot)


func has_save(slot: int) -> bool:
	ensure_initialized()
	for file in save_files:
		if LRDSaveFile.exists(path(file, slot)):
			return true
	return false


func has_any_save() -> bool:
	for slot in slot_count:
		if has_save(slot):
			return true
	return false


func metadata(slot: int) -> Dictionary:
	ensure_initialized()
	return (_metadata.get(slot, {}) as Dictionary).duplicate()


## Merges [param values] into a slot's metadata (shown on a slot picker) and
## stamps when it was last played.
func update_metadata(slot: int, values: Dictionary) -> void:
	ensure_initialized()
	var entry: Dictionary = _metadata.get(slot, {})
	entry.merge(values, true)
	entry["last_played_unix"] = int(Time.get_unix_time_from_system())
	_metadata[slot] = entry
	_save_metadata()
	metadata_changed.emit(slot, entry.duplicate())


## Drops metadata for any slot whose save files are gone (deleted out of band,
## a cloud sync, a manual clean), so the picker never advertises a missing save.
## Returns true when something was repaired.
func reconcile_with_disk() -> bool:
	var changed: bool = false
	for slot: int in _metadata.keys():
		if not _metadata[slot].is_empty() and not has_save(slot):
			_metadata.erase(slot)
			changed = true
	if changed:
		_save_metadata()
	return changed


## Removes a slot's save files, derived files and metadata.
func delete_slot(slot: int) -> void:
	ensure_initialized()
	for file in save_files + derived_files:
		LRDSaveFile.remove(path(file, slot))
	_metadata.erase(slot)
	_save_metadata()
	metadata_changed.emit(slot, {})


## Starts a fresh game in [param slot]: clears everything it held, then makes it
## active. The game then writes its starting state.
func new_game(slot: int) -> void:
	delete_slot(slot)
	if slot == _active:
		slot_changed.emit(slot)
	else:
		set_active_slot(slot)


## Moves an install-wide file from before slots existed into the active slot,
## once. See [method LRDSaveFile.migrate_legacy_file].
func adopt_legacy_file(legacy_path: String, file: String) -> bool:
	return LRDSaveFile.migrate_legacy_file(legacy_path, path(file))


func _load_active() -> int:
	var stored: Variant = LRDSaveFile.read_json(_active_path())
	var slot: int = int((stored as Dictionary).get("active", 0)) if stored is Dictionary else 0
	return slot if slot >= 0 and slot < slot_count else 0


func _save_metadata() -> void:
	var out: Dictionary = {}
	for slot: int in _metadata:
		out[str(slot)] = _metadata[slot]
	LRDSaveFile.write_json(_metadata_path(), out)


func _metadata_path() -> String:
	return _save_dir() + "slot_metadata.json"


func _active_path() -> String:
	return _save_dir() + "active_slot.json"


# The save folder actually used: under a test runner, never the player's own.
func _save_dir() -> String:
	return LRDSaveFile.resolve_path(save_dir)
