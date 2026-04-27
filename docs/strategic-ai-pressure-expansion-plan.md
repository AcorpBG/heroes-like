# Strategic AI Pressure Expansion Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-pressure-expansion-planning-10184`.

## Purpose

Choose the smallest useful broader strategic AI pressure expansion after the River Pass signal-yard scoring and compact event surfacing gates.

This plan uses `docs/strategic-ai-event-surfacing-report-gate-review.md` as a contract: public output stays compact, score tables stay in debug/report output, and a live-client gate is required only when a later slice changes visible turn pacing, enemy arrival frequency, map pressure, or UI composition.

This slice is documentation/planning only. It does not approve gameplay/code changes, production JSON migration, durable AI event log migration, save migration, `content/resources.json`, wood id change, rare-resource activation, market-cap overhaul, full AI hero task state, broad strategic AI rewrite, pathing/body-tile/approach adoption, renderer/editor behavior changes, generated PNG import, neutral encounter migration, or River Pass rebalance.

## Current Reality

Relevant current code and content:

- `EnemyAdventureRules` now has compact event helpers for target assignment, pressure summaries, site seizure, and site contest.
- `EnemyAdventureRules.resource_target_score_breakdown(...)` and `resource_pressure_report(...)` can explain why River Pass signal-yard sites matter while keeping score fields out of public text.
- `EnemyTurnRules.run_enemy_turn(...)` still returns compact messages and drives the empire cycle through income, weekly musters, town building, recruitment, pressure gain, raid advancement, raid spawning, siege, and intercept checks.
- `EnemyTurnRules._score_build_candidate(...)` already scores enemy town builds using income, growth, quality, readiness, pressure, recovery, market value, category weights, garrison need, and raid need.
- `EnemyTurnRules._choose_recruit_destination(...)` already chooses between garrisoning, feeding active raids, and rebuilding commanders using local defense, front state, strategy weights, and raid/rebuild need.
- River Pass has the enemy `duskfen_bastion` town for `faction_mireclaw`; its config emphasizes resource target pressure and raid reinforcement through `raid_target_weights.resource`, `site_denial_weight`, `hero_hunt_weight`, and `reinforcement.raid_bias`.

Current gap:

- The AI can explain resource target pressure and compact raid events, but the existing town governor pressure is still mostly opaque. Builds, recruits, garrison choices, raid reinforcement, and commander rebuilds affect future pressure, but there is no focused report or compact event contract that explains those choices.

## Option Comparison

| Option | Value | Risk | Decision |
| --- | --- | --- | --- |
| Explicit AI event streams | Useful for playback and later UI, but the narrow event helpers already exist. Making them durable now would mostly create save/log policy work. | Medium to high if it becomes a saved event log or UI surface before the next pressure behavior needs it. | Do not make this the next expansion. Keep events ephemeral/derived for the next slice. |
| Full AI hero roster/task state | Eventually required for production AI. It would move raids toward real computer heroes, roles, tasks, path plans, recovery, and continuity. | Very high now. It implies save migration, state normalization, pathing/fog/movement contracts, and broad behavior changes. | Defer. Plan later after another pressure proof and report surface exist. |
| Town governor pressure | High value and small boundary. Existing code already builds, recruits, garrisons, reinforces raids, and rebuilds commanders. A report/event slice can explain those choices without changing behavior. | Moderate if it changes build/recruit behavior; low if report/debug only. | Recommended next slice. |
| Faction personality pressure | Important, and some `enemy_strategy` data exists. It is better as a follow-up once town and raid choices both have report surfaces. | Medium. Personality claims become hand-wavy without build/recruit/raid evidence. | Follow-up after town governor report coverage. |
| Another narrow opponent-pressure proof | Safe and concrete, but another River Pass resource proof would mostly repeat the signal-yard gate unless it covers a new pressure source. | Low, but lower leverage than exposing town pressure. | Fold into the town governor slice using River Pass / Duskfen as the first example. |
| Defer AI expansion to concept-art/foundation track | Useful if the project needed visual direction more than AI, but this is not the direct continuation of the passed AI gate. | Low technical risk, but it leaves the current AI pressure gap unaddressed. | Do not defer. Keep concept-art work separate from this AI continuation. |

## Recommendation

Recommended next concrete slice: `strategic-ai-town-governor-pressure-report-implementation-10184`.

Boundary:

- Implement behavior-neutral town governor pressure reporting and compact derived event records for existing enemy town choices.
- Cover Duskfen / Mireclaw in River Pass first because it already participates in the signal-yard pressure loop and has a current enemy town, raid bias, and pressure objective.
- Explain current build and recruitment choices without changing the chosen build, the chosen recruit destination, raid launch thresholds, target scoring, resource economy, pathing, saves, or content JSON.

The next slice should answer these questions:

- Which build would the enemy town choose now, and which scoring components made it win?
- Did the choice increase future income, recruit growth, readiness, pressure output, recovery, market support, garrison safety, or raid throughput?
- Did recruited troops go to garrison, active raid reinforcement, or commander rebuild, and why?
- Did the town choice create a compact public pressure reason, such as `feeds raid hosts`, `stabilizes garrison`, `builds pressure`, `unlocks recruits`, or `rebuilds command`?

## Implementation Boundary For The Next Slice

Allowed:

- Add report/debug helpers around existing `EnemyTurnRules` town build and recruit decisions.
- Add focused Godot report coverage that runs River Pass enemy town pressure examples and prints a compact `AI_TOWN_GOVERNOR_PRESSURE_REPORT`.
- Add compact derived event records such as `ai_town_built`, `ai_town_recruited`, `ai_garrison_reinforced`, `ai_raid_reinforced`, and `ai_commander_rebuilt` if they reuse the event-surfacing contract.
- Keep public summaries to one short phrase per important town action.
- Keep detailed build/recruit score components in report/debug output only.

Not allowed:

- No behavior tuning unless a report proves an existing code bug that must be fixed within the slice.
- No production content JSON changes.
- No new AI profile schema or `content/resources.json`.
- No durable AI event log or save migration.
- No full AI hero roster/task state.
- No broad strategic AI rewrite or planner/executor split.
- No pathing/body-tile/approach adoption, renderer/editor changes, generated PNG import, neutral encounter migration, or River Pass rebalance.

## Report Shape

The focused report should include:

- Scenario id, faction id, town placement id, current day, treasury, and town strategic role.
- Selected build candidate and compact public reason.
- Build candidate component values in debug/report only: income, growth, quality, readiness, pressure, recovery, market, category, garrison need, raid need, cost, affordability, final score.
- Recruitment result: unit id, count, cost, destination, destination reason, and whether it garrisoned, reinforced an active raid, or rebuilt a commander.
- Compact derived events with public fields only: event type, faction, actor town, target, public importance, reason codes, public reason, summary, and debug reason.
- A leak check that public events do not expose score-table fields such as `final_score`, `income_value`, `growth_value`, `pressure_value`, `category_bonus`, or `raid_score`.

## Validation And Manual Gate Strategy

Automated validation for the next implementation slice:

- `python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt`
- `git diff --check`
- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --economy-resource-report`
- `python3 tests/validate_repo.py --overworld-object-report`
- `python3 tests/validate_repo.py --neutral-encounter-report`
- Focused Godot report command for `AI_TOWN_GOVERNOR_PRESSURE_REPORT`.
- Existing focused AI event/economy pressure reports if the implementation touches shared event or target helpers.

Manual live-client gate policy:

- Defer live-client inspection if the implementation is report-only and does not change visible turn messages, UI layout, enemy movement cadence, arrival frequency, or map pressure.
- Run a manual enemy-turn gate if town governor events are added to normal threat/dispatch text, if turn-message pacing changes, or if town build/recruit choices materially alter the number or strength of visible raids.
- The manual gate should inspect one River Pass enemy-turn window where Duskfen builds or recruits and verify that the player-facing output is compact and map-first.

## Follow-Up Slices

1. `strategic-ai-town-governor-pressure-report-gate-10184`
   - Review the focused town governor pressure report.
   - Decide whether the report-only boundary passes, whether any public text is too large, and whether a live-client gate is now required.

2. `strategic-ai-faction-personality-pressure-planning-10184`
   - Compare Embercourt and Mireclaw as the first two personality anchors.
   - Use existing raid target, town governor, and reinforcement report surfaces to define personality evidence before tuning.

3. `strategic-ai-commander-role-state-planning-10184`
   - Plan the smallest transition from raid commanders toward explicit AI hero roles and tasks.
   - Keep save migration, shared pathing adoption, full hero roster state, spells, and artifacts out until the plan names the exact state boundary.

4. `strategic-ai-capture-countercapture-defense-proof-planning-10184`
   - Plan one focused site-control proof where an AI captures, loses, retakes, or defends a persistent economy site with compact public events.
   - Use the town governor and resource pressure reports as prerequisites.

## Completion Decision

This planning slice selects town governor pressure reporting as the next AI expansion because it broadens pressure from "which site is targeted" to "how the enemy town creates future pressure" while staying inside existing systems.

Explicit event streams remain a contract, not the center of the next slice. Full AI heroes, durable logs, save migration, faction-wide personality tuning, pathing/object adoption, rare-resource economy, and production JSON migration remain later work.
