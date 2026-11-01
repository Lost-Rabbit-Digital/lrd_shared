# lrd_shared

The single versioned source for code shared between Lost Rabbit Digital's games. Games **vendor** an add-on from here, record the version, and send fixes back here rather than patching their copy. See the studio playbook's [Studio shared code](https://github.com/Lost-Rabbit-Digital/studio-playbook/blob/main/principles/studio-shared-code.md) principle.

## Add-ons

| Add-on | Version | What it does |
| --- | --- | --- |
| [`lrd_run_log`](addons/lrd_run_log/README.md) | 0.1.0 | Structured playtest run log: one row per run, stamped with schema, build and driver, plus report helpers |

Planned, tracked in dmchaledev/lrd_shared#2: `lrd_analytics`, `rabbit_developer_console`, `lrd_mcp_bridge`, the capture tool, the user-data tool, the localization and store scripts, and a shared save library.

## Working here

This is a small Godot 4.7 project, so the add-ons can be tested on their own. `addons/gdUnit4/` (6.1.3) is here for the tests only; don't vendor it from here.

```bash
godot --headless --import
godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c
gdformat -l 120 --check addons/lrd_run_log tests
gdlint addons/lrd_run_log tests
```

CI runs both on every push and pull request.
