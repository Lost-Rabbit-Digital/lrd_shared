## Who is driving this process: a person, or a named bot.
##
## Every row carries a `driver`. Bots name themselves with `--driver=<name>`, and
## an explicit name always beats any inference, because a bot row labelled
## `human` is the one error a run log must never make: it silently lands in every
## headline figure.
##
## Extracted from Xerophobia's RunLog._detect_driver and UserPaths.all_args.
class_name LRDRunArgs
extends RefCounted

## What a row says when nothing claimed it. Somebody sat down and played.
const DRIVER_HUMAN: String = "human"
const DRIVER_FLAG: String = "--driver="
## Opt-out for a run that must not log at all. Deliberately not a debug-build
## gate: developers playtest in debug builds, so that gate would collect data
## only from builds nobody plays.
const DISABLE_FLAG: String = "--no-run-log"


## Every argument this process was started with, on both sides of `--`.
## `OS.get_cmdline_args()` stops at `--`, and harness flags go after it.
static func all_args() -> PackedStringArray:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	return args


## The driver named by `args`.
##
## An explicit `--driver=<name>` wins. Otherwise each key of `inferences` is a
## flag that only an automated harness passes, mapped to the name to record
## (e.g. `{"--autoplay": "playtest_bot"}`); keep that list narrow. Anything
## else is [constant DRIVER_HUMAN].
static func driver_from(args: PackedStringArray, inferences: Dictionary = {}) -> String:
	for arg: String in args:
		if arg.begins_with(DRIVER_FLAG):
			var named: String = arg.substr(DRIVER_FLAG.length()).strip_edges()
			if named != "":
				return named
	for flag: String in inferences:
		if args.has(flag):
			return str(inferences[flag])
	return DRIVER_HUMAN


## Whether a row was played by a person. A row with no `driver` predates the
## column and counts as human: assuming robot would throw away the only real
## data an older log has.
static func is_human(row: Dictionary) -> bool:
	return str(row.get("driver", DRIVER_HUMAN)) == DRIVER_HUMAN


## Whether `args` turn logging off.
static func logging_disabled(args: PackedStringArray) -> bool:
	return args.has(DISABLE_FLAG)
