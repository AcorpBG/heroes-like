# Battle Animation Cue Dispatch Report

Date: 2026-05-23

## Status

Implementation evidence. This slice connects active battle animation events to the existing animation cue catalog at board runtime. It does not import final audio, final VFX, camera work, or combat balance changes.

## What Changed

- `BattleBoardView` now resolves each newly observed animation event through `AnimationCueCatalog.cue_playback_policy_for_event(...)`.
- The board keeps transient cue playback records keyed by battle stack id.
- Each record captures selected animation state, visual/playback/blocking policy, VFX cue ids, audio cue ids, audio policy, and max playback duration.
- Cue records expire with the existing stack animation playback lifecycle, so placeholder VFX/audio dispatch does not outlive the active event pose.
- Validation summaries now expose cue playback counts and active records for focused reports.

## Validation Evidence

Focused command:

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_event_animation_state_report.tscn
```

The report now includes `board_cue_dispatch` and `board_playback_lifecycle` coverage. It verifies:

- `battle_unit_ranged_attack` dispatches `vfx_placeholder_projectile_path` and `audio_placeholder_ranged_release`.
- `battle_status_applied` dispatches `vfx_placeholder_status_residue` and `audio_placeholder_status_apply`.
- Both source and target cue records are active during playback.
- Cue records expire when the board-side animation playback window expires.

## Boundaries

This is runtime cue dispatch over placeholder ids. Remaining production work includes imported audio assets, authored VFX assets, camera/shake timing, mixer policy, final animation timing, and combat feel/balance passes.
