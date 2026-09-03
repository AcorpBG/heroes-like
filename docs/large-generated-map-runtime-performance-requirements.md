# Large Generated Map Runtime Performance Requirements

Task: #10225
Parent: Phase 6 - Production Alpha Layer
Slice: `performance-large-generated-map-runtime-10225`

## Player Outcome

A generated Large 108x108 map must remain responsive after it opens. Selecting destinations, moving a hero, ending a turn, entering or leaving a Town, and saving must not appear frozen for a minute or defer equivalent work into later frames.

## Diagnosis Contract

- Materialize and launch a deterministic Large map through the normal generated-skirmish setup with explicit faction and hero choices.
- Record wall-clock and existing profile-bucket evidence for generation/setup, Overworld handoff and first render, ordinary refresh/selection, reachable movement, end turn, Town entry/exit, and explicit save.
- Attribute the dominant time to concrete functions/data traversals. Do not infer the cause from map size alone.
- Retain a baseline artifact with map dimensions, object counts, seed/provenance identity, operation timings, and dominant buckets.

## Implementation Invariants

- Preserve the exact generated scenario/package identity and authoritative runtime outcomes for the profiled seed.
- Preserve map topology, objects, coordinates, roads, terrain, guards, rewards, towns, pathing, fog, AI decisions, save schema/version, and deterministic replay behavior.
- Cache only derived/read-only data. Every cache must have a bounded identity and an explicit invalidation rule tied to the authoritative state it reflects.
- Do not hide stalls with loading text, animation, background retries, command throttling, or reduced map content.
- Keep production paths shared between Linux and Windows; no platform-specific performance bypass.

## Performance Acceptance

- On the deterministic Large fixture, selection, hover, movement, Town transition, and explicit save each complete synchronously in under five seconds in the repository validation environment. A full multi-faction End Turn, including confirmation integrity checks, enemy simulation, exact autosave, and refresh, completes in under fifteen seconds.
- The corrected quadratic Large-map object-materialization hotspot improves by at least an order of magnitude from the captured baseline; end-to-end generation and gameplay timings must also be recorded without conflating platform startup/import time with the corrected hotspot.
- Repeated unchanged-state selection/refresh operations must reuse derived work rather than rescan or deep-copy the whole generated map.
- State-changing movement, end turn, Town transitions, and saves must remain exact and must not reuse stale derived results.
- The regression report must expose wall time, subsystem buckets, derived-cache hit/miss or traversal counts, and before/after equivalence evidence.

## Validation

- Focused deterministic Large generated-map profile/regression report.
- Existing generated-map render, route, refresh, Town transition, save, enemy-turn, and profile-log regressions relevant to the measured path.
- Godot editor parse, `python3 tests/validate_repo.py`, and `git diff --check`.
- Linux and Windows release export/startup/generated-map entry gates below the unchanged 250 MB ceiling.

## Non-Goals

- No native RMG recovery or output change, content reduction, gameplay/balance change, art change, save-version bump, unrelated UI cleanup, or release-readiness claim.
