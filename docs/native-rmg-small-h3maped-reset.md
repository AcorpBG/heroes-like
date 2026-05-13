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

2026-05-13 correction: the report-treadmill active implementation was archived out of the build to `src/gdextension/src/archived_h3maped_small_rmg_report_treadmill_20260513.cpp`. The compiled active module is now a small h3maped executable boundary with these internal state phases only: binary verification, 36x36 one-level land scope gate, recovered size/water score, h3maped RNG template selection, `0x4ac62a..0x4ac6ec` player-slot assignment, `0x4a218c` / `0x49b452` runtime-zone records from the adapted project template, `0x4a1f3b` link-seed setup, one-level `0x4a17f5` / `0x4a1701` / `0x4a1ad8` / `0x4a19ed` coordinate replay, private `0x4a3a03` zone footprints through `0x4cc788` / `0x4ccb64` / `0x4ccdfc` / `0x4a2777` / `0x4a325d` / `0x4a3710`, explicit phase backlog, and runtime generation refusal.

The earlier overgrown active port remains archived at `src/gdextension/src/archived_h3maped_small_rmg_overgrown_active_20260513.cpp`; the previous phase ledger remains archived at `src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp`. Older archived ledgers remain evidence only.

The active module must not expose `small_generation_state`, `private_generation_context`, private terrain/town/object ledgers, or partial package payloads. Player slots, runtime zones, template link seeds, coordinate replay, and private zone footprint/cell ownership buffers are active non-public internal state. Terrain writeout, towns, roads, blockers, guards, mines, rewards, and final writeout are pending runtime ports.

Seed `1`, one human, three total players currently selects `h3maped_template_018` -> `translated_rmg_template_019_v1`, assigns source owners `0/1/2` to player colors `0/1/2`, leaves source owner `3` unassigned, builds six runtime-zone records with actual owner colors `[0, 1, -1, 2, -1, -1]`, preserves five template link seeds with guard values `[3000, 3000, 3000, 6000, 6000]`, replays 18 coordinate-placement steps to scaled zone centers `(23,11)`, `(21,22)`, `(12,23)`, `(18,4)`, `(18,30)`, and `(12,11)`, then builds private source-node footprint state with six zone walks, 301 boundary writes, 238 unique boundary cells, 869 span-filled cells, 1107 boundary-or-filled cells, 189 remaining unassigned cells, and owner cell counts `177/91/226/177/207/229`. This is still not map output; it is the private cell ownership state the next `0x4a3f27` terrain writeout port must consume.

Historical note: the section below describes the archived report-treadmill state before the correction above. It is preserved as failure evidence, not the active implementation contract.

The archived report-treadmill module used to:

- verifies `/root/Downloads/h3maped.exe` by size, MZ header, and SHA-256;
- accepts only small 36x36 one-level land configs;
- computes the recovered h3maped size/water score boundary;
- selects from the recovered small-land template vector using h3maped RNG `0x4e7269/0x4e7276`;
- builds active non-public player-slot state from `0x4ac62a..0x4ac6ec` source-owner masks and `generator+0xed8/+0xee0/+0xee4` slot arrays;
- builds active non-public `0x4a218c` runtime-zone records from the selected recovered project template catalog and player-slot mapping;
- builds active non-public `0x4a1f3b` link seeds and one-level `0x4a17f5`/`0x4a1701`/`0x4a1ad8`/`0x4a19ed` coordinate replay from the recovered project template links;
- builds active non-public `0x4a3a03` zone-footprint helper scheduling, `0x4cc788` initial source-node rectangle constants, `0x4ccb64` split insertion/bridge/crossing cleanup, and `0x4ccdfc` source-node finalization;
- feeds the finalized source-node cycles into private `0x4a2777` boundary traversal through the recovered `0x4a2b33` clip helper, `0x4a261a` deterministic line writer, and `0x4a2413` randomized line writer;
- feeds the private `0x4a2777` boundary buffer into the recovered `0x4a325d` span-fill primitive using runtime-zone `+0x10` seed coordinates;
- runs the small-land `0x4a3710` footprint finalizer path, where no synthetic runtime zones are appended and the adjacency insertion loops skip;
- runs non-public `0x49b53d` runtime terrain selection from the h3maped nine-town terrain table `0x540908` and source-zone terrain flags;
- runs private `0x4a3f27` terrain/cell writeout from the real post-span-fill zone-word buffer, including full-map water prefill, per-zone terrain repaint scheduling, owner-low-byte projection, and pending `0x49b2b6` terrain byte-zero packing evidence;
- decodes private `0x4bcff5` TerrainPlacement visual rows and toolkit constructor records directly from `/root/Downloads/h3maped.exe`, including the five static visual tables, selector samples, and bounded `0x4bad0f`/`0x49acf6` scratch/writeback samples;
- runs private `0x4bb74b`/`0x4bc5f0` TerrainPlacement live repaint queue feedback from the executable-derived repaint order, with live `0x4bce6d` scratch-neighbor masks and private `0x49acf6` generated-cell word projection;
- projects the live private `0x49acf6` generated-cell words through the `0x49b2b6` terrain tile-byte contract for terrain byte `0`, terrain art byte `1`, and terrain flag byte `6` candidates, while road/river bytes remain zero until their own executable-derived phases are ported;
- runs private `0x4a8d2c`/`0x4a8db2` town/castle scheduling and `0x4a93a2`/`0x49aa93`/`0x49a09c`/`0x49ba89` direct town record projection against the recovered town footprint mask, without runtime-grid or package adoption;
- carries the recovered source fields for the `0x4a9d6a` mine phase and `0x4aab7e` reward phase into a non-public object-vector prerequisite boundary, including seven mine minimum/density categories, treasure-band weights, private `0x4a9911`/`0x4a9641` mine-coordinate attempts, the `0x4aab7e` per-zone reward-band scheduler/budget/value-selection preview, and the `0x4a9f1c` generic value-banded selector's metadata/limit-table boundary plus the recovered `0x49f95a` static prefix, monster-table loop, `0x40ce11..0x40d0c8` monster-table initializer boundary for runtime-populated creature rows, 118 materialized single-level monster candidate records from extracted `CRTRAITS.TXT` plus the static `0x57cea0` terrain/tier table and `0x49c5cd` quantity formula, fixed type-6 value bands, type-10 object-bucket consumer loop with its executable metadata producer layout, type-17 loop, 61-record static candidate tail through `0x4a0eeb`, `generator+0x568` type-53 object-bucket loop through `0x4a1194` with three executable-derived bucket entries, 378 one-level candidate records, 704-record one-level candidate-vector order, and 29-record static constructor tail through `0x4a1701`, 17-entry candidate vtable map from `0x540ba0..0x540cac`, reconstructed value-vfunc semantics from `0x49c54d`/`0x49c64b`/`0x49c849`/`0x49ca8b`/`0x49cb60`/`0x49cd97`, materialized create-vfunc family semantics from `0x49c553..0x49cdb1`, materialized `0x4a9f1c` selector scan/weighted-choice control flow through `0x4aa192`, the `0x4aa9b7..0x4aab7b` reward coordinate scan/random-pick boundary with generated-cell `+0x20` owner/score gates, helper boundaries for `0x4aa603` filter gates and `0x4aa3e9` generated-cell/object mutation, helpers `0x4ae1fd`/`0x4ae52a`, and 110 materialized static candidate records, up to but not through private filter evaluation, generated-cell mutation, private reward coordinate records, reward object adoption, extended monster candidates, or public objects;
- explicitly blocks `0x4ab52a` roads/rivers until the complete `generator+0x14b0` coordinate vector producers are ported, instead of treating the previous town-only vector as road-ready;
- reports the strict executable-port backlog with roads/rivers and later phases marked `pending_strict_port`;
- refuses runtime generation and any partial public package payload.

Seed `1`, one human, three total players currently selects `h3maped_template_018` at source catalog index `18`, adapted to `translated_rmg_template_019_v1`, through the h3maped RNG first value `41` and selected vector index `2`. Accepted small-land templates for that profile remain `13`.

The active module no longer exposes the old top-level terrain art, blocker, guard, final-writeout records, or the private phase ledger. The active generation state beyond template selection is limited to player-slot assignment, runtime-zone records, link seeds, coordinate replay, and private zone-footprint/cell ownership buffers through `0x4a3710`. It materializes no runtime players, public map cells, package tiles, public roads, rivers, or public output. Terrain, town/player-start, mine/reward, road/river, blocker/guard, and final writeout work must be reintroduced as actual runtime generator implementation derived from `h3maped.exe`, not as broad inspection-ledger expansion.

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
2. Player-slot assignment: `0x4ac62a..0x4ac6ec` (active non-public generation state; no runtime player/package materialization).
3. Runtime-zone records: `0x4a218c` / `0x49b452` (active non-public generation state; no terrain/map-cell materialization). Town selector `0x49b3c1` is consumed for coordinate-replay town-choice RNG; `0x49b53d` runtime terrain selection remains pending in the active compiled restart.
4. Coordinate replay and zone-footprint phase: `0x4a1f3b`, `0x4a17f5`, `0x4a1701`, `0x4a1ad8`, and `0x4a19ed` are active non-public coordinate replay state. `0x4a3a03` helper scheduling, `0x4cc788` initial rectangle setup, `0x4ccb64` split insertion/bridge/crossing cleanup, `0x4ccdfc` source-node finalization, `0x4a2777` source-node boundary traversal, `0x4a2b33` clip helper, `0x4a261a` deterministic line writer, `0x4a2413` randomized line writer, `0x4a325d` span fill, and small-land `0x4a3710` footprint finalizer are active non-public private cell ownership state.
5. Terrain writeout and TerrainPlacement: `0x4a3f27`, `0x49b53d`, `0x4bcff5`, `0x4bb74b`, `0x4bc5f0`, and `0x49b2b6` are pending in the active compiled restart. Package output remains blocked until terrain, town, road, object, guard, and final-writeout phases are executable-derived.
6. Town object placement: `0x4a8d2c`, `0x4a8db2`, `0x4a93a2`, `0x49aa93`, `0x49a09c`, `0x49b3c1`, `0x49ba89`, and `0x540a9c` are pending in the active compiled restart.
7. Mines, rewards, and object-vector producers: `0x4a9d6a`, `0x4a9911`, `0x4a9641`, `0x4a9c7c`, `0x4aab7e`, `0x4aa354`, `0x4a9f1c`, and `0x4aa9b7` are pending in the active compiled restart.
8. Roads and rivers: `0x4ab52a`, `0x4aae7b`, `0x4ab37f`, `0x4b4243`, `0x458a2f`, `0x458893`, and `0x49b2b6` are intentionally blocked until the complete object coordinate vector exists. The previous town-only road pass was removed from the completed boundary because it explains the bad loop roads.
9. Connections, blockers, and guards: `0x4a79a3`, `0x4a61bc`, `0x4a696b`, `0x4a6cf2`, `0x4a7605`, `0x4a65a5`, `0x4a5e03`, `0x4a5e73`, and `0x4a5a23` (late payload postprocess, guard value scaling, corrected `0x4a6cf2` same-level return-false gate, same-level dispatch readiness, low/high owner-byte precondition reporting, baseline `0x4a5767`/`0x49a318` high-owner propagation, generated-cell `+0x28` bit25/direction handoff, and `0x4a79a3` transition-vector candidate scan active inspection only; remaining `0x49a318` bit22/object metadata branches, actual `0x4a61bc`/`0x4a696b` endpoint writes, guard object stamping, blockers, mines, rewards, and final adoption still pending).
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
