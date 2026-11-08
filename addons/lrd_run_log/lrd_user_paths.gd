## Keeps test suites and harnesses out of the developer's own `user://` files.
##
## A per-test convention ("redirect the path in before_test") is a rule somebody
## forgets: Xerophobia's suite once built a 19-contract career inside the
## developer's real profile, and every playtest then started from it. So the
## decision is made once, where files are opened: under a test runner or a named
## harness, a `user://` path resolves under [constant TEST_ROOT] instead. A path a
## harness already pointed at `user://test...` is left alone.
##
## Extracted from Xerophobia's UserPaths (scripts/utilities/user_paths.gd).
class_name LRDUserPaths
extends RefCounted

const TEST_ROOT: String = "user://test_runner/"

## Command-line fragments that identify a test runner. gdUnit4's CLI tool and the
## runner scene its editor panel launches (tests run from the editor never pass
## the CLI tool), GUT's runner, and the `res://tests/run_tests.gd` entry point the
## studio's games use. Projects with another runner append to this before
## anything is opened.
static var runner_markers: PackedStringArray = PackedStringArray(
	[
		"GdUnitCmdTool.gd",
		"GdUnitTestRunner.tscn",
		"gut_cmdln.gd",
		"tests/run_tests.gd",
	]
)

## -1 until asked, then 0 or 1. The command line can't change mid-process.
static var _under_runner: int = -1


## True when `args` belong to a harness rather than a player: a known test
## runner, or anything that named itself with a non-human `--driver=`.
static func is_harness(args: PackedStringArray) -> bool:
	for arg: String in args:
		for marker: String in runner_markers:
			if arg.ends_with(marker):
				return true
	return LRDRunArgs.driver_from(args) != LRDRunArgs.DRIVER_HUMAN


## True when this process is a harness. Cached for the process.
static func under_test_runner() -> bool:
	if _under_runner < 0:
		_under_runner = 1 if is_harness(LRDRunArgs.all_args()) else 0
	return _under_runner == 1


## Declare this process a harness, whatever started it. A `-s` tool script can't
## be recognised by name without listing it here, and the list is what gets
## forgotten, so a tool says so once before it opens anything. One-way on
## purpose: a process that admitted to being a harness has no business writing
## the real profile later. (A report tool must not call this: it exists to read
## the runs somebody really played.)
static func redirect_to_test_root() -> void:
	_under_runner = 1


## Test hook: forget the cached decision.
static func reset_for_tests() -> void:
	_under_runner = -1


## The path to actually open for `path`.
static func resolve(path: String) -> String:
	if not under_test_runner():
		return path
	if not path.begins_with("user://") or path.begins_with("user://test"):
		return path
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_ROOT))
	return TEST_ROOT + path.trim_prefix("user://")
