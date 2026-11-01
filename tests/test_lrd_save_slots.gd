## LRDSaveSlots: per-slot routing, lazy init, metadata as a cache.
extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	_dir = "user://test_lrd_slots/%d_%d/" % [Time.get_ticks_usec(), randi()]


func after_test() -> void:
	_rm_tree(_dir)


func _slots(count: int = 3) -> LRDSaveSlots:
	var slots := LRDSaveSlots.new(count, PackedStringArray(["progress.json"]), PackedStringArray(["lore.json"]))
	slots.save_dir = _dir
	return slots


func test_paths_are_per_slot() -> void:
	var slots := _slots()
	assert_str(slots.path("progress.json")).is_equal(_dir + "slot_0/progress.json")
	assert_str(slots.path("progress.json", 2)).is_equal(_dir + "slot_2/progress.json")


func test_the_active_slot_survives_a_restart() -> void:
	_slots().set_active_slot(2)
	var restarted := _slots()
	assert_int(restarted.active_slot()).is_equal(2)
	assert_str(restarted.path("progress.json")).is_equal(_dir + "slot_2/progress.json")


func test_the_first_accessor_initialises_even_before_anyone_else_did() -> void:
	_slots().set_active_slot(1)
	# A fresh instance, no explicit ensure_initialized(): the first path() asked
	# must already resolve the saved slot, not slot 0.
	assert_str(_slots().path("progress.json")).is_equal(_dir + "slot_1/progress.json")


func test_an_out_of_range_slot_is_ignored() -> void:
	var slots := _slots()
	slots.set_active_slot(7)
	assert_int(slots.active_slot()).is_equal(0)


func test_switching_slots_is_announced() -> void:
	var slots := _slots()
	var seen: Array[int] = []
	slots.slot_changed.connect(func(slot: int) -> void: seen.append(slot))
	slots.set_active_slot(1)
	slots.set_active_slot(1)
	assert_array(seen).is_equal([1])


func test_a_slot_has_a_save_only_when_a_save_file_exists() -> void:
	var slots := _slots()
	assert_bool(slots.has_save(0)).is_false()
	LRDSaveFile.write_json(slots.path("lore.json"), {"found": 1})
	assert_bool(slots.has_save(0)).override_failure_message("derived files alone are not a save").is_false()
	LRDSaveFile.write_json(slots.path("progress.json"), {"coins": 1})
	assert_bool(slots.has_save(0)).is_true()
	assert_bool(slots.has_any_save()).is_true()


func test_metadata_for_a_vanished_save_is_dropped_on_load() -> void:
	var slots := _slots()
	LRDSaveFile.write_json(slots.path("progress.json"), {"coins": 1})
	slots.update_metadata(0, {"day": 4})
	assert_int(int(slots.metadata(0).get("day", 0))).is_equal(4)
	LRDSaveFile.remove(slots.path("progress.json"))  # deleted out of band
	(
		assert_dict(_slots().metadata(0))
		. override_failure_message("the picker must not advertise a save that is gone")
		. is_empty()
	)


func test_metadata_merges_and_stamps_last_played() -> void:
	var slots := _slots()
	LRDSaveFile.write_json(slots.path("progress.json"), {})
	slots.update_metadata(0, {"day": 1, "coins": 5})
	slots.update_metadata(0, {"day": 2})
	var meta := slots.metadata(0)
	assert_int(int(meta["day"])).is_equal(2)
	assert_int(int(meta["coins"])).is_equal(5)
	assert_bool(meta.has("last_played_unix")).is_true()


func test_new_game_clears_the_save_and_derived_files() -> void:
	var slots := _slots()
	LRDSaveFile.write_json(slots.path("progress.json", 1), {"coins": 99})
	LRDSaveFile.write_json(slots.path("lore.json", 1), {"found": 3})
	slots.update_metadata(1, {"day": 9})
	slots.new_game(1)
	assert_int(slots.active_slot()).is_equal(1)
	assert_bool(LRDSaveFile.exists(slots.path("progress.json"))).is_false()
	(
		assert_bool(LRDSaveFile.exists(slots.path("lore.json")))
		. override_failure_message("a new game must not inherit the last playthrough's lore")
		. is_false()
	)
	assert_dict(slots.metadata(1)).is_empty()


func test_new_game_in_the_active_slot_still_tells_listeners_to_reload() -> void:
	var slots := _slots()
	var seen: Array[int] = []
	slots.slot_changed.connect(func(slot: int) -> void: seen.append(slot))
	slots.new_game(0)
	assert_array(seen).is_equal([0])


func test_delete_leaves_other_slots_alone() -> void:
	var slots := _slots()
	LRDSaveFile.write_json(slots.path("progress.json", 0), {"a": 1})
	LRDSaveFile.write_json(slots.path("progress.json", 1), {"b": 1})
	slots.delete_slot(0)
	assert_bool(slots.has_save(0)).is_false()
	assert_bool(slots.has_save(1)).is_true()


func test_a_legacy_install_wide_file_is_adopted_by_the_active_slot() -> void:
	var slots := _slots()
	slots.set_active_slot(2)
	var legacy: String = _dir + "lore_legacy.json"
	LRDSaveFile.write_json(legacy, {"found": 2})
	assert_bool(slots.adopt_legacy_file(legacy, "lore.json")).is_true()
	assert_dict(LRDSaveFile.read_json(slots.path("lore.json", 2))).is_equal({"found": 2.0})


func _rm_tree(dir: String) -> void:
	var access := DirAccess.open(dir)
	if access == null:
		return
	for sub in access.get_directories():
		_rm_tree(dir + sub + "/")
	for file in access.get_files():
		access.remove(file)
	DirAccess.remove_absolute(dir)
