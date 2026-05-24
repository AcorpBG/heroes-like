# Music Audio Runtime Baseline Report

Slice: `music-audio-runtime-baseline-20260523-10184`

## Scope

This slice adds `scripts/autoload/MusicAudio.gd`, a music runtime layer for menu, overworld, battle, and scenario outcome contexts.

The service now prefers committed original WAV cue layers from `content/music_runtime_manifest.json` under `art/audio/runtime/music/`, with bounded `AudioStreamGenerator` fallback when an asset is unavailable. It records cue ids, context ids, layer metadata, route source, bus, mute state, active player count, manifest state, asset paths, and stable signatures for validation.

## Runtime Contract

- `MusicAudio.sync_context(...)` is the single public routing call.
- Context cues are `music_menu_theme`, `music_overworld_theme`, `music_battle_theme`, and `music_outcome_theme`.
- Contexts generate root, harmony, and motion layers with deterministic frequencies.
- `tools/generate_music_runtime_assets.py` reproducibly writes the current runtime music WAV cue layers from `content/music_runtime_manifest.json`.
- Unchanged context signatures do not restart active music.
- The service respects `SettingsService.master_volume_percent()` and `SettingsService.music_volume_percent()`.
- Audio routes to `Music` when that bus exists, otherwise `Master`.
- Active generated players are capped by `MAX_ACTIVE_PLAYERS`.

## Live Shell Coverage

- `MainMenu` syncs the menu context on ready and exposes `music_audio` in `validation_snapshot()`.
- `OverworldShell` syncs the overworld context during refresh and exposes `validation_music_audio_summary()`.
- `BattleShell` syncs the battle context after a battle payload is normalized.
- `ScenarioOutcomeShell` syncs the outcome context after a final scenario status is available.

## Validation

`tests/music_audio_runtime_report.tscn` proves direct routing for all four contexts, stable non-restart behavior on a repeated menu signature, imported runtime music asset use, bus selection, player cap exposure, manifest loading, and at least one live shell route through `MainMenu`.

## Non-Goals

- Not final music composition.
- No final music stems, licensed tracks, adaptive soundtrack approval, or mixer mastering.
- No mixer/bus-layout migration.
- No save migration.
