# Strategic AI Event Surfacing Report Gate Review

Status: passed.
Date: 2026-04-26.
Slice: `strategic-ai-event-surfacing-report-gate-10184`.

## Scope

This gate reviews compact strategic AI event and threat reason surfacing after the River Pass signal-yard pressure implementation.

This review does not approve gameplay/code/content changes, production JSON migration, a durable AI event log, save migration, `content/resources.json`, `wood` to `timber` migration, rare-resource activation, market-cap overhaul, full AI hero task state, broad strategic AI rewrite, pathing/body-tile/approach adoption, renderer/editor behavior changes, generated PNG import, neutral encounter migration, or River Pass rebalance.

## Focused Report Results

Reran:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_event_surfacing_report.tscn
```

Result: passed. The command printed `AI_EVENT_SURFACING_REPORT` with `"ok": true`.

Meaningful output:

- `ai_target_assigned` for `river_free_company` carries public reason `recruit and income denial`, public importance `high`, and reason codes `persistent_income_denial`, `recruit_denial`, `route_pressure`, and `player_town_support`.
- `ai_target_assigned` for `river_signal_post` carries public reason `income and route vision denial`, public importance `high`, and reason codes `persistent_income_denial`, `route_vision`, and `player_town_support`.
- `ai_pressure_summary` for `riverwatch_hold` carries public reason `town siege remains the main front`, public importance `critical`, and reason codes `town_siege` and `objective_front`.
- `ai_site_seized` for `river_free_company` keeps the compact seizure summary: `Mireclaw Raid seizes Riverwatch Free Company Yard and denies its logistics route...`.
- `ai_site_contested` for `river_pass_ghoul_grove` records the objective front as a durable state reference.
- Threat text exposes the compact reason phrase `income and route vision denial`.
- Dispatch text exposes the same compact reason phrase in the local hostile-pressure line.

Also reran:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_economy_pressure_report.tscn
```

Result: passed. The command printed `AI_ECONOMY_PRESSURE_REPORT` with `"ok": true`.

Meaningful output:

- In `signal_post_owned`, resource order is `river_free_company`, `river_signal_post`, `river_sanctum`, `north_timber`, `midway_shrine`, `eastern_cache`; the full selector still chooses `riverwatch_hold`.
- In `signal_post_and_free_company_owned`, resource order remains `river_free_company`, `river_signal_post`, `river_sanctum`, `north_timber`, `midway_shrine`, `eastern_cache`; the full selector still chooses `riverwatch_hold`.
- Owned signal-yard sites keep their priority over reachable simple pickups, and town pressure still legitimately dominates the full target selector.

## Public Surface Review

Public event records and threat/dispatch text stay compact enough for the current gate.

Accepted public fields include target id/label, event type, public importance, short reason codes, one public reason phrase, a summary, and a debug reason. Public event records do not carry score-table fields such as `base_value`, `persistent_income_value`, `recruit_value`, `scarcity_value`, `denial_value`, `route_pressure_value`, `town_enablement_value`, `objective_value`, `faction_bias`, `travel_cost`, `guard_cost`, `assignment_penalty`, or `final_priority`.

Threat and dispatch text also avoid those score-table field names. They show one compact reason phrase in the existing focus/local-pressure line rather than adding a new text-heavy dashboard.

## Gate Decision

Pass.

The implementation satisfies the planned two-surface model for this narrow slice: compact public AI event/threat reasons are available for assignment, pressure summary, site seizure, and site contest examples, while detailed score breakdowns remain in focused report/debug output.

## Manual Live-Client Gate Decision

Manual live-client signal-yard enemy-turn inspection can be deferred.

Rationale: the focused deterministic reports already exercise the River Pass examples required for this gate, the public text remains compact, and the implementation did not add UI layout, save migration, pathing, renderer, or production content behavior that requires immediate live-client composition validation. A manual live-client signal-yard gate should be run later when broader strategic AI pressure expansion starts changing turn flow, visible enemy movement cadence, AI arrival frequency, or player-facing map pressure.

## Recommended Next Slice

Recommended next slice: strategic AI pressure expansion planning.

The next planning slice should define the smallest broader strategic AI pressure expansion after the signal-yard surfacing gate. It should decide whether to expand from River Pass signal-yard pressure into explicit AI event streams, full AI hero roster/task state, town governor pressure, or another narrow opponent-pressure proof. It should remain planning-only until the exact boundary is chosen.

Concept-art curation remains important but is not the direct continuation of this AI gate. Manual live-client gate work is deferred until AI expansion affects live turn readability or AcOrP asks for a fresh enemy-turn transcript.

## Caveats

- `debug_reason` is still present on event records for report/debug use. This is acceptable in the current report gate because it is compact prose and does not include score-table field names or component values beyond human-readable denial phrases.
- The dispatch excerpt includes existing management-watch text unrelated to this slice. The reviewed AI addition is the compact local hostile-pressure reason phrase, not a new dashboard.
- This is still deterministic report evidence, not proof of a complete live-client enemy-turn pacing experience.
