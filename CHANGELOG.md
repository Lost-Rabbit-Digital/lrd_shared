# Changelog

Versions are per add-on. Games record which version they vendor.

## lrd_save 0.2.0 (2026-11-08)

- `LRDSaveFile.write_json`: a failed final rename no longer leaves the save only as `.bak`. The old write moved the save to `.bak` and then renamed the temp file in; the save is now *copied* to `.bak` and the temp file renamed over it, so the save stays in place until it is replaced. If a rename removes the save and then fails (remove-then-move platforms), the copy is restored.
- `LRDSaveFile.write_json`: the old backup is no longer deleted before the new one is taken (a failure there lost it), a save that doesn't parse is never rotated over a good backup, and a failed final rename no longer leaves `<path>.tmp` behind. The doc comment now states what a failure guarantees, and that there is no fsync.
- lrd_save now honours `LRDUserPaths` from lrd_run_log when the game vendors it: under a test runner or harness, saves go to `user://test_runner/...` instead of the player's real `user://saves`. Found by class name at runtime, so lrd_save still works on its own. New `LRDSaveFile.resolve_path()`; `LRDSaveSlots.path()` returns the redirected path.
- Test seam `LRDSaveFile.fault` (with `STEP_*` constants) to fail any step of a write. Games never set it.

## lrd_run_log 0.1.1 (2026-11-07)

- `LRDUserPaths`: tests run from the editor's gdUnit4 panel are now recognised as a test run (`GdUnitTestRunner.tscn` marker). The editor never passes `GdUnitCmdTool.gd`, so those runs wrote run-log rows (and anything else resolved through `LRDUserPaths`) into the developer's real profile.
- `LRDBuildStamp`: reads the commit in a linked git worktree or submodule, where `.git` is a file (`gitdir:`) and branch refs live in the shared `commondir`. Rows from those checkouts used to carry the bare version with no sha.

## lrd_save 0.1.0 (2026-11-01)

- First release. Toward dmchaledev/lrd_shared#2 ("a save library with atomic writes and a backup fallback").
- `LRDSaveFile`: atomic JSON writes (`<path>.tmp`, read back, then swapped in), the previous save kept as `<path>.bak`, reads that fall back to the backup when the save is missing, empty or corrupt, and one-time adoption of pre-slot legacy files.
- `LRDSaveSlots`: per-slot paths, lazy initialisation from every accessor (playbook GDT-32), slot metadata reconciled with the files on disk, and `new_game()` clearing the slot's save and derived files.
- Sources: Starbrew Station (atomic writes), Bikini Heaven (backup fallback), Fragile Frontier (`SaveSlotManager`, `JsonFileUtils.migrate_legacy_file`).

## lrd_run_log 0.1.0 (2026-11-01)

- First release, extracted from Xerophobia (`RunLog`, `BuildStamp`, `UserPaths`, `tools/run_report.gd`). See dmchaledev/lrd_shared#1.
- `LRDRunLog`, `LRDRunReport`, `LRDBuildStamp`, `LRDRunArgs`, `LRDUserPaths`, plus a report-tool template.
- Changes from Xerophobia's version:
  - The game supplies its own fields. There is no game-specific row.
  - Packed refs are read by the build stamp.
  - gdUnit4 and `tests/run_tests.gd` are recognised as test runners.
  - Rows keep insertion order, so provenance comes first.
  - Rows can be mirrored to `LRDAnalytics`.
