# LRD Run Log

One structured row per playtest run, stamped with **schema, build and driver**, so a design question can be answered with a number and split at a change. A report helper counts only human runs by default and warns when the rows span more than one build.

This implements the studio playbook's [Playtest run log SOP](https://github.com/Lost-Rabbit-Digital/studio-playbook/blob/main/sops/playtest-run-log.md). It was extracted from Xerophobia's `RunLog`, `BuildStamp`, `UserPaths` and `tools/run_report.gd`.

**Version:** 0.1.0, which needs Godot 4.7. See `CHANGELOG.md` at the repo root.

## What's in it

| Class | Job |
| --- | --- |
| `LRDRunLog` | Appends one JSONL row per run. Every row leads with `schema`, `logged_at`, `build` and `driver`. A minimum duration filters out test harnesses and aborted loads. `--no-run-log` turns logging off. The log can optionally mirror each row to `LRDAnalytics`. |
| `LRDRunReport` | Reads a log for a report tool. It excludes bots unless the tool asks for them (`--all-drivers`), filters with `--build` and `--since`, counts rows from older schemas, and warns about mixed builds. |
| `LRDBuildStamp` | Builds `<config/version>+<short sha>`, reading the sha from `.git` at runtime. It handles loose refs, packed refs and a detached HEAD. In an export, which has no `.git`, it falls back to the version alone. |
| `LRDRunArgs` | Works out the `driver` from the command line: an explicit `--driver=<name>` wins, then a game-supplied list of flags that only bots pass. Anything else is `human`. |
| `LRDUserPaths` | Under a test runner (gdUnit4, GUT or `tests/run_tests.gd`) or a named bot, redirects every `user://` path to `user://test_runner/`, so tests never write the developer's real files. |

## Adopting it in a game

1. **Vendor it.** Copy `addons/lrd_run_log/` into the game unchanged, and note the version and commit in the game's `CLAUDE.md` or `docs/`. Fix bugs here and re-vendor; don't patch the copy. See the playbook's [Studio shared code](https://github.com/Lost-Rabbit-Digital/studio-playbook/blob/main/principles/studio-shared-code.md) principle.
2. **Name the question.** Choose the one headline metric the log answers, with its target, and the warning signs that would explain a miss.
3. **Write a row per run** wherever a run ends, including abandoned runs. Record raw fields, not labels:
   ```gdscript
   var run_log := LRDRunLog.new("shifts.jsonl", 1)

   func _ready() -> void:
       run_log.min_seconds = 20.0
       run_log.analytics_event = "shift_logged"  # optional: also send to LRDAnalytics

   func _on_shift_ended(stats: Dictionary) -> void:
       run_log.record({
           "shift": stats.shift,
           "strikes": stats.strikes,
           "correct": stats.correct,
           "quit_early": stats.quit_early,
           "duration": stats.seconds,
       }, stats.seconds)
   ```
4. **Point the bots at the same log.** Launch each bot with `--driver=<name>`, or set `run_log.driver = "progression_bot"` before its first row. An explicit name always wins over inference.
5. **Write the report tool.** Copy `examples/run_report_template.gd` to `tools/run_report.gd`, then replace its metric with yours.
6. **If `project.godot` isn't at the repo root,** set `LRDBuildStamp.git_dir = "res://../.git/"` once at startup. Spud Customs needs this, for example.

## Notes

- **Schema:** bump `schema` when a field changes meaning, never when you only add one.
- **Where rows go:** rows are never sent anywhere unless `analytics_event` is set. The file lives in `user://` and is never rotated, and playtesters send it to you.
- **Analytics limits:** `LRDAnalytics` keeps at most 50 params per event and 256 characters per string. Keep mirrored rows flat and small.
- **Opting out:** gate logging on the `--no-run-log` flag, not on `OS.is_debug_build()`. Developers playtest in debug builds, so a debug-build gate would collect data only from the builds nobody plays.
