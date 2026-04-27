# Strategic AI Glassroad Defense Proof Report

Status: passed.
Date: 2026-04-26.
Slice: `strategic-ai-glassroad-defense-proof-report-10184`.

## Scope

This report proves the bounded Embercourt `glassroad-sundering` defense and stabilization surfaces selected in `docs/strategic-ai-glassroad-defense-proof-plan.md`.

Primary site: `glassroad_watch_relay`.

Companion site: `glassroad_starlens`.

Town-front sanity target: `halo_spire_bridgehead`.

Town governor defense signal: `riverwatch_market`.

This slice added focused Godot report scaffolding only. It did not tune coefficients, change AI behavior, edit production JSON, add durable event logs, migrate saves, implement full AI hero task state, add defense-specific durable state, change pathing/body tiles/approach behavior, alter renderer/editor behavior, migrate neutral encounters, add `content/resources.json`, change wood resource ids, activate rare resources, overhaul market caps, rebalance River Pass, import generated PNGs, push, or open a PR.

## Focused Report

Command:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_glassroad_defense_proof_report.tscn
```

Result: passed. The command printed `AI_GLASSROAD_DEFENSE_PROOF_REPORT` with `"ok": true`.

## Meaningful Output

Fixture sanity passed for `glassroad-sundering`:

- Player faction: `faction_sunvault`.
- Enemy faction: `faction_embercourt`.
- Enemy label: `Charter Road Wardens`.
- Enemy town: `riverwatch_market`.
- Town-front sanity target: `halo_spire_bridgehead`.
- Enemy priority targets include `halo_spire_bridgehead`, `glassroad_watch_relay`, `glassroad_starlens`, and `glassroad_beacon_wardens`.
- Scenario overrides match the plan: `faction_outpost: 1.55`, `frontier_shrine: 1.2`, `town: 1.4`, `resource: 0.95`, `encounter: 1.2`, and `town_siege_weight: 1.5`.

With `glassroad_watch_relay` and `glassroad_starlens` staged as player-controlled persistent sites, the focused resource ordering from Embercourt origin `{x: 9, y: 1}` is:

1. `glassroad_watch_relay`
2. `glassroad_starlens`
3. `glassroad_lens_house`
4. `glassroad_wood`
5. `glassroad_ore`
6. `market_cache`
7. `glassroad_shrine`

`glassroad_watch_relay` carries public reason `income and route vision denial` with reason codes `persistent_income_denial`, `route_vision`, and `player_town_support`.

`glassroad_starlens` carries public reason `route pressure` with reason code `route_pressure`. This remains a coarse current-metadata reason, but the stabilization surface is present: `Relight Shrine`, `watch_days: 3`, `readiness_bonus: 1`, `pressure_bonus: 1`, and `recovery_relief: 2`.

The full `choose_target(...)` sanity check still chooses:

- `target_kind`: `town`
- `target_placement_id`: `halo_spire_bridgehead`
- `target_label`: `Halo Spire`
- `public_reason`: `town siege remains the main front`

This is accepted. The proof does not force relay targets globally above the main town front.

## Assignment And Retake

The focused relay assignment event is:

- `event_type`: `ai_target_assigned`
- `target_id`: `glassroad_watch_relay`
- `public_reason`: `income and route vision denial`
- `public_importance`: `high`
- `reason_codes`: `persistent_income_denial`, `route_vision`, `player_town_support`
- `state_policy`: `derived`

The staged current-system raid arrival retakes the relay:

- before: `player`
- after: `faction_embercourt`

The resulting seizure event is:

- `event_type`: `ai_site_seized`
- `target_id`: `glassroad_watch_relay`
- `public_reason`: `income and route vision denial`
- `public_importance`: `high`
- `reason_codes`: `site_seized`, `persistent_income_denial`, `route_vision`, `player_town_support`
- `state_policy`: `durable_state_reference`
- summary includes compact logistics denial wording and the current recovery side effect: `Halo Spire recovery +1 from Prism Watch Relay | 1 day to stabilize.`

The current `_secure_resource_target(...)` effects are visible in the report:

- pressure before: `0`
- pressure after: `1`
- treasury before: `{}`
- treasury after: `{"gold": 60}`

No relay retake blocker was found.

## Town Governor Stabilization

The Riverwatch town governor stabilization case passes:

- `ai_town_built` for `building_market_square` / Market Square.
- Selected build category: `economy`.
- Selected build public reason: `builds pressure`.
- Dominant debug components include `weighted_market_value`, `weighted_income_value`, `weighted_quality_value`, and `weighted_pressure_value`.
- `ai_town_recruited` for 9 River Guard.
- Recruitment destination: `garrison`.
- Recruitment public reason: `stabilizes garrison`.
- Recruitment reason code: `garrison_safety`.
- `ai_garrison_reinforced` for `riverwatch_market`.

The accepted caveat remains that Market Square's compact public build phrase is still `builds pressure`; the report/debug components explain the market and income stabilization reason.

## Public Surface Check

The public compact/leak check passed across assignment, pressure, seizure, and town-governor events.

Public events used the shared compact event keys: event id/day/sequence, event type, faction, actor, target, visibility, public importance, summary, reason codes, public reason, debug reason, and state policy.

Public event records did not expose score-table keys such as `base_value`, `persistent_income_value`, `denial_value`, `assignment_penalty`, `final_priority`, `final_score`, `income_value`, `growth_value`, `pressure_value`, `category_bonus`, or `raid_score`.

Detailed score fields remain in report/debug target and town-governor rows only.

## Caveats

- This is deterministic proof scaffolding, not a live-client enemy-turn pacing transcript.
- The relay retake is staged at the target to prove current seizure/controller-flip behavior directly.
- The full selector can still prefer `halo_spire_bridgehead`; this is a valid town-front result.
- Starlens stabilization is a companion reason/profile surface, not a second broad seizure path.
- No defense-specific durable state need was proven.
- No coefficient defect was found.

## Gate Decision

Pass.

Current systems prove the selected Embercourt Glassroad defense and stabilization surfaces: player-owned `glassroad_watch_relay` and `glassroad_starlens` are high-value Glassroad targets in the expected order, the relay assignment event is compact and reasoned, a staged Embercourt raid can retake the relay and flip controller state, Starlens exposes its current stabilization profile, Riverwatch's town governor emits garrison stabilization events, and public records do not leak score-table fields.

## Recommended Next Slice

Recommended next slice: `strategic-ai-commander-role-state-planning-10184`.

Rationale: this proof did not expose a relay retake blocker, defense-specific durable state need, or coefficient defect. Defense-specific state planning and bounded coefficient tuning should remain deferred. The next useful strategic AI foundation step is planning explicit commander-role state boundaries for future non-staged assignment, defense, raid, and recovery behavior without implementing full AI hero task state yet.
