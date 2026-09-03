# Post-Battle Report Screen Requirements

Task: #10224
Parent: Phase 6 - Production Alpha Layer
Slice: `ux-post-battle-report-casualty-ledger-10224`

## Player Outcome

Every resolved tactical battle pauses on a dedicated, readable battle report before the player returns to the adventure map or advances to the scenario outcome. The report makes losses and consequences understandable without changing how combat is resolved.

## Required Behavior

- Build the report from the authoritative pre-clear battle state at resolution time.
- Show the battle identity and outcome, then separate player and enemy casualty ledgers.
- Each participating stack row shows unit identity, starting count, surviving count, and losses; zero-loss and destroyed stacks remain visible.
- Show totals for deployed, surviving, and lost troops on both sides.
- Preserve existing reward, artifact, commander, frontier, logistics, and scenario consequence summaries when present.
- Route victory, defeat, hero defeat, town loss, retreat, surrender, enemy withdrawal, and stalemate through the same report surface exactly once.
- Acknowledging the report continues to the same destination the battle previously used: the Overworld for a continuing scenario and Scenario Outcome for a terminal scenario.
- The pending report and its casualty data survive autosave/load. Report acknowledgement is transactionally saved before leaving the report; a failed save keeps the report open with a retry message.
- Keyboard and controller focus begins on Continue. `ui_accept` activates it, and mouse input remains available.
- Layout remains readable without clipping at 1280x720 and 2048x1079. At smaller widths, casualty columns stack vertically and remain scrollable.

## Architecture And Data

- `BattleRules.gd` owns the immutable report payload because it owns terminal battle state and casualty calculation.
- `AppRouter.gd` owns report entry, acknowledgement checkpointing, and destination routing.
- `BattleReportShell.gd` only renders the stored payload and sends the acknowledgement intent.
- Store the report in the existing session flags/save payload with a pending marker; do not duplicate or reconstruct battle simulation state in the scene.
- The report sequence/id must be deterministic for an identical resolved session and must not influence combat RNG, rewards, progression, or map state.

## Validation

- Focused Godot report covering per-stack casualty math, every terminal outcome family, report entry, acknowledgement routing, save/load resume, focus/accessibility, and responsive layout constraints.
- Existing battle quick-resolve, withdrawal, battle-resolution checkpoint, outcome, and save regressions.
- `python3 tests/validate_repo.py` and `git diff --check`.
- Linux and Windows export/package startup checks under the unchanged 250 MB package ceiling.
- Visual captures inspected at 2048x1079 and 1280x720.

## Non-Goals

- No combat formula, AI, balance, reward, progression, encounter, campaign, RMG, town, or overworld behavior changes.
- No save-version bump or migration beyond accepting the new pending report payload within existing flags.
- No new unit art, battlefield art, music, sound, copied Heroes assets, or unrelated UI cleanup.
- No claim that this slice makes the whole game release-ready.
