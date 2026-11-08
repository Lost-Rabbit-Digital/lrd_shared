# Changelog

Versions are per add-on. Games record which version they vendor.

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
