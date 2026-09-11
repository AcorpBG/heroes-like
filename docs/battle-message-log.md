# Persistent Battle Message Log

Owner-directed Phase 6 slice `ui-battle-message-log-20260911`, derived from project.md and PLAN.md.

Keep the most recent battle messages readable after short animations finish. Provide bounded, scrollable battle-local history of ordered player/enemy action, damage and casualty captions. Use a compact edge pocket, preserve the battlefield and all commands, and support keyboard focus. Instant playback must retain messages too. Opening/scrolling history must not change simulation or save data. History resets for a new BattleShell; no save-schema migration is requested.

Validation: Python-owned focused Godot retention/order/bounds checks and small/wide screenshots; existing battle readability; repository validation and Linux/Windows export/package checks. No art generation, balance, overworld or RMG changes. Status: completed 2026-09-11.

## Implementation

`BattleMessageLog.gd` adds an 88-pixel history strip between the battlefield and command footer, with about four recent lines visible. It retains up to 200 captions for the current BattleShell, permits selection/scrolling and participates in the explicit keyboard focus cycle. New entries follow the bottom only when the reader was already at the bottom. Updates are coalesced so an instant action does not rebuild the text for every animation frame.

`BattleShell.gd` uses the same caption formatter for live animation and retained history. Round, side, unit, action/target, damage and losses come from existing authoritative playback records. Frames append as they play; instant/headless paths and switching an active queue to instant preserve the remaining captions. Refresh does not clear the history. No battle rules, RNG, saved data or action timing changes.

The shared UiAudio service supports an explicit `silent_ui_audio` control opt-out used only by this automatically advancing history scrollbar. Otherwise its generic Range binding emits adjustment sounds as combat text scrolls. Ordinary controls remain unchanged; focused validation checks the log produces no UI audio records.

## Reproduction commands

```sh
python3 -B tests/battle_message_log_regression.py --label fresh-small --render --resolution 1280x720
python3 -B tests/battle_message_log_regression.py --label fresh-wide --render --resolution 1920x1080 --reduced-motion
python3 -B tests/battle_message_log_regression.py --label fresh-headless
python3 -B tests/packaged_battle_message_log_regression.py --platform linux --binary <export>/heroes-like.x86_64 --pack <export>/heroes-like.pck --label fresh-packaged --render --resolution 1280x720
python3 -B tests/packaged_battle_message_log_regression.py --platform windows --binary <export>/heroes-like.exe --pack <export>/heroes-like.pck --wine-prefix <new-task-owned-prefix> --label fresh-windows
python3 -B tests/full_play_validation_suite.py --label fresh-log-runtime --rendered --accessibility disabled --only battle_controller_board_navigation_smoke battle_resolution_autosave_failure_route_safety_regression
python3 tests/validate_repo.py
git diff --check
```

The focused probe also runs the existing battle readability assertions: deterministic state, melee approach, enemy playback, controller-action locking and instant playback. The packaged wrapper retains those assertions through the established isolated-export bootstrap. History is battle-local, not an archive after leaving battle or reloading a save. Windows headless Wine does not certify hardware rendering.

## Validation evidence

Evidence root: `.artifacts/battle_message_log_20260911/`.

- `accepted-wide/report.json`: 86 checks pass, source 1920x1080/reduced motion. `linux-proof/report.json`: 86 checks pass, isolated Linux package at 1280x720. Both final `retained-log.png` screenshots inspected: persistent four-line strip, unobstructed battlefield/commands, readable text.
- `windows-proof/report.json`: 47 checks pass in isolated Windows/Wine, including actual BattleShell action-to-log routing, not only standalone controls. Both package probes retain assertions and verify unchanged isolated exports/current manifest. Linux and Windows PCKs are each 313197656 bytes, 5599 members; only `project.binary` differs. No numeric package ceiling applies.
- Existing controller navigation and battle-resolution autosave failure/retry reports both pass under `.artifacts/full_play_runtime_20260905/battle_log_accepted_20260911/`. The earlier controller failure was real: automatic history scrolling added `ui_adjust` records; the preserved diagnostic isolates the history VScrollBar, with unchanged PresentationAudio records. The silent-control fix passes the unmodified existing test. Temporary diagnostic changes were removed.
- `validate-repo.log`: full repository validation passes. Final shared-audio and tracker validators also pass after the silent-control change. `git diff --check` passes.
- Initial scroll-follow timing failure and export-host setup failures are retained as diagnostics, not accepted evidence. The first export service lacked its user environment and created local editor settings; those settings were moved into `failed-export-userdata/`. Final exports use the correct service user. Four obsolete export directories (about 1.5 GiB) were deleted after their processes exited; reports and accepted exports remain. Deleted exports are rebuildable. Unrelated untracked files and caches are untouched.

Final official Linux and Windows export/startup smokes pass (`linux-accepted/report.json`, `windows-accepted/report.json`), including the established Windows generated Overworld/Town flow. No unexpected runtime errors in accepted checks. This closes this narrow UI slice, not overall release readiness.
