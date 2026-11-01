## Which build a run-log row came from, with no build step to forget.
##
## Read off `.git` at runtime rather than baked in by an export step: a stamp
## written by a tool is a stamp somebody forgets to re-run, and the builds that
## matter most are the ones nobody prepares (a developer pressing play). From
## source `res://` is the project directory, so the ref is there; in an export
## it is not, and the stamp falls back to `application/config/version`.
##
## It cannot see a dirty working tree, which would need git itself, so a row is
## "this commit, plus whatever was uncommitted".
##
## Extracted from Xerophobia's BuildStamp (scripts/utilities/build_stamp.gd).
class_name LRDBuildStamp
extends RefCounted

const UNKNOWN: String = "unknown"

## Where `.git` sits relative to `res://`. Projects that keep `project.godot`
## in a subfolder (`godot_project/`) set this to "res://../.git/" before the
## first row is written.
static var git_dir: String = "res://.git/"

static var _describe_cache: String = ""


## `<version>+<short sha>`, or just the version where there is no git to read.
## One opaque string: the report groups rows by it and never parses it.
static func describe() -> String:
	if _describe_cache != "":
		return _describe_cache
	var stamp: String = version()
	var sha: String = commit()
	if sha != UNKNOWN:
		stamp += "+" + sha.substr(0, 7)
	_describe_cache = stamp
	return _describe_cache


## Forget the cached stamp (tests, or after changing [member git_dir]).
static func reset_cache() -> void:
	_describe_cache = ""


## The version in project.godot, which both an export and a source run carry.
## Never empty: an unset version would group every exported row under "".
static func version() -> String:
	var value: String = str(ProjectSettings.get_setting("application/config/version", ""))
	return value if value != "" else UNKNOWN


## The full sha at HEAD, or [constant UNKNOWN].
##
## Handles a branch HEAD (symbolic ref, loose or packed) and a detached HEAD.
static func commit() -> String:
	var head: String = _read(git_dir + "HEAD")
	if head == "":
		return UNKNOWN
	if not head.begins_with("ref: "):
		return head  # Detached: HEAD is the sha.
	var ref: String = head.substr(5).strip_edges()
	var loose: String = _read(git_dir + ref)
	if loose != "":
		return loose
	return _packed_ref(ref)


static func _packed_ref(ref: String) -> String:
	var packed: String = _read(git_dir + "packed-refs")
	for line: String in packed.split("\n"):
		var parts: PackedStringArray = line.strip_edges().split(" ")
		if parts.size() == 2 and parts[1] == ref:
			return parts[0]
	return UNKNOWN


static func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text().strip_edges()
	file.close()
	return text
