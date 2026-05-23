# Battle Exit Event Motion Presentation Report

Slice: `battle-exit-event-motion-presentation-20260523-10184`

Status: implementation evidence.

## Scope

Retreat and surrender already had exit snapshots, cue dispatch, generated audio, and camera presentation. This slice adds the missing board-token motion handoff so the exiting stack has a distinct visible presentation role while the snapshot is still being rendered.

## Behavior

- `BattleBoardView` maps `battle_unit_retreat` playback to `retreat_withdraw` token motion.
- `BattleBoardView` maps `battle_unit_surrender` playback to `surrender_stand_down` token motion.
- Surrender is now a first-class battle troop state family in `AnimationCueCatalog`, `content/animation_event_cues.json`, `content/unit_animation_manifest.json`, and the deterministic unit-art generator.
- `tests/battle_event_animation_state_report.tscn` validates the exit snapshot path exposes active token motion, event id, role, and role counts for both exit actions.

## Boundaries

- No final authored animation timing.
- No imported VFX or audio assets.
- No combat balance tuning.
- No save migration or durable battle-state schema change.
- No broad battle UX redesign.

## Validation

Focused commands:

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_event_animation_state_report.tscn
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/animation_battle_troop_state_contract_report.tscn
python3 tests/validate_repo.py
```
