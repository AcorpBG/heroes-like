# Strategic AI Neutral Town Expansion Report

Slice: `strategic-ai-neutral-town-expansion-10184`

Status: implementation evidence.

## Scope

This report covers the neutral-town expansion behavior now implemented in live strategic AI. Reachable neutral towns enter the commander target surface as expansion objectives. Empty neutral towns are captured on arrival, while defended neutral towns route ready assaults through the live town battle system and are captured after the defender loses.

This is not a full strategic AI production-ready claim. Full generated-map matrix approval, broader generated-map army/economy timing, and live-client pacing remain open.

## Behavior

- Empty neutral towns are scored as `town` targets with `town_expansion` and `neutral_town_claim` reason codes.
- Defended neutral towns add `neutral_town_siege` and remain valid while the town remains neutral.
- Arrival at an empty neutral town calls `OverworldRules.transition_town_control(...)` with owner `enemy`, the active faction id, and source `strategic_ai_neutral_town_expansion`.
- Capture emits `ai_town_captured`, completes the live commander task, records commander outcome `town_captured`, and adds a small pressure gain.
- Ready defended neutral-town assaults queue a `town_defense` battle with `defender_owner = neutral`.
- Weak defended neutral-town assaults use the same assault risk gate as other town assaults, while preserving neutral-expansion reason codes for regroup/support decisions.
- Enemy victory captures the defended neutral town into enemy control, completes the commander task, and avoids player-collapse/resource-loss aftermath for neutral defenders.
- Player-town assault and town-defense regroup continue to use their existing paths.

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
