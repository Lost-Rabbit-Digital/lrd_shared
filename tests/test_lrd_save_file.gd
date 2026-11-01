## LRDSaveFile: atomic writes, the backup fallback, legacy adoption.
extends GdUnitTestSuite

var _dir: String


func before_test() -> void:
	_dir = "user://test_lrd_save/%d_%d/" % [Time.get_ticks_usec(), randi()]
	DirAccess.make_dir_recursive_absolute(_dir)


func after_test() -> void:
	_rm_tree(_dir)


func test_a_write_round_trips() -> void:
	var path: String = _dir + "save.json"
	assert_int(LRDSaveFile.write_json(path, {"coins": 12, "name": "owl"})).is_equal(OK)
	assert_dict(LRDSaveFile.read_json(path)).is_equal({"coins": 12.0, "name": "owl"})
	assert_bool(LRDSaveFile.last_read_used_backup).is_false()


func test_a_second_write_keeps_the_first_as_backup() -> void:
	var path: String = _dir + "save.json"
	LRDSaveFile.write_json(path, {"v": 1})
	LRDSaveFile.write_json(path, {"v": 2})
	assert_bool(FileAccess.file_exists(path + LRDSaveFile.BAK_SUFFIX)).is_true()
	assert_dict(_parse_file(path + LRDSaveFile.BAK_SUFFIX)).is_equal({"v": 1.0})
	(
		assert_bool(FileAccess.file_exists(path + LRDSaveFile.TMP_SUFFIX))
		. override_failure_message("no temp file is left behind")
		. is_false()
	)


func test_a_corrupt_save_falls_back_to_the_backup() -> void:
	var path: String = _dir + "save.json"
	LRDSaveFile.write_json(path, {"v": 1})
	LRDSaveFile.write_json(path, {"v": 2})
	_write_raw(path, '{"v": 2, "trunc')  # a crash mid-write, the old way
	assert_dict(LRDSaveFile.read_json(path)).is_equal({"v": 1.0})
	assert_bool(LRDSaveFile.last_read_used_backup).is_true()


func test_an_empty_save_falls_back_to_the_backup() -> void:
	var path: String = _dir + "save.json"
	LRDSaveFile.write_json(path, {"v": 1})
	LRDSaveFile.write_json(path, {"v": 2})
	_write_raw(path, "")
	assert_dict(LRDSaveFile.read_json(path)).is_equal({"v": 1.0})


func test_a_missing_save_with_only_a_backup_still_loads() -> void:
	var path: String = _dir + "save.json"
	LRDSaveFile.write_json(path, {"v": 1})
	LRDSaveFile.write_json(path, {"v": 2})
	DirAccess.remove_absolute(path)  # a crash between the two renames
	assert_dict(LRDSaveFile.read_json(path)).is_equal({"v": 1.0})
	assert_bool(LRDSaveFile.exists(path)).is_true()


func test_nothing_usable_reads_as_null_or_the_default() -> void:
	var path: String = _dir + "none.json"
	assert_that(LRDSaveFile.read_json(path)).is_null()
	assert_dict(LRDSaveFile.read_json_or(path, {"fresh": true})).is_equal({"fresh": true})


func test_a_stray_temp_file_is_not_mistaken_for_the_save() -> void:
	var path: String = _dir + "save.json"
	LRDSaveFile.write_json(path, {"v": 1})
	_write_raw(path + LRDSaveFile.TMP_SUFFIX, '{"v": 99}')
	assert_dict(LRDSaveFile.read_json(path)).is_equal({"v": 1.0})
	LRDSaveFile.write_json(path, {"v": 2})
	assert_dict(LRDSaveFile.read_json(path)).is_equal({"v": 2.0})


func test_a_write_that_cannot_open_leaves_the_save_alone() -> void:
	var path: String = _dir + "save.json"
	LRDSaveFile.write_json(path, {"v": 1})
	# A directory where the temp file should go makes the open fail.
	DirAccess.make_dir_absolute(path + LRDSaveFile.TMP_SUFFIX)
	assert_int(LRDSaveFile.write_json(path, {"v": 2})).is_not_equal(OK)
	assert_dict(LRDSaveFile.read_json(path)).is_equal({"v": 1.0})
	DirAccess.remove_absolute(path + LRDSaveFile.TMP_SUFFIX)


func test_writing_creates_missing_folders() -> void:
	var path: String = _dir + "a/b/save.json"
	assert_int(LRDSaveFile.write_json(path, [1, 2])).is_equal(OK)
	assert_array(LRDSaveFile.read_json(path)).is_equal([1.0, 2.0])


func test_remove_clears_the_save_its_backup_and_temp() -> void:
	var path: String = _dir + "save.json"
	LRDSaveFile.write_json(path, {"v": 1})
	LRDSaveFile.write_json(path, {"v": 2})
	_write_raw(path + LRDSaveFile.TMP_SUFFIX, "{}")
	LRDSaveFile.remove(path)
	assert_bool(LRDSaveFile.exists(path)).is_false()
	assert_bool(FileAccess.file_exists(path + LRDSaveFile.TMP_SUFFIX)).is_false()


func test_a_legacy_file_is_adopted_once_and_only_after_the_copy_lands() -> void:
	var legacy: String = _dir + "lore.json"
	var slot_file: String = _dir + "slot_0/lore.json"
	_write_raw(legacy, '{"found": 3}')
	assert_bool(LRDSaveFile.migrate_legacy_file(legacy, slot_file)).is_true()
	assert_dict(LRDSaveFile.read_json(slot_file)).is_equal({"found": 3.0})
	assert_bool(FileAccess.file_exists(legacy)).is_false()
	_write_raw(legacy, '{"found": 9}')
	(
		assert_bool(LRDSaveFile.migrate_legacy_file(legacy, slot_file))
		. override_failure_message("a slot that already has the file is never overwritten")
		. is_false()
	)


func test_a_corrupt_legacy_file_is_left_where_it_is() -> void:
	var legacy: String = _dir + "lore.json"
	_write_raw(legacy, "not json")
	assert_bool(LRDSaveFile.migrate_legacy_file(legacy, _dir + "slot_0/lore.json")).is_false()
	assert_bool(FileAccess.file_exists(legacy)).is_true()


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _parse_file(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _rm_tree(dir: String) -> void:
	var access := DirAccess.open(dir)
	if access == null:
		return
	for sub in access.get_directories():
		_rm_tree(dir + sub + "/")
	for file in access.get_files():
		access.remove(file)
	DirAccess.remove_absolute(dir)
