extends GdUnitTestSuite

const PATH: String = "user://test_lrd_report/runs.jsonl"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PATH.get_base_dir()))
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	for row: Dictionary in [
		{"schema": 1, "logged_at": "2026-10-01T10:00:00", "build": "1.0+aaaaaaa", "driver": "human", "won": true},
		{"schema": 2, "logged_at": "2026-10-20T10:00:00", "build": "1.1+bbbbbbb", "driver": "human", "won": false},
		{"schema": 2, "logged_at": "2026-10-21T10:00:00", "build": "1.1+bbbbbbb", "driver": "human", "won": true},
		{
			"schema": 2,
			"logged_at": "2026-10-21T11:00:00",
			"build": "1.1+bbbbbbb",
			"driver": "progression_bot",
			"won": true
		},
		{"logged_at": "2026-09-01T10:00:00", "build": "0.9", "won": false},
	]:
		file.store_line(JSON.stringify(row))
	file.close()


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _report(options: Dictionary, schema: int = 0) -> LRDRunReport:
	return LRDRunReport.from_args(PATH, options, schema)


func test_arguments_parse_in_both_forms() -> void:
	var parsed: Dictionary = LRDRunReport.parse_args(
		PackedStringArray(["--build", "1.1+bbbbbbb", "--since=2026-10-15", "--all-drivers"])
	)
	assert_str(str(parsed["build"])).is_equal("1.1+bbbbbbb")
	assert_str(str(parsed["since"])).is_equal("2026-10-15")
	assert_bool(bool(parsed["all_drivers"])).is_true()
	assert_str(str(parsed["file"])).is_empty()


func test_bots_are_excluded_unless_asked_for() -> void:
	var report := _report({})
	assert_int(report.rows.size()).is_equal(4)
	assert_int(report.bot_rows).is_equal(1)
	assert_int(_report({"all_drivers": true}).rows.size()).is_equal(5)


func test_build_and_date_filters() -> void:
	assert_int(_report({"build": "1.1+bbbbbbb"}).rows.size()).is_equal(2)
	assert_int(_report({"since": "2026-10-15"}).rows.size()).is_equal(2)


func test_mixed_builds_are_called_out() -> void:
	var mixed := _report({})
	assert_str(mixed.mixed_build_warning()).contains("span 3 builds")
	assert_str(_report({"build": "1.1+bbbbbbb"}).mixed_build_warning()).is_empty()


func test_older_schema_rows_are_counted() -> void:
	assert_int(_report({}, 2).older_schema_rows).is_equal(2)


func test_header_says_what_was_dropped() -> void:
	var lines: String = "\n".join(_report({}).header_lines())
	assert_str(lines).contains("4 counted of 5")
	assert_str(lines).contains("Excluded 1 bot row")
	assert_str(lines).contains("WARNING")


func test_share_of_rows() -> void:
	var report := _report({"build": "1.1+bbbbbbb"})
	assert_float(report.share(func(row: Dictionary) -> bool: return bool(row["won"]))).is_equal(0.5)
