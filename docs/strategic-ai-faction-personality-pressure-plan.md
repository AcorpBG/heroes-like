# Strategic AI Faction Personality Pressure Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-faction-personality-pressure-planning-10184`.

## Purpose

Plan how faction personality should be evidenced from the strategic AI pressure reports that already exist, before any coefficient tuning or strategy config migration.

The first comparison anchors are Embercourt and Mireclaw. They are the lowest-risk pair because their design contrast is clear in `docs/factions-content-bible.md`, their current `content/factions.json` records already contain different `enemy_strategy` weights, and current scenarios expose both factions as opponents. Mireclaw has the stronger focused report evidence today through River Pass / Duskfen; Embercourt has config and scenario reality but needs a matching report pass before personality claims should harden.

This slice is planning only. It does not edit gameplay code, production content JSON, scenario content, AI coefficients, resource schemas, pathing, renderer/editor behavior, saves, generated assets, neutral encounter metadata, or River Pass balance.

## Evidence Inputs

Existing report gates that can support personality planning:

- `docs/strategic-ai-economy-pressure-report-gate-review.md`: proves player-owned `river_free_company` and `river_signal_post` can outrank simple pickups for Duskfen / Mireclaw while `riverwatch_hold` can still dominate the full target selector.
- `docs/strategic-ai-event-surfacing-report-gate-review.md`: proves compact public reasons for target assignment, pressure summary, site seizure, site contest, threat text, and dispatch text without score-table leakage.
- `docs/strategic-ai-town-governor-pressure-report-gate-review.md`: proves Duskfen / Mireclaw build, garrison, raid reinforcement, and commander rebuild report surfaces with compact derived events.
- `content/factions.json`: current Embercourt and Mireclaw `enemy_strategy` weights already differ across build categories, build value weights, raid target weights, site family weights, reinforcement biases, and raid posture.
- Relevant current scenario config: River Pass exercises Mireclaw as the active enemy pressure faction; `prismhearth-watch` and later campaign/scenario records expose Embercourt as an enemy pressure faction; Ninefold Confluence exposes both as pressure claims.

Design evidence from `docs/factions-content-bible.md`:

- Embercourt should read as stable civic infrastructure pressure: roads, crossings, relief lines, garrison readiness, town sieges, and prepared support.
- Mireclaw should read as predatory marsh pressure: raids, site denial, wounded-prey pressure, den growth, cheap replacements, and counter-capture.

## Current Reality

Mireclaw currently has direct focused AI report proof:

- Resource pressure: `river_free_company` and `river_signal_post` become high-value denial targets when player-controlled.
- Compact public reasons: `recruit and income denial`, `income and route vision denial`, and `town siege remains the main front`.
- Town governor pressure: Duskfen selects `building_slingers_post`, routes recruits to garrison stabilization, feeds an active raid, and rebuilds Vaska Reedmaw in focused cases.
- Config alignment: Mireclaw has lower safe economy, higher pressure bonus, high dwelling/growth/pressure weights, high resource/encounter/hero target weights, high neutral dwelling weight, raid-biased reinforcement, lower raid threshold scale, extra max active raid capacity, high site denial, and high hero hunt weights.

Embercourt currently has partial evidence but not a matching focused report gate:

- Config alignment: Embercourt has higher safe gold income, higher readiness, high civic/economy/support build weights, high income/readiness weights, town-heavy raid target weights, high faction-outpost weight, garrison-biased reinforcement, high town siege and objective weights, and lower site-denial/hero-hunt weights.
- Scenario reality: Embercourt appears as an enemy pressure faction in `prismhearth-watch` through Charter Road Wardens, with high town/resource-front priority ids and town-siege strategy overrides.
- Missing focused evidence: no current gate records an Embercourt town governor report equivalent to the Duskfen / Mireclaw report, and no current personality report compares Embercourt target reasons against Mireclaw reasons under the same report vocabulary.

Conclusion: the next slice should be report-only faction personality evidence, not tuning. The project should first prove that existing surfaces can distinguish Embercourt and Mireclaw consistently.

## Pressure Surfaces Usable Before Tuning

These surfaces are safe to use as personality evidence now because they already exist as report/debug or compact derived-event boundaries.

### Target Preferences

Usable evidence:

- Target kind ordering from `resource_pressure_report(...)` and `choose_target(...)`.
- Resource target breakdown categories kept in debug/report output: persistent income denial, recruit denial, route pressure, player-town support, objective value, travel cost, guard cost, assignment penalty, and final priority.
- `enemy_strategy.raid_target_weights`, `site_family_weights`, priority target ids, and scenario strategy overrides.

Personality use:

- Embercourt evidence should emphasize town fronts, faction outposts, roads/crossings, support infrastructure, and objective fronts.
- Mireclaw evidence should emphasize resource counter-capture, neutral dwellings, exposed encounters, hero pressure, raid lanes, and denial of player town support.

Boundary:

- Do not change target coefficients in the evidence slice. If evidence contradicts intended personality, record it as a tuning/audit finding.

### Town Build Reasons

Usable evidence:

- Town build report fields: selected build, public reason, income, growth, quality, readiness, pressure, recovery, market, category, garrison need, raid need, affordability, and final score.
- Compact town build event: `ai_town_built`.

Personality use:

- Embercourt should tend toward readiness, income, civic/support, garrison safety, town-front and objective support.
- Mireclaw should tend toward growth, dwelling, pressure output, raid throughput, and replacement loops.

Boundary:

- Keep component scores report/debug-only. Public personality text should be one compact reason phrase at most.

### Recruitment Destination Reasons

Usable evidence:

- Recruitment destination breakdowns for garrison stabilization, active raid reinforcement, and commander rebuild.
- Compact derived events: `ai_town_recruited`, `ai_garrison_reinforced`, `ai_raid_reinforced`, and `ai_commander_rebuilt`.
- Current reinforcement strategy weights in `content/factions.json`.

Personality use:

- Embercourt should show stronger garrison stabilization, ranged/quality reinforcement, and town-front retention when reports are run against an Embercourt enemy town.
- Mireclaw already shows active raid reinforcement and commander rebuild support, while still stabilizing a critical garrison gap when forced by state.

Boundary:

- Do not infer a faction never defends or never raids. Personality is a bias under state pressure, not a hard behavior lock.

### Garrison, Raid, And Commander Priorities

Usable evidence:

- Reinforcement config: garrison bias, raid bias, ranged/melee weighting, low/high tier weighting.
- Raid strategy config: threshold scale, max active bonus, pressure commitment, objective weight, town siege weight, site denial weight, hero hunt weight.
- Town governor focused cases for garrison, active raid, and commander rebuild.

Personality use:

- Embercourt should read as a front-holding faction: garrison-biased, siege/objective-aware, stronger ranged/quality reinforcement.
- Mireclaw should read as a counter-capture/raid faction: raid-biased, low-tier replacement-biased, site-denial and hero-hunt weighted.

Boundary:

- Commander-role planning remains later. The personality evidence slice may inspect commander rebuild outputs, but it should not add full AI hero task state or save migration.

### Compact Public Reason Phrases

Usable evidence:

- Public reason phrases on target assignment, pressure summaries, seizure, contest, threat text, dispatch text, and town-governor derived events.
- Leak checks that prevent score-table fields from entering public event payloads.

Personality use:

- Phrases should remain action-readable first: `stabilizes garrison`, `feeds raid hosts`, `rebuilds command`, `income and route vision denial`, `town siege remains the main front`.
- Faction personality can be layered by choosing reason codes and summaries that reflect the action, not by adding lore paragraphs.

Boundary:

- No text-heavy AI dashboard. Public personality evidence stays compact and map-first.

## Next Concrete Slice Decision

Recommended next concrete slice: `strategic-ai-faction-personality-evidence-report-10184`.

Decision: run a report-only faction personality evidence slice before coefficient/strategy config audit planning, commander-role planning, or another foundation track.

Rationale:

- The current reports prove the surfaces work, but only Mireclaw has direct focused evidence across resource pressure, event reasons, and town governor choices.
- Embercourt has strong config/scenario evidence, but the project should not claim an Embercourt strategic personality until a focused report exercises equivalent target, town build, recruitment, and compact reason surfaces.
- Coefficient tuning would be premature without side-by-side evidence.
- Commander-role state is important but larger and should build on personality evidence rather than define it by implication.

## Proposed Evidence Report Scope

The next slice should stay report-only and behavior-neutral.

Allowed:

- Add or run focused report coverage that compares Embercourt and Mireclaw through existing surfaces.
- Use current scenarios as reality fixtures: River Pass / Duskfen for Mireclaw, an Embercourt-opponent scenario such as `prismhearth-watch` for Embercourt, and optionally Ninefold Confluence as breadth context.
- Report target preferences, town build reasons, recruitment destinations, reinforcement choices, commander rebuild examples, compact public reason phrases, and public leak checks.
- Record mismatches as audit findings.

Not allowed:

- No coefficient tuning or behavior tuning.
- No production JSON/content/scenario edits.
- No new AI profile schema.
- No durable AI event log or save migration.
- No full AI hero roster/task state.
- No broad strategic AI rewrite.
- No pathing/body-tile/approach adoption.
- No renderer/editor changes.
- No generated PNG import.
- No neutral encounter migration.
- No River Pass rebalance.

## Validation And Manual Gate Strategy

Automated validation for this planning slice:

- `python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt`
- `git diff --check`
- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --economy-resource-report`
- `python3 tests/validate_repo.py --overworld-object-report`
- `python3 tests/validate_repo.py --neutral-encounter-report`

Recommended validation for the next report-only evidence slice:

- The same repository validation commands above.
- Focused Godot report command(s) for the existing economy, event, and town governor pressure reports.
- New or extended focused report output only if needed to compare Embercourt and Mireclaw under the same vocabulary.
- Public event/reason leak checks for both factions.

Manual live-client gate policy:

- Defer live-client inspection while the work remains report-only and does not change live UI text, turn pacing, enemy movement cadence, arrival frequency, map pressure, pathing, renderer, save/load, or content.
- Run a manual enemy-turn gate later if personality evidence starts feeding normal player-facing turn text, changes public threat/dispatch composition, tunes raid cadence, changes reinforcement strength, or alters visible map pressure.

## Follow-Up Slices

1. `strategic-ai-faction-personality-evidence-report-10184`
   - Produce the side-by-side Embercourt/Mireclaw evidence report from existing target, event, and town-governor surfaces.
   - Decide which personality claims are supported, weak, or contradicted before tuning.

2. `strategic-ai-strategy-config-audit-planning-10184`
   - Plan a coefficient and config audit only after evidence exists.
   - Keep this as planning first, especially around build weights, raid target weights, reinforcement bias, site family weights, and scenario overrides.

3. `strategic-ai-commander-role-state-planning-10184`
   - Plan the smallest transition from raid commanders toward explicit AI hero roles and tasks.
   - Keep save migration, shared pathing adoption, adventure spells, artifacts, and full hero roster state out until the state boundary is named.

4. `strategic-ai-capture-countercapture-defense-proof-planning-10184`
   - Plan one focused site-control proof where an AI captures, loses, retakes, or defends a persistent economy site with compact public events.
   - Use the personality evidence report to choose whether Embercourt defense or Mireclaw counter-capture is the better first proof.

## Completion Decision

This planning slice selects report-only faction personality evidence as the next AI step.

The current evidence is enough to define surfaces and boundaries, but not enough to tune. Mireclaw has strong report evidence; Embercourt needs equivalent report evidence before any side-by-side personality conclusion should drive coefficients, public UI wording, commander roles, or scenario balance.
