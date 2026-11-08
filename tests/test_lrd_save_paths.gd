## lrd_save under a test runner: saves land under LRDUserPaths' test root, never
## in the player's real `user://saves`, and lrd_save still works without
## lrd_run_log.
extends GdUnitTestSuite

var _file: String
var _real_dir: String = "user://saves/"
var _test_dir: String = LRDUserPaths.TEST_ROOT + "saves/"
var _real_markers_before: Dictionary


func before_test() -> void:
	_file = "redirect_%d_%d.json" % [Time.get_ticks_usec(), randi()]
	_real_markers_before = _snapshot(_real_dir)
	_clear_test_root_slot_state()


func after_test() -> void:
	LRDSaveFile.user_paths_class = &"LRDUserPaths"
	LRDSaveFile.reset_path_resolution_for_tests()
	LRDUserPaths.reset_for_tests()
	for slot in 3:
		LRDSaveFile.remove(_test_dir + "slot_%d/%s" % [slot, _file])
	LRDSaveFile.remove(LRDUserPaths.TEST_ROOT + _file)
	_clear_test_root_slot_state()


func test_slots_save_under_the_test_root_in_a_test_run() -> void:
	var slots := LRDSaveSlots.new(3, PackedStringArray([_file]))
	var path: String = slots.path(_file)
	assert_str(path).is_equal(_test_dir + "slot_0/" + _file)
	assert_int(LRDSaveFile.write_json(path, {"coins": 3})).is_equal(OK)
	slots.update_metadata(0, {"day": 2})
	slots.set_active_slot(1)
	assert_bool(FileAccess.file_exists(_test_dir + "slot_0/" + _file)).is_true()
	assert_bool(slots.has_save(0)).is_true()
	(
		assert_bool(FileAccess.file_exists(_real_dir + "slot_0/" + _file))
		. override_failure_message("a test run wrote the player's real user://saves")
		. is_false()
	)
	(
		assert_dict(_snapshot(_real_dir))
		. override_failure_message("a test run touched the player's slot metadata or active slot")
		. is_equal(_real_markers_before)
	)


func test_a_bare_user_path_is_redirected_too() -> void:
	assert_int(LRDSaveFile.write_json("user://" + _file, {"v": 1})).is_equal(OK)
	assert_bool(FileAccess.file_exists(LRDUserPaths.TEST_ROOT + _file)).is_true()
	assert_bool(FileAccess.file_exists("user://" + _file)).is_false()
	assert_dict(LRDSaveFile.read_json("user://" + _file)).is_equal({"v": 1.0})
	assert_bool(LRDSaveFile.exists("user://" + _file)).is_true()
	LRDSaveFile.remove("user://" + _file)
	assert_bool(FileAccess.file_exists(LRDUserPaths.TEST_ROOT + _file)).is_false()


## Each add-on must work alone: without LRDUserPaths in the project, paths are
## used as given rather than failing.
func test_without_lrd_run_log_paths_are_used_as_given() -> void:
	LRDSaveFile.user_paths_class = &"NoSuchUserPathsClass"
	LRDSaveFile.reset_path_resolution_for_tests()
	assert_str(LRDSaveFile.resolve_path("user://saves/slot_0/a.json")).is_equal("user://saves/slot_0/a.json")


# The redirected active slot and metadata persist between runs; start clean.
func _clear_test_root_slot_state() -> void:
	for name: String in ["active_slot.json", "slot_metadata.json"]:
		LRDSaveFile.remove(_test_dir + name)


# The real save folder's top-level files and their modified times.
func _snapshot(dir: String) -> Dictionary:
	var out: Dictionary = {}
	for name: String in ["active_slot.json", "slot_metadata.json"]:
		for suffix: String in ["", LRDSaveFile.BAK_SUFFIX]:
			var path: String = dir + name + suffix
			out[path] = FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else -1
	return out
