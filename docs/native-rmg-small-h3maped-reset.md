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

The active module is intentionally small again after the 2026-05-13 owner-directed restart correction. The overgrown active port was moved out of the build to `src/gdextension/src/archived_h3maped_small_rmg_overgrown_active_20260513.cpp`; the previous phase ledger remains archived at `src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp`. Older archived ledgers remain evidence only.

The compiled active module now only:

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
- carries the recovered source fields for the `0x4a9d6a` mine phase and `0x4aab7e` reward phase into a non-public object-vector prerequisite boundary, including seven mine minimum/density categories, treasure-band weights, private `0x4a9911`/`0x4a9641` mine-coordinate attempts, the `0x4aab7e` per-zone reward-band scheduler/budget/value-selection preview, and the `0x4a9f1c` generic value-banded selector's metadata/limit-table boundary plus the recovered `0x49f95a` static prefix, monster-table loop, `0x40ce11..0x40d0c8` monster-table initializer boundary for runtime-populated creature rows, 118 materialized single-level monster candidate records from extracted `CRTRAITS.TXT` plus the static `0x57cea0` terrain/tier table and `0x49c5cd` quantity formula, fixed type-6 value bands, type-10 object-bucket consumer loop with its executable metadata producer layout, type-17 loop, 61-record static candidate tail through `0x4a0eeb`, `generator+0x568` type-53 object-bucket loop through `0x4a1194` with three executable-derived bucket entries, 378 one-level candidate records, 704-record one-level candidate-vector order, and 29-record static constructor tail through `0x4a1701`, 17-entry candidate vtable map from `0x540ba0..0x540cac`, reconstructed value-vfunc semantics from `0x49c54d`/`0x49c64b`/`0x49c849`/`0x49ca8b`/`0x49cb60`/`0x49cd97`, materialized create-vfunc family semantics from `0x49c553..0x49cdb1`, materialized `0x4a9f1c` selector scan/weighted-choice control flow through `0x4aa192`, and 110 materialized static candidate records, up to but not through extended monster and selection/coordinate commit needed by `0x4aa9b7`;
- explicitly blocks `0x4ab52a` roads/rivers until the complete `generator+0x14b0` coordinate vector producers are ported, instead of treating the previous town-only vector as road-ready;
- reports the strict executable-port backlog with roads/rivers and later phases marked `pending_strict_port`;
- refuses runtime generation and any partial public package payload.

Seed `1`, one human, three total players currently selects `h3maped_template_018` at source catalog index `18`, adapted to `translated_rmg_template_019_v1`, through the h3maped RNG first value `41` and selected vector index `2`. Accepted small-land templates for that profile remain `13`.

The active module no longer exposes the old top-level terrain art, blocker, guard, final-writeout records, or the private phase ledger. The active generation state beyond template selection is limited to player-slot assignment, runtime-zone records, link seeds, coordinate replay, zone-footprint helper scheduling, initial source-node rectangle setup, compact polygon split/source-node finalization, private source-node boundary traversal, private span fill, the no-appended-zone footprint finalizer, runtime terrain selection, private terrain/cell writeout, private TerrainPlacement visual-table decoding, private TerrainPlacement live feedback, private terrain tile-byte writeback, private town/castle placement candidates, and partial private mine/reward object-vector state. It materializes no runtime players, map cells, package tiles, public roads, rivers, or public output. Terrain art/index/flag byte candidates, town/player-start candidates, and 18 private mine coordinate records exist only as private evidence until rewards, density extras, adjacent resources, guard objects, rivers, connection objects, blockers, the complete `generator+0x14b0` coordinate vector, and final public adoption are ported. Older detailed records were archived because they encouraged incremental report growth without a usable generated map. Future phases must be reintroduced as actual runtime generator implementation derived from `h3maped.exe`, not as broad inspection-ledger expansion.

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
3. Runtime-zone records: `0x4a218c` / `0x49b452` (active non-public generation state; no terrain/map-cell materialization). Terrain selector `0x49b3c1` is consumed for coordinate-replay town-choice RNG, and `0x49b53d` runtime terrain selection is active as non-public state.
4. Coordinate replay and zone-footprint phase: `0x4a1f3b`, `0x4a17f5`, `0x4a1701`, `0x4a1ad8`, and `0x4a19ed` are active non-public coordinate replay state. `0x4a3a03` helper scheduling, `0x4cc788` initial rectangle setup, `0x4ccb64` split insertion/bridge/crossing cleanup, `0x4ccdfc` source-node finalization, `0x4a2777` source-node boundary traversal, `0x4a2b33` clip helper, `0x4a261a` deterministic line writer, `0x4a2413` randomized line writer, `0x4a325d` span fill, and small-land `0x4a3710` footprint finalizer are active non-public boundary/finalizer state.
5. Terrain writeout and TerrainPlacement: `0x4a3f27` is active as private terrain/cell writeout state, `0x4bcff5` visual table/toolkit decoding plus bounded `0x4bad0f`/`0x49acf6` sample contracts are active as private state, `0x4bb74b`/`0x4bc5f0` live repaint queue feedback is active as private generated-cell state, and `0x49b2b6` terrain tile-byte projection is active as private terrain/art/flag byte candidates. Package output remains blocked until later town/road/object/final-writeout phases are executable-derived too.
6. Town object placement: `0x4a8d2c`, `0x4a8db2`, `0x4a93a2`, `0x49aa93`, `0x49a09c`, `0x49b3c1`, `0x49ba89`, and `0x540a9c` are active as private town/castle placement and synchronized player-start candidates. Public runtime-grid/package adoption remains blocked until roads/rivers, objects, guards, rewards, and final writeout are executable-derived too.
7. Mines, rewards, and object-vector producers: `0x4a9d6a`, `0x4a9911`, `0x4a9641`, `0x4a9c7c`, `0x4aab7e`, `0x4aa354`, `0x4a9f1c`, and `0x4aa9b7` are active as source-field schedules and partial private coordinate-vector materialization. Seed 1 currently scans all 18 minimum mine records and materializes all 18 private mine coordinate records after replacing the all-cells owner proxy with a `0x49a09c` circular mask gate and `0x49a1d8`-style cell validity. The `0x4a9641` special wood/ore gate is confirmed as squared-distance comparison from the executable. The reward boundary now runs the recovered `0x4aab7e` per-zone eligibility rule (`low >= 100`, positive density), density-product counter scheduler, `0x320` land budget argument, and `0x4aa354` value RNG preview for 18 first-cycle attempts across six zones. The `0x4a9f1c` boundary records the generic candidate vector offsets, object metadata table, default `0x7d00` limit policy, 30 global-limit overrides, 24 per-zone-limit overrides, recovered metadata flag counts, the two fixed `0x49f95a` prefix records, the `0x581298` monster-table loop/`0x49c5cd` constructor contract, the `0x40cc46` CRTRAITS loader, the `0x40ce11` monster-table initializer boundary, 118 materialized single-level monster candidate records, 18 fixed type-6 value-band records across vtables `0x540bd0`/`0x540be0`/`0x540bf0`, the `generator+0xd8..0xdc` type-10 object-bucket consumer loop with five value records per bucket entry, and the recovered type-10 bucket layout from the `0x49da08` base object-table producer (`generator+0x34 + 10*0x10`, begin `+0xd8`, end `+0xdc`). The type-10 pool count is now materialized as 8 bucket entries and 40 value-band candidate records from the `0x401d24..0x401e0c` metadata initializer plus the `0x49da08` source-table row filters. The same boundary includes the `0x4a0402..0x4a045a` type-17 loop, the 61 fixed/static candidate-tail records from `0x4a00cc..0x4a0eeb`, the `0x4a0eeb..0x4a1194` type-53 object-bucket loop over `generator+0x568..0x56c` with three source rows, per-bucket `0x540c60` monster records, eight fixed `0x540c70`/`0x540c80` value records, 378 one-level candidate records, and 447 extended candidate records once the extended monster table is enabled, the `0x4a1194..0x4a1701` 29-record static constructor tail, the `0x540ba0..0x540cac` create/value/disabled vfunc table, the reconstructed value-vfunc formulas used by `0x4a9f1c` at `0x4a9ffd..0x4aa004`, the materialized `0x4a9f1c` selector scan/weighted-choice control flow through `0x4aa192`, and a private 110-record static candidate vector subset from the exact recovered static records. Extended monster candidates, coordinate commits through `0x4aa9b7`, density extras, adjacent resources, guard objects, and public object/package adoption remain pending.
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
