# Immediate Goals

Task: #10184
Document role: owner-facing near-term goal sheet
Source docs: `project.md`, `PLAN.md`, `ops/progress.json`

## Purpose

This file names the next immediate goals clearly enough for implementation work to start without rereading long history. It is not a progress log and does not replace `PLAN.md` or `ops/progress.json`.

The current focus is Phase 5 - Playable Alpha Baseline. Campaign production remains deferred.

## Battle Balance Target

Current state:
- The economy/town development slice is complete enough to stop driving immediate work.
- The next highest-impact balance surface is battle pacing and faction matchup evidence.
- Full Godot battle runs are too slow for fast iteration, so balance needs a deterministic Python benchmark that uses the same content stats and closely ports the current battle formulas.

Target state:
- A fast Python benchmark can simulate faction-vs-faction battles without launching the Godot runtime.
- The benchmark uses live faction, town, hero, spell, unit, growth, and battle-stat content from `content/*.json`.
- The benchmark reports week 1, week 2, week 3, and week 4 matchup matrices for every ordered faction pairing.
- The benchmark exposes win-rate, pacing, action-mix, casualty, and consequence outliers as tuning evidence.
- The benchmark is a balance tool first. It must not hide bad combat results just to make a gate pass.

## Goal 1 - Fast Faction Battle Benchmark

Progress slice: `battle-fast-faction-benchmark-10184`

Implement a pure-Python benchmark for fast tactical balance iteration:
- load the current unit, faction, hero, spell, town, and building content;
- reuse town-development output where it helps select representative towns and growth context;
- construct deterministic faction army snapshots for weeks 1-4;
- simulate every ordered non-self faction matchup;
- run multiple deterministic seeds per matchup;
- emit JSON suitable for quick comparison and future tuning automation.

Army snapshot policy:
- week 1: initial starting growth plus one recruited week capped at T1-T3;
- week 2: initial starting growth plus week-one T1-T4 and week-two T1-T5 recruitment;
- week 3: initial starting growth plus week-one T1-T4, week-two T1-T5, and week-three T1-T7 recruitment;
- week 4: initial starting growth plus week-one T1-T4, week-two T1-T5, and week-three/week-four T1-T7 recruitment with fully developed growth for the final full-tier ticks.

## Goal 2 - First Balance Evidence

Use the benchmark to produce the first faction matrix evidence:
- early faction-vs-faction tests for week 1;
- midgame faction-vs-faction tests for weeks 2 and 3;
- endgame faction-vs-faction tests for week 4;
- ordered matchup rows for all six factions;
- pair summaries that make side bias, runaway matchups, and too-short/too-long battle pacing visible.

Initial balance target:
- faction-pair dominant win rates should trend toward a 45-55% health band over repeated seeds;
- the benchmark must not model fake stalemate outcomes; unresolved simulations are structural failures, not balance data;
- average battle length should usually land in a readable tactical range;
- failures are tuning evidence for the next combat pass, not a reason to suppress the benchmark.

## Goal 3 - Tune From Evidence, Not Reports

After the benchmark exists, use its results to select the next combat tuning slice:
- unit stat adjustments;
- growth and stack-size adjustments;
- initiative and pacing changes;
- ability power and trigger changes;
- spell impact and AI casting choices;
- terrain/tag value changes;
- battle AI target/action scoring changes.

Do not tune broadly until the benchmark output identifies the highest-value outliers.

## Goal 4 - Validation

Required validation for this slice:

```bash
python3 tests/battle_faction_fast_balance_benchmark.py --quick
python3 tests/battle_faction_fast_balance_benchmark.py --seeds 100 --weeks 1,2,3,4 --gate
python3 tests/town_development_balance_report.py
python3 tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```

Success means:
- the fast benchmark runs without Godot;
- all six factions have valid seven-tier army snapshots;
- all ordered non-self faction matchups are simulated for weeks 1-4;
- structural benchmark failures are gated;
- balance outliers are reported clearly for the next tuning pass;
- existing town-development and repo validation still pass.

## Non-Goals

- Do not start campaign production.
- Do not claim final combat balance from the first benchmark.
- Do not make authored scenario maps the benchmark source of truth.
- Do not add new gates that only make reports pass without improving playability.
- Do not replace Godot battle validation; this is a fast balance harness for iteration.
