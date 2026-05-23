# Player-Facing Authored Skirmish Browser Report

Slice: `player-facing-authored-skirmish-browser-20260523-10184`
Date: 2026-05-24

## Scope

Active authored scenarios already have skirmish availability metadata and `build_skirmish_setup` can launch them, but the browser row source was still maps-folder package only. This slice makes `ScenarioSelectRules.build_skirmish_browser_entries` include active authored skirmish fronts.

## Implemented Boundary

- Authored browser rows are derived from active scenario content and `selection.availability.skirmish`.
- Rows carry `source_kind: authored_scenario`, scenario id, label, summary, availability, and recommended difficulty.
- Maps-folder package rows remain appended to the same browser list.
- Generated-map transient draft scenario ids remain excluded from authored skirmish rows and campaign content.
- `PLAYER_FACING_SKIRMISH_BROWSER_SMOKE` validates direct browser exposure, setup generation, main-menu selection, and generated-map transient draft isolation.

## Non-Goals

- No new authored scenario maps or encounter content.
- No generated-map campaign adoption.
- No full skirmish/campaign breadth completion claim.

## Validation

Focused gates:

- `godot --headless --path . --quit-after 120 --scene res://tests/player_facing_skirmish_browser_smoke.tscn`
- `godot --headless --path . --quit-after 120 --scene res://tests/random_map_scenario_load_smoke.tscn`
- `python3 tests/validate_repo.py`
- `jq empty ops/progress.json`
- `git diff --check`
