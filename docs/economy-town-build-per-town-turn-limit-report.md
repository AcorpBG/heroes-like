# Economy Town Build Per-Town Turn Limit Report

Status: implementation evidence.

Slice: `economy-town-build-per-town-turn-limit-20260524-10184`

## Scope

This slice adds `town_build_per_town_turn_limit_report_v1`, a focused live Godot report proving the one-build limit is per town rather than a hidden global player construction lock.

The report creates a two-town live runtime session, selects Riverwatch, builds once through `OverworldRules.build_in_active_town`, proves a second same-town build is rejected and `TownRules.get_build_actions` is empty for that town, then selects Duskfen on the same session day and proves Duskfen can still build. It then proves Duskfen is also blocked from a second same-day build and both towns expose build actions again on the next day.

## Evidence

- `town_build_per_town_turn_limit_report_v1` uses live `OverworldRules.set_active_town_visit`, `TownRules.get_build_actions`, and `OverworldRules.build_in_active_town`.
- Current focused evidence proves town A same-day second build blocking.
- Current focused evidence proves town B same-day construction still succeeds after town A has built.
- Current focused evidence proves town B same-day second build blocking.
- Current focused evidence proves both towns stamp their own `last_build_day` and expose next-day build actions.
- No `SAVE_VERSION` bump is required.
- `wood` remains canonical.

## Boundaries

- This is a construction-rule gate, not final price tuning, campaign pacing approval, or town UI art approval.
- The report uses a focused two-town fixture with rich resources so the result isolates construction-limit semantics from affordability.
