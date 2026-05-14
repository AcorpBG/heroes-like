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

2026-05-14 fast structural validator authority update: the active code now runs a strict native validator over the non-authoritative package and final writeout drafts without launching a Godot report scene. Seed `1` reports `strict_fast_structural_validator_pass_runtime_blocked` with zero failures, 1296 terrain/final tile cells, 40 package objects, 3 owned player towns and 3 starts, 18 mines, 3 reward references, 10 blocking connection blockers, 6 blocking connection guards, 5 guarded route links, zero route links missing blockers/guards, zero duplicate placement ids, and zero out-of-bounds package objects. The validator is now the authority gate for the current draft, but it still does not authorize public runtime output; the next required ports are public `generate_random_map()` authority and editor/runtime adoption audit.

2026-05-14 final `0x49b2b6` writeout draft boundary update: the active code now assembles a non-authoritative final writeout draft in `inspect_h3maped_small_rmg_port()` after package draft adoption. Seed `1` reports seven tile-byte arrays sized to the 36x36 surface: terrain byte `0`, terrain art byte `1`, zero river bytes `2/3` for the current one-level land scope, road bytes `4/5`, and final flag byte `6` combining terrain flags and road flip bits. The draft carries the 40 package-object payload and 5 route links forward, reports `draft_pass_runtime_blocked`, and keeps `runtime_generation_allowed: false` / `public_runtime_authoritative: false`. This does not authorize public `.h3m` or runtime package output; the next required ports after validator authority are public generation authority and editor/runtime adoption audit.

2026-05-14 public package draft boundary update: the active code now adapts strict private h3maped state into a non-authoritative project package draft in `inspect_h3maped_small_rmg_port()`. Seed `1` reports a draft map document with 1296 terrain tiles, one private road overlay segment, 3 owned player towns synchronized with 3 player starts, 18 mine objects, 3 reward objects, 10 connection blocker objects, 6 connection guard objects, 40 package objects total, 5 route links, and draft structural validation status `draft_pass_runtime_blocked`. This is not public runtime generation: `generate_random_map()` still returns `h3maped_small_clean_restart_generation_not_ready`, `runtime_generation_allowed` remains false, and the next required port after the package/writeout drafts is validator authority.

2026-05-14 connections/blockers/guards private boundary update: the active code now materializes private `0x4a79a3` connection post-processing records without enabling runtime package output. It derives owner-low/high transition channels through a private `0x4a5767` / `0x49a318` projection, builds `0x4a79d8` transition vectors, selects `0x4a61bc` same-level endpoints for four links, and uses the `0x4a7605` / `0x4a7312` second-pass fallback for the one remaining link. Seed `1` now reports 5/5 private connection records, 10 private blocker cells, and 6 private guard records after `0x4a65a5` scaling and `0x4a5e03` guard materialization. Public package/writeout adoption remains non-authoritative and validator-blocked.

2026-05-14 original-template hydration correction: selected small h3maped templates now hydrate runtime-zone records and link seeds directly from `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json` by recovered source catalog index. The translated project catalog bridge is disabled for this small h3maped path; project ids/assets are only allowed at final content adaptation boundaries after the relevant executable phase has been ported. Seed `1`, one human, three total players selects `h3maped_template_018` at source catalog index `18` with no adapted translated-template authority.

2026-05-14 roads/rivers private boundary update: the active code now exposes only the strict private `0x4ab52a` coordinate-vector walk and `0x4aae7b` low-word path-cost candidate boundary. It materializes the three current town/castle `generator+0x14b0` coordinate records from `0x4a95af`, evaluates three private pair candidates against the recovered `0x7530` threshold, and records the executable anchors for `0x4ab37f` and `0x4b4243`. It still does not serialize public road overlay bytes, river overlay bytes, blockers, guards, runtime-grid adoption, package tiles, or final output. The next accepted implementation step is the actual road toolkit geometry/writeback (`0x4ab37f` / `0x4b4243`) before connection blockers/guards (`0x4a79a3` family).

2026-05-14 reward filter/mutation update: the active code now includes a narrow private port of `0x4aa603` / `0x4aa3e9` inside the mines/rewards/object-vector boundary. It terrain-filters reward templates, scans generated-cell `+0x20` owner/score candidates, records three private reward coordinates for seed `1`, mutates private generated-cell body/action state, and depletes local score fields through the recovered `0x4a54a7` helper. This is still not runtime map output: no public objects, package tiles, roads, blockers, guards, or final writeout are exposed. The next accepted implementation step is strict roads/rivers plus blockers/guards (`0x4ab52a` / `0x4aae7b` / `0x4a79a3` family).

2026-05-14 corrective execution note: the uncommitted attempt to turn incomplete roads, connection fallback helpers, proxy blockers/guards, and package adaptation into active runtime output is rejected. It is evidence only. The active code must return to the strict baseline where incomplete executable phases block generation. No `generate_runtime_payload` path may claim validation `"pass"` or public package adoption until the required h3maped functions are ported as executable-derived state. Roads and connection blockers/guards stay blocked until the complete object coordinate vector and mutation state exist.

2026-05-13 strict restart correction: the active public boundary is reset to h3maped binary verification, 36x36 one-level land scope gating, recovered size/water scoring, h3maped RNG template-selection evidence, strict `0x4ac62a..0x4ac6ec` player-slot assignment, strict `0x4a218c` / `0x49b452` runtime-zone records, strict `0x4a1f3b` link-seed setup, strict `0x4a17f5` / `0x4a1701` / `0x4a1ad8` / `0x4a19ed` coordinate replay, strict `0x4a3a03` / `0x4cc788` / `0x4cc955` / `0x4ccb64` / `0x4ccdfc` zone-footprint source-node setup, strict `0x4a2777` / `0x4a2b33` / `0x4a261a` / `0x4a2413` / `0x4a325d` boundary and span fill, strict small-land `0x4a3710` / `0x49b61b` / `0x4a3554` footprint finalizer ordering, strict `0x49b53d` runtime terrain selection, strict `0x4a3f27` private terrain cell writeout, strict `0x4bcff5` TerrainPlacement visual-table/toolkit decoding, strict `0x4bb74b` / `0x4bc5f0` live TerrainPlacement repaint feedback, strict `0x49b2b6` terrain/art/flag tile-byte candidates, strict `0x4a8d2c` / `0x4a8db2` / `0x4a93a2` private town/castle candidates, strict `0x4a9d6a` / `0x4a9911` / `0x4aa354` / `0x4a9f1c` / `0x4aa9b7` private mines/rewards/object-vector prerequisites, an explicit executable-port backlog, and runtime generation refusal. It no longer exposes `active_generation_state`, `small_generation_state`, `private_generation_context`, private town/object ledgers, package payloads, or partial map output.

The earlier overgrown active port remains archived at `src/gdextension/src/archived_h3maped_small_rmg_overgrown_active_20260513.cpp`; the previous phase ledger remains archived at `src/gdextension/src/archived_h3maped_small_rmg_phase_ledger_20260513.cpp`. Older archived ledgers remain evidence only.

The active module must not expose `active_generation_state`, `small_generation_state`, `private_generation_context`, private town/object ledgers, or runtime-authoritative package payloads. Previous private town, mine, reward, road, blocker, and guard ledgers are archived evidence only; active package, final writeout, and fast structural validation are limited to strict non-authoritative draft gates built from the current executable-derived private state. The next active implementation step is public generation authority behind the validator before editor/runtime adoption can be audited.

Seed `1`, one human, three total players currently selects original source `h3maped_template_018` at recovered catalog index `18` through h3maped RNG first value `41` and selected vector index `2`, fills `generator+0xee0/+0xee4` assignment/mapping slots as `[0, 1, 2, -1, -1, -1, -1, -1]`, builds six runtime-zone records and five link seeds from the original recovered template catalog, replays coordinates to scaled zone centers `(23,11)`, `(21,22)`, `(12,23)`, `(18,4)`, `(18,30)`, and `(12,11)`, builds strict source-node geometry with six split calls, 23 active source-node pairs, 14 finalized triplets, 42 finalized nodes, and six source-node walks, builds a private span-filled zone buffer with 301 boundary trace writes, 238 unique boundary cells, 869 filled interior cells, and 1107 boundary-or-filled cells, runs the small-land `0x4a3710` finalizer path with no appended synthetic runtime zones, zero adjacency inserts, six ordering resets, and six per-zone ordering rebuilds, runs `0x49b53d` terrain selection to choose h3maped terrain ids `[2,0,7,7,4,5]` / project terrains `[grass,dirt,lava,lava,swamp,rough]` with two terrain RNG calls from `255755822` to `2166683160`, runs `0x4a3f27` private terrain cell writeout, then continues through the active private town, mine, reward filter/mutation, private roads/rivers overlay, private connection blocker/guard phases, non-authoritative package draft adoption, non-authoritative final `0x49b2b6` writeout draft, and fast structural validator authority. Public runtime generation and editor/runtime adoption remain pending executable ports.

Historical note: the section below describes the archived report-treadmill state before the correction above. It is preserved as failure evidence, not the active implementation contract.

The archived report-treadmill module used to:

- verifies `/root/Downloads/h3maped.exe` by size, MZ header, and SHA-256;
- accepts only small 36x36 one-level land configs;
- computes the recovered h3maped size/water score boundary;
- selects from the recovered small-land template vector using h3maped RNG `0x4e7269/0x4e7276`;
- builds active non-public player-slot state from `0x4ac62a..0x4ac6ec` source-owner masks and `generator+0xed8/+0xee0/+0xee4` slot arrays;
- builds active non-public `0x4a218c` runtime-zone records from the selected original recovered h3maped template catalog and player-slot mapping;
- builds active non-public `0x4a1f3b` link seeds and one-level `0x4a17f5`/`0x4a1701`/`0x4a1ad8`/`0x4a19ed` coordinate replay from the original recovered h3maped template connections;
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

Seed `1`, one human, three total players currently selects `h3maped_template_018` at source catalog index `18`, with the translated-template bridge disabled, through the h3maped RNG first value `41` and selected vector index `2`. Accepted small-land templates for that profile remain `13`.

The active module no longer exposes the old top-level terrain art, blocker, guard, final-writeout records, or the private phase ledger. The active generation state beyond template selection is limited to player-slot assignment, runtime-zone records, link seeds, coordinate replay, source-node geometry, private boundary/span-fill buffers, the small-land footprint finalizer, runtime-zone terrain id selection, private terrain cell writeout, static TerrainPlacement visual-table/toolkit decoding, live TerrainPlacement repaint feedback, private `0x49b2b6` terrain/art/flag tile-byte candidates, private `0x4a8d2c` / `0x4a8db2` / `0x4a93a2` town/castle candidates, and private mine/reward/object-vector prerequisite records. It materializes no runtime players, public map cells, package tiles, public roads, rivers, public objects, or public output. Reward coordinate filter/mutation, road/river, blocker/guard, and final writeout work must be reintroduced as actual runtime generator implementation derived from `h3maped.exe`, not as broad inspection-ledger expansion.

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
2. Player-slot assignment: `0x4ac62a..0x4ac6ec` (active strict executable port for `generator+0xee0/+0xee4` assignment/mapping slots only).
3. Runtime-zone records: `0x4a218c` / `0x49b452` (active strict executable port for `generator+0x10e0/+0x10e4/+0x10e8` runtime-zone vector records only). Town selector `0x49b3c1` must be consumed for coordinate-replay town-choice RNG when that phase is reintroduced.
4. Coordinate replay and zone-footprint phase: `0x4a1f3b`, `0x4a17f5`, `0x4a1701`, `0x4a1ad8`, and `0x4a19ed` are active through coordinate replay and bbox rescale. `0x4a3a03`, `0x4cc788`, `0x4cc955`, `0x4ccb64`, and `0x4ccdfc` are active through source-node setup. `0x4a2777`, `0x4a2b33`, `0x4a261a`, `0x4a2413`, and `0x4a325d` are active through private boundary/span fill. Small-land `0x4a3710`, `0x49b61b`, and `0x4a3554` are active through the no-appended-zone footprint finalizer. `0x49b53d` runtime terrain selection is active for runtime-zone terrain ids only.
5. Terrain writeout and TerrainPlacement: `0x4a3f27` is active through private terrain cell writeout, `0x4bcff5` is active through static visual-table/toolkit decoding, `0x4bb74b`/`0x4bc5f0` are active through private repaint queue feedback, and `0x49b2b6` is active for terrain byte `0`, terrain art byte `1`, and terrain flag byte `6` candidates.
6. Town object placement: `0x4a8d2c`, `0x4a8db2`, `0x4a93a2`, `0x49aa93`, `0x49a09c`, `0x49b3c1`, `0x49ba89`, and `0x540a9c` are active for private town/castle candidates only. Town object package adoption remains blocked until the object-vector producers are ported.
7. Mines, rewards, and object-vector producers: `0x4a9d6a`, `0x4a9911`, `0x4a9641`, `0x4a9c7c`, `0x4aab7e`, `0x4aa354`, `0x4a9f1c`, `0x4aa9b7`, `0x4aa603`, and `0x4aa3e9` are active through private mine records, private reward coordinate records, and generated-cell/object mutation evidence only. Public object/package adoption remains blocked.
8. Roads and rivers: `0x4ab52a` and `0x4aae7b` are active for private coordinate-vector pair costs using town/castle `generator+0x14b0` records, and accepted predecessor chains now materialize private road overlay bytes through the recovered `0x458a2f` / `0x458893` art/flip classifier and `0x49b2b6` road byte staging. The final writeout draft carries zero river bytes for the current small-land scope; broader river behavior remains unsupported until water/river scope is selected.
9. Connections, blockers, and guards: `0x4a79a3`, `0x4a61bc`, `0x4a7605`, `0x4a7312`, `0x4a65a5`, `0x4a5e03`, `0x4a5767`, and `0x49a318` are active for private connection blocker/guard records only. `0x4a696b`, `0x4a6cf2`, `0x4a5e73`, and `0x4a5a23` remain pending.
10. Public package draft adoption: active only as non-authoritative project package draft materialized from strict private h3maped state; public runtime package authority remains blocked.
11. Final h3m writeout: `0x49b2b6` is active only as a non-authoritative final tile-byte/package-payload draft. Public runtime authority remains blocked on fast structural validation and editor/runtime adoption.
12. Fast structural validator authority: active for the current package/writeout draft and still runtime-blocked; public runtime package authority remains a separate port.

## Hard Rules

- No hash-based template selection as a substitute for h3maped behavior.
- No sample-specific exact-count fitting in runtime generation.
- No adapter/proxy fallback output for incomplete h3maped phases.
- No self-declared validation pass for generated maps until the executable-derived phase chain actually covers the generated output.
- No road clusters that merely look like road counts.
- No blocker/decoration placement that passes counts while leaving unguarded open paths between zones.
- No player-start repair pass that only patches owner/town fields after placement.
- No validation that treats metadata zone links as sufficient when map cells do not enforce the link.
- No production fallback to archived native catalog-auto output.
- No reuse of legacy hashed TerrainPlacement art/index/flip approximation in the clean h3maped reset path.
