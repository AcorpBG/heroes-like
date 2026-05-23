# Skirmish Launch Briefing UX Report

Date: 2026-05-23
Slice: `skirmish-launch-briefing-ux-20260523-10184`

## Purpose

The skirmish launch board already exposed real launch metadata, but the handoff still read like a package/debug surface in generated-map flows. This slice adds an explicit compact `briefing_check` to skirmish setup payloads so the menu can show the opening context and first player decision before launch.

## What Changed

- Authored skirmish setup payloads now include `briefing_check` derived from scenario briefing, objective stakes, front context, and readiness evidence.
- Maps-folder package skirmish payloads now include `briefing_check` with an `Opening briefing` and `First decision` line.
- `MainMenu` includes the briefing in the Skirmish Front Check tooltip and visible setup summary.
- `tests/menu_outcome_visual_smoke.gd` gates the visible and tooltip handoff tokens.

## Boundaries

- No campaign-domain reactivation.
- No scenario content rewrite.
- No save/load behavior change.
- No broad onboarding redesign.
- No alpha completeness claim.

## Validation

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 180 --scene res://tests/menu_outcome_visual_smoke.tscn
python3 tests/validate_repo.py
python3 -m py_compile tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```
