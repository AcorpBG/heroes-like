# Music Audio Runtime Baseline Report

Slice: `music-audio-runtime-baseline-20260523-10184`

## Scope

This slice adds `scripts/autoload/MusicAudio.gd`, a music runtime layer for menu, overworld, town, battle, and scenario outcome contexts.

The service now prefers committed original WAV cue layers from `content/music_runtime_manifest.json` under `art/audio/runtime/music/`, with bounded `AudioStreamGenerator` fallback when an asset is unavailable. The production-loop follow-up plus faction Town and Overworld expansions provide fifty-one distinct seamless eight-second 44.1 kHz stereo layers and play detached imported WAV resources in forward-loop mode. It records cue ids, context ids, layer metadata, route source, bus, mute state, active player count, manifest state, asset paths, loop state, and stable signatures for validation.

## Runtime Contract

- `MusicAudio.sync_context(...)` is the single public routing call.
- Context cues are `music_menu_theme`, `music_overworld_theme`, `music_town_theme`, `music_battle_theme`, and `music_outcome_theme`. Exact live Town and scenario player faction identity select six additional `music_town_<faction>_theme` and `music_overworld_<faction>_theme` roots; missing or unknown identity retains the corresponding generic context cue.
- Every context owns exact root, harmony, and motion cue layers; the established three-player cap is unchanged.
- `tools/generate_music_runtime_assets.py` reproducibly writes fifty-one byte-distinct original layered stereo loops from `content/music_runtime_manifest.json`. Each generic or faction Town/Overworld phrase shares one exact eight-second boundary across its three stems.
- Imported WAV resources are deep-duplicated before `LOOP_FORWARD` metadata is applied, so the source import cache is not mutated.
- Normal imported playback remains active beyond a full segment; an unchanged context signature does not restart it, while a changed context still stops and replaces the three old players.
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

`tests/music_audio_runtime_report.tscn` proves exact manifest and imported asset coverage for all fifty-one layers, six direct Town and Overworld faction routes plus generic/unknown fallback, 44.1 kHz stereo eight-second imports, forward-loop metadata, all three players still active after a full segment, stable non-restart behavior, changed-context replacement, generated fallback, bus selection, player cap exposure, a live shell route through `MainMenu`, and all six real faction `TownShell` and `OverworldShell` routes at 1280x720 and 1920x1080. Repository validation separately checks 16-bit source PCM, bounded peaks, non-silent distinct channels, exact loop boundaries, unique hashes, and deterministic generation.

## Non-Goals

- Not final music composition.
- No final music stems approval, orchestral recording, licensed tracks, adaptive soundtrack redesign, hardware listening certification, or mixer mastering.
- No mixer/bus-layout migration.
- No save migration.
