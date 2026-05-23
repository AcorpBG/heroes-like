# Player-Facing Campaign Reactivation Smoke Report

Slice: `player-facing-campaign-reactivation-smoke-20260523-10184`
Date: 2026-05-23

## Scope

The authored campaign and scenario domains are reactivated for player-facing menu flow. `content/campaigns.json` records `player_facing_active_campaign_count` for the five authored campaign arcs, and `content/scenarios.json` records `player_facing_active_scenario_count` for the sixteen authored scenarios.

This is a focused activation and smoke-gate slice. It makes the existing CampaignRules browser/start/chapter APIs visible through the main menu and updates reports that previously enforced the archived-domain reset.

## Implemented Boundary

- `CampaignRules` is the live campaign browser and launch source of truth.
- `menu_outcome_visual_smoke` validates the active campaign board path, launch preview, chapter selection, commander preview, and operational board copy.
- `map_campaign_replayability_breadth_report` validates active campaign API exposure, chapter unlock/replay semantics, campaign-session boot, skirmish-session separation, and generated-map non-adoption boundaries.
- Random-map smoke continues to require generated map packages to stay out of authored scenario and campaign content.

## Non-Goals

- No full campaign-breadth completion claim.
- No final campaign balance, encounter tuning, or authored narrative polish claim.
- No generated-map campaign adoption.
- No campaign schema migration.

## Validation

Focused gates:

- `godot --headless --path . --quit-after 120 --scene res://tests/player_facing_campaign_menu_smoke.tscn`
- `godot --headless --path . --quit-after 120 --scene res://tests/map_campaign_replayability_breadth_report.tscn`
- `godot --headless --path . --quit-after 120 --scene res://tests/random_map_scenario_load_smoke.tscn`
- `python3 tests/validate_repo.py`
- `jq empty content/scenarios.json content/campaigns.json ops/progress.json`
- `git diff --check`
