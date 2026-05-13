# Native RMG Small h3maped Reset

Status: active reset slice.

The previous native RMG implementations are archived as debug/evidence code. They are not the production generator path, and `MapPackageService.generate_random_map()` must not fall back to them.

## Source Anchor

- Binary: `/root/Downloads/h3maped.exe`
- Format: PE32 GUI Intel 80386 Windows executable
- SHA-256: `4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37`
- Recovered spec: `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- Active module: `src/gdextension/src/h3maped_small_rmg.cpp`
- Archived active boundary: `src/gdextension/src/archived_h3maped_small_rmg_active_boundary_20260513.cpp`
- Archived current ledger: `src/gdextension/src/archived_h3maped_small_rmg_inspection_ledger_20260513.cpp`
- Older historical ledger: `src/gdextension/src/legacy_h3maped_small_rmg_inspection_ledger.cpp`

## Scope

Initial scope is only 36x36, one-level, land maps.

Medium, large, XL, water, islands, and underground generation are out of scope for this reset until the small land path can materialize zones, terrain, owned starts, towns, roads, blockers, guards, mines, rewards, and final writeout from h3maped-derived phases.

## Current Boundary

The active module is intentionally small again. The previous active h3maped boundary file was archived out of the build at `src/gdextension/src/archived_h3maped_small_rmg_active_boundary_20260513.cpp` after owner direction to restart without further incremental drift.

The compiled active module now only:

- verifies `/root/Downloads/h3maped.exe` by size, MZ header, and SHA-256;
- accepts only small 36x36 one-level land configs;
- computes the recovered h3maped size/water score boundary;
- selects from the recovered small-land template vector using h3maped RNG `0x4e7269/0x4e7276`;
- ports player-slot assignment `0x4ac62a..0x4ac6ec` as inspection-only evidence, including `generator+0xed8`, `generator+0xee0`, and `generator+0xee4`;
- ports runtime-zone record setup `0x4a218c` as inspection-only evidence from the recovered template catalog, including runtime vector offsets `generator+0x10e0/+0x10e4/+0x10e8` and `0x414`-byte record size;
- ports `0x4a1f3b` source-zone link endpoint seeds as inspection-only evidence, preserving `Value`, `Wide`, and `Border Guard` payloads for later `0x4a79a3`;
- ports interleaved runtime town choice `0x49b3c1` inside `0x4a218c`/coordinate replay as inspection-only evidence before coordinate candidates consume their RNG values;
- ports one-level coordinate candidate replay `0x4a17f5/0x4a1701/0x4a1ad8/0x4a19ed` as inspection-only evidence;
- ports runtime terrain selection `0x49b53d` as inspection-only evidence: match-to-town zones use table `0x540908`, treasure zones choose from source terrain flags through h3maped RNG, and terrain cells feed the private `0x4a3f27` writeout inspection;
- ports the `0x4a3a03` zone-footprint phase boundary as inspection-only evidence: one level collects the six runtime zones, queues six `0x4a2777` helper inputs, small one-level land appends no synthetic `0xd4` source zone, and helper materialization remains pending;
- ports the `0x4cc788` initial source-node rectangle as inspection-only evidence, including constants `0xffffff38` / `0x190` and the four initial `0x4cc955` edges that later `0x4ccb64` split insertion must mutate before real `0x4a2777` traversal;
- ports the `0x4a2b33` endpoint clip helper as inspection-only evidence for the 36x36 active map rectangle before any `0x4a2777` boundary traversal writes are allowed;
- ports the `0x4a261a` deterministic line writer as inspection-only evidence over a bounded sample buffer before any writes can feed generated map cells;
- ports the `0x4a2413` randomized line writer as inspection-only evidence over a bounded one-level land sample before any writes can feed generated map cells;
- ports the `0x4ccb64` source-node split loop and `0x4ccdfc` finalizer as private inspection-only graph evidence over the current scaled runtime-zone points;
- ports real `0x4a2777` source-node cycle traversal as a private boundary-buffer report using `0x4a2b33`, `0x4a261a`, and `0x4a2413`; it reports six consumed runtime-zone cycles, 301 private trace writes, and 238 unique private boundary cells, but does not feed terrain, map cells, or public package output;
- ports `0x4a325d` span fill over that private `0x4a2777` boundary buffer as private inspection-only evidence; it reports six fill attempts, 869 filled interior cells, 1107 boundary-or-filled private cells, and 189 remaining unassigned cells, but does not feed terrain, map cells, or public package output;
- ports the small-land `0x4a3710` finalizer as private inspection-only evidence; with no appended synthetic runtime zones, both adjacency insertion phases skip and only six `0x49b61b` ordering resets plus six `0x4a3554` ordering rebuild calls are scheduled;
- ports `0x4a3f27` terrain/cell writeout as private inspection-only evidence over the real `0x4a325d` zone-word buffer; it materializes private generated-cell terrain words and `0x49b2b6` byte-zero terrain candidates, applies the recovered `0x4bbfcc` boundary counter over that generated terrain grid, and records private live repaint visual feedback words, but not roads, objects, runtime-grid adoption, or public package tiles;
- ports the first TerrainPlacement visual-table/toolkit boundary as inspection-only evidence from h3maped static tables and vtables: `0x4bcff5`, `0x4bb5ce`, `0x4bd099`, `0x4bb74b`, `0x4bc5f0`, `0x4bcfc3`, `0x4bce6d`, `0x4ba938`, `0x4ba989`, `0x4baa94`, `0x4baabf`, `0x4bad0f`, `0x49acf6`, `0x4bbd01`, `0x4bc988`, and `0x4bbfcc`; this decodes visual row tables and selector samples, ports bounded scratch-word/writeback samples, records the queue/final-sweep normalization contract, and ports the private `0x4a4025`/`0x4bb74b` repaint path through the recovered `0x4bc5f0` set A/B queue drain, but does not yet adopt art/flag bits into a public grid or package;
- ports the town/castle minimum schedule and private direct town stamping projection as inspection-only evidence from `0x4a8d2c`, `0x4a8db2`, `0x4a93a2`, `0x49aa93`, `0x49a09c`, `0x49b3c1`, `0x49ba89`, and `0x540a9c`; this consumes the post-queue generated-cell terrain grid, projects three owned player castle records and synchronized player-start candidates for seed `1`, and skips the fourth unassigned source-owner castle, but does not adopt town objects into the public runtime grid or package;
- ports late connection payload and overlap precondition evidence from `0x4a79a3`, `0x4a61bc`, `0x4a696b`, `0x4a6cf2`, `0x4a7605`, `0x4a65a5`, `0x4a5e03`, `0x4a5e73`, and `0x4a5a23`; this marks five unique links and ten reciprocal records, scales guard values through the recovered strength helper, and reports overlap rectangles against the private generated-cell zone grid, but does not materialize road/river geometry, endpoint objects, or guards;
- records a strict restart backlog for the required executable phase ports;
- refuses runtime generation.

Seed `1`, one human, three total players currently selects `h3maped_template_018` at source catalog index `18`, adapted to `translated_rmg_template_019_v1`. Its recovered source-owner masks are `0x0f` for human-capable owners and `0x0f` for player-capable owners; default color ordering maps source owners `0,1,2` to actual colors `0,1,2`. Runtime-zone setup reports six source zones, owner colors `[0,1,-1,2,-1,-1]`, three assigned start zones, one unassigned start zone, two treasure zones, and four minimum player castles. Link seed setup reports five source-zone links: `1-4`, `2-5`, `4-5`, `3-5`, and `6-4`. Coordinate replay now includes four interleaved `0x49b3c1` town-choice RNG calls before candidate placement, reports 18 placement steps, 18 coordinate RNG calls, 22 total replay RNG events, final replay RNG state `255755822`, bbox span `84`, and scaled zone centers `(23,11)`, `(21,22)`, `(12,23)`, `(18,4)`, `(18,30)`, and `(12,11)`. Runtime terrain selection `0x49b53d` selects project terrains `[grass, dirt, lava, lava, swamp, rough]` with two terrain RNG calls and final terrain-selection RNG state `2166683160`. Private `0x4a3f27` terrain/cell writeout reports 1296 cells, 1107 non-water terrain-byte-zero cells, 189 unassigned water cells, and terrain counts water `189`, grass `177`, dirt `91`, lava `403`, swamp `207`, and rough `229`; byte `1` terrain art and byte `6` terrain flip remain blocked from public adoption. The generated-grid `0x4bbfcc` boundary counter now runs over those 1296 terrain cells as inspection-only evidence before visual row adoption. The TerrainPlacement table boundary decodes five static visual row tables totaling 230 rows and proves representative h3maped selector samples: grass full/native row `60`, normal transition class `28` row `77`, water transition class `16` row `20`, and rock class `8` row `11`. Bounded scratch/writeback samples prove `0x4bad0f` scratch words and `0x49acf6` generated-cell fields for those rows, including grass row `60` word `0x24=3842`, grass row `77` word `0x24=4930` / `0x28=32768`, water row `20` word `0x24=1288`, and rock row `11` word `0x24=713`; the queue/final-sweep contract now records `0x4bc5f0`, `0x4bbd01`, `0x4bc988`, and `0x4bbfcc` ordering and correction classes. The live repaint feedback path now projects `2845` private visual writes across the `0x4a4025` full-water repaint, `0x4bb74b` per-zone repaint sequence, and recovered `0x4bc5f0` set A/B queue drain. It drains `176` set-A entries and `10522` set-B entries without guard exhaustion, performs `221` private retouch terrain writes, leaves `1296` dirty final scratch cells, reports zero missing visual buckets and zero scratch roundtrip mismatches, and records `181` post-queue terrain differences versus the earlier pre-drain `0x4a3f27` terrain grid; public tile/package adoption remains pending.

The town/castle projection for the same seed consumes the post-queue generated-cell terrain grid. It reports four source minimum player castles, schedules three assigned owned player castles for owner colors `[0,1,2]`, skips one unassigned source-owner castle, performs three `0x4a93a2` direct candidate scans over `445` matching zone/terrain cells, finds `85` footprint-eligible town anchors through `0x49aa93`/`0x49a09c`, marks `39` private occupied body cells, and projects three `0x49ba89`/`0x540a9c` town records at `(26,16)`, `(23,23)`, and `(18,5)`. The projected project player starts are synchronized to those private town anchors with owner slots `[1,2,3]` and default town ids `town_riverwatch`, `town_duskfen`, and `town_prismhearth`; public package/runtime-grid adoption remains blocked.

The late connection payload report for the same seed consumes the five `0x4a1f3b` link seeds through the recovered `0x4a79a3` postprocessor. It reports five unique links, ten reciprocal link records, ten processed-marker writes at `+0x0a`, raw guard values `[3000,3000,3000,6000,6000]`, scaled `0x4a65a5` guard values `[2000,2000,2000,5000,5000]`, zero `Wide` suppressions, and zero `Border Guard` special links. The `0x4a6cf2` overlap precondition report finds overlap rectangles for link indices `[0,1,3,4]`, requires the later/fallback helper path for link index `[2]`, and reports `488` total overlap cells, with `167` cells from side A zones and `316` cells from side B zones. Runtime road geometry, endpoint object stamping, guard placement, blockers, mines, rewards, and final package writeout remain blocked.

The active module materializes private inspection-only zone boundary buffers for `0x4a2777`, private inspection-only span-fill buffers for `0x4a325d`, private `0x4a3710` small-land finalizer scheduling evidence, private `0x4a3f27` terrain/cell word evidence, private TerrainPlacement static visual-table evidence, private town/start placement candidates, and private late connection payload/overlap precondition evidence. It still does not materialize terrain art, runtime players, public towns, roads, blockers, guards, mines, rewards, public runtime grids, or packages.

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
8. Connections, blockers, and guards: `0x4a79a3`, `0x4a61bc`, `0x4a696b`, `0x4a6cf2`, `0x4a7605`, `0x4a65a5`, `0x4a5e03`, `0x4a5e73`, and `0x4a5a23` (late payload postprocess, guard value scaling, and overlap precondition active inspection only; endpoint/corridor geometry, guard object stamping, blockers, mines, rewards, and final adoption still pending).
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
