# Main Menu Archived Campaign Empty-State Smoke Report

Slice: `main-menu-archived-campaign-empty-state-smoke-20260523-10184`
Date: 2026-05-23

## Scope

The current campaign domain reset is intentional: `content/campaigns.json` exposes `archived_native_campaign_set_disabled`, and player-facing campaign APIs return no selectable campaign arcs.

This slice aligns the main menu and `menu_outcome_visual_smoke` with that product state. The campaign board now reports an `archived_empty` validation status, shows a disabled empty-state action, and directs players to `Skirmish` for playable authored fronts while campaign arcs remain archived.

## Implemented Boundary

- Main menu campaign details, chapter details, commander preview, operational board, journal, primary action, and chapter action now expose explicit archived campaign reset text when no campaign entries exist.
- The validation snapshot reports `campaign_board_status`, empty-state text/tooltips, and disabled campaign action flags so smoke tests can distinguish archived-empty from active campaign boards.
- `tests/menu_outcome_visual_smoke.gd` accepts the archived-empty state only when no campaign entries leak and the disabled labels/tooltips explain the reset.
- `tests/validate_repo.py` gates the archived-empty smoke contract and this report.

## Non-Goals

- No reactivation of archived campaign domain.
- No new campaign chapters, campaign progression arcs, or campaign content migration.
- No change to skirmish content selection beyond preserving the existing launch smoke coverage.

## Validation

Expected focused gates:

- `godot --headless --path . --quit-after 120 --scene res://tests/menu_outcome_visual_smoke.tscn`
- `godot --headless --path . --quit-after 120 --scene res://tests/map_campaign_replayability_breadth_report.tscn`
- `python3 tests/validate_repo.py`
- `jq empty ops/progress.json`
- `git diff --check`
