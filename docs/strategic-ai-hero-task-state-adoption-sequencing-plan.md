# Strategic AI Hero Task-State Adoption Sequencing Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-hero-task-state-adoption-sequencing-planning-10184`.

## Purpose

Decide the next strategic AI hero task-state adoption sequence after the passed `AI_HERO_TASK_STATE_BOUNDARY_REPORT` gate.

This slice is planning only. It does not implement reports/tests, write `hero_task_state`, bump `SAVE_VERSION`, migrate saves, add durable event logs, add defense-specific durable state, tune coefficients, edit production JSON, implement full AI hero task state, adopt live commander-role behavior, adopt live AI hero behavior, change target selection, change raid movement or arrival, change town-governor choices, change pathing/body-tile/approach behavior, change renderer/editor behavior, import generated PNGs, migrate neutral encounters, add `content/resources.json`, change wood resource ids, activate rare resources, overhaul market caps, rebalance River Pass, push, or open a PR.

## Evidence Boundary

Accepted inputs:

- `docs/strategic-ai-hero-task-state-report-gate-review.md` passed. The focused report printed `AI_HERO_TASK_STATE_BOUNDARY_REPORT` with `ok: true`, `schema_status: "task_state_boundary_report_only"`, `behavior_policy: "derive_candidate_tasks_only"`, `save_policy: "no_hero_task_state_write"`, seven reviewed cases, nine checked candidate tasks, old-save absence, no save version change, and public leak checks across eight compact public task events.
- `docs/strategic-ai-hero-task-state-report-implementation-report.md` records that current task helpers in `EnemyAdventureRules.gd` are derived/report-only and do not drive target selection, movement, arrival, town-governor choices, or save writes.
- `docs/strategic-ai-hero-task-state-boundary-plan.md` defines the future task-state shape, task ids, ownership/lifecycle, role-to-task adapter path, route/task ownership split, invalidation rules, save/schema risks, old-save compatibility, and rollback/escape hatch.
- `docs/strategic-ai-commander-role-live-turn-transcript-report-gate-review.md` passed. It proves the current live enemy turn can be explained from before/after derived snapshots without saved commander-role state.

Current code reality to preserve:

- `EnemyTurnRules.normalize_enemy_states(session)` rebuilds each `enemy_states[]` record from known fields: faction id, pressure, counters, siege progress, treasury, posture, captured artifact ids, and normalized commander roster. A future `enemy_states[].hero_task_state` field would be dropped unless a later slice intentionally preserves or normalizes it.
- `SessionStateStore.SAVE_VERSION` is `9`, and no task-state gate has approved changing it.
- `SaveService` normalizes top-level payloads through `SessionStateStore.normalize_payload(...)` and writes the current `SessionStateStore.SAVE_VERSION`; it should not become the owner of strategic AI task semantics.
- Old saves have no `hero_task_state`; absence currently means no saved task board and derived report candidates only.

## Option Comparison

| Option | Value | Risk | Decision |
| --- | --- | --- | --- |
| Minimal schema planning next | Could turn the draft task-state shape into exact fields and defaults. | Premature because the normalizer/drop behavior is the immediate save-safety risk, and schema planning can imply writes before preservation is proven. | Defer. Use after the preservation report gate passes. |
| Report-only save-normalizer preservation planning | Targets the concrete next risk: future optional `hero_task_state` must survive enemy-state normalization when present, old saves must remain compatible when absent, and no `SAVE_VERSION` bump should occur unless separately planned. | Low if kept planning/report-only. Main risk is accidentally treating synthetic task boards as approved schema. | Recommended next. |
| Live behavior transcript proof | Could prove candidate tasks against another live enemy-turn transcript. | Too early. The current evidence boundary already explains live turns, and this would pull toward behavior adoption without save-normalizer safety. | Defer. |
| Full AI hero task-state planning | Could plan route execution, actors, task boards, pathing, save/load, and UI together. | Too broad for the next slice. It would mix normalizer safety, route/pathing, target selection, and UI gates before the narrow save boundary is proven. | Defer. |
| Pause AI and return to another foundation track | Avoids AI schema risk. | Loses momentum on a concrete save-boundary issue exposed by the passed task-state report gate. | Reject as default. |

## Recommended Next Slice

Run `strategic-ai-hero-task-state-save-normalizer-preservation-planning-10184`.

Purpose:

- Plan a future report-only preservation proof for optional `enemy_states[].hero_task_state`.
- Keep derived reports as the current evidence boundary while checking the exact save/normalization edge before schema planning.
- Define how a later report can use synthetic fixture-only task boards to inspect normalization behavior without approving live schema writes.

The next planning document should define a future `AI_HERO_TASK_STATE_NORMALIZER_PRESERVATION_REPORT` or equivalent report marker. It should plan cases for:

- old-save absence: no `hero_task_state` field normalizes as no saved tasks and does not bump `SAVE_VERSION`;
- optional future field preservation: a synthetic fixture-only `hero_task_state` survives `EnemyTurnRules.normalize_enemy_states(...)` only if a later implementation explicitly preserves it;
- malformed future task-state tolerance: invalid synthetic task records are ignored or downgraded in report views without corrupting commander roster continuity;
- unknown field isolation: preserving `hero_task_state` must not preserve arbitrary enemy-state junk as live behavior state;
- SaveService boundary: top-level save/restore compatibility remains owned by `SessionStateStore`/`SaveService`, while strategic task semantics stay in enemy-turn/adventure rules;
- no-write policy: no report fixture writes task state back to production saves.

## Gates

Gate 1: this sequencing plan.

- This document exists.
- `PLAN.md`, `ops/progress.json`, and `ops/acorp_attention.md` mark adoption sequencing complete.
- Recommended next slice is save-normalizer preservation planning, not schema writes or live behavior adoption.

Gate 2: save-normalizer preservation planning.

- Define exact report marker, fixture payloads, failure conditions, and validation commands.
- Explicitly state that any synthetic `hero_task_state` fixture data is report-only and not approved live schema.
- Define the expected `EnemyTurnRules.normalize_enemy_states(...)` preservation policy before implementation.

Gate 3: report-only preservation implementation.

- Only after Gate 2.
- If implemented later, prove old-save absence, optional future-field preservation policy, malformed-state tolerance, and no save-version change.
- Keep task records unsaved except synthetic fixture payloads.

Gate 4: minimal schema planning.

- Only after the preservation report gate passes.
- Decide exact schema shape, normalizer behavior, old-save fixtures, malformed-state handling, and whether a `SAVE_VERSION` change is necessary.
- No schema write is allowed unless separately planned.

Gate 5: schema write/read adoption.

- Only after schema planning and old-save fixtures.
- Must include rollback/ignore-optional-state behavior.
- Must not drive live target selection or movement yet.

Gate 6: live AI hero/task behavior.

- Separate later gate.
- Requires route ownership, actor ownership, target selection integration, manual live-client pacing/readability review, save/resume behavior, and UI composition planning.

## Risks

- Normalizer loss: `EnemyTurnRules.normalize_enemy_states(...)` currently drops unrecognized enemy-state fields. A future optional task board would disappear unless intentionally handled.
- Silent schema drift: adding `hero_task_state` without fixtures could create data that appears saved but is lost on enemy-turn normalization.
- Old-save regression: treating missing `hero_task_state` as malformed would break saves that predate task boards.
- Version confusion: optional report-only or schema-planning work must not bump `SAVE_VERSION`; a bump needs a separate migration plan and fixtures.
- Semantic leakage: `SaveService` should not own task validation, role adapters, target reservations, route policy, or public AI reason generation.
- Fake planner risk: synthetic fixture task boards must not be mistaken for live AI hero task implementation.
- Public-surface leakage: compact public task events must continue to hide task ids, source ids, score tables, fixture annotations, route fields, body tiles, approach fields, and save/schema fields.

## Rollback And Escape Hatch

For this planning slice:

- No rollback code is needed because no implementation changed.

For the recommended preservation report planning/implementation path:

- Remove or disable the focused report scene/helpers if they become noisy.
- Keep the existing `AI_HERO_TASK_STATE_BOUNDARY_REPORT` as the evidence boundary.
- Continue treating missing `hero_task_state` as no saved tasks.
- Continue deriving candidate tasks from commander-role/report snapshots.
- Do not change `SAVE_VERSION`, live enemy-turn behavior, target selection, movement, arrival, town-governor choices, production JSON, or saves.

For a later schema adoption:

- The first runtime escape hatch must be ignoring optional `hero_task_state` and falling back to current active raids, commander rosters, target memory, and derived reports.
- If optional task state creates duplicate target ownership, stale actor links, stale route assumptions, or old-save regressions, disable task execution and return to report-only candidate generation.

## Completion Decision

Strategic AI hero task-state adoption sequencing is complete.

The next recommended slice is report-only save-normalizer preservation planning. Minimal schema planning, live behavior transcript proof, full AI hero task-state planning, and an AI pause are all deferred until the normalizer/save boundary is planned and then proved without schema writes, save migration, or `SAVE_VERSION` changes.
