# Strategic AI Event Surfacing Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-event-surfacing-planning-10184`.

## Purpose

Plan the smallest reusable surface for strategic AI events and threat reasons after the River Pass signal-yard pressure gate passed.

The goal is not to build a broad AI dashboard, a full AI hero task system, or a new save schema. The goal is to define a compact public/debug contract that can explain target assignment, site contest, site seizure, pressure summaries, and deterministic reports without covering the overworld with text panels.

This document is planning only. It does not approve gameplay code changes, production content JSON changes, `content/resources.json`, wood id change, rare-resource activation, market-cap overhaul, pathing/body-tile/approach adoption, renderer/editor/save behavior changes, generated PNG import, neutral encounter migration, full AI hero task state, broad strategic AI rewrite, or River Pass rebalance.

## Current Reality

Useful existing surfaces:

- `EnemyAdventureRules.assign_target(...)` already assigns raid targets and records commander target memory.
- `EnemyAdventureRules.resource_target_score_breakdown(...)` and `resource_pressure_report(...)` already expose detailed River Pass resource target reasons for reports.
- Resource candidates already carry `target_debug_reason`.
- `EnemyAdventureRules.advance_raids(...)` already moves raids, resolves arrivals, and returns compact `event_message` strings.
- `_secure_resource_target(...)` already emits site seizure messages such as logistics denial for persistent sites.
- `_contest_encounter_target(...)` already emits a compact event when a raid turns an objective encounter into a live front.
- `EnemyTurnRules.describe_threats(...)` already produces a compact threat summary and includes focus, contestation, visible commanders, commander memory, and public strategy.
- `OverworldRules.describe_dispatch(...)` already has a compact field dispatch surface with latest order, active tile, local threat summary, management watch, and scenario pulse.
- Scenario script recent events and battle recent events exist, but there is no reusable strategic AI event stream yet.

Current gaps:

- Target assignment can be explained in debug data, but there is no standardized event record for assignment.
- Public threat summaries aggregate focus and contestation, but they do not carry a small reason payload that can be reused by UI, reports, and future animation.
- Site contest and seizure messages are message strings, not structured records.
- Detailed score breakdowns are appropriate for reports, but too large for player-facing surfaces.
- Save policy is not explicit: some AI facts are durable state, while many reasons should be recomputed or kept only in turn-local reports.

## Design Decision

Use a two-surface model:

1. Minimal public surface
   - Small, ordered event summaries and threat reasons suitable for existing dispatch/threat text, a compact edge rail, a footer pocket, or a contextual popout.
   - No score tables, no multi-panel reports on the overworld, and no long explanation blocks.
   - Show only important, player-relevant AI actions: a target is being pressured, a visible site is contested, a site is seized, a town front is intensifying, or a visible commander is returning to a known focus.

2. Debug/report surface
   - Full target score breakdowns, selected top candidates, reason codes, component values, and validation payloads.
   - Intended for focused Godot reports, manual gate notes, regression diagnosis, and later developer-only debug panels.
   - Detailed component lists stay out of normal in-game presentation.

This keeps the scenic overworld primary while still giving strategic AI decisions enough traceability for production work.

## Event Schema

Recommended base event fields:

| Field | Required | Surface | Notes |
| --- | --- | --- | --- |
| `event_id` | debug/report | debug | Stable within a turn/report if cheap; may be derived from day, faction, actor, type, and target. |
| `day` | yes | public/debug | Session day when emitted. |
| `sequence` | debug/report | debug | Turn-local ordering index. |
| `event_type` | yes | public/debug | One of the allowed strategic AI event types below. |
| `faction_id` | yes | public/debug | Acting AI faction. |
| `faction_label` | public | public/debug | Display label when available. |
| `actor_id` | optional | public/debug | Raid placement id, commander id, town placement id, or blank for faction-level summaries. |
| `actor_label` | optional | public/debug | Compact display name. |
| `target_kind` | yes | public/debug | `town`, `resource`, `encounter`, `artifact`, `hero`, `pressure`, or future kind. |
| `target_id` | yes | public/debug | Placement id or stable state id. |
| `target_label` | public | public/debug | Compact target name. |
| `target_x` / `target_y` | optional | debug/report | Useful for map focus and validation, not required in public text. |
| `visibility` | yes | public/debug | `visible`, `scouted`, `rumored`, or `hidden_debug`. |
| `public_importance` | yes | public/debug | `low`, `medium`, `high`, or `critical`. |
| `summary` | yes | public/debug | One short player-facing sentence fragment or sentence. |
| `reason_codes` | yes | public/debug | Small stable codes, usually 1-3 entries. |
| `public_reason` | optional | public/debug | Short phrase, e.g. `denies 40 gold daily`. |
| `debug_reason` | debug/report | debug | Existing free-text reason such as `denies 40 gold daily, recruit denial, player-town support`. |
| `score_ref` | debug/report | debug | Optional key into a report-only score breakdown. Do not store full score tables on normal events. |
| `state_policy` | debug/report | debug | `ephemeral`, `derived`, or `durable_state_reference`. |

Allowed first event types:

| Event type | Emits from | Public use |
| --- | --- | --- |
| `ai_target_assigned` | Target assignment after `choose_target(...)` / `assign_target(...)`. | Show only when visible/important or when it changes a known front. |
| `ai_site_contested` | Encounter or site contest handlers. | Public when visible or objective-relevant. |
| `ai_site_seized` | Resource/artifact seizure handlers. | Public when visible, player-owned, or objective-relevant. |
| `ai_pressure_summary` | End of enemy faction turn / threat summary. | Compact line in existing threat/dispatch surfaces. |
| `ai_target_scored` | Reports only. | Never normal public UI; links to score breakdowns. |

Reason code vocabulary for the first slice:

| Code | Meaning |
| --- | --- |
| `persistent_income_denial` | Target denies daily income from a controlled site. |
| `recruit_denial` | Target denies claim or weekly recruits. |
| `player_town_support` | Target supports a player town. |
| `route_vision` | Target provides visibility or route-watch value. |
| `route_pressure` | Target affects a contested lane/front. |
| `objective_front` | Target is near or part of scenario objective pressure. |
| `town_siege` | Town pressure legitimately outranks site denial. |
| `commander_memory` | Commander is returning to or reinforcing a previous focus. |
| `site_seized` | Site control changed to the AI faction. |
| `site_contested` | A site/encounter is locked down but not cleared from play. |

## Storage And Ephemeral Policy

Default policy: recompute reasons and keep event records ephemeral unless the game already stores the underlying strategic fact.

Durable state that already exists or should remain durable:

- Raid target fields: `target_kind`, `target_placement_id`, `target_label`, `goal_x`, `goal_y`, `goal_distance`, `arrived`.
- Commander target memory: focus target, last target, front label, pressure count.
- Site state: `collected`, `collected_by_faction_id`, `collected_day`, response/delivery fields.
- Encounter contest state: `contested_by_faction_id`, `contested_day`.
- Enemy pressure state: pressure, posture, siege progress, commander roster.

Ephemeral or derived data:

- Full score breakdowns.
- `ai_target_scored` events.
- Top candidate tables.
- Most `debug_reason` strings.
- Per-turn public summary events, unless a later UI/replay slice explicitly adds a bounded recent AI event log.

First implementation should avoid save migration. If a recent public AI event list becomes necessary, store only a small bounded list under existing overworld state after a separate implementation decision, with version-tolerant normalization. The planning recommendation is to start without that migration and derive public summaries from current turn results plus existing durable target/site/contest state.

## Public Surface

Public display should stay compact:

- Existing threat summary: add at most one reason phrase to visible focus lines when it is useful, e.g. `march on Riverwatch Free Company Yard (recruit denial)`.
- Existing dispatch surface: keep AI information in the local threat line or a short "Hostile pressure" pocket, not a full report.
- Site seizure: keep current one-line event messages. For persistent logistics sites, the existing seizure message already fits: `seizes Riverwatch Free Company Yard and denies its logistics route`.
- Site contest: keep one-line messages for objective/front changes.
- Optional contextual popout later: when a player inspects a visible raid or threatened site, show target, ETA/pressure state if known, and one short reason. Do not show component scores.

Public importance rules:

- `critical`: town capture/loss, defeat-route pressure, or objective-breaking seizure.
- `high`: visible raid assigned to player-owned `river_free_company`, `river_signal_post`, `riverwatch_hold`, or another objective/resource front.
- `medium`: visible contest or seizure of a player-owned persistent site.
- `low`: hidden movement, low-value pickups, report-only target scoring.

Visibility policy:

- Visible or scouted events can appear in public surfaces.
- Hidden events may contribute to vague summaries such as `Raid hosts are moving beyond the fog`.
- Debug reports can include hidden events when explicitly run.

## Debug And Report Surface

Report/debug output should own detailed explanations:

- `ai_target_scored` records may carry `score_ref` to a score breakdown.
- Resource target reports should continue to include the full fields from `resource_target_score_breakdown(...)`.
- The next implementation report should include a compact AI event report that proves assignment, contest/seizure, and pressure summary records can be generated from the same River Pass state.
- Debug payloads should include top candidates and selected target, but production public UI should not display those tables.

## River Pass First Example

Use the existing signal-yard pressure gate as the first example set.

### Target assignment

When Mireclaw assigns a raid to `river_free_company`:

```json
{
  "event_type": "ai_target_assigned",
  "faction_id": "faction_mireclaw",
  "actor_id": "raid_or_commander_id",
  "target_kind": "resource",
  "target_id": "river_free_company",
  "target_label": "Riverwatch Free Company Yard",
  "visibility": "visible_or_hidden_debug",
  "public_importance": "high",
  "reason_codes": ["persistent_income_denial", "recruit_denial", "player_town_support"],
  "public_reason": "recruit and income denial",
  "debug_reason": "denies 40 gold daily, recruit denial, player-town support",
  "state_policy": "derived"
}
```

When Mireclaw assigns a raid to `river_signal_post`:

```json
{
  "event_type": "ai_target_assigned",
  "faction_id": "faction_mireclaw",
  "target_kind": "resource",
  "target_id": "river_signal_post",
  "target_label": "Ember Signal Post",
  "public_importance": "high",
  "reason_codes": ["persistent_income_denial", "route_vision", "player_town_support"],
  "public_reason": "income and route vision denial",
  "debug_reason": "denies 20 gold daily, route vision, player-town support",
  "state_policy": "derived"
}
```

### Town pressure

When `choose_target(...)` legitimately keeps `riverwatch_hold` above economy denial:

```json
{
  "event_type": "ai_pressure_summary",
  "faction_id": "faction_mireclaw",
  "target_kind": "town",
  "target_id": "riverwatch_hold",
  "target_label": "Riverwatch Hold",
  "public_importance": "critical",
  "reason_codes": ["town_siege", "objective_front"],
  "public_reason": "town siege remains the main front",
  "state_policy": "derived"
}
```

### Site contest and seizure

`ai_site_contested` should cover objective/encounter lockdowns such as existing `_contest_encounter_target(...)` behavior. For the signal-yard proof, site seizure is the more important example:

```json
{
  "event_type": "ai_site_seized",
  "faction_id": "faction_mireclaw",
  "actor_id": "raid_or_commander_id",
  "target_kind": "resource",
  "target_id": "river_free_company",
  "target_label": "Riverwatch Free Company Yard",
  "public_importance": "high",
  "reason_codes": ["site_seized", "persistent_income_denial", "recruit_denial"],
  "summary": "Mireclaw seizes Riverwatch Free Company Yard and denies its logistics route.",
  "state_policy": "durable_state_reference"
}
```

For `river_signal_post`, the equivalent seizure reason is `persistent_income_denial` plus `route_vision`.

## Validation And Manual Gate Plan

Standard validation for the planning slice remains:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
```

Recommended implementation-specific validation for the next slice:

- Add a focused deterministic Godot report for `ai_event_surfacing_report` or extend the existing AI economy pressure report with an event section.
- Construct River Pass states where the player owns `river_signal_post`, then both `river_signal_post` and `river_free_company`.
- Verify `ai_target_assigned` records include target ids, target labels, public importance, reason codes, public reason, and debug reason.
- Verify `riverwatch_hold` can still produce a town-pressure summary when it remains the dominant target.
- Verify site seizure records can be produced from the existing `_secure_resource_target(...)` result shape without changing resource-site behavior.
- Verify objective/encounter contest records can be produced from `_contest_encounter_target(...)` result shape without neutral encounter migration.
- Verify hidden events do not become full public details unless visible/scouted/objective-critical.
- Verify no full score breakdown appears in normal dispatch/threat text.

Manual gate checklist after implementation:

- Start from or construct the Riverwatch signal-yard proof state.
- Capture `river_signal_post`; advance an enemy turn and inspect compact threat/dispatch wording plus debug report.
- Capture `river_free_company`; advance an enemy turn and inspect assignment/pressure reason surfacing.
- Let a raid reach or contest a site if practical; otherwise confirm arrival/seizure event generation by deterministic report.
- Confirm the overworld remains scenery/play-surface first: no text-heavy dashboard, no stacked report boxes over the map.
- Save/resume if any durable AI event list is added. If no durable list is added, confirm target/site/contest state continues to regenerate coherent summaries.

Pass criteria:

- Public surface exposes only compact, actionable reasons.
- Debug/report surface exposes full score and reason details.
- `river_free_company`, `river_signal_post`, and `riverwatch_hold` examples all produce coherent event/reason records.
- Site contest and site seizure are represented by reusable event types.
- No save migration is required for the first implementation unless explicitly justified.

Failure criteria:

- The public surface turns into a score table or text dashboard.
- Event records duplicate full score breakdowns into normal runtime state.
- Event reasons depend on hidden difficulty bonuses or unimplemented resource/object metadata.
- Implementation requires forbidden migrations or broad AI rewrite.

## Boundaries

This plan does not approve:

- Gameplay implementation in this planning slice.
- Production content JSON edits.
- `content/resources.json`.
- wood id change.
- Rare-resource activation.
- Market-cap overhaul.
- Runtime economy rule migration.
- Pathing/body-tile/approach/editor adoption.
- Renderer behavior changes.
- Save format migration as a default requirement.
- Generated PNG import or asset work.
- Neutral encounter migration.
- Full AI hero roster/task state.
- Broad strategic AI rewrite.
- River Pass rebalance.

## Next Slice Recommendation

Recommended next slice: `strategic-ai-event-surfacing-implementation-10184`.

Reason: the current pressure gate passed, and the existing AI code already has the necessary hooks. Implementation should be narrow and report-first:

- Add small helper(s) to build AI event records from target assignment, resource target reasons, contest, seizure, and pressure summary state.
- Keep full score breakdowns debug/report-only.
- Attach only compact public reasons to existing threat/dispatch surfaces when visible or important.
- Prefer ephemeral/derived event records and avoid save migration.
- Add a focused Godot event surfacing report using the River Pass signal-yard cases.

A manual gate should follow implementation. Another foundation track is not recommended before this because later strategic AI expansion needs the event/reason contract first.

## Rollback

For this planning slice, rollback is:

- Remove this document.
- Revert related updates in `PLAN.md`, `ops/progress.json`, and `ops/acorp_attention.md`.

For the recommended implementation slice, rollback should remain narrow:

- Revert event helper/report/threat wording changes.
- Keep production JSON, resource schema, pathing, renderer, editor, save format, generated assets, neutral encounters, full AI hero state, and River Pass balance unchanged.
