# Post-Battle Report Screen Implementation Report

Task: #10224
Slice: `ux-post-battle-report-casualty-ledger-10224`
Completed: 2026-09-03

## Root Cause And Correction

Battle resolution already recorded a prose aftermath in `last_battle_aftermath`, but it discarded the terminal per-stack state and routed directly to the Overworld or Scenario Outcome. The player therefore had no dedicated stop where starting strength, survivors, losses, rewards, and strategic consequences could be reviewed.

`BattleRules.gd` now captures an immutable, deterministic version-1 report before the live battle payload is cleared. Each player and enemy stack retains its unit identity, starting count, surviving count, lost count, and destroyed state, with matching side totals. The report stays in the existing session flags/save payload and uses a pending acknowledgement marker, so save version 9 remains unchanged.

`BattleShell.gd` and `AppRouter.gd` now insert `BattleReportShell` between every resolved player battle and its prior destination. Continuing expeditions return to the Overworld; terminal expeditions continue to Scenario Outcome. Entry and acknowledgement use the established autosave authority. A failed acknowledgement save restores the complete pre-acknowledgement session snapshot and keeps the report open for retry, while save/load resume redirects a pending report back to the report screen.

The new screen uses the existing original generated victory/defeat scenic raster art. It presents separate player and enemy casualty cards, per-stack `starting -> surviving -lost` rows, aggregate totals, battle metadata, rewards, artifacts, force state, and composed Overworld consequences. Continue receives initial keyboard/controller focus, has tooltip and accessibility copy, and `ui_cancel` restores focus instead of bypassing the report. The two casualty cards stack into one scrollable column below 1040 logical pixels.

## Focused Evidence

- `POST_BATTLE_REPORT_RUNTIME_REPORT`: passed exact synthetic casualty math; all nine outcome families (`victory`, `defeat`, `hero_defeat`, `town_lost`, `retreat`, `surrender`, `enemy_retreat`, `enemy_surrender`, `stalemate`); a real quick-resolve victory; exact SaveService round trip; pending entry; continuing and terminal destinations; and an injected precommit save failure that retained the pending report.
- 2048x1079 visual capture: `.artifacts/post_battle_report_10224/battle_report_2048x1079.png`, SHA-256 `94c94c99f30fe3e73765b70204c2a69cec3549a5b2947eab3734883a160c0dcc`.
- 1280x720 visual capture: `.artifacts/post_battle_report_10224/battle_report_1280x720.png`, SHA-256 `2df6e2a45f50bced934c20561cd534986f07031fcbdaa723b1afb320ccbbc785`.
- Both captures were visually inspected after rendering. The header, two casualty cards, consequence panel, status copy, and focused Continue control are readable with no clipping or overlap. The focused report also proves the 960x720 compact layout changes to one scrollable casualty column.

## Regression And Package Evidence

Passed focused or directly related runtime checks:

- `battle_resolution_autosave_failure_route_safety_regression.tscn`
- `battle_quick_resolve_runtime_report.tscn`
- `battle_withdrawal_confirmation_runtime_report.tscn`
- `battle_ai_withdrawal_decision_report.tscn`
- `artifact_battle_salvage_execution_report.tscn`
- `battle_active_outcome_diversity_clear_regression.tscn`
- `application_scenario_outcome_autosave_failure_recovery_regression.tscn`
- `scenario_outcome_new_session_confirmation_safe_cancel_regression.tscn`
- `core_systems_regression_smoke.tscn`
- Godot headless editor parse/import
- `python3 tests/validate_repo.py`
- `git diff --check`

The unchanged release gates passed:

- Linux release export and headless startup: 71,071,768-byte executable, 244,997,916-byte PCK, required Linux GDExtension present, no fatal export/boot matches.
- Windows release export and Wine startup/generated-map entry: 104,540,160-byte executable, 244,997,916-byte PCK, required Windows GDExtension present, no fatal export/runtime matches, generated faction/hero flow reached Overworld and Town.
- Both PCKs remain 5,002,084 bytes below the unchanged 250,000,000-byte ceiling and exclude source/development art.

Two broad legacy visual tests still expose unrelated baseline assertions in untouched files: `town_battle_visual_smoke.tscn` expects a wide System command frame that its current responsive Battle UI does not restore, and `scenario_outcome_normal_entry_focus_regression.tscn` expects the expanded `Main Menu` label while the current collapsed Outcome command uses `Menu`. Neither tested file is changed by #10224; focused battle report, battle rules, save routing, Outcome recovery, and package gates pass.

## Non-Claims

This slice does not change combat results, AI, balance, rewards, campaign progression, RMG behavior, Town/Overworld gameplay, save schema, or package limits, and it does not claim whole-game release readiness.
