# Strategic AI Economy Pressure Slice Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-economy-pressure-planning-10184`.

## Purpose

Plan the first strategic AI pressure slice after the Riverwatch signal-yard economy proof passed.

The goal is not to implement the full strategic AI foundation yet. The smallest useful target is to make the current enemy pressure model value and contest the same economy facts that the player proof just demonstrated: persistent income sites, common-resource pickups, fight-gated route choices, town spend/recruit decisions, save/resume continuity, and remaining River Pass objectives.

This document is planning only. It does not approve production JSON migration, AI implementation, runtime economy/pathing/editor/renderer/save behavior changes, resource migration, rare-resource activation, market overhaul, generated PNG or asset import, or broad River Pass rebalance.

## Evidence Base

Primary evidence:

- `docs/economy-capture-resource-loop-proof-plan.md`
- `docs/economy-capture-resource-loop-live-proof-report.md`
- `docs/economy-capture-resource-loop-manual-gate-review.md`
- `docs/strategic-ai-foundation.md`
- Current `EnemyTurnRules.gd` and `EnemyAdventureRules.gd` rule surfaces

Riverwatch proof facts to preserve as implementation targets:

| Surface | Proven fact | AI implication |
| --- | --- | --- |
| `river_signal_post` | Persistent player-controlled site, `50 gold` claim reward, `20 gold` daily control income, vision/pressure support. | First AI should value it as an economy-denial and route-watch target, not as a generic pickup. |
| `river_free_company` | Persistent player-controlled site, `80 gold`, `40 gold` daily income, immediate `River Guard` and `Ember Archer` joins, weekly recruit potential. | First AI should treat it as the highest-value Riverwatch economy/recruit denial target. |
| `north_wood` | Common pickup changes `wood` from 4 to 6 and helps the Bowyer Lodge path. | AI scoring should know common pickups can solve build/recruit blockers, but the first implementation should not rewrite pickup behavior. |
| `southern_ore` | Fight-gated ore branch adds `ore +2`, and Hollow Mire itself adds ore before the pickup. | AI should read ore branches as route-pressure evidence and future blocker-solving value. |
| Ghoul Grove and Hollow Mire | Fights gate route, resource, and objective progress. | AI should not ignore route blockers when evaluating pressure; first slice can score adjacent/route-gated targets without neutral encounter migration. |
| Riverwatch spend/recruit | Captures convert into `building_bowyer_lodge` and `unit_ember_archer` recruitment. | AI pressure should target sites that enable visible town power, not only direct town attacks. |
| Save/resume | Day, resources, controlled sites, resolved encounters, town build, recruits, army, and objective progress survive resume. | Any implementation must keep AI pressure state save-stable and not add transient-only target decisions. |
| Remaining objectives | Duskfen capture and Reed Totemists remain after the economy proof path. | AI should still pressure the Duskfen/Riverwatch front instead of chasing every map trinket. |

## Existing Reality

Current code already has useful hooks for this slice:

- `EnemyTurnRules.run_enemy_turn` applies enemy treasury income, town builds, recruitment, pressure gain, raid advancement, raid spawning, siege progress, and public threat summaries.
- `EnemyAdventureRules.choose_target` builds raid targets and selects the highest priority candidate.
- `EnemyAdventureRules._resource_target_priority` already values contestable resource nodes, persistent sites, player-controlled sites, escorted responses, delivery manifests, linked player towns, and objective proximity.
- `EnemyAdventureRules._resource_site_strategic_value` already considers claim rewards, control income, claim/weekly recruits, vision, pressure, and support profile value.
- `river-pass` already marks `river_signal_post` and `river_free_company` as Mireclaw priority targets and weights resource raids above baseline.

Current gaps that this plan should address without broad rewrite:

- Target scores are compact priority integers, not explainable component records.
- Resource scarcity is implicit through hardcoded `gold`, `wood`, and `ore` value, not tied to town build/recruit blockers.
- Duskfen pressure can value Riverwatch sites, but there is no focused manual gate proving the AI prefers the signal-yard economy front over unrelated targets after the player captures those sites.
- Event surfacing is message-oriented, not a structured AI event stream with reason codes.
- There is no validation report dedicated to AI economy target selection.

## Smallest AI Pressure Target

The first implementation target should be:

> In `river-pass`, when the player captures `river_signal_post` and/or `river_free_company`, Mireclaw pressure should prefer contesting those signal-yard economy sites before unrelated low-value pickups, unless Riverwatch town siege or a visible weak hero is clearly higher priority.

That is the narrowest useful pressure slice because:

- It uses current River Pass content and current resource ids.
- It reuses the existing raid/commander pressure model instead of requiring full AI heroes.
- It makes the opponent contest a proven player-facing economy loop.
- It creates readable pressure around Duskfen without rebalancing the whole scenario.
- It prepares the later real strategic AI pipeline by forcing target scoring to expose reasons.

Priority target order for this slice:

1. `river_free_company`: highest value because it combines daily gold, recruit denial, immediate recruit proof, and Riverwatch support.
2. `river_signal_post`: second-highest because it combines daily gold, vision/route control, pressure support, and route-watch flavor.
3. `southern_ore`: valuable only after route/fight context makes it relevant, and not above persistent player-controlled sites.
4. `north_wood` and `eastern_cache`: opportunistic only; they should not distract from persistent captured sites once claimed by the player.
5. `duskfen_bastion` / Riverwatch siege logic: remains the strategic front. The slice should not make AI economy denial so strong that the town objective disappears from pressure summaries.

## Proposed Scoring Fields

Implementation should keep the current integer priority path, but add a score breakdown helper for resource targets. The breakdown can be debug/report-only at first.

Recommended resource target scoring fields:

| Field | Meaning | River Pass expectation |
| --- | --- | --- |
| `target_kind` | Existing target type. | `resource`. |
| `placement_id` | Scenario placement id. | `river_free_company`, `river_signal_post`, etc. |
| `site_id` | Resource-site content id. | `site_riverwatch_free_company_yard`, `site_ember_signal_post`. |
| `site_family` | Existing site family. | `neutral_dwelling`, `faction_outpost`, or blank for simple pickups. |
| `base_value` | Base claim reward value from current resources. | Lower for signal post, higher for pickup cash, but not decisive alone. |
| `persistent_income_value` | Daily control income value with a small horizon, e.g. 3-5 days. | Strong on signal post and free company. |
| `recruit_value` | Claim and weekly recruit value. | Strong on free company. |
| `scarcity_value` | Current-resource blocker value for `gold`, `wood`, and `ore`. | Wood/ore pickups are meaningful when they solve Riverwatch orders, but this remains advisory in first implementation. |
| `denial_value` | Extra value when player controls a persistent site or it is linked to a player town. | Strong on both signal-yard sites after player capture. |
| `route_pressure_value` | Value from objective proximity, Duskfen/Riverwatch lane, response route, or guarded branch. | Strong around signal yard and southern mire lane. |
| `town_enablement_value` | Value when a site enabled likely player builds/recruits. | Strong on free company after Bowyer Lodge/archer proof. |
| `objective_value` | Existing objective proximity/town-front value. | Keeps Riverwatch/Duskfen front relevant. |
| `faction_bias` | Scenario/faction strategy weights and priority target bonus. | Mireclaw keeps high resource/site-denial weight. |
| `travel_cost` | Path distance/turn delay. | Prevents chasing distant pickups. |
| `guard_cost` | Neutral blocker or route fight estimate. | Advisory only unless current pathing can prove it. |
| `assignment_penalty` | Existing penalty for duplicate raid assignments. | Prevents both raids picking the same site too eagerly. |
| `final_priority` | Integer priority consumed by existing target chooser. | Must match existing target selection. |
| `debug_reason` | Short reason string for reports/events. | Example: `denies 40 daily gold and Free Company recruits`. |

For this slice, `scarcity_value`, `town_enablement_value`, and `guard_cost` can be conservative heuristics. They must remain explainable and based on current content/state, not hidden difficulty bonuses.

Recommended first formula shape:

```text
final_priority =
  base_value
  + persistent_income_value
  + recruit_value
  + scarcity_value
  + denial_value
  + route_pressure_value
  + town_enablement_value
  + objective_value
  + faction_bias
  - travel_cost
  - guard_cost
  - assignment_penalty
```

The exact coefficients should be tuned in implementation through report output, not by broad River Pass balance edits.

## Event And Surfacing Expectations

The first implementation should not build a large UI dashboard. Surfacing should stay compact and compatible with scenic/play-surface rules.

Minimum event/report expectations:

- Add or expose a debug/report target table for the current enemy turn showing top resource targets and score components.
- Preserve existing player-facing threat summary text from `EnemyTurnRules.describe_threats`.
- When a raid target is assigned to a signal-yard site, include a compact reason in debug output and, where existing messages allow it, in the public summary.
- When a raid seizes `river_signal_post` or `river_free_company`, current messages already state site seizure and logistics denial. Do not add a new overlay.
- Event records, if added in implementation, should use the strategic AI foundation fields: `event_type`, `faction_id`, `actor_id`, `target_kind`, `target_id`, `summary`, `public_importance`, and `debug_reason`.

Allowed first event types:

- `ai_target_scored`
- `ai_target_assigned`
- `ai_site_contested`
- `ai_site_seized`
- `ai_pressure_summary`

These can remain report/debug records in the first implementation. They should not force animation playback, save-schema migration, or UI panel work.

## Validation And Manual Gate Plan

Implementation slice validation should prove target preference and state preservation, not full strategic AI.

Automated validation should still include:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
```

Recommended implementation-specific validation:

- Add a focused deterministic AI economy pressure report or unit-style fixture if the implementation touches scoring helpers.
- Report top target candidates for a River Pass state where the player owns `river_signal_post`.
- Report top target candidates for a River Pass state where the player owns both `river_signal_post` and `river_free_company`.
- Confirm `river_free_company` outranks simple pickups once player-controlled.
- Confirm `river_signal_post` outranks simple pickups once player-controlled.
- Confirm `riverwatch_hold` siege pressure can still outrank economy denial when the scenario pressure state says town attack is the main threat.
- Confirm no target score uses rare resources, `wood`, market caps, generated object metadata, or hidden omniscient state.

Manual gate checklist:

- Start or construct the same Riverwatch economy proof state from the live proof report.
- Let the enemy turn run after `river_signal_post` is player-controlled.
- Record whether the Mireclaw summary or debug report names signal-yard pressure.
- Let the enemy turn run after `river_free_company` is player-controlled.
- Record whether a raid prefers the Free Company / Signal Post lane over `north_wood`, `eastern_cache`, or unrelated artifacts when no town/hero target should dominate.
- Advance until a contesting raid arrives, or record that travel time prevents arrival within the short gate while target choice still passes.
- Save/resume after target assignment and verify raid target, site control, enemy pressure, and summary remain coherent.

Pass criteria:

- The AI can explain why `river_free_company` or `river_signal_post` is a high-value target.
- Persistent player-controlled economy sites receive a clear denial bonus.
- Free Company recruit value is visible in the score breakdown.
- Common pickups remain valued but do not distract from owned persistent signal-yard sites.
- Duskfen/Riverwatch front pressure remains visible.
- Save/resume preserves any new target/reason state if implementation stores it.

Failure criteria:

- The AI still chases simple pickups or unrelated targets while ignoring player-owned signal-yard income without a town/hero reason.
- The score cannot be explained from current state and content.
- The implementation requires rare-resource activation, wood id change, market overhaul, pathing/body-tile adoption, renderer/editor/save migration, or broad scenario rebalance.
- The player-facing surface becomes a text-heavy dashboard over the map.

## Non-Change Boundaries

The implementation slice following this plan must not include:

- No production resource schema migration.
- No `content/resources.json`.
- No wood id change.
- No rare-resource activation.
- No market-cap or exchange overhaul.
- No runtime economy rule migration.
- No pathing/body-tile/approach/editor adoption.
- No renderer or generated asset import work.
- No save format migration unless the implementation explicitly stores new AI target state; prefer recomputable debug reasons first.
- No real full AI hero roster/task-state implementation.
- No broad strategic AI rewrite.
- No broad River Pass rebalance.
- No new neutral encounter migration bundle.

## Prerequisite Decision

No prerequisite blocker exists.

The economy proof data is sufficient to start a narrow implementation slice because:

- The relevant sites are already authored and manually proofed.
- Current AI rules already target resources and persistent sites.
- River Pass already provides Duskfen/Mireclaw pressure and priority target ids.
- The first implementation can be a scoring/report/event-surfacing improvement without changing resource schema, pathing, renderer, editor, save format, markets, or broad balance.

Next current slice should be `strategic-ai-economy-pressure-implementation-10184`.

## Next Slices

1. `strategic-ai-economy-pressure-implementation-10184`
   - Implement the narrow target scoring/report/event-surfacing improvement for River Pass signal-yard economy pressure.
   - Prefer helper functions and report/debug output over new schema.
   - Keep the existing raid/commander model as the execution surface.

2. `strategic-ai-economy-pressure-report-gate-10184`
   - Review automated report/manual observations.
   - Decide whether the AI pressure gate passes, needs coefficient tuning, or exposes a missing event/UI surface.

3. `strategic-ai-economy-pressure-tuning-10184`
   - Optional only if the report gate shows poor target ordering.
   - Tune weights or scenario-local strategy values without broad River Pass rebalance.

4. `strategic-ai-event-surfacing-planning-10184`
   - If the pressure gate passes, plan the first reusable AI event stream surface for movement, target assignment, site contest, and compact threat summaries before real AI hero work.

## Rollback

For this planning slice, rollback is:

- Remove this document.
- Revert the related `PLAN.md`, `ops/progress.json`, and `ops/acorp_attention.md` updates.

For the next implementation slice, rollback should be equally narrow:

- Revert scoring/report/event helper changes.
- Keep River Pass production data, resource schema, pathing, renderer, editor, save format, markets, generated assets, and broad AI architecture unchanged unless that slice explicitly changes them.
