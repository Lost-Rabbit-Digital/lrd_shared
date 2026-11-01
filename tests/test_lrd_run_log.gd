extends GdUnitTestSuite

const DIR: String = "user://test_lrd_log/"

var log: LRDRunLog


class FakeAnalytics:
	extends Node
	var events: Array = []

	func track_event(event_name: String, params: Dictionary = {}) -> void:
		events.append([event_name, params])


func before_test() -> void:
	log = LRDRunLog.new("runs.jsonl", 2)
	log.log_dir = DIR
	log.driver = "test_suite"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(log.path()))


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(log.path()))


func _rows() -> Array[Dictionary]:
	return LRDRunLog.read_rows(log.path())


func test_a_row_leads_with_provenance() -> void:
	assert_bool(log.record({"shift": 3, "strikes": 1})).is_true()
	var row: Dictionary = _rows()[0]
	assert_array(row.keys().slice(0, 4)).is_equal(["schema", "logged_at", "build", "driver"])
	assert_int(int(row["schema"])).is_equal(2)
	assert_str(str(row["driver"])).is_equal("test_suite")
	assert_str(str(row["build"])).is_equal(LRDBuildStamp.describe())
	assert_int(int(row["shift"])).is_equal(3)


func test_rows_append_and_are_never_rotated() -> void:
	log.record({"n": 1})
	log.record({"n": 2})
	log.record({"n": 3})
	var rows: Array[Dictionary] = _rows()
	assert_int(rows.size()).is_equal(3)
	assert_int(int(rows[2]["n"])).is_equal(3)


func test_runs_under_the_floor_are_not_play() -> void:
	log.min_seconds = 30.0
	assert_bool(log.record({"n": 1}, 12.0)).is_false()
	assert_bool(log.record({"n": 2}, 45.0)).is_true()
	assert_bool(log.record({"n": 3})).is_true()  # no duration: no floor
	assert_int(_rows().size()).is_equal(2)


func test_a_game_field_cannot_overwrite_provenance() -> void:
	log.record({"driver": "human", "schema": 99, "n": 1})
	var row: Dictionary = _rows()[0]
	assert_str(str(row["driver"])).is_equal("test_suite")
	assert_int(int(row["schema"])).is_equal(2)


func test_without_an_explicit_driver_the_command_line_decides() -> void:
	log.driver = ""
	assert_str(log.resolved_driver()).is_equal(LRDRunArgs.driver_from(LRDRunArgs.all_args()))


func test_the_test_runner_never_writes_the_real_file() -> void:
	var real := LRDRunLog.new("runs.jsonl", 1)
	assert_str(real.path()).starts_with(LRDUserPaths.TEST_ROOT)


func test_malformed_lines_are_skipped_and_counted() -> void:
	log.record({"n": 1})
	var file := FileAccess.open(log.path(), FileAccess.READ_WRITE)
	file.seek_end()
	file.store_line("not json")
	file.store_line("[1, 2]")
	file.close()
	log.record({"n": 2})
	var skipped: Array = [0]
	var rows: Array[Dictionary] = LRDRunLog.read_rows(log.path(), skipped)
	assert_int(rows.size()).is_equal(2)
	assert_int(int(skipped[0])).is_equal(2)


func test_rows_mirror_to_analytics_only_when_asked() -> void:
	var fake := FakeAnalytics.new()
	fake.name = "LRDAnalytics"
	get_tree().root.add_child(fake)
	log.record({"n": 1})
	assert_int(fake.events.size()).is_equal(0)
	log.analytics_event = "run_logged"
	log.record({"n": 2})
	assert_int(fake.events.size()).is_equal(1)
	assert_str(str(fake.events[0][0])).is_equal("run_logged")
	assert_int(int(fake.events[0][1]["n"])).is_equal(2)
	fake.free()
