# LRD Save

Crash-safe JSON saves and save slots. A crash, full disk or power cut mid-save can no longer empty a player's save, and a new game can no longer inherit the last playthrough's state.

**Version:** 0.2.0, which needs Godot 4.7. See `CHANGELOG.md` at the repo root.

## What's in it

| Class | Job |
| --- | --- |
| `LRDSaveFile` | `write_json()` writes `<path>.tmp`, reads it back, copies the previous save to `<path>.bak` (only if it parses), then renames the temp file over the save. The save is never moved aside, so a failure at any step leaves it as it was and no temp file behind. `read_json()` falls back to the backup when the save is missing, empty or corrupt (`last_read_used_backup` says when it did). `migrate_legacy_file()` moves a pre-slot file into its slot once, deleting the original only after the copy is confirmed. |
| `LRDSaveSlots` | `path(file, slot)` routes every per-save file through the active slot. Initialises lazily from every accessor, so an early autoload still gets the right slot. Slot metadata (for a picker) is a cache, dropped for any slot whose files are gone. `new_game(slot)` clears the slot's save files **and** derived files (unlocks, found lore). |

JSON has one number type: numbers read back as `float`, so cast with `int()` where a whole number is meant.

## Adopting it in a game

1. Copy `addons/lrd_save/` into the game and record the version (e.g. in `VENDORED_FROM.md`).
2. Own one `LRDSaveSlots` in your save autoload, naming the files that make up a save and the derived files a new game must clear:
   ```gdscript
   var slots := LRDSaveSlots.new(3, PackedStringArray(["progress.json"]), PackedStringArray(["lore.json", "unlocks.json"]))
   ```
3. Replace every `FileAccess.open("user://...", WRITE)` for save data with `LRDSaveFile.write_json(slots.path("..."), data)`, and every read with `LRDSaveFile.read_json(...)`.
4. For any install-wide file from before slots, call `slots.adopt_legacy_file("user://old.json", "old.json")` once at startup.
5. Reload on `slots.slot_changed` rather than writing the outgoing slot's data into the incoming one.
6. If the game uses Steam Auto-Cloud, include `saves/slot_*/*.json` (the `.bak` files can stay local).

## Tests and harnesses

If the game also vendors `lrd_run_log`, every path lrd_save opens goes through `LRDUserPaths.resolve()`: under a test runner or a `--driver=` harness, `user://saves/...` becomes `user://test_runner/saves/...`, so tests and bots never touch the player's saves. `LRDSaveFile.resolve_path()` exposes the same mapping, and `slots.path()` already returns the redirected path. lrd_save finds `LRDUserPaths` by class name at runtime, so it has no hard dependency: without `lrd_run_log`, paths are used as given, and tests should point `slots.save_dir` at a throwaway folder.

Not covered: Godot has no fsync, so a power cut moments after a write can lose that write (the previous save or its backup remains).
