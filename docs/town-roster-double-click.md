# Town roster double-click entry

Phase 6 owner-directed slice `ui-town-roster-double-click-20260911` (completed 2026-09-11), derived from project.md and PLAN.md.

The right-hand Overworld town roster currently connects only `pressed` to selection/centering. Add left-button double-click entry to the exact owned town, via `_visit_selected_town` and the existing authoritative town-visit/router path. Single click and keyboard selection remain unchanged. Resolve the current placement by id rather than stale coordinates; reject missing/lost towns and input during transitions or modal/turn blocking. Preserve hero position, movement, ownership, economy, save schema and town development. No art, RMG, map click redesign, or unrelated cleanup.

Targets: `scenes/overworld/OverworldShell.gd`; focused Python-owned Godot pointer/entry regression. Validate single-click selection, non-left and release events, stale/lost ownership, blocked input, retained buttons after refresh, exact scene/placement entry and unchanged hero/resources. Run source and isolated Linux/Windows release probes, official exports, `python3 tests/validate_repo.py`, and `git diff --check`. Perform completion cleanup and preserve evidence.

## Implementation

Town cards now connect `gui_input` once, alongside the unchanged `pressed` selection handler. Only a pressed left-button double-click activates entry. The handler checks existing input/turn/session guards, resolves current ownership by placement id, uses the existing entrance/level selection helper, verifies the selected placement, and calls `_visit_selected_town()`. That path retains `OverworldRules.set_active_town_visit()` and `AppRouter.go_to_town()` authority. Tooltip/accessibility text explains the shortcut and existing Enter Town alternative. Map-surface click behavior is unchanged.

Evidence root: `.artifacts/town_roster_double_click_20260911/`. `source-final/report.json` passes 18 checks opening Riverwatch; `source-remote-final/report.json` and `linux-proof/report.json` pass 20 checks opening Duskfen while Riverwatch was previously active. These use real viewport mouse events and the actual Town scene, not a router stub. Source Town screenshots inspected at 1280x720 and Linux package capture at 1920x1080. The remote test fixture gives the existing second holding to the player without altering production content, then verifies unchanged hero position, movement and resources. Run it with `TOWN_ROSTER_REMOTE=1 python3 -B tests/town_roster_double_click_regression.py --label <new-label> --render`.

Release probes use `tests/packaged_town_roster_double_click_regression.py` with the established platform, binary, pack and label arguments (plus a fresh `--wine-prefix` for Windows). Linux/Windows packs contain 5599 matching members, except platform `project.binary`, and are each 313201272 bytes. Windows is headless Wine validation, not physical-GPU certification. This UI slice makes no release-readiness claim.

`windows-proof/report.json` also passes all 20 remote-entry checks without runtime errors. Official Linux/Windows export/startup checks pass, including the Windows generated Overworld/Town building flow. The prior command-roster repository assertion was updated only to match the expanded accessibility description.

Completion cleanup removed two obsolete fixture-debug capture directories (3,065,668 bytes, about 2.92 MiB; rebuildable). All three disposable Wine prefixes were cleaned by the existing managed lifecycle. Final reports/screenshots/packages, caches, source and unrelated pre-existing files are retained.

`python3 -B tests/validate_repo.py` passed (`validate-repo.log`), and `git diff --check` passed. Only the selected UI behavior, its regression tests and tracking/docs are included in the commit.
