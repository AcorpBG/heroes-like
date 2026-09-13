# Production audio implementation

Owner authorization: 2026-09-13. Status: completed 2026-09-13. Implements P0 and required P1 of `audio-generation-plan.md`; P2 optional expansion remains deferred.

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

`audio-production-acceptance-20260913`: source and packaged behavior validation, listening review, cleanup and final handoff. All three stages are complete following technical acceptance and the owner's full manual playtest approval.

## Current validation

All 520 required P0/P1 files exist, including revised orchestral music and stingers. Source/master/runtime hashes and signal checks pass. The 31 earlier acoustic variants remain in the excluded source area. The owner explicitly resumed testing on 2026-09-13.

Windows source and exported-PCK checks each pass 3167 runtime assertions, including named save/resume through SaveService and AppRouter: restored progress does not replay notifications, the real overworld opens, and one full mix resumes. All 520 assets pass source/master/runtime hashes and signal checks; six repository audio validators pass. Every manifest resource loads, durations match, full mixes play alone, legacy layering and missing-file fallback remain bounded, stingers duck/recover, bank cooldowns and mute/caps work, and objective observation preserves simulation/save state. The release executable also starts and exits successfully with a fresh profile. Godot's release template disables path overrides, so the PCK harness runs through the same-version editor binary; release startup is checked separately. The editor/PCK harness cannot load the release-only native extension and does not prove the packaged native save backend; this remains the technical scope of that harness, separate from the owner's manual acceptance below.

A live Small 36x36 three-player map reached day two: town/garrison transfer, resource collection, ranged fire, offensive magic, movement/melee, retaliation, unit death, victory/result return, mine claim, AI turns and manual save completed without script errors. Roadward Lodge Watch ended in victory after two rounds, with 18 of 19 friendly troops surviving. This is a first gameplay-loop review, not a terminal full-match playthrough or artistic listening approval. The saved match remains preserved in the isolated playtest profile.

The review corrected objective audio to use structured objective state instead of the compact generated-map label, reset notification baselines after loading, preserve high priority for defeat sounds and avoid treating nonhuman defense values as metal armor. Generation CSVs are now excluded from Godot imports; 40 disposable generated translations (250684 bytes) were removed. Generated sources, masters, alternatives, caches, saves and validation logs remain intact.

Both platform exports were refreshed and validated. The Windows pack contains all 520 required audio imports, matches the six published manifests, verifies all PCK payload digests, and excludes source assets. Pack size: 412162488 bytes; SHA-256: `e7c270a15b6222e5d44b2477e074209cbe68a48f02b8ec9bde9435ec83d33462`.

Linux passed the same 3167 source and 3167 packaged runtime assertions, all 520 asset checks, six repository validators, and release executable startup on commit `c4efc9abf93f899615079b2b10115bc75cbc9244`. The [successful workflow](https://github.com/AcorpBG/heroes-like/actions/runs/34732034272) rebuilt the Linux pack: 401358176 bytes, SHA-256 `8de9e9f91df609132a27cb18473e5696e1e9a6caca8ea81ef4a2c9f0068623a4`. Its payload digests, all required audio imports, manifests and source exclusion pass. Evidence is retained in `.artifacts/audio-production/linux-ci-c4efc9ab/` and the workflow artifact. CI skips Godot import of already export-excluded source directories while Python still checks their original hashes. Local WSL remains unavailable (`HCS_E_HYPERV_NOT_INSTALLED`); Linux validation ran on GitHub's Ubuntu runner.

The owner subsequently completed a full manual playtest, accepted the audio, and explicitly requested full completion on 2026-09-13. This closes the remaining manual audio acceptance; all three audio slices are complete. The release game left open after the Escape stop was terminated, and process inventory confirmed no game or Godot processes remained. The saved Small match is preserved.

Follow-up routing correction: underground footsteps now use the generated underground bank using the viewed hero level; wet footsteps retain the water bank. Spell/UI catalog aliases now resolve to existing recordings, and visual object-idle events explicitly leave continuous audio to AmbientAudio. All 520 files also passed mono compatibility and signal-offset review, with no severe cancellation flagged; this is a technical check, not artistic approval. No further agent desktop playtest is required for this accepted audio scope.

## Owner acceptance

On 2026-09-13 the owner reported: "I did manually full play test audio is acceptable and should be marked fully complete". This is owner-provided full-playtest and listening approval, following the Windows/Linux technical evidence above. It does not imply a separately instrumented audition of every individual variant. The five production manifests now record accepted status and this approval. Per-render provenance retains its historical generation-time review state; this library-level acceptance supersedes that pending state for the delivered 520-file set. P2 optional expansion remains deferred.
