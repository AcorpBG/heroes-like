# Strategic AI Strategy Config Audit Plan

Status: completed planning, documentation only.
Date: 2026-04-26.
Slice: `strategic-ai-strategy-config-audit-planning-10184`.

## Purpose

Plan a narrow Embercourt and Mireclaw strategy-config audit before any coefficient tuning.

The baseline is `docs/strategic-ai-faction-personality-evidence-report.md`: Embercourt is supported as town-front and civic infrastructure pressure; Mireclaw is supported as raid and resource-denial pressure. Weak, contradicted, and missing claims become audit questions, not tuning instructions.

This slice does not change AI behavior, production content JSON, scenario content, coefficients, resource schemas, pathing, renderer/editor behavior, saves, generated assets, neutral encounter metadata, River Pass balance, durable event logs, full AI hero task state, or public UI surfaces.

## Fixture Reality

The audit must treat current scenario content as the source of truth:

- `river-pass`: player `faction_embercourt`, enemy `faction_mireclaw`.
- `prismhearth-watch`: player `faction_sunvault`, enemy `faction_mireclaw`; this is not an Embercourt enemy fixture.
- `glassroad-sundering`: player `faction_sunvault`, enemy `faction_embercourt`; this is the current direct Embercourt enemy fixture.
- `ninefold-confluence`: player `faction_embercourt`, enemies include Mireclaw, Sunvault, Thornwake, Brasshollow, and Veilmourn, but not Embercourt as an enemy.

Audit scope should therefore use `glassroad-sundering` for direct Embercourt enemy scenario review, `river-pass` and `prismhearth-watch` for Mireclaw enemy review, and `ninefold-confluence` only as broad Mireclaw multi-faction context.

## Audit Categories

### 1. Faction Base Strategy Weights

Source: `content/factions.json` for `faction_embercourt.enemy_strategy` and `faction_mireclaw.enemy_strategy`.

Questions:

- Which base weights are intentional personality anchors, and which are scaffold leftovers?
- Do Embercourt's higher civic/economy/support/readiness/garrison/town weights consistently support town-front and infrastructure pressure?
- Do Mireclaw's higher dwelling/growth/pressure/resource/encounter/hero/raid/site-denial weights consistently support raid and denial pressure?
- Are any base weights too extreme or too flat to preserve contrast before scenario overrides apply?

Expected audit output:

- A compact table of base Embercourt versus Mireclaw weights.
- A decision label for each row: keep, question, later tune candidate, or insufficient evidence.
- No coefficient edits.

### 2. Scenario Overrides

Sources: relevant `enemy_factions` blocks in `content/scenarios.json`.

Questions:

- Does `river-pass` strengthen Mireclaw resource denial without erasing the town-front objective at `riverwatch_hold`?
- Does `prismhearth-watch` reinforce Mireclaw sabotage/hero-hunt pressure against Sunvault rather than accidentally serving as Embercourt evidence?
- Does `glassroad-sundering` make Embercourt more town, outpost, relay, and road-front oriented without turning it into generic raiding?
- Does `ninefold-confluence` make Mireclaw's broad-map priorities coherent as one rival among many, while avoiding any Embercourt enemy claim?
- Are `priority_target_placement_ids`, `priority_target_bonus`, siege targets, raid thresholds, and strategy overrides aligned with the evidence report?

Expected audit output:

- A scenario-by-scenario override table.
- Explicit notes for fixture mismatches and missing same-scenario A/B coverage.
- Audit questions for any override that contradicts faction identity.

### 3. Public Reason Phrase Vocabulary

Sources: faction personality evidence report, event surfacing gate, town governor gate, and focused report output.

Questions:

- Which reason phrases are shared state reasons versus faction personality signals?
- Should Embercourt gain compact civic/readiness wording later, such as income expansion, route security, garrison readiness, or charter-front support?
- Does Mireclaw already have enough compact denial language through `recruit and income denial`, `income and route vision denial`, and `feeds raid hosts`?
- Does any public phrase imply unsupported behavior, leak score-table concepts, or encourage text-heavy UI?

Expected audit output:

- A phrase inventory grouped by public surface: target assignment, pressure summary, site seizure, site contest, town build, recruitment, garrison, raid, and commander rebuild.
- Recommended phrase gaps as later implementation candidates only, not wording changes in this planning slice.

### 4. Resource And Site Family Priorities

Sources: `raid_target_weights`, `site_family_weights`, scenario priority target ids, and resource target report evidence.

Questions:

- For Embercourt, do faction outposts, relays, roads/crossings, towns, and support infrastructure receive enough priority compared with generic resources and encounters?
- For Mireclaw, do persistent economy sites, recruit-denial sites, neutral dwellings, route disruption, and exposed support sites receive enough priority?
- Are current site family names too coarse to distinguish civic infrastructure from generic outposts or marsh-den pressure from generic neutral dwellings?
- Which site/resource claims are missing because production JSON has not migrated broader resource-site metadata?

Expected audit output:

- Placement-level examples for `glassroad_watch_relay`, `glassroad_starlens`, `glassroad_beacon_wardens`, `river_free_company`, `river_signal_post`, `prismhearth_watch_relay`, `prismhearth_lens_house`, `bog_drum_crossing`, `dwelling_bogbell_croft`, and `ninefold_basalt_gatehouse_watch`.
- A list of missing metadata that should remain future planning, not current production JSON migration.

### 5. Build Category And Value Weights

Sources: `build_category_weights`, `build_value_weights`, town governor report evidence, and faction bible intent.

Questions:

- Do Embercourt's civic/economy/support/readiness weights produce civic infrastructure pressure, or does public output collapse to generic `builds pressure` too often?
- Does Mireclaw's dwelling/growth/pressure bias explain Slingers Post and replacement-loop choices without making garrison stabilization impossible under threat?
- Are market/income/readiness components for Embercourt visible enough in report/debug output to justify later phrase or coefficient work?
- Are build weights being audited separately from affordability and current town content limitations?

Expected audit output:

- A build-weight matrix for both factions.
- A report-evidence note for each current selected build claim.
- A short list of bounded later tuning candidates, if any, with required validation commands.

### 6. Reinforcement, Garrison, Raid, And Commander Rebuild Bias

Sources: `reinforcement`, `raid`, town governor report evidence, and staged garrison/raid/commander cases.

Questions:

- Does Embercourt's garrison/ranged/high-tier bias support front-holding and readiness without preventing raids when state pressure requires them?
- Does Mireclaw's raid/melee/low-tier bias support active raid reinforcement and commander rebuild without making town defense incoherent?
- Which outputs are shared state-pressure surfaces rather than faction-specific proof?
- What claims are blocked until commander-role state exists?

Expected audit output:

- A split between supported faction bias, shared behavior, and missing commander-role evidence.
- No AI hero state design or save migration in this audit plan.

### 7. Validation And Report Commands

The audit report should run repository validation:

```bash
python3 -m json.tool ops/progress.json >/tmp/heroes-progress-jsoncheck.txt
git diff --check
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report
python3 tests/validate_repo.py --overworld-object-report
python3 tests/validate_repo.py --neutral-encounter-report
```

Recommended focused report commands for the audit report:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_faction_personality_evidence_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_economy_pressure_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_event_surfacing_report.tscn
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_town_governor_pressure_report.tscn
```

The audit report may cite focused report output and current JSON values. It should not add new tests unless the existing reports cannot answer a narrow audit question without behavior changes.

### 8. Manual Gate Triggers

Manual live-client enemy-turn inspection remains deferred while the work is documentation/report-only.

Trigger a manual gate later if a follow-up slice:

- Changes coefficients, raid cadence, reinforcement strength, target ordering, arrival frequency, or visible map pressure.
- Connects personality reasons to normal player-facing turn text or changes UI composition.
- Adds capture/counter-capture behavior, durable event logs, full AI hero task state, or save-state migration.
- Alters pathing, body tiles, approach tiles, renderer behavior, editor behavior, or production scenario content.

## Audit Questions From Weak Or Contradicted Evidence

- Embercourt direct evidence must stay tied to `glassroad-sundering`, not `prismhearth-watch`.
- Embercourt civic/readiness identity is supported by config and debug components, but current public selected build wording can still read as generic `builds pressure`.
- Mireclaw denial identity is supported, but full target selection can still choose town siege when the scenario front makes that legitimate.
- Shared phrases such as `feeds raid hosts` and `rebuilds command` prove reusable surfaces, not unique faction personality by themselves.
- Same-scenario A/B evidence is missing; do not tune as if geography-neutral personality proof exists.
- Capture/counter-capture evidence is missing; do not claim either faction can yet retake or defend persistent sites under normal turns.
- Commander-role identity is missing; do not claim distinct AI hero task roles beyond current raid commander and rebuild surfaces.

## Recommended Next Slice

Recommended next concrete slice: `strategic-ai-strategy-config-audit-report-10184`.

Purpose:

- Produce the actual audit report from the categories above.
- Classify existing Embercourt and Mireclaw base weights and scenario overrides as supported, questionable, contradicted, or missing-evidence.
- Identify any bounded coefficient tuning candidates, but do not tune them.
- Decide whether the next slice after the audit report should be a bounded coefficient tuning plan, commander-role state planning, or capture/counter-capture proof planning.

Rationale:

The evidence report is strong enough to plan the audit, but not enough to tune. The project needs one explicit audit report that reconciles config values, scenario overrides, reason vocabulary, and fixture reality before choosing coefficient work or a larger AI state proof.

## Deferred

- Coefficient tuning and behavior tuning.
- Production JSON migration or scenario rebalance.
- `content/resources.json`, `wood` to `timber` migration, rare-resource activation, and market-cap overhaul.
- Pathing, body-tile, approach, renderer, editor, save, and generated PNG import work.
- Neutral encounter migration.
- Durable AI event logs.
- Full AI hero task state or broad strategic AI rewrite.
- River Pass rebalance.

## Completion Decision

This planning slice selects a report-only strategy-config audit as the next step. The audit should be evidence classification first and tuning selection second, with no production content or behavior changes.
