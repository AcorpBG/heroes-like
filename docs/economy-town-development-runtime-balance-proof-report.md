# Economy Town Development Runtime Balance Proof Report

Status: implemented runtime proof.
Date: 2026-05-24.
Slice: `economy-town-development-runtime-balance-proof-20260524-10184`.

## Scope

This slice strengthens the town-development balance gate by moving the six-faction 30-turn proof through live Godot rules.

The previous Python report validates authored content and the deterministic balance profile. This runtime report adds a stronger check: it creates live `SessionStateStore.SessionData` sessions, selects each authored town through `OverworldRules.set_active_town_visit(...)`, advances income through `OverworldRules.end_turn(...)`, and builds through `OverworldRules.build_in_active_town(...)`.

## Evidence

The executable evidence is `tests/town_development_runtime_balance_report.gd` and `.tscn`.

The report proves:

- all 15 authored towns complete their authored buildable development within the 30-turn target;
- town construction uses live Godot build rules, not a Python-only simulation;
- every authored town rejects a same-day second build with the live one-build-per-town-per-day guard;
- the town build-action surface no longer exposes same-day follow-up build actions after a build;
- high-tier rare-resource costs are paid through live resource deduction;
- normal market actions remain bounded to `wood` and `ore`;
- daily balance income flows through controlled live resource-site income plus the normal town income path.

The seed-town completion days from the first runtime proof remain:

- Embercourt `town_highwater_keep`: day 17
- Mireclaw `town_nightglass_redoubt`: day 18
- Sunvault `town_prismhearth`: day 18
- Thornwake `town_thornwake_graftroot_caravan`: day 7
- Brasshollow `town_brasshollow_orevein_gantry`: day 7
- Veilmourn `town_veilmourn_bellwake_harbor`: day 7

## Runtime Rule Fix

This slice also closes a live-surface gap found while implementing the report: `build_in_active_town(...)` already rejected same-day second builds, but `TownRules.get_build_actions(...)` still derived available build actions without passing the current day into `OverworldRules.get_town_build_options(...)`.

`get_town_build_options(...)` now accepts `current_day`, and `TownRules.get_build_actions(...)` passes `session.day`, so the available-action surface and the authoritative build rule agree.

## Boundaries

This is not final scenario-wide economy balance, final market cap persistence, final AI economy planning, or final town UI/art. It is a focused runtime proof that the requested town-development loop is viable through live rules for every authored town.

## Validation

Focused gate:

```bash
godot --headless --log-file /tmp/heroes-like-town-runtime-balance.log --path . --scene res://tests/town_development_runtime_balance_report.tscn
```

Repository gates:

```bash
python3 tests/town_development_balance_report.py
python3 tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```
