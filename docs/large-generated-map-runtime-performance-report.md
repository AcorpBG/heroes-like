# Large Generated Map Runtime Performance Report

Task: #10225

Slice: `performance-large-generated-map-runtime-10225`

Date: 2026-09-03

## Deterministic Case

- Seed: `large-runtime-profile-10225`
- Size: `homm3_large`, 108x108
- Faction/hero: Veilmourn / Orso Nightchart
- Scenario: `native_h3maped_c2520619_skirmish`
- Normalized seed: `1166246304`
- Materialized-map signature before and after: `7362cf00`
- Final fixture counts: 14 towns, 670 resource nodes, 36 artifact nodes, 131 encounters, 1,953 runtime map objects, and 2,961 package source objects.

## Root Causes

The one-minute generation stall was native object materialization. Decorative placement repeatedly called `object_record_by_key_0xec4_ecc`, which linearly scanned the growing object vector for neighbor lookups. On this fixture, source-order object materialization took 107,727 ms and its decorative dispatch alone took 103,853 ms. This was quadratic derived lookup work, not required H3MapEd generation behavior.

After entry, three independent scale costs compounded:

- AI routing rebuilt array-backed queues and blocked-tile dictionary probes for each target/path query, and target-selection branches discarded already-built path contexts.
- Immutable generated-scenario reads called `ContentService.get_scenario()`, deep-copying the multi-megabyte scenario record for objective and front queries.
- Town view assembly recalculated identical logistics, recovery, front, pressure, readiness, and development projections within one normalized read scope.
- End Turn confirmation deep-copied and serialized the whole session twice solely to detect a stale modal request; runtime saves likewise performed avoidable full-payload copies and emitted whitespace-expanded JSON.

## Corrections

- Native object private state now owns a derived key-to-index lookup updated at the authoritative append point. Decorative source scores are cached per immutable wrapper, selected candidates are copied only after scoring, and attempt vectors move rather than deep-copy.
- Native phase timing is opt-in through `AURELION_RMG_PROFILE_PHASES`; the map-package result exposes the same timing buckets only when requested.
- Strategic path distance fields now use preallocated packed queues and a packed blocked mask while preserving the existing eight-direction and blocked-corner rules. One per-raid path context is threaded through retake, support, saved/live task, explicit objective, and fallback selection.
- `ContentService.get_scenario_readonly()` exposes immutable authored/generated scenario records to runtime query paths. The copying accessor remains authoritative for editor or mutation ownership.
- Town derived values are cached only inside the existing normalized read scope. The cache is cleared at the outer scope boundary and keys include the complete town value plus any precomputed metric context.
- End Turn restores only the forecast branch that its warning surface may normalize and uses an in-process recursive fingerprint of mutable session state, excluding immutable map/render/package catalogs. Existing cancel, stale-day, stale-status, stale-state, and exact-confirm regressions pass.
- Runtime save preparation now creates one owned snapshot, edits only the copied flags branch, preserves every version-9 payload field, and writes compact machine-owned JSON. Exact generated Town save and transactional recovery regressions pass.

## Measured Result

Baseline evidence was captured before correction on the same fixture. The focused baseline used 271.47 seconds wall time and approximately 2.26 GB peak RSS. Setup took 104.46 seconds; native decorative dispatch took 103.85 seconds. A representative late profiling turn took approximately 41.35 seconds including 35.5 seconds of rules, 4.14 seconds of autosave, and 1.69 seconds of refresh. Initial Town construction took 10.25 seconds.

Final focused runs retained signature `7362cf00` and reported:

| Operation | Final wall time |
| --- | ---: |
| Generated setup | 16.09 s |
| Native recovered workflow | 13.25 s |
| Session construction | 4.71 s |
| Cold destination selection | 0.414 s |
| Warm destination selection | 0.186 s |
| Hover | 0.093 s |
| Adjacent move | 0.361 s |
| Town entry/exit | 1.79 s |
| Town entity build | 1.09 s |
| Explicit exact save | 4.00 s |
| Full End Turn confirmation/rules/autosave/refresh | 9.98 s |

The corrected native decorative lookup path fell to approximately 6.3 seconds in the instrumented run, more than 16x faster. Setup is approximately 6.5x faster, Town entity construction approximately 9.4x faster, and the complete fresh-fixture End Turn approximately 4x faster. No slow work is deferred to later frames.

## Validation

- `large_generated_map_runtime_profile_report.tscn`: passed after applying the 15-second full-turn bound; exact signature, counts, command timings, and generated save round trip are asserted.
- `h3maped_rmg_core_selftest`: passed.
- AI path reuse, live target selection, and strategic planner reports: passed.
- End Turn confirmation/cancel/stale-state runtime report: passed.
- Town transition, Large generated Town explicit-save, and transactional-save regressions: passed.
- `python3 tests/validate_repo.py`: passed.
- Linux release export/package/headless boot: passed.
- Windows release export/package/Wine boot plus generated setup, Overworld entry, and Town entry: passed.
- Linux and Windows PCKs: matching 245,006,172 bytes, 4,993,828 bytes below the 250,000,000-byte ceiling.

The older `native_random_map_package_session_adoption_report.tscn` still expects capability labels removed by the earlier exact-state-chain reset (`native_random_map_package_session_adoption_bridge` and `generated_map_package_disk_startup`) and fails before exercising a map. This slice does not reinstate obsolete native capability claims. Current native API skeleton, deterministic Large generation/session/save coverage, and packaged generated-flow coverage pass.

This is a bounded performance correction, not a native-RMG semantic change or a whole-game release-readiness claim.
