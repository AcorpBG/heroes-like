# Readable Battle Turns And Melee Approach

Owner-directed Phase 6 slice `battle-readable-turns-and-melee-approach-20260910`, derived from `project.md` and `PLAN.md`.

## Requirements

- Enemy actions must be understandable as ordered movement, attack, impact and retaliation, rather than overlapping updates or instant final-state jumps. Preserve compact battle composition and identify the acting stack/target.
- Clicking a reachable enemy with a melee stack must allow movement to a legal adjacent hex and attack as one action, respecting movement points, obstacles, occupancy, status, retaliation and determinism. Show the approach/attack intent before confirmation; preserve ranged and unreachable-target behavior.
- Runtime/domain rules own legality and simulation. Presentation must not change damage RNG or let input race unfinished playback. Normal, fast, instant and reduced-motion settings remain supported.
- Focused regressions, real rendered action evidence, existing affected battle tests, repository validation and Linux/Windows export/gameplay checks are required before completion. Keep reports compact and preserve unrelated untracked files and caches.

## Scope

BattleRules, BattleShell, BattleBoardView, narrowly related animation helpers and Python-owned tests. No RMG, art generation, broad balance/content changes, new save schema or unrelated cleanup.

## Source diagnosis and implementation

The old `board_click_attack_intent_for_target` offered Strike only if `_can_make_melee_attack` was true at the current hex. `_resolve_move_action` then completed the entire action, so moving adjacent and striking required separate turns. `melee_approach_destination` now derives a deterministic nearest adjacent empty cell from the existing reachable-cell authority. Board targeting, legal-target highlights, Strike availability and the preview use this same intent. Actual Strike applies the legal approach, existing movement pressure/objective effects and the existing damage/retaliation resolver, completing the turn once. Already-adjacent/reach attacks and ranged-priority clicks remain direct. Enemy melee stacks choosing Advance can use the same legal approach and strike; this changes action economy as requested, not damage formulas or RNG policy.

`_complete_action` drains enemy turns synchronously. Previously the board refreshed only after that drain, and its per-stack animation dictionary overwrote earlier events; all surviving records started together. Movement, hits and retaliation could disappear or overlap. `BattleActionPlayback.gd` now captures opt-in intermediate battle views at movement/event boundaries. Capture also observes lower-priority events without changing the authoritative priority-filtered event stream. Each view contains one visual event, the corresponding stack counts/positions and acting-stack identity. These temporary views are removed from the live battle before the synchronous call returns, stripped from exit/context snapshots, and consumed by the UI rather than returned as gameplay result fields. Ordinary headless rule callers do not capture them.

BattleShell plays those views in order for player actions, enemy responses and enemy-first battle entry. The board shows a compact, readable action strip with actor/target and damage/casualties, and the header no longer claims a stale active stack during playback. Movement follows a BFS-derived free-hex visual path using the same neighbor/occupancy conventions; no simulation path rules were changed. Fast mode shortens playback while retaining motion; Instant skips the queue, and reduced-motion keeps the existing static-motion policy and readable captions. Normal-play inputs and manual Save/Menu actions cannot race pending playback. Controller-origin results are announced after the live session and command focus are restored, with the existing session/turn/focus guards.

Terminal resolution still reaches its existing durable autosave checkpoint before visual exit playback; a failed checkpoint shows the existing retry surface and cannot route. Playback completion uses the already-authorized route rather than reapplying combat or the checkpoint. The existing validation-only routing-disable mode retains synchronous controls, consistent with its prior exit-animation behavior.

## Validation (completed 2026-09-10)

Evidence root `.artifacts/battle_readability_20260910/`. The Python-owned `battle_readability_regression.py` tests reachable/blocked/occupied approaches, direct adjacency, enemy move-and-strike, enemy-first entry, exact full-session equality between captured and ordinary rule execution, no temporary save fields, ordered single-event frames, contiguous movement paths, real board-click playback, input rejection, focus restoration and Instant skipping with normal routing enabled. The final visual probe also checks the actual captured dimensions after SettingsService applies its window preferences. These are controlled battle fixtures, not balance/playthrough certification; their enlarged health pools deliberately keep the exchange alive, and normalized authored unit HP produces atypically large displayed counts.

Accepted affected runtime reports are retained under `.artifacts/full_play_runtime_20260905/`: `battle_readability_existing_20260910` (deterministic RNG, quick resolve, post-battle report), `battle_readability_existing_v3_20260910` (withdrawal), `battle_readability_existing_v4_20260910` (controller), `battle_readability_route_final_20260910` (resolution autosave failure/retry), `battle_speed_final_20260910` (speed-setting write failure/recovery), and `battle_cues_final_20260910` (shared load/save cues). All nine named reports pass without unexpected runtime errors. Only the named passing rows are accepted in mixed earlier reports.

Final dimension-measured tests pass 63 checks each: `measured-fast-1920` (source Fast, 1920x1080), `measured-reduced-1280` (source reduced-motion, 1280x720), and `linux-measured-final` (packaged Normal, 1280x720). Inspected `linux-measured-final/action-2.png` shows the isolated impact/loss caption; `measured-fast-1920/action-5.png` shows the enemy strike/target caption. The measured captures contain the full controls without viewport clipping; sprite labels can naturally approach each other during a melee lunge, while the separate action strip remains readable. Nine ordered events are observed per rendered exchange.

Exported Windows rule/resource tests pass 39 checks in `windows-measured-final` (headless). SHA-locked probes retain all assertions and use compiled battle owners from the actual isolated exports. Official `linux-final/report.json` and `windows-final/report.json` pass, including Windows generated-map entry and Town construction. Linux/Windows PCKs each contain 5591 members / 313177932 bytes; member names match and only `project.binary` differs. Final exports are retained; two superseded task-owned export directories were removed after checking their processes had finished. Their reports remain, caches and pre-existing unrelated artifacts are untouched. Full `python3 tests/validate_repo.py` passes (retained `validate-repo-final.log`); `git diff --check` passes. The heroes-progress workflow tracks this as a completed Phase 6 implementation slice, not release readiness.

Earlier report failures are retained as diagnostics: two temporary probe type-inference errors; enemy fixture still carrying a spell-capable secondary hero payload; result comparisons including temporary playback arrays; controller tests checking focus before playback ended and controller feedback being published during a detached presentation view. The test's settle helper now waits for the real visual handoff; production deferred controller publication and snapshot consumption fix the corresponding defects. No gameplay assertion was removed.

Finalization also caught playback reading a global preference instead of the battle's authoritative speed. The queue now starts from the captured battle speed and only adopts successfully committed speed changes, preserving Instant exit timing and write-failure recovery. Repository structural checks were updated from synchronous-only signatures to require controller-origin deferred publication after focus restoration, and load-cue consumption after either ordinary entry refresh or enemy-first playback. Their underlying guard assertions remain. Visual inspection caught SettingsService resizing the probe window; the corrected test explicitly measures the requested capture dimensions rather than trusting launch arguments.

Commands:

```sh
python3 -B tests/battle_readability_regression.py --label <fresh> --render
python3 -B tests/battle_readability_regression.py --label <fresh> --render --speed fast --resolution 1920x1080
python3 -B tests/battle_readability_regression.py --label <fresh> --render --reduced-motion
python3 -B tests/full_play_validation_suite.py --label <fresh> --rendered --accessibility disabled --only battle_deterministic_rng_state_report battle_quick_resolve_runtime_report battle_withdrawal_confirmation_runtime_report post_battle_report_runtime_report battle_controller_board_navigation_smoke battle_resolution_autosave_failure_route_safety_regression
python3 tests/validate_repo.py
git diff --check
python3 -B tests/packaging_linux_export_smoke.py
python3 -B tests/packaging_windows_export_smoke.py
python3 -B tests/packaged_battle_readability_regression.py --platform linux --binary <isolated-linux-exe> --pack <matching-pck> --label <fresh> --render
python3 -B tests/packaged_battle_readability_regression.py --platform windows --binary <isolated-windows-exe> --pack <matching-pck> --wine-prefix <new-task-owned-prefix> --label <fresh>
```

Export helpers must run serially because they share the import cache. Packaged tests reuse the existing SHA-locked bootstrap without loose game scripts/resources. Windows Wine headless checks prove rules and packaged resource loading, not Windows GPU animation quality. No art or native binaries changed, no package size ceiling was added, and no universal combat-balance or release-ready claim is made.
