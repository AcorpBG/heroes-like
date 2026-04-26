# Strategic AI Faction Personality Evidence Report

Status: completed report-only evidence.
Date: 2026-04-26.
Slice: `strategic-ai-faction-personality-evidence-report-10184`.

## Scope

This report compares Embercourt and Mireclaw through existing strategic AI surfaces only: target preferences, town build reasons, recruitment destinations, garrison/raid/commander priorities, and compact public reason phrases.

This slice adds focused report coverage but does not change AI behavior, production content, coefficients, scenario JSON, renderer/editor behavior, pathing, saves, neutral encounter metadata, generated assets, or River Pass balance.

## Focused Report Coverage

Added:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_faction_personality_evidence_report.tscn
```

Result: passed. The command prints `AI_FACTION_PERSONALITY_EVIDENCE_REPORT` with `"ok": true`.

Report fixtures:

- Mireclaw: `river-pass`, enemy faction `faction_mireclaw`, enemy town `duskfen_bastion`, staged player control of `river_signal_post` and `river_free_company`.
- Embercourt: `glassroad-sundering`, enemy faction `faction_embercourt`, enemy town `riverwatch_market`, staged player control of `glassroad_watch_relay` and `glassroad_starlens`.

The report uses a shared vocabulary for both factions:

- `target_preferences`
- `pressure_summary`
- `town_build_reason`
- `recruitment_destination`
- `garrison_priority`
- `raid_priority`
- `commander_rebuild_priority`
- `compact_public_reason`

Public event leak checks passed for both factions. Compact public events did not expose score-table keys such as `final_score`, `income_value`, `growth_value`, `pressure_value`, `base_value`, `persistent_income_value`, `assignment_penalty`, or `final_priority`.

## Scenario Reality Finding

The requested/read-first scenario list named `prismhearth-watch` as relevant. Current content does not expose Embercourt as the enemy in that scenario:

- `prismhearth-watch`: player `faction_sunvault`, enemy `faction_mireclaw`.
- `glassroad-sundering`: player `faction_sunvault`, enemy `faction_embercourt`.
- `river-pass`: player `faction_embercourt`, enemy `faction_mireclaw`.
- `ninefold-confluence`: player `faction_embercourt`, enemies include Mireclaw, Sunvault, Thornwake, Brasshollow, and Veilmourn, but not Embercourt as an enemy.

For direct Embercourt enemy evidence, the focused report therefore uses `glassroad-sundering`.

## Supported Claims

### Embercourt

Supported config evidence:

- Embercourt reads as safer civic infrastructure pressure than Mireclaw in `content/factions.json`: base gold income `60` versus Mireclaw `35`, readiness bonus `8` versus Mireclaw `2`, and higher support/economy/civic build category weights.
- Embercourt has stronger town-front posture weights: `town` raid target `1.4` in the Glassroad scenario, `town_siege_weight` `1.5`, `garrison_bias` `1.35`, `ranged_weight` `1.25`, and `high_tier_weight` `1.15`.
- Embercourt has lower site-denial/hero-hunt posture than Mireclaw: base `site_denial_weight` `0.8` and `hero_hunt_weight` `0.8`.

Supported report evidence:

- Full target selection in `glassroad-sundering` chooses `halo_spire_bridgehead` as a town target with public reason `town siege remains the main front`.
- Resource ordering still values controlled infrastructure: `glassroad_watch_relay` ranks first among resource targets with `income and route vision denial`, followed by `glassroad_starlens`.
- The town governor report selects `building_market_square` at Riverwatch Hold, with dominant debug components from market, income, quality, and pressure.
- Under a critical garrison gap, Embercourt routes recruitment to garrison stabilization with public reason `stabilizes garrison`.
- Under staged active raid and commander-rebuild cases, the same shared surfaces emit `feeds raid hosts` and `rebuilds command` without leaking score tables.

Supported personality claim:

Embercourt is currently evidenced as a town-front and infrastructure-stabilization faction: it privileges siege fronts, charter assets, market/income support, garrison stabilization under threat, and compact public reasons around town pressure.

### Mireclaw

Supported config evidence:

- Mireclaw reads as raid/counter-capture pressure: pressure bonus `2`, growth weight `1.35`, pressure weight `1.6`, resource target weight `1.35` in River Pass after override, hero target weight `1.25`, neutral dwelling weight `1.4`, raid bias `1.45`, low-tier weight `1.2`, and `site_denial_weight` `1.5` in River Pass.
- Mireclaw has lower safe infrastructure posture than Embercourt: base gold income `35`, readiness bonus `2`, garrison bias `0.75`, town target weight `0.9`, and town siege weight `0.85` before scenario context.

Supported report evidence:

- `river_free_company` and `river_signal_post` rank as the top two resource targets when player-controlled.
- `river_free_company` carries public reason `recruit and income denial`; `river_signal_post` carries `income and route vision denial`.
- Full target selection can still choose `riverwatch_hold` with `town siege remains the main front`, preserving a legitimate objective/town front while resource denial remains visible in the resource report.
- Duskfen selects `building_slingers_post` with public reason `feeds raid hosts`.
- Under staged active raid and commander rebuild cases, Duskfen emits `feeds raid hosts` and `rebuilds command`.

Supported personality claim:

Mireclaw is currently evidenced as a raid and denial faction: it values controlled logistics sites, recruit denial, route vision denial, low-tier replacement flow, active raid reinforcement, and commander rebuild loops.

## Weak Claims

- Embercourt's report evidence is direct now, but it is not from `prismhearth-watch`; it depends on `glassroad-sundering`, the current Embercourt enemy scenario.
- Embercourt's selected build public phrase is `builds pressure`, not `expands income` or `stabilizes garrison`, even though the debug components show market/income/readiness-style support. The phrase is acceptable as compact output, but weak as a personality-specific civic phrase.
- Both factions can emit `feeds raid hosts` and `rebuilds command` in staged cases because those are shared state-pressure surfaces. They prove the surfaces work for both factions, not that the factions are uniquely defined by those actions.
- Full target selection chooses a town front for both factions in the focused scenarios. The stronger personality contrast is clearer in config, resource ordering, build categories, and recruitment bias than in the top-level target kind alone.
- The focused report uses staged player-owned resource sites, treasury, garrison strength, active raid, and shattered commander states. It is deterministic report evidence, not a normal live-turn transcript.

## Contradicted Claims

- The planning/input assumption that `prismhearth-watch` exposes Embercourt as the relevant enemy pressure faction is contradicted by current `content/scenarios.json`; that scenario's enemy faction is Mireclaw.
- A naive claim that Embercourt public town-build output already reads purely defensive/civic is contradicted by the focused report: its current selected public reason is `builds pressure`.
- A naive claim that Mireclaw always prioritizes site denial over towns is contradicted by the focused River Pass full selector: `riverwatch_hold` can still dominate as the main front while signal-yard denial remains the top resource-pressure evidence.

## Missing Evidence

- No normal live-client enemy-turn transcript compares Embercourt and Mireclaw turn pacing, arrival frequency, or visible map pressure.
- No capture/counter-capture proof shows either faction taking, losing, retaking, or defending a persistent economy site under normal turns.
- No same-scenario A/B fixture runs both Embercourt and Mireclaw against identical geography and target sets.
- No coefficient audit has checked whether existing config values are intentional, balanced, or only inherited from earlier scaffolds.
- No commander-role state proves distinct Embercourt and Mireclaw hero task identities beyond shared raid commander and rebuild surfaces.
- No durable AI event log, save migration, AI hero task state, adventure-spell evaluation, artifact planning, or broader strategic planner proof exists.

## Evidence Decision

The report is sufficient to claim early behavior-neutral personality evidence:

- Embercourt: supported as town-front, civic infrastructure, garrison/readiness, and charter-asset pressure.
- Mireclaw: supported as raid, denial, growth/replacement, resource counter-pressure, and commander-rebuild pressure.

The evidence is not sufficient for coefficient tuning by itself. The main follow-up need is a strategy config audit plan that reconciles intended faction identity, current content reality, scenario overrides, public reason phrases, and the Prismhearth/Glassroad fixture mismatch before any behavior tuning.

## Recommended Next Slice

Recommended next concrete slice: `strategic-ai-strategy-config-audit-planning-10184`.

Purpose:

- Plan a narrow audit of Embercourt and Mireclaw strategy config and scenario overrides before tuning.
- Confirm which weights are intentional personality anchors versus temporary scaffold values.
- Decide whether public reason vocabulary should gain clearer civic/readiness wording for Embercourt while staying compact.
- Decide whether the first capture/counter-capture proof should use Mireclaw retaking a logistics site or Embercourt defending a town/resource front.

Deferred:

- Coefficient tuning.
- Commander-role state planning.
- Capture/counter-capture proof implementation.
- Live-client enemy-turn pacing gate.
- Durable event logs, save migration, full AI hero state, pathing/body-tile/approach adoption, renderer/editor changes, neutral encounter migration, generated PNG import, and River Pass rebalance.
