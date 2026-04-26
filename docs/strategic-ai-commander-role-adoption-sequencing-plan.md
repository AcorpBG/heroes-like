# Strategic AI Commander Role Adoption Sequencing Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-commander-role-adoption-sequencing-planning-10184`.

## Purpose

Compare the next narrow strategic AI step for commander-role adoption before any schema write, save migration, live commander-role behavior switch, durable event log, defense-specific durable state, coefficient tuning, or full AI hero task implementation.

This slice is planning only. It does not change AI behavior, production JSON, reports/tests, schema, save format, coefficients, pathing/body-tile/approach behavior, renderer/editor behavior, generated PNG imports, neutral encounter migration, `content/resources.json`, `wood` to `timber` migration, rare resources, market caps, or River Pass balance.

## Evidence Baseline

- `docs/strategic-ai-commander-role-report-gate-review.md` passed the report-only gate. The focused `AI_COMMANDER_ROLE_STATE_REPORT` output had `"ok": true`, `schema_status: "report_fixture_only"`, eight reviewed cases, and a passing public leak check across eight compact role events.
- `docs/strategic-ai-commander-role-report-implementation-report.md` records the current implementation boundary. `EnemyAdventureRules.gd` owns report-only front/reason adapters, commander state views, resource target views, role proposals, active encounter linkage, compact public role events, and public leak checks.
- `docs/strategic-ai-minimal-commander-role-state-schema-plan.md` defines the future optional schema location as `session.overworld.enemy_states[].commander_roster[].commander_role_state`, but no schema write is approved.
- `docs/strategic-ai-commander-role-state-plan.md` keeps active raid encounter fields, commander roster continuity, and future commander-role state as separate layers.
- `scripts/core/EnemyTurnRules.gd` currently normalizes enemy states, runs enemy empire cycles, advances raids, and emits compact turn summaries without saved role state.
- `scripts/core/SessionStateStore.gd` still has `SAVE_VERSION := 9`. `SaveService.gd` normalizes save payloads through `SessionStateStore.normalize_payload(...)`; there is no commander-role migration path in the live save pipeline.

## Option Comparison

| Option | Value | Risk | Decision |
| --- | --- | --- | --- |
| Derived live-turn transcript/report surfacing for commander-role decisions | Proves role proposals against current enemy-turn flow and save/resume observations without changing behavior or schema. It can expose whether derived role vocabulary stays coherent when attached to actual turn execution. | Low if kept report-only and routed through existing derived/public event policy. Main risk is accidentally turning report text into player-facing dashboards. | Recommended next slice. |
| Minimal `commander_role_state` write/read adoption | Starts the real schema path and tests old-save compatibility assumptions. | Premature. The role views are still report-derived, no live retask/expiration contract exists, and no visible behavior requires saved state yet. It would increase save/schema risk before proving turn-flow value. | Defer until transcript/report gate passes. |
| Full AI hero task-state sequencing | Aligns with the long-term strategic AI target: real AI heroes, routes, objectives, recovery, and task continuity. | Too broad for the next narrow slice. It pulls in movement, pathing, task queues, front planning, save data, and UI gates before commander role adoption has a live-turn evidence surface. | Defer; use the transcript slice to define its future inputs. |
| Pause commander roles until broader strategic AI hero movement is ready | Avoids premature schema and behavior churn. | Wastes the already useful report-only evidence and leaves no bridge from current raid commanders to future full AI heroes. | Reject as default; keep progress through a behavior-neutral transcript/report slice. |

## Recommended Next Slice

Run `strategic-ai-commander-role-live-turn-transcript-report-planning-10184`.

The slice should plan a behavior-neutral derived transcript/report over existing enemy-turn execution. It should not implement the report yet. Its job is to define exactly how a later report can read current enemy-turn inputs and outputs, attach derived commander-role proposals to the turn trace, and verify public leak boundaries without changing live target selection, raid movement, raid arrival, town-governor choices, save data, or UI composition.

Recommended report marker for the later implementation:

```text
AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT
```

First planned scenarios:

- `river-pass`, `faction_mireclaw`: Free Company and Signal Post pressure with `riverwatch_hold` as the town-front sanity target.
- `glassroad-sundering`, `faction_embercourt`: Glassroad relay and Starlens pressure with `halo_spire_bridgehead` / `riverwatch_market` as supporting town-front and town-governor sanity surfaces.

## Adoption Gates

### Gate 1: Planning Gate

Required before implementation:

- Define report ownership, expected payload, and fixture setup.
- Prove the report can be derived from current session state, enemy states, active encounters, commander roster entries, and current event records only.
- Keep role proposals explicitly marked as `derived` or `report_only`.
- Define public leak checks for compact transcript events.
- Define validation commands and failure conditions.

Pass result: allow a report-only implementation slice.

Fail result: stay at existing `AI_COMMANDER_ROLE_STATE_REPORT` coverage and revisit full AI hero task planning later.

### Gate 2: Report-Only Implementation Gate

Required before schema or live behavior:

- Later report implementation prints one `AI_COMMANDER_ROLE_TURN_TRANSCRIPT_REPORT` payload.
- Payload includes enemy-turn phase records, active commander links, derived role proposal before/after the turn, target assignment or no-op reason, raid movement/arrival summary, town-governor supporting event references, and compact public transcript events.
- River Pass and Glassroad cases pass with no score-table, fixture-token, or raw memory-counter leakage in public surfaces.
- Report proves old-save behavior remains unchanged by not writing `commander_role_state` and by keeping `SAVE_VERSION` unchanged.

Pass result: allow a gate review comparing minimal schema adoption versus another behavior-neutral AI hero planning slice.

Fail result: fix report derivation or pause commander-role adoption. Do not tune coefficients or add schema as a shortcut.

### Gate 3: Live-Client Gate

Required only if a later implementation changes visible enemy-turn pacing, arrival frequency, map pressure, save/resume state, or player-facing turn text:

- Manual live-client enemy-turn review confirms the turn remains readable without dashboard-style overlays.
- Any player-visible commander role text is compact and contextual.
- Save/resume across an enemy-turn boundary preserves current behavior.

Pass result: live surfacing may remain. It still does not by itself approve saved role state.

Fail result: hide or remove live surfacing and return to report-only diagnostics.

### Gate 4: Minimal Schema Adoption Gate

Required before writing `commander_role_state`:

- Transcript report proves a real need for continuity that cannot be derived from existing roster state, active raid encounters, target memory, and day.
- A precise write/read adapter is planned for `enemy_states[].commander_roster[].commander_role_state`.
- Old-save compatibility is tested without bumping `SAVE_VERSION`; a save version bump requires a separate migration plan.
- Role invalidation is defined for missing target, controller change, commander recovery, rebuild state, arrival, and front quieting.
- Rollback can ignore or strip the nested optional field without corrupting commander roster continuity.

Pass result: allow a minimal schema implementation planning slice.

Fail result: continue using derived views and compact event/report surfaces.

### Gate 5: Full AI Hero Task-State Gate

Required before full AI hero tasks:

- Real AI hero movement, route planning, front selection, pathing constraints, fog/scouting assumptions, spell/artifact evaluation, town origin, recovery, and save/load behavior are planned together.
- `commander_role_state` is either retained as a compatibility adapter or explicitly mapped into future task records.
- Player-facing UI composition is planned without covering the overworld with text dashboards.

Pass result: allow full AI hero task-state planning or implementation slices.

Fail result: keep commander roles as derived report/live transcript surfaces.

## Rollback And Escape Hatch

Default escape hatch: disable the new transcript/report path and continue using the existing `AI_COMMANDER_ROLE_STATE_REPORT`.

For the recommended next planning slice:

- No rollback code is needed because no implementation is approved.
- If the planned transcript requires schema writes, durable event logs, or live behavior changes to be useful, reject it and defer commander roles until full AI hero task planning.

For a later report-only implementation:

- Remove the report scene/helper calls and keep existing role report helpers.
- Do not change saves, content JSON, enemy turn behavior, or public UI.
- Treat all transcript records as derived diagnostics.

For a later minimal schema slice:

- The first rollback must be "ignore optional nested `commander_role_state`" rather than a save migration.
- A destructive save migration or `SAVE_VERSION` bump is not allowed without its own plan and old-save fixtures.

## Save And Schema Risk Boundaries

- `SAVE_VERSION` remains `9`.
- No `commander_role_state` writes are approved.
- No save migration or autosave/manual-slot migration is approved.
- `enemy_states[].commander_roster[]` remains the current durable commander identity/continuity owner.
- Active raid encounter fields remain the current map-actor owner for spawned raid movement, target coordinates, arrival, seizure, and embedded `enemy_commander_state`.
- Public commander-role text remains recomputed from reason codes and current target data; labels and public reason strings are not saved.
- Durable event logs remain deferred. Current AI events and role events are derived report/public records.

## Non-Change Boundaries

Do not include any of the following in the next slice:

- implementation, tests, or report helpers;
- schema writes, save migration, `SAVE_VERSION` changes, or production save fixtures;
- live commander-role behavior;
- full AI hero task state, route plans, path arrays, movement budgets, or fog/scouting memory;
- durable event logs or defense-specific durable state;
- coefficient tuning, strategy weight changes, market-cap changes, or River Pass rebalance;
- production JSON edits, neutral encounter migration, `content/resources.json`, `wood` to `timber` migration, rare resources, generated PNG import, renderer/editor work, pathing/body-tile/approach adoption, or asset import.

## Validation Commands

For this planning slice:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
```

For the later transcript/report implementation slice, add focused Godot report coverage only after planning approves the payload:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_commander_role_turn_transcript_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_commander_role_state_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_site_control_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_glassroad_defense_proof_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_town_governor_pressure_report.tscn
```

## Decision

Recommended next step: derived live-turn transcript/report surfacing planning.

Do not adopt minimal `commander_role_state` writes yet. Do not start full AI hero task state yet. Do not pause commander-role work entirely. The narrowest useful bridge is to plan a behavior-neutral transcript report that ties the already-passed commander-role evidence to existing enemy-turn execution, while preserving the save/schema and live-behavior boundaries.
