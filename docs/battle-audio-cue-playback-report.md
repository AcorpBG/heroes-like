# Battle Audio Cue Playback Report

Date: 2026-05-23

## Status

Implementation evidence. This slice makes active battle audio cue ids produce runtime playback through generated waveforms. It does not import final audio assets, add music, add ambience, or claim final sound design.

## What Changed

- `BattleBoardView` now exposes `validation_audio_playback_summary()` alongside animation, cue, and VFX playback summaries.
- Active `selected_audio_cue_ids` are converted into short `AudioStreamGenerator` sounds on the `Master` bus.
- Generated cue specs cover the current battle placeholder audio ids:
  - ranged release,
  - status apply and clear,
  - melee release,
  - hit,
  - unit rout,
  - cast,
  - unit step,
  - defend,
  - retaliation,
  - retreat and surrender order,
  - turn ready,
  - idle soft.
- Playback records expose selected cue ids, generated waveform metadata, generated frame counts, active player count, bus, mute state, and expiry timing.
- Active generated players are capped and cleaned up after playback.

## Validation Evidence

Focused command:

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/battle_event_animation_state_report.tscn
```

The focused report now includes `board_audio_playback`. It verifies:

- `battle_unit_ranged_attack` synthesizes `audio_placeholder_ranged_release`;
- `battle_status_applied` synthesizes `audio_placeholder_status_apply`;
- audio playback records are active during the board playback window;
- generated waveform counts are present for source and target cue records;
- audio playback records expire with the board playback lifecycle.

## Boundaries

This is runtime placeholder audio playback. Remaining production layers include final authored sound effects, imported audio assets, music, ambient map audio, UI audio, mixer priority, platform audio QA, and combat feel/balance tuning.
