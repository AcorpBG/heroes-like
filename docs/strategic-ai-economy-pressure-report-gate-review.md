# Strategic AI Economy Pressure Report Gate Review

Status: passed.
Date: 2026-04-26.
Slice: `strategic-ai-economy-pressure-report-gate-10184`.

## Scope

This gate reviews the first narrow River Pass strategic AI economy pressure implementation and its focused Godot report output.

This review does not approve production JSON migration, `content/resources.json`, `wood` to `timber` migration, rare-resource activation, market-cap overhaul, full AI hero task state, broad strategic AI rewrite, pathing/body-tile/approach adoption, renderer/editor/save behavior changes, generated PNG import, neutral encounter migration, or River Pass rebalance.

## Validation Command

Focused report command rerun:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_economy_pressure_report.tscn
```

Result: passed. The command printed `AI_ECONOMY_PRESSURE_REPORT` with `"ok": true`.

## Meaningful Target Ordering

Case `signal_post_owned`, with `river_signal_post` set to player control:

1. `river_free_company` - final priority `390`; reason `recruit denial, player-town support`.
2. `river_signal_post` - final priority `363`; reason `denies 20 gold daily, route vision, player-town support`.
3. `river_sanctum` - final priority `168`; reason `claims 100 experience`.
4. `north_timber` - final priority `157`; reason `player-town support`.
5. `midway_shrine` - final priority `145`; reason `player-town support`.
6. `eastern_cache`.

Finding: the player-owned signal post outranks the simple pickup set present in the reachable report (`north_timber`, `eastern_cache`) and remains above other lower-value opportunity targets. `river_free_company` ranking above it is acceptable because it is the same signal-yard economy front and carries recruit denial plus player-town support value, not a simple pickup distraction.

Case `signal_post_and_free_company_owned`, with both signal-yard sites set to player control:

1. `river_free_company` - final priority `466`; reason `denies 40 gold daily, recruit denial, player-town support`.
2. `river_signal_post` - final priority `363`; reason `denies 20 gold daily, route vision, player-town support`.
3. `river_sanctum` - final priority `168`; reason `claims 100 experience`.
4. `north_timber` - final priority `157`; reason `player-town support`.
5. `midway_shrine` - final priority `145`; reason `player-town support`.
6. `eastern_cache`.

Finding: the owned persistent economy sites are the top two resource targets. Free Company correctly outranks Signal Post because it combines daily gold denial, recruit denial, persistent control, and Riverwatch town support.

In both cases, the full target selector chose:

- `target_kind`: `town`
- `target_placement_id`: `riverwatch_hold`

Finding: economy denial did not erase the strategic town front. Riverwatch town pressure can still dominate the full selector in the tested siege context.

## Plan Satisfaction

The implementation satisfies the planned narrow target:

- Explainable scoring: passed. `resource_target_score_breakdown(...)` exposes base value, persistent income, recruit value, scarcity, denial, route pressure, town enablement, objective value, faction bias, travel cost, guard cost, assignment penalty, final priority, and debug reason.
- Owned signal-yard priority over simple pickups: passed. Player-owned `river_signal_post` outranks simple pickups in the signal-post case, and player-owned `river_free_company` plus `river_signal_post` rank first and second in the both-owned case.
- Town pressure still allowed to dominate: passed. `choose_target(...)` still selects `riverwatch_hold` in the opening siege context.
- No hidden difficulty bonus: passed. Reviewed scoring uses current content/state, scenario strategy weights, priority-target ids, distance, guard hints, and assignment penalties. No new difficulty-resource, movement, visibility, or combat bonus is present in the reviewed helper path.
- No broad rewrite: passed. The change stays inside `EnemyAdventureRules` resource scoring/report helpers and focused report coverage. Town, hero, artifact, encounter, delivery interception, renderer, editor, pathing, save, economy schema, and production content migration remain outside this slice.

## Caveats

- `southern_ore` is named in the planning target as a simple pickup comparator, but it is not present in the focused reachable report ordering from the tested origin. This is not a gate blocker because the report still proves the intended priority against the reachable simple pickups and does not show any simple pickup outranking owned signal-yard sites.
- The report is deterministic/debug evidence, not a complete live-client arrival transcript. Arrival and seizure behavior were already covered by existing raid/resource-site rules and were not the focus of this gate.
- Public surfacing remains compact. Detailed score reasons are available in report/debug data and resource candidate metadata, not a player-facing event stream yet.

## Gate Decision

Pass.

The first narrow pressure target is met: the AI can explain why signal-yard economy sites matter, persistent player-controlled sites receive denial value, Free Company recruit value is visible, simple pickups do not distract from owned persistent signal-yard sites, and Riverwatch town pressure remains a legitimate dominant target.

## Recommended Next Slice

Recommended next slice: `strategic-ai-event-surfacing-planning-10184`.

Rationale: coefficient tuning is not needed from this report; the target ordering is coherent. Broad strategic AI pressure expansion should wait until the project has a compact reusable way to surface AI target assignment, site contest, seizure, and threat-summary reasons without building a text-heavy dashboard. The next slice should plan a small public/debug AI event stream and threat-reason surface that can support later strategic AI work.

