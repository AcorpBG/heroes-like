# Economy Capture Income Loop Expansion Report

Status: implemented bounded live-rule smoke.
Date: 2026-04-27.
Slice: `economy-capture-income-loop-expansion-10184`.

## Scope

This slice expands the prior Riverwatch signal-yard proof onto a second existing front, `glassroad-sundering`, without changing production content, save format, market rules, or resource ids.

The executable evidence is `tests/economy_capture_income_expansion_report.gd` and `.tscn`.

## Evidence

The focused Godot report exercises current runtime rules for the Glassroad relay/lens-house loop:

- starts `glassroad-sundering` with live stockpile resources `gold`, `wood`, and `ore`;
- claims `glassroad_watch_relay` through `OverworldRules.collect_active_resource`;
- advances a day and asserts visible `Field sites yield 25 gold`;
- claims `glassroad_lens_house`, proving persistent control plus immediate field recruits;
- advances a day and asserts combined `Field sites yield 70 gold`;
- claims current common-resource pickups `glassroad_wood`, `glassroad_ore`, and `market_cache`;
- builds `building_market_square` in `halo_spire_bridgehead`;
- verifies the post-market town decision surface exposes `building_starseer_annex` as affordable through current `gold`/`wood`/`ore` gates;
- recruits one `unit_prism_adept`;
- saves to manual slot 3 and restores through `SaveService`, matching day, resources, controlled sites, town build state, recruits, army, game state, scenario status, and `SAVE_VERSION 9`.

The report deliberately positions the hero on selected sites as a deterministic fixture. It does not add resources directly, change content, force battle outcomes, migrate saves, activate rare resources, alter normal market exchange, or rebalance Glassroad.

## Validation

Focused smoke:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/economy_capture_income_expansion_report.tscn
```

Required baseline validation remains:

```bash
python3 tests/validate_repo.py
python3 tests/validate_repo.py --economy-resource-report --economy-resource-report-json /tmp/heroes-economy-resource-report.json
python3 tests/validate_repo.py --market-faction-cost-report --market-faction-cost-report-json /tmp/heroes-market-faction-cost-report.json
python3 tests/validate_repo.py --strict-economy-resource-fixtures
```

## Boundaries

- `wood` remains canonical.
- Rare resources remain staged/report-only.
- Normal town market exchange remains bounded to `wood` and `ore`.
- No `SAVE_VERSION` bump or save migration.
- No broad market migration, faction-cost rebalance, route/pathing migration, renderer/editor change, or production JSON migration.

## Result

The final P2.3 child passes: a second existing front now has executable current-rule evidence that capture/control matters, income is visible, town/recruit/market decisions are affected, and save/resume preserves the loop.
