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

## Generation checkpoint and owner hold

All 520 required P0/P1 files have been generated, including revised orchestral music and stingers. Per-file technical checks passed; sources, masters, prompts, seeds and hashes are preserved. The 31 earlier acoustic music/stinger variants remain in the excluded source area as alternatives. No generated source was deleted.

Before the owner hold, a focused Godot harness passed 1934 checks. This is not a live playthrough or artistic approval. The owner is using the computer and will notify when testing may resume. No further tests or game launches until that authorization. Full Small-match listening, packaged Windows/Linux acceptance and old fixed-duration validator migration remain unfinished. WSL startup additionally requires virtualization unavailable on this host. Local routing changes are a draft pending those checks.
