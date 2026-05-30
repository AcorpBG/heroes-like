# Strategic AI Neutral Town Expansion Report

Slice: `strategic-ai-neutral-town-expansion-10184`

Status: implementation evidence.

## Scope

This slice changes live strategic AI behavior. Reachable empty neutral towns now enter the commander target surface as expansion objectives, and an arriving AI raid can transition that town into enemy control with the correct controlling faction and stabilization front state.

This is not a full strategic AI production-ready claim. Defended neutral-town siege battles, full generated-map matrix approval, and broad live-client pacing remain open.

## Behavior

- Empty neutral towns are scored as `town` targets with `town_expansion` and `neutral_town_claim` reason codes.
- Neutral-town targets are valid only while the town remains neutral and has no garrison.
- Arrival at an empty neutral town calls `OverworldRules.transition_town_control(...)` with owner `enemy`, the active faction id, and source `strategic_ai_neutral_town_expansion`.
- Capture emits `ai_town_captured`, completes the live commander task, records commander outcome `town_captured`, and adds a small pressure gain.
- Player-town assault, town-defense regroup, and guarded/defended neutral towns remain outside this narrow slice.

## Validation

Focused command:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ai_neutral_town_expansion_report.tscn
```

Repository gates:

```sh
python3 tests/validate_repo.py
jq empty ops/progress.json
git diff --check
```
