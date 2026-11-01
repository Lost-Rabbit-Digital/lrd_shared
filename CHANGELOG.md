# Changelog

Versions are per add-on. Games record which version they vendor.

## lrd_run_log 0.1.0 (2026-11-01)

- First release, extracted from Xerophobia (`RunLog`, `BuildStamp`, `UserPaths`, `tools/run_report.gd`). See dmchaledev/lrd_shared#1.
- `LRDRunLog`, `LRDRunReport`, `LRDBuildStamp`, `LRDRunArgs`, `LRDUserPaths`, plus a report-tool template.
- Changes from Xerophobia's version:
  - The game supplies its own fields. There is no game-specific row.
  - Packed refs are read by the build stamp.
  - gdUnit4 and `tests/run_tests.gd` are recognised as test runners.
  - Rows keep insertion order, so provenance comes first.
  - Rows can be mirrored to `LRDAnalytics`.
