extends GdUnitTestSuite


func after_test() -> void:
	LRDUserPaths.reset_for_tests()


func test_test_runners_and_named_bots_are_harnesses() -> void:
	(
		assert_bool(LRDUserPaths.is_harness(PackedStringArray(["-s", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"])))
		. is_true()
	)
	assert_bool(LRDUserPaths.is_harness(PackedStringArray(["--script", "res://tests/run_tests.gd"]))).is_true()
	assert_bool(LRDUserPaths.is_harness(PackedStringArray(["--driver=smoke"]))).is_true()


func test_a_player_is_not_a_harness() -> void:
	assert_bool(LRDUserPaths.is_harness(PackedStringArray(["--fullscreen"]))).is_false()
	assert_bool(LRDUserPaths.is_harness(PackedStringArray(["--driver=human"]))).is_false()


func test_user_paths_move_under_the_test_root_in_a_harness() -> void:
	LRDUserPaths.redirect_to_test_root()
	assert_str(LRDUserPaths.resolve("user://runs.jsonl")).is_equal(LRDUserPaths.TEST_ROOT + "runs.jsonl")


func test_paths_a_harness_already_chose_are_left_alone() -> void:
	LRDUserPaths.redirect_to_test_root()
	assert_str(LRDUserPaths.resolve("user://test_mine/runs.jsonl")).is_equal("user://test_mine/runs.jsonl")
	assert_str(LRDUserPaths.resolve("res://data/runs.jsonl")).is_equal("res://data/runs.jsonl")


func test_this_suite_itself_is_detected_as_a_test_run() -> void:
	assert_bool(LRDUserPaths.under_test_runner()).is_true()
