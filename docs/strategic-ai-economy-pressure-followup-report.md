# Strategic AI Economy Pressure Follow-Up Report

Status: completed implementation.
Date: 2026-04-27.
Slice: `strategic-ai-economy-pressure-followup-10184`.

## Scope

This follow-up addresses the concrete caveat from `docs/strategic-ai-economy-pressure-report-gate-review.md`: `southern_ore` was named in the original pressure plan as a simple-pickup comparator, but the focused reachable report did not include it.

The change is report/helper evidence only. It does not alter target scoring, coefficients, live target selection, raid movement, save data, resources, economy rules, rare resources, markets, scenario placement, pathing, renderer/editor behavior, or public UI output.

## Delivered

- Added `EnemyAdventureRules.resource_pressure_target_report(...)` for named resource target evidence.
- Added bounded route-gate metadata for report output when a resource target shares its tile with an unresolved encounter.
- Extended `tests/ai_economy_pressure_report.gd` with `southern_ore_hollow_mire_gate`.

## Finding

The missing `southern_ore` evidence was not a scoring defect. In River Pass, `southern_ore` shares tile `(6, 4)` with unresolved `river_pass_hollow_mire`, so the ranked reachable resource report correctly excludes it before the route fight is resolved.

After the fixture marks `river_pass_hollow_mire` resolved, `southern_ore` enters the ranked report with positive ore-branch scarcity evidence. It ranks behind player-owned `river_free_company` and `river_signal_post`, preserving the passed signal-yard economy pressure ordering.

## Validation

Focused report rerun:

```bash
godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/ai_economy_pressure_report.tscn
```

Result: passed. The report printed `AI_ECONOMY_PRESSURE_REPORT` with `"ok": true` and included `southern_ore_hollow_mire_gate`.

## Boundaries

Detailed score fields remain report/debug evidence. No player-facing/public event or threat output was changed, and no durable AI event log or save migration was introduced.
