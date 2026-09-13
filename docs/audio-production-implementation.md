# Production audio implementation

Owner authorization: 2026-09-13. Status: in progress. Implements P0 and required P1 of `audio-generation-plan.md`; P2 optional expansion remains deferred.

Owner calibration feedback: make the music more orchestral. The production music and stingers use revised full-symphony prompts (massed strings, woodwinds, brass, harp and restrained orchestral percussion), retaining each faction's identity. Earlier acoustic calibration renders remain source evidence, not the final music selection.

## Scope and delivery

- Generate all 54 current one-shot replacements, 11 ambient loops and 25 coherent music compositions, preserving existing root cue identity and explicit generic fallback.
- Change the music manifest to declare full-mix playback for these compositions. Keep the existing layered playback path for legacy content; a full mix must never play together with synthetic harmony/motion fallbacks. This changes 75 proposed stem deliveries into 25 real stereo compositions without reducing the 25 context identities.
- Generate the required P1 material, weapon, body, school/effect, town ambience, resource, notification and stinger banks. Resolve proposed body/equipment assignments against authored content and current art before using them.
- Implement bounded event-driven variant selection, spell identity, ground-material movement, viewed-town ambience, actual-level terrain ambience and committed-transition notifications. Presentation selection must not consume simulation RNG or mutate gameplay/save state.
- Preserve source audio, prompts, seeds, exact model revision, workflow settings, hashes and edit provenance. Keep runtime WAV/OGG in exported paths and source FLAC/WAV outside exports. Never overwrite generated masters with legacy synthesis tools.

## Acceptance

1. Every required delivery exists, decodes, has finite signal and headroom, and is traceable to its source generation and edit settings; no copied external game assets or unrelated generated tracks masquerading as stems.
2. Runtime uses the replacement full mix, SFX and banks at the correct event and context; imports/fallbacks, mute, reduced repetition, caps, scene exit and save/resume remain correct.
3. Longer SFX use their actual lifetime; looping audio is edited with documented boundaries and reviewed over repeats. No onset silence, hard truncation, overlapping independent songs or repeated UI/alarm noise.
4. Focused tests exercise actual routing and full-mix compatibility; update obsolete fixed-duration/generator assumptions without deleting meaningful audio correctness checks.
5. Windows and Linux import/package/startup checks and a live Small-match review substantiate delivery. Technical signal checks do not substitute for artistic listening approval; report the exact scope of listening evidence.
6. Clean task-owned disposable intermediates, preserve sources/evidence/caches, commit only authorized changes and push/merge normally.

## Staged ownership

`audio-production-library-20260913`: generation, source provenance, runtime asset delivery, full-mix music contract and protection against regeneration overwrites.

`audio-production-routing-20260913`: production banks and data-driven integration in existing audio services and presentation event owners.

`audio-production-acceptance-20260913`: source and packaged behavior validation, listening review, cleanup and final handoff. These stages remain incomplete until their respective behavior and checks pass.

## Current validation

All 520 required P0/P1 files exist, including revised orchestral music and stingers. Source/master/runtime hashes and signal checks pass. The 31 earlier acoustic variants remain in the excluded source area. The owner explicitly resumed testing on 2026-09-13.

Windows source checks pass, including the five migrated repository audio validators. The exported Windows PCK passes 3103 runtime checks from a separate working directory: every manifest resource loads, durations match, full mixes play alone, legacy layering and missing-file fallback remain bounded, stingers duck/recover, bank cooldowns and mute/caps work, and objective observation preserves simulation/save state. The release executable also starts and exits successfully with a fresh profile. Godot's release template disables path overrides, so the PCK harness runs through the same-version editor binary; release startup is checked separately.

A live Small 36x36 three-player map reached day two: town/garrison transfer, resource collection, ranged fire, offensive magic, movement/melee, retaliation, unit death, victory/result return, mine claim, AI turns and manual save completed without script errors. Roadward Lodge Watch ended in victory after two rounds, with 18 of 19 friendly troops surviving. This is a first gameplay-loop review, not a terminal full-match playthrough or artistic listening approval. The saved match remains in the isolated playtest profile for release-build resume checks.

The review corrected objective audio to use structured objective state instead of the compact generated-map label, reset notification baselines after loading, preserve high priority for defeat sounds and avoid treating nonhuman defense values as metal armor. Generation CSVs are now excluded from Godot imports; 40 disposable generated translations (250684 bytes) were removed. Generated sources, masters, alternatives, caches, saves and validation logs remain intact.

Both platform exports were built. The Windows pack contains all 520 required audio imports, matches the six published manifests, verifies all PCK payload digests, and excludes source assets. Pack size: 412162952 bytes. Linux execution is pending the audio integration workflow because local WSL fails with HCS_E_HYPERV_NOT_INSTALLED. Final listening feedback and remaining release-build review are pending; these slices remain in progress.

Follow-up routing correction: underground footsteps now use the generated underground bank using the viewed hero level; wet footsteps retain the water bank. Spell/UI catalog aliases now resolve to existing recordings, and visual object-idle events explicitly leave continuous audio to AmbientAudio. The revised source passes 3161 runtime checks and six repository validators. Refreshed package acceptance is in progress. Desktop interaction is paused after the owner stopped Computer Use with Escape.
