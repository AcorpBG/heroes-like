# Battle Attack And Hit Token Feedback Report

Date: 2026-05-23

## Status

Implementation evidence. Battle attack and hit events already selected generated animation states and emitted placeholder VFX/audio cues, but stack tokens stayed fixed at their board cell during the event playback window. This slice uses existing source/target event context to add bounded token-level presentation transforms for attacks and impacts.

## What Changed

- `BattleBoardView` now computes token presentation transforms for melee attacks, retaliations, ranged attacks, casts, hits, status application, and deaths.
- Melee and retaliation events lunge the acting stack toward the target during normal playback.
- Ranged and cast events apply compact recoil/anchor motion without moving the resolved board cell.
- Hit, status, and death target events use `source_battle_id` to stagger or pulse the affected stack away from the source.
- The existing stack token, health bar, count badge, caption, and click hit shape all use the transformed presentation center.
- `tests/battle_event_animation_state_report.tscn` now proves a real melee strike presents the attacker as `melee_lunge` and the target as `hit_stagger` while retaining cue-driven melee VFX.

## Validation

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_event_animation_state_report.tscn
```

## Boundaries

This adds event-driven token feedback for attack and impact readability. It does not add final authored motion curves, per-unit attack timing, camera shake, imported VFX/audio assets, or combat balance tuning.
