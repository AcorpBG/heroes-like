# UI Audio Cue Runtime Report

Slice: `ui-audio-cue-runtime-baseline-20260523-10184`

Runtime asset follow-up: `ui-runtime-sfx-asset-layer-20260524-10184`

## Scope

This slice adds a generated runtime UI audio baseline and a follow-up manifest-backed runtime UI SFX asset layer. It is not final sound design, music, ambience, or mixer polish.

## Implemented Gate

- Added `scripts/autoload/UiAudio.gd` and registered it in `project.godot`.
- `UiAudio` scans the scene tree and attaches to common Godot UI controls without per-screen wiring.
- Supported cues include `ui_click`, `ui_select`, `ui_adjust`, `ui_tab`, `ui_confirm`, and `ui_invalid`.
- Runtime playback prefers committed original WAV assets from `content/ui_sfx_manifest.json` under `art/audio/runtime/ui/` on the `Master` bus, with generated `AudioStreamGenerator` waveforms preserved as fallback.
- Playback records expose cue id, source, metadata, frequency, duration, gain, mute state, played state, active player count, player cap, manifest path, imported-asset count, generated-fallback count, and selected asset path.
- Added `tests/ui_audio_cue_runtime_report.tscn` to exercise `Button`, `OptionButton`, `HSlider`, `TabContainer`, `ItemList`, confirm, and invalid-action cues.

## Validation Command

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ui_audio_cue_runtime_report.tscn
```

The result is a runtime UI-audio layer with reproducible original WAV assets for production polish work. Final sound design, music, ambience, bus/mixer design, and hand-authored sound direction remain open.
