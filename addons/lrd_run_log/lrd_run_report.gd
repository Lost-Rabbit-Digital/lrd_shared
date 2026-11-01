## Reads a run log and hands a game's report tool the rows it should count.
##
## Two things quietly ruin every figure a run log produces, and this class says
## them out loud instead of leaving them to be noticed:
##
## - **Bots.** Harnesses write into the same file. They're excluded unless the
##   report asks for them (`--all-drivers`).
## - **Builds.** A log spans builds, and a balance change halfway through means
##   an average across the change describes neither side. When the selected rows
##   carry more than one build, [method mixed_build_warning] says so.
##
## A game's `tools/run_report.gd` (an `extends SceneTree` script) parses its
## arguments with [method parse_args], builds a report with [method from_args],
## computes its own headline metric over [member rows], and prints
## [method header_lines] first. Labels such as "stayed" or "abandoned" are
## derived there, from raw fields, so the cut points can be argued about after
## the data exists.
##
## See studio-playbook sops/playtest-run-log.md. Extracted from Xerophobia's
## tools/run_report.gd.
class_name LRDRunReport
extends RefCounted

## The rows that survived the filters, oldest first.
var rows: Array[Dictionary] = []
## Rows read from the file before filtering.
var total_rows: int = 0
## Bot rows dropped because `--all-drivers` wasn't given.
var bot_rows: int = 0
## Lines in the file that weren't a JSON object.
var malformed_lines: int = 0
## Rows whose `schema` is lower than the one the report asked for.
var older_schema_rows: int = 0
var source_path: String = ""


## Parse a report tool's arguments (pass `OS.get_cmdline_user_args()`):
## `--file <path>`, `--build <stamp>`, `--since <YYYY-MM-DD>`, `--all-drivers`.
## Both `--flag value` and `--flag=value` work.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {"file": "", "build": "", "since": "", "all_drivers": false}
	var i: int = 0
	while i < args.size():
		var arg: String = args[i]
		var key: String = arg.trim_prefix("--")
		var value: String = ""
		if "=" in key:
			value = key.get_slice("=", 1)
			key = key.get_slice("=", 0)
		elif i + 1 < args.size() and not args[i + 1].begins_with("--"):
			value = args[i + 1]
		match key:
			"all-drivers":
				out["all_drivers"] = true
			"file", "build", "since":
				out[key] = value
				if not "=" in arg:
					i += 1
		i += 1
	return out


## A report over `default_path`, filtered as `options` (from [method parse_args])
## asks. `current_schema` counts rows written by an older schema, so a report can
## say "these rows predate the column" rather than reading a missing field as 0.
static func from_args(default_path: String, options: Dictionary, current_schema: int = 0) -> LRDRunReport:
	var path: String = str(options.get("file", ""))
	if path == "":
		path = default_path
	var report := LRDRunReport.new()
	report.load_file(path)
	report.apply_filters(
		bool(options.get("all_drivers", false)),
		str(options.get("build", "")),
		str(options.get("since", "")),
		current_schema
	)
	return report


## Read every row of `path` into [member rows], unfiltered.
func load_file(path: String) -> void:
	source_path = path
	var skipped: Array = [0]
	rows = LRDRunLog.read_rows(path, skipped)
	malformed_lines = int(skipped[0])
	total_rows = rows.size()


## Keep only the rows the report should count.
func apply_filters(include_bots: bool, build: String, since: String, current_schema: int = 0) -> void:
	var kept: Array[Dictionary] = []
	bot_rows = 0
	older_schema_rows = 0
	for row: Dictionary in rows:
		if not include_bots and not LRDRunArgs.is_human(row):
			bot_rows += 1
			continue
		if build != "" and str(row.get("build", "")) != build:
			continue
		# ISO timestamps compare correctly as strings.
		if since != "" and str(row.get("logged_at", "")) < since:
			continue
		if current_schema > 0 and int(row.get("schema", 0)) < current_schema:
			older_schema_rows += 1
		kept.append(row)
	rows = kept


## Distinct builds among [member rows], in first-seen order.
func builds() -> PackedStringArray:
	var seen: PackedStringArray = []
	for row: Dictionary in rows:
		var build: String = str(row.get("build", LRDBuildStamp.UNKNOWN))
		if not build in seen:
			seen.append(build)
	return seen


## Rows per build among [member rows].
func rows_per_build() -> Dictionary:
	var counts: Dictionary = {}
	for row: Dictionary in rows:
		var build: String = str(row.get("build", LRDBuildStamp.UNKNOWN))
		counts[build] = int(counts.get(build, 0)) + 1
	return counts


## A warning when [member rows] span more than one build, else "".
func mixed_build_warning() -> String:
	var counts: Dictionary = rows_per_build()
	if counts.size() <= 1:
		return ""
	var parts: PackedStringArray = []
	for build: String in counts:
		parts.append("%s (%d)" % [build, counts[build]])
	return (
		(
			"WARNING: these rows span %d builds: %s. Figures below average across them; "
			+ "pass --build <stamp> to read one."
		)
		% [counts.size(), ", ".join(parts)]
	)


## The lines every report prints before its metric: what was read, what was
## dropped and why, and the mixed-build warning when there is one.
func header_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("Run log: %s" % ProjectSettings.globalize_path(source_path))
	lines.append("Rows: %d counted of %d in the file" % [rows.size(), total_rows])
	if bot_rows > 0:
		lines.append("Excluded %d bot row(s); --all-drivers includes them" % bot_rows)
	if malformed_lines > 0:
		lines.append("Skipped %d malformed line(s)" % malformed_lines)
	if older_schema_rows > 0:
		lines.append("%d row(s) predate the current schema; newer columns are missing from them" % older_schema_rows)
	var warning: String = mixed_build_warning()
	if warning != "":
		lines.append(warning)
	return lines


## The share of [member rows] for which `predicate` is true, 0..1 (0 with no rows).
func share(predicate: Callable) -> float:
	if rows.is_empty():
		return 0.0
	var hits: int = 0
	for row: Dictionary in rows:
		if predicate.call(row):
			hits += 1
	return float(hits) / float(rows.size())
