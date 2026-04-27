# Artifact Source And Reward Rules Report

Status: implementation evidence.
Date: 2026-04-27.
Slice: `artifact-source-reward-rules-10184`.

## Scope

This slice adds bounded artifact source/reward metadata and validation/report hooks. It connects authored artifacts to existing map object and resource-site reward contexts through source tables, guard tiers, rarity bands, eligible object/site families, faction constraints, and set constraints.

## Implemented

- Added `source_reward_tables` to `content/artifacts.json`.
- Added `ArtifactRules.artifact_source_reward_report()` for source-table validation and map object/site context matching.
- Added repository validator support and opt-in `--artifact-source-reward-report` output.
- Added focused Godot report scene `tests/artifact_source_reward_report.tscn`.

## Runtime Boundary

The source/reward tables are authored metadata and report hooks only. They do not execute live drops, change equipment effects, alter save payloads, enable AI valuation behavior, activate rare resources, or migrate scenarios.

Existing guarded reward site metadata is used as evidence context where it is already safe: reward categories, guard tiers, and metadata-only runtime boundaries remain unchanged.

## Validation

Required validation for completion:

- canonical wood alias scan
- `python3 tests/validate_repo.py`
- `python3 tests/validate_repo.py --artifact-taxonomy-report --artifact-set-faction-report --artifact-source-reward-report`
- `godot4 --headless --path . --quit-after 20 --scene res://tests/artifact_taxonomy_schema_report.tscn`
- `godot4 --headless --path . --quit-after 20 --scene res://tests/artifact_set_faction_content_report.tscn`
- `godot4 --headless --path . --quit-after 20 --scene res://tests/artifact_source_reward_report.tscn`
- `python3 -m json.tool ops/progress.json >/tmp/heroes-progress-json.txt`
- progress helper `status` and `next`
- `git diff --check`
