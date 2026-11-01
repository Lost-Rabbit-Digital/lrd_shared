## One newline-delimited JSON row per run, so a design question can be answered
## with a number and split at a change.
##
## Each game owns its row: what a "run" is (a shift, a prestige run, a puzzle),
## which raw fields it carries, and the headline metric its report computes.
## This class owns what every row must have and how it is written:
##
## - provenance first: `schema`, `logged_at`, `build`, `driver`
## - append-only `user://<file>.jsonl`, never rotated, never sent anywhere
##   unless [member analytics_event] is set
## - a duration floor, so test harnesses and aborted loads stay out
## - tests and harnesses redirected away from the real file ([LRDUserPaths])
##
## Write raw fields, not labels. Baking "stayed" or "too hard" into a row freezes
## a cut point chosen before any data exists; the report draws the lines.
##
## Usage:
## [codeblock]
## var log := LRDRunLog.new("shifts.jsonl", 1)
## log.min_seconds = 20.0
## log.record({"shift": 3, "strikes": 1, "duration": 412.5}, 412.5)
## [/codeblock]
##
## See studio-playbook sops/playtest-run-log.md. Extracted from Xerophobia's
## RunLog (scripts/systems/run_log.gd).
class_name LRDRunLog
extends RefCounted

## The fields every row starts with, in order.
const PROVENANCE_KEYS: PackedStringArray = ["schema", "logged_at", "build", "driver"]

## File name under [member log_dir], e.g. "shifts.jsonl".
var file_name: String
## Bump when a field changes meaning, never when one is merely added: readers
## can then say "this row predates the column" instead of inventing a zero.
var schema: int
## A directory rather than a path, so tests can point it elsewhere.
var log_dir: String = "user://"
## Runs shorter than this are a harness or an aborted load, not play.
## Ignored when [method record] is given no duration.
var min_seconds: float = 0.0
## Who is playing. An explicit value always wins over inference: set it before
## the first [method record] if this process is a bot.
var driver: String = ""
## Harness-only flags mapped to the driver name to record when no `--driver=`
## is given (see [method LRDRunArgs.driver_from]).
var driver_inferences: Dictionary = {}
## When not empty, every written row is also sent to the LRDAnalytics autoload
## as this event, so local playtest files and live telemetry share one shape.
## LRDAnalytics keeps at most 50 params and 256-character strings per event.
var analytics_event: String = ""

var _enabled: bool = true


func _init(p_file_name: String, p_schema: int) -> void:
	file_name = p_file_name
	schema = p_schema
	var args: PackedStringArray = LRDRunArgs.all_args()
	_enabled = not LRDRunArgs.logging_disabled(args)


## The file rows go to, after the test-runner redirect.
func path() -> String:
	return LRDUserPaths.resolve(log_dir.path_join(file_name))


## Whether `--no-run-log` turned this log off.
func is_enabled() -> bool:
	return _enabled


## The driver rows will carry: the explicit [member driver], else the command line.
func resolved_driver() -> String:
	if driver != "":
		return driver
	return LRDRunArgs.driver_from(LRDRunArgs.all_args(), driver_inferences)


## The row [method record] would write for `fields`: provenance first, then the
## game's fields. A game field may not overwrite provenance.
func build_row(fields: Dictionary) -> Dictionary:
	var row: Dictionary = {
		"schema": schema,
		"logged_at": Time.get_datetime_string_from_system(true, false),
		"build": LRDBuildStamp.describe(),
		"driver": resolved_driver(),
	}
	for key: Variant in fields:
		if str(key) in PROVENANCE_KEYS:
			push_warning("[LRDRunLog] Ignoring field '%s': it is provenance" % key)
			continue
		row[key] = fields[key]
	return row


## Append one row. Returns true if it was written.
##
## `duration_seconds` is checked against [member min_seconds]; pass a negative
## value to skip the floor (a run with no meaningful length).
func record(fields: Dictionary, duration_seconds: float = -1.0) -> bool:
	if not _enabled:
		return false
	if duration_seconds >= 0.0 and duration_seconds < min_seconds:
		return false
	var row: Dictionary = build_row(fields)
	# sort_keys off: provenance stays first, so `tail` reads when and which build.
	if not _append(JSON.stringify(row, "", false)):
		return false
	_mirror(row)
	return true


func _append(line: String) -> bool:
	var target: String = path()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	var file: FileAccess = FileAccess.open(target, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		push_warning("[LRDRunLog] Could not open %s (error %d)" % [target, FileAccess.get_open_error()])
		return false
	file.seek_end()
	file.store_line(line)
	file.close()
	return true


func _mirror(row: Dictionary) -> void:
	if analytics_event == "":
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var analytics: Node = tree.root.get_node_or_null("LRDAnalytics")
	if analytics != null and analytics.has_method("track_event"):
		analytics.track_event(analytics_event, row)


## Every row in the file at `file_path`, oldest first. Lines that aren't a JSON
## object are skipped and counted in `skipped` (pass a one-element Array).
static func read_rows(file_path: String, skipped: Array = []) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if skipped.is_empty():
		skipped.append(0)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return rows
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line == "":
			continue
		# A JSON instance rather than JSON.parse_string, which logs an engine
		# error for every bad line.
		var json := JSON.new()
		if json.parse(line) == OK and json.data is Dictionary:
			rows.append(json.data)
		else:
			skipped[0] = int(skipped[0]) + 1
	file.close()
	return rows
