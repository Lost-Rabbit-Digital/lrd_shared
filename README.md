# lrd_shared (retired)

This repo used to hold several of the studio's shared add-ons in one place. The studio
now keeps **one canonical repo per add-on**, so the LRD Addon Manager indexes each folder
from exactly one repo and each add-on has one version. Everything that was here, or was
planned to come here, has a home of its own:

| Add-on | Canonical repo |
| --- | --- |
| `lrd_save` | [lrd_save](https://github.com/Lost-Rabbit-Digital/lrd_save) |
| `lrd_run_log` (incl. `LRDUserPaths` test-run detection) | [lrd_run_log](https://github.com/Lost-Rabbit-Digital/lrd_run_log) |
| `lrd_analytics` | [lrd_analytics](https://github.com/Lost-Rabbit-Digital/lrd_analytics) |
| `rabbit_developer_console` | [rabbit_developer_console_plugin](https://github.com/Lost-Rabbit-Digital/rabbit_developer_console_plugin) |
| `lrd_mcp_bridge` | [lrd_mcp_bridge](https://github.com/Lost-Rabbit-Digital/lrd_mcp_bridge) |
| `manage_user_data` | [manage_user_data_plugin](https://github.com/Lost-Rabbit-Digital/manage_user_data_plugin) |
| Shared CI, export and store scripts | [lrd-ci](https://github.com/Lost-Rabbit-Digital/lrd-ci) |

The full history is in this repo's git log, and the release notes up to the split are in
`CHANGELOG.md`. Remove the `godot-addon` topic and archive the repo once nothing links here.
