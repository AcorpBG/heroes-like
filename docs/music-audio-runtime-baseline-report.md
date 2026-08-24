# Music Audio Runtime Baseline Report

Slice: `music-audio-runtime-baseline-20260523-10184`

## Scope

This slice adds `scripts/autoload/MusicAudio.gd`, a music runtime layer for menu, overworld, town, battle, and scenario outcome contexts.

The service now prefers committed original WAV cue layers from `content/music_runtime_manifest.json` under `art/audio/runtime/music/`, with bounded `AudioStreamGenerator` fallback when an asset is unavailable. The production-loop follow-up plus faction Town, Overworld, Battle, and terminal Outcome expansions provide seventy-five distinct seamless eight-second 44.1 kHz stereo layers and play detached imported WAV resources in forward-loop mode. It records cue ids, context ids, layer metadata, route source, bus, mute state, active player count, transition groups, manifest state, asset paths, loop state, and stable signatures for validation.

## Runtime Contract

- `MusicAudio.sync_context(...)` is the single public routing call.
- Context cues are `music_menu_theme`, `music_overworld_theme`, `music_town_theme`, `music_battle_theme`, and `music_outcome_theme`. Exact live Town and scenario player faction identity select six additional `music_town_<faction>_theme`, `music_overworld_<faction>_theme`, and `music_battle_<faction>_theme` roots. Exact terminal Outcome status selects the original `music_outcome_victory_theme` or `music_outcome_defeat_theme`; missing or unknown identity/status retains the corresponding generic context cue.
- The faction Battle set begins with `music_battle_embercourt_theme` and contains one exact root/harmony/motion trio for each of the six production factions.
- Every context owns exact root, harmony, and motion cue layers; the established three-player cap is unchanged.
- `tools/generate_music_runtime_assets.py` reproducibly writes seventy-five byte-distinct original layered stereo loops from `content/music_runtime_manifest.json`. Each generic, faction Town/Overworld/Battle, or terminal Outcome phrase shares one exact eight-second boundary across its three stems.
- Imported WAV resources are deep-duplicated before `LOOP_FORWARD` metadata is applied, so the source import cache is not mutated.
- Normal imported playback remains active beyond a full segment; an unchanged context signature does not restart it, while a changed context crossfades from the three old players into the three exact replacement layers.
- Unchanged context signatures do not restart active music.
- A changed signature starts the exact three incoming layers at -60 dB while the exact three outgoing layers remain live, then linearly crossfades both groups over 360 ms. Steady state remains three players and transition state is capped at six.
- A rapid third route invalidates the older tween generation, immediately retires only its stale outgoing group, and crossfades from the latest current group. Stale completion callbacks cannot retire or alter the newest context.
- Explicit `stop_music(...)` and validation reset remain immediate: they invalidate the transition generation, kill its tween, and retire every player without a delayed callback.
- The service respects `SettingsService.master_volume_percent()` and `SettingsService.music_volume_percent()`.
- Audio routes to `Music` when that bus exists, otherwise `Master`.
- Active generated players are capped by `MAX_ACTIVE_PLAYERS`.

## Live Shell Coverage

- `MainMenu` syncs the menu context on ready and exposes `music_audio` in `validation_snapshot()`.
- `OverworldShell` syncs the overworld context during refresh and exposes `validation_music_audio_summary()`.
- `BattleShell` syncs the battle context after a battle payload is normalized.
- `ScenarioOutcomeShell` syncs the outcome context after a final scenario status is available.

## Validation

`tests/music_audio_runtime_report.tscn` proves exact manifest and imported asset coverage for all seventy-five byte-distinct original layered stereo loops, six direct Town, Overworld, and Battle faction routes plus generic/unknown fallback, exact victory/defeat Outcome routing plus generic status fallback, 44.1 kHz stereo eight-second imports, forward-loop metadata, all three players still active after a full segment, stable non-restart behavior, exact outgoing/incoming crossfade groups, rapid-route cancellation, target-volume settle, immediate explicit stop, generated fallback, bus selection, steady and transition player caps, a live shell route through `MainMenu`, real `MainMenu` to `OverworldShell` crossfades, all six real faction `TownShell`, `OverworldShell`, and `BattleShell` routes, and real victory/defeat `ScenarioOutcomeShell` routes at 1280x720 and 1920x1080. Repository validation separately checks transition lifecycle order and isolation plus 16-bit source PCM, bounded peaks, non-silent distinct channels, exact loop boundaries, unique hashes, and deterministic generation.

## Non-Goals

- Not final music composition.
- No final music stems approval, orchestral recording, licensed tracks, adaptive soundtrack redesign, hardware listening certification, or mixer mastering.
- No mixer/bus-layout migration.
- No save migration.
- No beat/bar synchronization or adaptive soundtrack redesign.
