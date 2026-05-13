# Native RMG Small h3maped Reset

Status: active reset slice.

The previous native RMG implementations are archived as debug/evidence code. They are not the production generator path, and `MapPackageService.generate_random_map()` must not fall back to them.

## Source Anchor

- Binary: `/root/Downloads/h3maped.exe`
- Format: PE32 GUI Intel 80386 Windows executable
- SHA-256: `4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37`
- Recovered spec: `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- Active module: `src/gdextension/src/h3maped_small_rmg.cpp`
- Archived phase ledger: `src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp`
- Archived active boundary: `src/gdextension/src/archived_h3maped_small_rmg_active_boundary_20260513.cpp`
- Archived current ledger: `src/gdextension/src/archived_h3maped_small_rmg_inspection_ledger_20260513.cpp`
- Older historical ledger: `src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp`

## Scope

Initial scope is only 36x36, one-level, land maps.

Medium, large, XL, water, islands, and underground generation are out of scope for this reset until the small land path can materialize zones, terrain, owned starts, towns, roads, blockers, guards, mines, rewards, and final writeout from h3maped-derived phases.

## Current Boundary

The active module is intentionally small again after the 2026-05-13 owner-directed restart correction. The previous active phase ledger was moved out of the build to `src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp`. Older archived ledgers remain evidence only.

The compiled active module now only:

- verifies `/root/Downloads/h3maped.exe` by size, MZ header, and SHA-256;
- accepts only small 36x36 one-level land configs;
- computes the recovered h3maped size/water score boundary;
- selects from the recovered small-land template vector using h3maped RNG `0x4e7269/0x4e7276`;
- builds a private, non-materializing `0x4ac62a..0x4ac6ec` player-slot assignment context for the selected template;
- builds a private, non-materializing `0x4a218c` runtime-zone record context for the selected template;
- builds private, non-materializing `0x4a1f3b` link seeds and one-level `0x4a17f5`/`0x4a1701`/`0x4a1ad8`/`0x4a19ed` coordinate replay context;
- builds private, non-materializing `0x4a3a03` zone-footprint helper scheduling and `0x4cc788` initial source-node rectangle context;
- builds private `0x4ccb64` polygon split and `0x4ccdfc` source-node finalizer context;
- feeds the finalized source-node cycles into private `0x4a2777` boundary traversal evidence through `0x4a2b33`, `0x4a261a`, and `0x4a2413`;
- feeds the private `0x4a2777` boundary buffer into private `0x4a325d` span-fill evidence;
- runs the private small-land `0x4a3710` footprint finalizer path with no appended synthetic zones;
- reports the strict executable-port backlog;
- refuses runtime generation and any partial public package payload.

Seed `1`, one human, three total players currently selects `h3maped_template_018` at source catalog index `18`, adapted to `translated_rmg_template_019_v1`, through the h3maped RNG first value `41` and selected vector index `2`. Accepted small-land templates for that profile remain `13`.

The active module no longer exposes the old top-level player-slot, runtime-zone, coordinate, terrain, town, road, blocker, guard, mine, reward, or final-writeout inspection-ledger records. It does expose a compact `private_generation_context` with completed phases `template_selection`, `player_slot_assignment`, `runtime_zone_records`, `link_seed_setup`, `coordinate_replay_and_zone_footprints`, `zone_footprint_phase_boundary`, `source_node_rectangle`, `polygon_split_model`, `source_node_boundary_traversal`, `span_fill_4a325d`, and `footprint_finalizer_4a3710`; that context materializes no runtime players, terrain cells, map cells, zone footprints, roads, guards, blockers, or public output. For seed `1`, one human, and three total players, the `0x4a218c` context carries six source runtime-zone records from `h3maped_template_018`, owner colors `[0, 1, -1, 2, -1, -1]`, three assigned start zones, one unassigned start zone, two treasure zones, and four minimum player castles. The coordinate replay carries five source links, 18 coordinate RNG calls, four interleaved town-choice RNG calls, final replay RNG state `255755822`, bbox span `84`, and scaled zone centers `(23,11)`, `(21,22)`, `(12,23)`, `(18,4)`, `(18,30)`, and `(12,11)`. The new `0x4a3a03` context queues six `0x4a2777` helper inputs for level `0` and appends no synthetic `0xd4` source zone for one-level land. The `0x4cc788` context records initial source-node rectangle bounds `-200..400`, constants `0xffffff38` and `0x190`, and four `0x4cc955` edges. The `0x4ccb64`/`0x4ccdfc` context privately recovers six split calls, 12 bridge pairs, 34 crossing-cleanup scans, 24 crossing tests, eight crossing collapses, 23 active source-node pairs, 14 finalized coordinate triplets, 42 finalized nodes, and six source-node walks. The private `0x4a2777` traversal consumes those walks as boundary evidence only: six consumed runtime-zone walks, six flagged connector segments, 12 deterministic final segments, 18 appended vertices, 12 skipped out-of-bounds clips, 106 randomized RNG calls, 138 inserted midpoint candidates, final RNG state `264218432`, 301 trace writes, 238 unique boundary cells, zero out-of-bounds writes, and no loop-guard exhaustion. The private `0x4a325d` span fill consumes that buffer as span-fill evidence only: six fill attempts, six filled zones, one blocked seed, zero relocations, 869 filled interior cells, 1107 boundary-or-filled private cells, 189 remaining unassigned cells, 1107 reserved-flag cells, 93 pushed/popped spans, max pending span count 3, zero out-of-bounds spans, and per-zone distribution `177/91/226/177/207/229`. The new private `0x4a3710` small-land finalizer records one land level, no synthetic branch, original/final runtime-zone counts `6/6`, zero appended runtime zones, skipped adjacency insertion phases, six `0x49b61b` ordering resets, six `0x4a3554` per-zone rebuilds, and zero materialized adjacency. `0x4a3f27` terrain/cell writeout, map cells, roads, guards, blockers, mines, rewards, and public writeout remain blocked. Older detailed records were archived because they encouraged incremental report growth without a usable generated map. Future phases must be reintroduced as actual generator implementation derived from `h3maped.exe`, not as broad inspection-ledger expansion.

## Runtime Gate

Supported small land generation currently returns:

- `ok: false`
- `generation_status: h3maped_small_clean_restart_generation_not_ready`
- `error_code: h3maped_phase_port_incomplete`
- `runtime_generation_allowed: false`

Out-of-scope generation currently returns `archived_legacy_native_rmg_disabled`.

Explicit translated-template requests do not bypass the reset gate.

## Required Ports

The restart must port these phases from `h3maped.exe` before public package output is allowed:

1. Template selection: `0x49f0cd`, `0x4ac597`, `0x4e7276`.
2. Player-slot assignment: `0x4ac62a..0x4ac6ec` (active inspection only; no runtime player materialization).
3. Runtime-zone records and terrain selectors: `0x4a218c`, `0x49b3c1`, `0x49b53d` (active inspection only; no cells, terrain art, or runtime players).
4. Coordinate replay and zone-footprint phase: `0x4a1f3b`, `0x4a17f5`, `0x4a1701`, `0x4a1ad8`, `0x4a19ed`, `0x4a3a03`, `0x4cc788`, `0x4ccb64`, `0x4ccdfc`, `0x4a2777`, `0x4a2b33`, `0x4a261a`, `0x4a2413`, `0x4a325d`, and `0x4a3710` (`0x4a1f3b` link endpoint seeds, one-level coordinate replay, `0x4a3a03` helper-input queue, `0x4cc788` initial rectangle, `0x4a2b33` clip helper, `0x4a261a` deterministic line writer, `0x4a2413` randomized line writer, `0x4ccb64` split insertion/cleanup, `0x4ccdfc` finalization, real `0x4a2777` traversal, `0x4a325d` span fill, and small-land `0x4a3710` active inspection only; cell materialization pending strict port).
5. Terrain writeout and TerrainPlacement: `0x4a3f27`, `0x4bcff5`, `0x4bd099`, `0x4bb74b`, `0x4bc5f0`, `0x4bcfc3`, `0x4bce6d`, `0x4ba938`, `0x4ba989`, `0x4baa94`, `0x4baabf`, `0x4bad0f`, `0x49acf6`, `0x4bbd01`, `0x4bc988`, and `0x4bbfcc` (`0x4a3f27`, the static visual table/toolkit boundary, bounded scratch/writeback samples, queue/final-sweep contract, generated-grid boundary counter, and private live repaint feedback through the recovered set A/B queue drain active inspection only; generated-cell art/flag grid public adoption and package adoption still pending).
6. Town object placement: `0x4a8d2c`, `0x4a8db2`, `0x4a93a2`, `0x49aa93`, `0x49a09c`, `0x49b3c1`, `0x49ba89`, and `0x540a9c` (minimum schedule, direct town footprint scan, private `0x49ba89` record projection, and synchronized project town/player-start candidates active inspection only; public runtime-grid/package adoption still pending).
7. Roads and rivers: `0x4ab52a`, `0x4aae7b`, `0x4ab37f`, `0x4b4243`.
8. Connections, blockers, and guards: `0x4a79a3`, `0x4a61bc`, `0x4a696b`, `0x4a6cf2`, `0x4a7605`, `0x4a65a5`, `0x4a5e03`, `0x4a5e73`, and `0x4a5a23` (late payload postprocess, guard value scaling, corrected `0x4a6cf2` same-level return-false gate, same-level dispatch readiness, low/high owner-byte precondition reporting, baseline `0x4a5767`/`0x49a318` high-owner propagation, generated-cell `+0x28` bit25/direction handoff, and `0x4a79a3` transition-vector candidate scan active inspection only; remaining `0x49a318` bit22/object metadata branches, actual `0x4a61bc`/`0x4a696b` endpoint writes, guard object stamping, blockers, mines, rewards, and final adoption still pending).
9. Mines, rewards, and objects: `0x49aa93` object placement family.
10. Final h3m writeout: `0x49b2b6`.

## Hard Rules

- No hash-based template selection as a substitute for h3maped behavior.
- No sample-specific exact-count fitting in runtime generation.
- No road clusters that merely look like road counts.
- No blocker/decoration placement that passes counts while leaving unguarded open paths between zones.
- No player-start repair pass that only patches owner/town fields after placement.
- No validation that treats metadata zone links as sufficient when map cells do not enforce the link.
- No production fallback to archived native catalog-auto output.
- No reuse of legacy hashed TerrainPlacement art/index/flip approximation in the clean h3maped reset path.
