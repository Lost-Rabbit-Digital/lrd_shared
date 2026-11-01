extends GdUnitTestSuite


func test_an_explicit_driver_wins() -> void:
	var args := PackedStringArray(["--autoplay", "--driver=progression_bot"])
	var inferred: String = LRDRunArgs.driver_from(args, {"--autoplay": "playtest_bot"})
	assert_str(inferred).is_equal("progression_bot")


func test_an_empty_driver_flag_falls_back_to_inference() -> void:
	var args := PackedStringArray(["--driver=", "--autoplay"])
	assert_str(LRDRunArgs.driver_from(args, {"--autoplay": "playtest_bot"})).is_equal("playtest_bot")


func test_no_flags_means_a_person() -> void:
	assert_str(LRDRunArgs.driver_from(PackedStringArray(["--fullscreen"]))).is_equal(LRDRunArgs.DRIVER_HUMAN)


func test_a_row_without_a_driver_counts_as_human() -> void:
	assert_bool(LRDRunArgs.is_human({"schema": 1})).is_true()
	assert_bool(LRDRunArgs.is_human({"driver": "human"})).is_true()
	assert_bool(LRDRunArgs.is_human({"driver": "smoke"})).is_false()


func test_the_opt_out_flag_disables_logging() -> void:
	assert_bool(LRDRunArgs.logging_disabled(PackedStringArray(["--no-run-log"]))).is_true()
	assert_bool(LRDRunArgs.logging_disabled(PackedStringArray([]))).is_false()
