## Template for a game's report tool. Copy it to `tools/run_report.gd`, set the
## constants, and replace `_print_metric()` with the question your log exists to
## answer. Run it with:
##
##     godot --headless -s tools/run_report.gd
##     godot --headless -s tools/run_report.gd -- --build 2.0.25+1a2b3c4
##     godot --headless -s tools/run_report.gd -- --since 2026-11-01 --all-drivers
##     godot --headless -s tools/run_report.gd -- --file path/to/runs.jsonl
##
## It reads the real file on purpose: don't call LRDUserPaths.redirect_to_test_root()
## here. A report exists to read the runs somebody really played.
extends SceneTree

## The file your game's LRDRunLog writes, e.g. "user://shifts.jsonl".
const LOG_PATH: String = "user://runs.jsonl"
## The schema your game currently writes; older rows are counted and flagged.
const SCHEMA: int = 1


func _initialize() -> void:
	var options: Dictionary = LRDRunReport.parse_args(OS.get_cmdline_user_args())
	var report: LRDRunReport = LRDRunReport.from_args(LOG_PATH, options, SCHEMA)
	for line: String in report.header_lines():
		print(line)
	print("")
	if report.rows.is_empty():
		print("No rows to report.")
	else:
		_print_metric(report)
	quit()


## Replace with the game's headline metric and its warning signs. Derive labels
## here from raw fields, so cut points can change without rewriting the log.
func _print_metric(report: LRDRunReport) -> void:
	var completed: float = report.share(func(row: Dictionary) -> bool: return bool(row.get("completed", false)))
	print("Completed: %.0f%% of %d runs" % [completed * 100.0, report.rows.size()])
