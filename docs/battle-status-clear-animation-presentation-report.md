# Battle Status Clear Animation Presentation Report

Date: 2026-05-23
Task: #10184

## Scope

This slice makes status removal visible in the event-driven battle presentation pipeline. Cleanses and round-expired effects now emit `battle_status_expired` / `status_expired` instead of being folded into the existing status-apply presentation.

## Implementation

- `BattleRules` maps `battle_status_expired` to `status_expired`.
- `BattleRules.cast_player_spell(...)` and enemy spell casting preserve the concrete cleanse count from `cleanse_effect` resolution and emit `battle_status_expired` when an effect was actually removed.
- Round preparation counts effects that expire before the new round, purges them through `SpellRules.purge_expired_stack_effects(...)`, and emits `battle_status_expired` for the affected stack.
- `BattleBoardView` presents the event through `status_clear` token motion, `vfx_placeholder_status_clear`, `audio_placeholder_status_clear`, and status camera focus/shake records.
- `tests/battle_event_animation_state_report.gd` now proves both a real `spell_prism_bastion` cleanse and a round-expiry purge.

## Validation

Passing command:

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --scene res://tests/battle_event_animation_state_report.tscn
```

Focused report summary:

```text
BATTLE_EVENT_ANIMATION_STATE_REPORT {"case_count":17,"cases":["fallback","defend","move","melee_hit","ranged_status","death","spell_cast","status_cleanse","status_round_expiry","retreat","surrender","board_runtime","board_cue_dispatch","board_vfx_presentation","board_audio_playback","board_camera_presentation","board_playback_lifecycle"],"ok":true}
```

The report intentionally runs to completion without `--quit-after 120`; the expanded animation lifecycle cases can be cut short by the frame limit before final report writeback.

## Non-Goals

- No final imported VFX or audio assets.
- No spell balance retune.
- No broad battle UX redesign.
