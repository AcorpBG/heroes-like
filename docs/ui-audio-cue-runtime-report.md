# UI Audio Cue Runtime Report

Slice: `ui-audio-cue-runtime-baseline-20260523-10184`

## Scope

This slice adds a generated runtime UI audio baseline. It is not final sound design, imported audio assets, music, ambience, or mixer polish.

## Implemented Gate

- Added `scripts/autoload/UiAudio.gd` and registered it in `project.godot`.
- `UiAudio` scans the scene tree and attaches to common Godot UI controls without per-screen wiring.
- Supported cues include `ui_click`, `ui_select`, `ui_adjust`, `ui_tab`, `ui_confirm`, and `ui_invalid`.
- Runtime playback uses generated `AudioStreamGenerator` waveforms on the `Master` bus.
- Playback records expose cue id, source, metadata, frequency, duration, gain, mute state, played state, active player count, and the player cap.
- Added `tests/ui_audio_cue_runtime_report.tscn` to exercise `Button`, `OptionButton`, `HSlider`, `TabContainer`, `ItemList`, confirm, and invalid-action cues.

## Validation Command

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ui_audio_cue_runtime_report.tscn
```

The result is a runtime placeholder UI-audio layer for production polish work. Final imported UI audio, music, ambience, bus/mixer design, and hand-authored sound direction remain open.
