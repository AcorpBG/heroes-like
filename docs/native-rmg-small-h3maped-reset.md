# Native RMG Small h3maped Reset

Status: active reset slice.

The previous native catalog-auto RMG path is archived as legacy evidence/debug code. It is not the production random map generator path. Normal generation must not silently fall back to that implementation because it mixed recovered-template labels with hash selection, per-case fitting, road-cluster materialization, and validation gates that did not prove physical zone separation.

## Source Anchor

The replacement slice is scoped to the verified local Heroes III map editor executable:

- Binary: `/root/Downloads/h3maped.exe`
- Format: PE32 GUI Intel 80386 Windows executable
- SHA-256: `4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37`
- Recovered spec reference: `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`

If an implementation detail is not supported by executable-derived behavior, recovered spec evidence, or direct generated-map comparison, it is not allowed into the production path.

## Scope

Initial scope is small maps only:

- Size: 36x36.
- Surface-only land maps first.
- Surface plus underground, normal water, and islands only after the small land path has binary-backed template selection, physical zone separation, roads, blockers, guards, towns, mines, and reward placement working without fallback.

Medium, large, and extra-large maps are out of scope for this reset slice.

## Hard Rules

- No hash-based template selection as a substitute for h3maped behavior.
- No sample-specific exact-count fitting in runtime generation.
- No road clusters that merely look like road counts; roads must serialize route geometry.
- No blocker/decoration placement that passes count checks while leaving unguarded open paths between zones.
- No player-start repair pass that only patches owner/town fields after placement.
- No validation that treats metadata zone links as sufficient when map cells do not enforce the link.
- No production fallback to archived native catalog-auto output.

## Required Port Shape

The new small-map path should be isolated from the archived implementation and should mirror the executable-derived sequence:

1. Select the small-map template using h3maped-derived rules.
2. Materialize physical zones and terrain regions.
3. Place owned starting towns at player starts.
4. Place neutral towns according to the selected template.
5. Build real roads between the towns, zones, and required exits.
6. Place mines, rewards, monsters, blockers, and decorations using executable-derived density and mask semantics.
7. Guard zone links and high-value paths physically on the grid.
8. Validate by reading the produced map cells and objects, not by trusting generator intent.

Our content IDs, art assets, and object registries may adapt the output to this project, but placement semantics, masks, blocked tiles, guarded links, and route topology must follow the executable-derived behavior.

## First Acceptance Target

The first target comparison is a 36x36 single-level land map from the local owner corpus, especially `maps/h3m-maps/S-RandomNumberofplayers.h3m` when present. The first useful pass must report:

- player-owned town count and ownership,
- neutral town count,
- physical zone count and terrain separation,
- road connected components and endpoints,
- guarded versus unguarded zone links,
- blocker/decorative obstacle occupancy,
- mine and reward distribution.

Passing broad counts alone is not sufficient.

## Current Boundary

The first GDExtension boundary is `MapPackageService.inspect_h3maped_small_rmg_port(config)`. It currently supports inspection for 36x36 single-level land configs only and computes the recovered accepted-template vector using the h3maped size-score formula and player-capacity filter from `0x49f0cd`.

The executable-backed RNG boundary is now recovered for template selection:

- `0x4e7269` writes the global PRNG state.
- `0x4e7276` advances with `state = state * 0x343fd + 0x269ec3` and returns `(state >> 16) & 0x7fff`.
- `0x4ac597..0x4ac5a4` selects the accepted template by `0x4e7276() % accepted_template_count`.
- `0x49d914` seeds the generator through `0x4e778d`, which derives a numeric time value. The inspection boundary therefore only selects when the config seed is already numeric and can be passed to the seed setter without custom hashing.

After selection, the boundary resolves the selected recovered source template through `content/random_map_template_catalog.json` by `import_provenance.source_template_index == source_catalog_index + 1`. This is intentionally provenance-based rather than translated-name-based because the source catalog is zero-based in the h3maped inspection report while the imported content records are one-based and preceded by original runtime templates. For seed `1`, selected source `h3maped_template_018` resolves to adapted template `translated_rmg_template_019_v1` with 6 active zones, 5 active links, 4 player-capable start zones, 2 treasure zones, 4 minimum player castles, and the recovered human/player-capable owner bitmaps.

The executable-backed player-slot assignment boundary is now ported for `0x4ac62a..0x4ac6ec`. The wrapper at `0x4adfe1` constructs the generator at `ebp-0x14ec`, copies selected player-color bytes into `generator+0xed8` at `ebp-0x614`, and then calls `0x4ac552`. If no selected-color bitmap is supplied by the project config, the constructor-zeroed `generator+0xed8` state is preserved and the color order is `0..7`, matching the second pass at `0x4ac65b..0x4ac66e`. For seed `1` with 1 human and 2 computer players, source owner slots `0,1,2` map to actual colors `0,1,2`.

The first high-confidence part of `0x4a218c` is also exposed as a runtime-zone seed report. It reports one runtime-zone seed per active source zone, source `+0x08` base sizes, source `+0x1c` owner/color carryover through `generator+0xee4`, retained link endpoints, and the executable's initial land scale argument. For seed `1` on a 36x36 land map, the selected template has 6 runtime-zone seeds, 5 link seeds, minimum source zone size `11`, land divisor `5`, and link-seed scale argument `79`.

Single-level coordinate seeding is now ported for the h3maped boundary. The report models `0x4a1f3b` runtime-zone insertion/refinement, `0x4a17f5` 32-direction angle candidates from the executable tables at `0x58dc28/0x58dd28`, `0x4a1701` distance validation, `0x4a1ad8` single-level candidate pruning, `0x4e7276` candidate selection after template RNG state, and `0x4a19ed` bounding-box rescale. For seed `1`, the inspection executes 18 placement steps: 6 initial runtime-zone insertions plus two 6-zone refinement passes.

The first scheduling part of `0x4a3a03` is ported as level-footprint phase evidence for the current small land scope. It collects runtime zones whose copied rectangle level matches the phase level, reports that all 6 selected-template runtime zones belong to level `0`, and preserves the executable branch that skips the synthetic `0xd4` fallback source zone on one-level land because `level != 1` and water mode is land. The synthetic source defaults are documented in the report for the branches where h3maped can allocate it. The actual footprint geometry helpers `0x4a2777`, `0x4a325d`, and `0x4a3710` are the next blocker and are not faked.

The `0x4a2777` footprint helper now consumes the recovered real `0x4cca55` source-node cycles for the selected small template instead of stopping at standalone branch samples. Its endpoint clip dependency, `0x4a2b33`, is ported as an executable-backed helper and reported through the boundary: early in-bounds return, integer division truncation, max-bound-minus-one clipping behavior, and sample clips against the current map bounds. Its deterministic cell-buffer line writer dependency, `0x4a261a`, is also ported as executable-backed C++ and reported through the boundary: endpoint swapping, endpoint-inclusive Bresenham-style stepping, 48-byte map-cell stride, zone-id writes through `cell+0x20 & 0x00ff0000`, reserved-cell marking through `cell+0x2b |= 0x10`, and the water-mode reserved-flag suppression branch. Its flagged randomized/interpolated line writer dependency, `0x4a2413`, is ported as an executable-backed helper: midpoint subdivision, `0x4e7276` jitter, `0x4cc5ad` distance use, clamp-before-write behavior, and zone-word writes through the same cell writer path. The rectangular fallback, non-fallback connector, and continuation/boundary-wrapping branches remain exposed as standalone evidence. The real-cycle traversal clips finalized node `+0x1c/+0x20` coordinates through `0x4a2b33`, appends `runtime_zone+0x3f4` footprint vertices, dispatches caller-flagged connector painting through `0x4a2413`, paints continuation/final segments through `0x4a261a`, and reports 267 h3maped boundary cells for seed `1`. It still reports `project_materialized_cell_count: 0` because these boundary cells are executable-buffer evidence, not final project terrain cells.

The `0x4a325d` cell-span fill helper called from `0x4a3ee8..0x4a3eef` is now ported against the real `0x4a2777` boundary buffer for the selected small land template. It consumes a h3maped-style cell buffer initialized with the `0x00ff0000` unassigned zone-word sentinel, fills horizontal spans by writing the current zone id into `cell+0x20`, marks reserved state through `cell+0x2b`, and queues above/below unassigned runs as follow-up spans. The boundary report still keeps the standalone contained sample fill, and it now also reruns the real boundary traversal and starts span fill from the copied `runtime_zone+0x10` x/y/level seed for each runtime zone. For seed `1`, it fills 681 unique cells across 5 zones, blocks 1 seed because it is already on a non-unassigned boundary cell, leaves 348 cells unassigned, and reports zero out-of-bounds spans. Project map materialization remains blocked until the remaining h3maped seed-relocation/zone-fill behavior and `0x4a3710` adjacency/order vectors are ported. `0x4a3710` is still only disassembled into the boundary report: it locates same-level source polygon/list nodes, clips edges through `0x4a2b33`, inserts bidirectional adjacency records into `runtime_zone+0xc4`, and rebuilds order/depth state through `0x49b61b` and `0x4a3554`.

The runtime polygon layout is now partially recovered from `h3maped.exe` and reported as explicit evidence. `0x49b452` constructs runtime zones with initialized vectors at `runtime_zone+0x3e4`, `+0x3f4`, and `+0x404`; `0x4cc788`, `0x4cc5db`, `0x4ccb64`, and `0x4ccdfc` construct, split, and finalize 0x24-byte polygon nodes whose finalized coordinates live at node `+0x1c/+0x20`. The boundary also ports the `0x4a3a03` polygon seed-call schedule: `0x4cc788` initializes the enclosing polygon with `-200..400` bounds, then `0x4a3a79` calls `0x4ccb64` once for each same-level runtime zone using the `runtime_zone+0x10` x/y and runtime-zone pointer. For seed `1`, the selected small land template yields 6 primary split seed calls on level `0`; the seed-specific split model now executes the `0x4cca55` locator, duplicate check, `0x4cc6f2` edge test, primary split insertion, `0x4cc643` relink, `0x4ccb1f` bridge loop, `0x4cc9cc` edge-removal branch, `0x4ccc7a/0x4cc68e` crossing cleanup, and `0x4ccd69/0x4ccdfc` finalized-coordinate fanout. It records 13 bridge pairs, 1 edge-removal branch, 24 crossing tests, 6 crossing collapses, 24 allocated / 23 active node pairs after cleanup, 14 finalized triplets, 42 finalized nodes, and 28 active payload-gated nodes. The synthetic branch at `0x4a3dc8` remains skipped for one-level land. Terrain-cell materialization is still blocked because real span fill is partial and `0x4a3710` adjacency/order vector finalization is not yet ported.

The polygon model now also exposes and feeds the exact `0x4cca55 -> 0x4a2777` source-node cycle inputs for the selected small template. For each of the 6 same-level runtime zones, the report locates the node that `0x4a3e58..0x4a3e8c` would pass to `0x4a2777`, then walks the node `+0x10` cycle and reports payload, previous link, finalized `+0x1c/+0x20` coordinates, active state, and guard status. The first helper consumes all six walks, paints h3maped boundary cells, and the second helper now consumes those cells for partial real span-fill evidence.

The polygon splitter contract now records the exact helper boundary that feeds footprint painting and the later span-fill step. `0x4cca55` locates the containing node through three orientation branches over primary and paired node links; `0x4ccb64` skips exact point duplicates, optionally advances via `0x4cc6f2`, allocates a new primary/paired 0x24-byte node pair through `0x4cc955`, relinks with `0x4cc643`, bridges through `0x4ccb1f`, erases crossed edges through `0x4cc9cc`, tests crossings with `0x4ccc7a`, collapses crossings with `0x4cc68e`, and lets `0x4ccdfc` fan one computed intersection from `0x4ccd69` into three related nodes. The first project-owned allocation model now materializes the four initial `0x4cc788` enclosing polygon node pairs plus the `0x4cc904 -> 0x4ccb1f` constructor bridge pair, producing 10 vector nodes rooted at `initial_pair_0_primary`; the seed-specific split model then inserts all six selected runtime-zone split points, thirteen bridge pairs, and finalized polygon coordinates. The report still avoids terrain-cell materialization until those finalized coordinates are consumed through full executable-derived `0x4a2777` traversal and then `0x4a325d` span fill.

`MapPackageService.generate_random_map` routes normal small land `native_catalog_auto` requests to this boundary and returns `h3maped_small_port_generation_not_ready` instead of producing a fallback map. This is intentional until the partial real `0x4a325d` span fill is completed for all zones, `0x4a3710` adjacency/order finalization is ported, and the later h3maped placement phases can safely materialize project terrain, roads, blockers, guards, towns, mines, and rewards.
