# Economy Town Development Live Balance Gate Report

Status: implemented bounded production-readiness gate.
Date: 2026-05-24.
Slice: `economy-town-development-live-balance-gate-20260524-10184`.

## Scope

This slice moves the town economy out of report-only rare-resource staging and into live runtime validation for the current authored town-development model.

The implemented policy is:

- `gold`, `wood`, `ore`, `aetherglass`, `embergrain`, `peatwax`, `verdant_grafts`, `brass_scrip`, and `memory_salt` are live stockpile resource ids.
- Normal town markets remain common-resource exchanges only; rare resources are not normal-market-buyable.
- Low and mid town development remains primarily `gold`, `wood`, and `ore`.
- High-tier faction signature buildings require the faction rare resource.
- Each town can complete one build order per town day.
- Six seed faction towns have an authored development-balance profile with a 30-turn completion target.

## Implementation

Runtime resource normalization now preserves all live stockpile ids across scenario setup, campaign/resource payloads, scripted resource effects, battle reward/loss handling, hero command descriptions, and town affordability checks.

Town construction now tracks `last_build_day` on town state and blocks a second build order for that town on the same session day. The build action surface passes the active day into `OverworldRules.get_town_build_status(...)`, so the UI and rules agree before a player presses the build button.

Faction signature building ladders now use rare resources at higher tiers:

- Embercourt: `embergrain`
- Mireclaw: `peatwax`
- Sunvault: `aetherglass`
- Thornwake: `verdant_grafts`
- Brasshollow: `brass_scrip`
- Veilmourn: `memory_salt`

Rare-resource sites and matching resource-front map-object metadata are live stockpile sources rather than report-only markers.

## Evidence

`tests/town_development_balance_report.py` validates the current authored data and simulates deterministic seed-town development under the authored balance profile. It proves:

- all nine resource ids are live stockpile resources;
- all six rare resources have live sources;
- each seed faction town has seven signature unit-building tiers;
- lower signature tiers avoid rare-resource costs;
- high signature tiers include the matching faction rare resource;
- tier 5-7 signature unit buildings obey pacing floors of day 4, day 12, and day 22;
- every authored town hits at least one late rare-resource bottleneck on day 18 or later before full development completes;
- every authored town finishes deterministic development under bounded post-completion common-resource surplus caps;
- one build per simulated town day is enforced by the build loop;
- all authored towns complete their buildable development within the day-24-to-day-30 deterministic phase curve.

Current focused completion days are:

- 15 authored towns complete between day 24 and day 30, with every town preserving early, midgame, and late construction work.
- Late rare-resource bottleneck evidence covers 15/15 authored towns, with at least one day 18+ rare-gated high-tier or upgrade stall in every deterministic development curve.
- Post-completion common-resource surplus evidence covers 15/15 authored towns, with ending gold, wood, and ore under deterministic absolute and ratio caps.
- Tier 7 signature unit buildings arrive between day 22 and day 28.

## Boundaries

This is not final economy production balance. It does not claim final scenario pacing, final AI economy planning, final market cap/save-schema persistence, final town UI/art, final campaign economy tuning, or final broad random-map economy ecology.

It is a live-rule gate for the requested town-development shape: full resource ids wired as stockpiles, rare resources used by high-tier town development, one build per town per day, seven-tier seed faction unit ladders, and deterministic six-faction 30-turn feasibility.

## Validation

Focused gates:

```bash
python3 tests/town_development_balance_report.py
godot --headless --log-file /tmp/heroes-like-economy-capture.log --path . --scene res://tests/economy_capture_income_expansion_report.tscn
godot --headless --log-file /tmp/heroes-like-town-smoke.log --path . --scene res://tests/town_battle_visual_smoke.tscn
```

Repository gates:

```bash
python3 -m py_compile tests/town_development_balance_report.py tests/validate_repo.py
python3 tests/validate_repo.py
python3 tests/validate_repo.py --strict-economy-resource-fixtures
jq empty ops/progress.json
git diff --check
```
