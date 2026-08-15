# UI Audio Cue Runtime Report

Slice: `ui-audio-cue-runtime-baseline-20260523-10184`

Runtime asset follow-up: `ui-runtime-sfx-asset-layer-20260524-10184`

Production-fidelity follow-up: `presentation-ui-production-sfx-fidelity-10184`

## Scope

The baseline added generated UI audio and the asset-layer follow-up introduced manifest-backed runtime WAVs. The production-fidelity follow-up replaces the complete six-cue mono placeholder pack with distinct original deterministic 44.1 kHz stereo 16-bit production transients while preserving the existing cue contract. It is not final sound design or mixer-mastering approval, music, ambience, or Battle audio work.

## Implemented Gate

- Added `scripts/autoload/UiAudio.gd` and registered it in `project.godot`.
- `UiAudio` scans the scene tree and attaches to common Godot UI controls without per-screen wiring.
- Supported cues include `ui_click`, `ui_select`, `ui_adjust`, `ui_tab`, `ui_confirm`, and `ui_invalid`.
- Runtime playback prefers committed original WAV assets from `content/ui_sfx_manifest.json` under `art/audio/runtime/ui/` on the `Effects` bus routed through `Master`, with generated `AudioStreamGenerator` waveforms preserved as fallback.
- The six exact click, select, adjust, tab, confirm, and invalid paths retain their authored durations, roles, and volumes while using cue-specific latch, glass-pluck, ratchet, page-turn, seal-chime, and wooden-denial material gestures.
- Playback records expose cue id, source, metadata, frequency, duration, gain, mute state, played state, active player count, player cap, manifest path, imported-asset count, generated-fallback count, selected asset path, and imported stream length, mix rate, stereo, runtime format, and loop mode. The committed source WAV contract remains 16-bit PCM while Godot's imported runtime representation is QOA.
- Added `tests/ui_audio_cue_runtime_report.tscn` to exercise `Button`, `OptionButton`, `HSlider`, `TabContainer`, `ItemList`, confirm, and invalid-action cues.
- Focused validation proves all six exact imported identities and all five real control-family routes, generated fallback, Effects mute, the normal eight-player and reduced-repetition four-player budgets, and cooldown suppression before player creation.

## Validation Command

```bash
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 120 --scene res://tests/ui_audio_cue_runtime_report.tscn
```

The result is a production-fidelity runtime UI-audio pack with reproducible original stereo WAV assets and unchanged interaction authority. Final sound design and mixer-mastering approval, packaged listening, audio hardware certification, music, ambience, signing/publication, whole-game, and release readiness remain open.
