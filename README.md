# lrd_shared

The single versioned source for code shared between Lost Rabbit Digital's games. Games **vendor** an add-on from here, record the version, and send fixes back here rather than patching their copy. See the studio playbook's [Studio shared code](https://github.com/Lost-Rabbit-Digital/studio-playbook/blob/main/principles/studio-shared-code.md) principle.

## Add-ons

| Add-on | Version | What it does |
| --- | --- | --- |
| [`lrd_run_log`](addons/lrd_run_log/README.md) | 0.1.0 | Structured playtest run log: one row per run, stamped with schema, build and driver, plus report helpers |
| [`lrd_save`](addons/lrd_save/README.md) | 0.1.0 | Crash-safe JSON saves (atomic write, backup fallback) and save slots that route every per-save file through the active slot |

Planned, tracked in dmchaledev/lrd_shared#2: `lrd_analytics` (with its player consent and opt-out), `rabbit_developer_console`, `lrd_mcp_bridge`, the capture tool, the user-data tool, and the localization and store scripts.

**Not here:** co-op networking is [`lrd_steam_net`](https://github.com/Lost-Rabbit-Digital/lrd_steam_net); the runtime platform layer (Steam init, Sentry, settings, input devices, audio buses, the "More from LRD" panel) is [`lrd_platform`](https://github.com/Lost-Rabbit-Digital/lrd_platform).

## Working here

This is a small Godot 4.7 project, so the add-ons can be tested on their own. `addons/gdUnit4/` (6.1.3) is here for the tests only; don't vendor it from here.

```bash
godot --headless --import
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c
gdformat -l 120 --check addons/lrd_run_log addons/lrd_save tests
gdlint addons/lrd_run_log addons/lrd_save tests
```

CI runs both on every push and pull request.
