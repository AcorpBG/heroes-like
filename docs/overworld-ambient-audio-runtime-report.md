# Overworld Ambient Audio Runtime Report

Status: implementation evidence.

Slice: `overworld-ambient-audio-runtime-baseline-20260523-10184`.

Implemented behavior:
- `scripts/autoload/AmbientAudio.gd` is registered as the `AmbientAudio` autoload in `project.godot`.
- The service synthesizes bounded generated overworld ambience through `AudioStreamGenerator`, `AudioStreamGeneratorPlayback`, and `AudioStreamPlayer` on the `Master` bus.
- `AmbientAudio.sync_overworld_session(...)` derives layers from live session terrain, dominant map terrain, day, hero position, and enemy pressure.
- Terrain layers use `overworld_ambient_<terrain>` cue ids, pressure adds `overworld_ambient_pressure`, and later days add `overworld_ambient_day_pulse`.
- The service keeps signature-based restart behavior so identical context does not restart the ambient segment every refresh.
- `OverworldShell` syncs ambient audio from the active session during ready/refresh and exposes `validation_ambient_audio_summary()` plus the same summary inside `validation_snapshot()`.

Validation evidence:
- `OVERWORLD_AMBIENT_AUDIO_RUNTIME_REPORT`
- `overworld_ambient_audio_runtime_v1`
- `overworld_ambient_mix`
- `overworld_ambient_pressure`
- `overworld_ambient_day_pulse`
- `AmbientAudio.sync_overworld_session`
- `OverworldShell.validation_ambient_audio_summary`
- `Master`

Boundaries:
- This is generated runtime ambience, not final sound design.
- No imported final audio assets, music, ambient stems, mixer mastering, or platform audio certification.
- No save migration.
