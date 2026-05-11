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

The reset now has a new isolated native module:

- Header: `src/gdextension/include/h3maped_small_rmg.hpp`
- Implementation: `src/gdextension/src/h3maped_small_rmg.cpp`
- Public boundary: `MapPackageService.inspect_h3maped_small_rmg_port(config)`

This module is the only active production-facing replacement path. The previous large `map_package_service.cpp` native catalog-auto implementation remains in the repository as archived debug/evidence code only. Normal `native_catalog_auto` requests cannot fall through to it unless a caller explicitly passes `allow_archived_legacy_native_rmg` for local evidence/debug.

The clean restart boundary currently supports only 36x36 one-level land inspection. It verifies the local h3maped reset anchor by checking `/root/Downloads/h3maped.exe` file size and MZ header against the recorded reset SHA-256, then computes template acceptance from h3maped-derived size-score/player-capacity data. Numeric seeds use the recovered executable RNG step from `0x4e7269/0x4e7276`; non-numeric seeds are blocked rather than hashed.

For seed `1`, 1 human, and 3 total players, the boundary reports:

- status `h3maped_small_clean_restart_template_selection_ready`,
- 13 accepted small-land templates,
- RNG first value `41`,
- selected vector index `2`,
- selected source template `h3maped_template_018`,
- adapted template `translated_rmg_template_019_v1`,
- 6 active zones, 5 links, 4 player-start zones, 2 treasure zones, and 4 minimum player castles.

The clean module now also ports the inspection-only player-slot assignment step from `0x4ac62a..0x4ac6ec`. It builds human/player capability bitmaps from source zone `+0x04/+0x1c`, reads the selected-color bitmap as `generator+0xed8`, fills assignment slots as `generator+0xee0`, and reports mapped owner colors as `generator+0xee4`. With the default constructor-zeroed selected-color bitmap, seed `1` assigns source owners `[0, 1, 2]` to actual colors `[0, 1, 2]`; with color `2` preselected, the reported color order becomes `[2, 0, 1, 3, 4, 5, 6, 7]` and source owners map to `[2, 0, 1]`.

The clean module now ports the record-construction part of runtime-zone build `0x4a218c` for inspection only. It rebuilds the runtime-zone vector report, derives the scale divisor from h3maped water mode, computes the initial scale reference as `min(min_source_base_size * width, min_source_base_size * height) / divisor`, initializes one runtime-zone record per active source zone using the `0x49b452` field semantics, applies source owner mapping through `generator+0xee4`, interleaves town/faction choices through `0x49b3c1`, resolves source link endpoints into runtime-zone link seeds, and applies `0x49b53d` runtime terrain selection before footprint placement. For the seed `1` boundary case this reports 6 runtime-zone records, 5 link seeds, minimum source base size `11`, land divisor `5`, and initial scale reference `79`.

The clean module also ports the `0x4a1f3b` early endpoint-control schedule for inspection only. During runtime-zone construction, h3maped calls `0x4a1f3b` once while each zone is being allocated, when only earlier runtime zones are present in the vector, then runs two full stabilization passes over all runtime zones. The report lists available endpoint-linked runtime zones for each scheduled call and the fallback candidate count if no coordinate candidate survives. For the seed `1` boundary case this reports 18 scheduled calls, 25 endpoint attempts, and 3 possible fallback candidates across creation calls.

The clean module now replays the one-level `0x4a218c` runtime/coordinate RNG order for inspection only. The report exposes `0x49b452`/`0x49b3c1` town RNG, `0x4a17f5` 32-angle candidates from tables `0x58dc28/0x58dd28`, `0x4a1701` spacing validation, `0x4a1ad8` single-level candidate pruning, and `0x4a19ed` bounding-box rescale. For the seed `1` boundary case this produces 4 town RNG calls, 18 coordinate RNG calls, 22 interleaved replay events, 18 candidate-selection steps, and a rescale span of `84` onto the 36-tile small map.

The clean module now ports `0x49b53d` runtime terrain selection before the `0x4a3a03` footprint phase. For the seed `1` boundary case it consumes two terrain RNG calls for the treasure zones, uses the recovered town-choice terrain table at `0x540908`, and selects dirt/dirt/snow/grass/dirt/rough across the 6 runtime zones. Because those RNG calls happen before footprint placement in the executable order, the same seed now reports `0x4a2777` real source-node boundary traversal with 221 unique boundary cells, `0x4a325d` real boundary span fill with 890 unique filled cells and 185 remaining unassigned cells.

The clean module also ports the `0x4a3f27` terrain fill/repaint schedule for inspection over the real `0x4a325d` zone-word buffer. It records the full-map terrain-8 water fill, scans owner bytes and repaint-member bits, and schedules 1111 per-cell `0x4bd099` repaint calls for seed `1`, producing terrain counts dirt 492, grass 165, snow 222, rough 232, and water 185. It now also normalizes one-level terrain art/index/flip fields through the ported TerrainPlacement relation-ring/class/row/flip model, exposing 1296-cell `terrain_code_u16`, `terrain_art_index_u8`, `terrain_flip_h`, `terrain_flip_v`, and `terrain_shape_class_u8` arrays with 413 transition cells and 20 visual fallback cells for the seed `1` boundary case.

The clean module now ports the field-consumption boundary for the `0x4a8d2c` direct settlement minimum pass, the owner-byte candidate-scan boundary of direct helper `0x4a93a2`, the recovered `0x49a1d8` validity precheck used by `0x49aa93`, the current Town-body `0x49a09c` gate order over the generated-cell grid, the recovered `0x4a93a2` best-distance random tie consumer, and the `0x4a93a2` post-selection object-record writeout ledger. For the seed `1` boundary case the selected template reports four required player castles, zero required player towns, zero neutral towns/castles, 24 density fields, no positive settlement density weights, three assigned-owner direct candidate scans with 451 total owner/repaint candidates, 451 candidates passing the terrain validity precheck, 97 Town-footprint passes, three 0x28-byte town object records with generator+0xf44 serials 0..2, one recovered owner `-1` early-fail call for the unassigned player slot, and one `0x4e7276` random tie call. Project package adoption of the generator virtual placement hook, generalized object/template terrain-class handling beyond the current Town body grid, `0x4a901a` weighted placement, ownership writeout, and later cleanup/link processing remain pending.

The clean module now also rebinds the selected template's mine and treasure fields from the recovered h3maped source catalog because the adapted project catalog currently drops those fields as null. Phase `0x4a9d6a` mine minimum/density source fields and phase `0x4aab7e` treasure-band triplets are ported as source ledgers for inspection: seed `1` reports 6 bound source rows, 42 mine minimum fields, 42 mine density fields, 18 positive mine minimum fields, 18 positive mine density fields, total minimum mine count 18, total mine density weight 18, 18 eligible treasure bands, and total treasure density weight 96. The `0x4a9911` mine helper template-bucket ledger is now bound to recovered `objects.txt` rows for inspection: Mine type `53` has 46 template rows, Resource type `79` has 7 adjacent-resource rows, the 18 minimum mine helper calls see 116 subtype-matched template candidates, apply the recovered terrain-bitset filter through reversed `objects.txt` terrain masks, allocate `0x1c` records through `0x49ba89`, specialize vtable `0x540ab0`, compute guard bases 1500/3500/7000 before `0x4a960a -> 0x4a65a5`, and record the adjacent resource handoff through `0x4a9e40`. The recovered `0x4a9641` placement constraint boundary now executes for inspection against the generated-cell grid and selected mine wrappers: it scans the object footprint rectangle, requires the generated-cell `+0x20` owner byte to match the runtime/source zone, applies the current `0x49aa93` body/collision/terrain/owner gate, optionally applies the wood/ore special distance ring from the zone anchor, ranks tied candidates by the `+0x20` low-word score and nearby valid-cell count capped at 5, chooses through `0x4e7276`, and marks selected mine body cells in the inspection occupancy grid. Production package adoption of these selected records, exact generator cell bit-26 lifecycle, `0x4aa354` reward placement, and guarding remain pending.

The direct-placement blocker has been narrowed from an unknown condition to the recovered `0x49aa93` gate sequence. The executable first calls `0x49a6f9` for rectangle/footprint rejection, reads object metadata flags from `0x57c648 + type*0x10`, calls `0x49a09c` for footprint passability/owner/occupied/water scanning, then applies the already ported `0x49a1d8` anchor validity precheck, owner-byte match, bit-22 object collision plus metadata-secondary checks, and final water/non-water terrain matching. The boundary now binds the `0x57c648` runtime object metadata path to recovered `objects.txt`/`objnames.txt` source data for inspection: 232 object type names, 1326 object rows, Town type `98` with 9 template rows, and Random Town type `77` with 1 template row. It also ports the Town text-mask body scan used by `0x49a6f9` for inspection with 13 passability/body cells and 1 action cell. The current Town-body `0x49a09c` gate order reports 97 passes, 135 bounds rejects, 1 bit-22 reject, 22 bit-25/materialized-cell rejects, 196 owner rejects, and zero terrain-9/water-class rejects across the 3 assigned-owner scans. The same seed `1` run stamps 3 direct town records into the inspection object layer and marks 39 bit-22-style occupied body cells. The `0x4a93a2` writeout ledger records each 0x28-byte allocation, constructor `0x49ba89`, town vtable `0x540a9c`, generator+0xf44 serial, record+0x1c/+0x20/+0x24 field writes, generator virtual placement hook site, source-zone coordinate writeback site, and anchor bit27/bit26 update site. The third player-castle call now selects from 3 tied best-distance candidates through the recovered `0x4a93a2` random tie path: RNG value `12382`, selected index `1`, selected coordinate `(18,5)`. The remaining blockers are project package adoption of the virtual placement hook, generalized object/template terrain-class handling beyond the current Town body grid, weighted placement, and later guard/reward/object passes.

The clean module now ports the recovered late raw-link payload semantics from `0x4a79a3` into the generated package ledger. It does not invent road geometry. For each selected template link it records endpoints, runtime-zone pair, raw `Value`, `Wide` normal-guard suppression, and `Border Guard` special-object intent. The seed `1` boundary case carries 5 connection records. The exact `0x4a61bc`/`0x4a696b`/`0x4a6cf2`/`0x4a7605` connection geometry, `0x4a65a5 -> 0x4a5e03` normal guard object placement, `0x4a5e73 -> 0x4a5a23` type-9 Border Guard materialization, and `0x4ab37f` road adapter path remain pending clean ports.

The road boundary is now explicit in the partial package instead of being collapsed to a generic pending flag. Disassembly of `/root/Downloads/h3maped.exe` shows `0x4ab52a` iterating generator coordinate records from `+0x14b4..+0x14b8` as 12-byte entries, selecting road type through `0x4e7276 % 3 + 1`, checking candidate cell low words against `0x7530`, then preparing path state through `0x4aae2f` and `0x4aae7b` before calling `0x4ab37f`. The vector object source is now narrowed: constructor/destructor code initializes and releases `generator+0x14b0`, final road code reads begin/end from `+0x14b4/+0x14b8`, direct town placement pushes records at `0x4a959b`, and generic object placement pushes records at `0x4a6bb4`, both through helper `0x4ae1fd`. The current package ledger materializes 15 partial 12-byte coordinate-vector records from the adopted 3 town records and 12 mine records, including vector index, byte offset, append source, source placement id, coordinate triplet, and occupancy key, but does not claim exact h3maped metadata-offset adjustment or the complete executable vector because rewards, guards, monsters, decoration/blockers, and final object passes are not yet ported. The clean reset path now ports the bounded `0x4aae2f` reset ledger over the generated cell dimensions: it resets `width * height * levels` cells, writes `-1` to the coordinate chain at `cell+0x10/+0x14/+0x18`, and forces the `cell+0x1c` low word to `0x7d00` while preserving the upper word. The `0x4aae7b` boundary is now recovered as a path-state seed/propagation ledger: it takes one 12-byte coordinate record, seeds local queue vectors, resets the seed cell low word to zero, expands through neighbor offsets at `0x5a2658`, requires materialized cells through `cell+0x28` bit 25, handles object-present bit 22 and metadata table `0x57c648`, recognizes special object types `0x67`, `0x2b..0x2c`, and `0x2d` through `generator+0x14c0/+0x14d0` vectors, and writes lower path costs plus predecessor coordinates back to `cell+0x1c` and `cell+0x10/+0x14/+0x18`. The `0x4ab37f` bridge is now recovered as adapter setup only: it takes the same coordinate triplet plus the selected road type, builds a generated-cell terrain adapter at `ebp-0x50` with vtable `0x540a14`, wraps it in a road adapter at `ebp-0x1c` with vtable `0x540a34`, calls the road toolkit entry `0x4b4243`, cleans through `0x4b42c0` and `0x49a030`, then follows predecessor coordinates from `cell+0x10/+0x14/+0x18` while the path-cost low word at `cell+0x1c` remains nonzero. The clean reset path therefore reports `h3maped_0x4ab52a_0x4ab37f_road_adapter_boundary_recovered_toolkit_pending`, emits zero road segments/cells, and records `no_synthetic_road_geometry: true` until the complete `+0x14b0` coordinate vector and `0x4b4243` toolkit body are ported.

The boundary exposes a phase ledger and keeps every unported materialization phase pending:

1. `template_selection` - `0x49f0cd`, `0x4ac597..0x4ac5a4`, `0x4e7276` - ported for inspection only.
2. `player_slot_assignment` - `0x4ac62a..0x4ac6ec` - ported for inspection only.
3. `runtime_zone_build` - `0x4a218c`, `0x4a1f3b`, `0x4a17f5`, `0x4a1701`, `0x4a1ad8`, `0x4a19ed`, `0x49b452`, `0x49b3c1`, `0x49b53d` - runtime records, endpoint control flow, interleaved coordinate-candidate replay, and runtime terrain selection ported for inspection only.
4. `zone_footprint_placement` - `0x4a3a03`, `0x4cc788`, `0x4cca55`, `0x4ccb64`, `0x4ccdfc`, `0x4a2777`, `0x4a325d`, `0x4a3710` - level collection, polygon source-node walks, `0x4a2777` boundary traversal, `0x4a325d` span fill, and small-land `0x4a3710` no-appended-zone finalizer ported for inspection only.
5. `terrain_fill_repaint` - `0x4a3f27`, `0x4bcff5`, `0x4bd099` - terrain fill/repaint schedule and one-level TerrainPlacement art/index/flip normalization ported for inspection only.
6. `object_category_placement` - `0x4a8d2c`, `0x4a93a2`, `0x49a1d8`, `0x49aa93`, `0x49a6f9`, `0x49a09c`, `0x4a8db2`, `0x4a8c15` - town/castle field consumption, direct owner-byte candidate scanning, direct validity precheck, recovered best-distance random tie selection, recovered full eligibility gate ledger, `objects.txt`/`objnames.txt` Town/Random Town metadata binding, Town text-mask body scan, current Town-body `0x49a09c` gate order, direct town record/body-cell marking, and the `0x4a93a2` post-selection object-record writeout ledger ported for inspection only; project package adoption, generalized object/template terrain-class handling, weighted placement, and cleanup still pending.
7. `guard_reward_monster_placement` - `0x4a9d6a`, `0x4a9911`, `0x4a9c7c`, `0x4a9641`, `0x4aab7e` - mine/reward source field ledgers, `0x4a9911` mine template/record/guard handoff ledger, recovered terrain-mask filtering, and `0x4a9641` mine candidate scan/selection/body-cell marking ported for inspection; production package adoption, `0x4aa354`, reward placement, and guarding still pending.
8. `final_cell_object_passes` - `0x49eb8d`, `0x4ab52a`, `0x4ac4ae` - pending clean port.

`MapPackageService.generate_random_map` now adopts the clean small-map port into a partial generated package for normal small land `native_catalog_auto` requests. It materializes the ported terrain grid, owned town records, and selected mine records into a structurally valid `MapDocument` with status `h3maped_small_clean_restart_phase_package_adoption_partial`, but it does not claim runtime authority or full parity. The package keeps roads, physical connection blockers, rewards through `0x4aa354`, guards/monsters, and final h3maped writeout phases explicitly pending with `native_runtime_authoritative: false`, `full_parity_claim: false`, and `no_authored_writeback: true`.

For the seed `1` boundary case, the package adoption path currently reports:

- `generated_validation_status: pass`,
- `generated_town_count: 3`,
- `generated_mine_count: 12`,
- `generated_connection_count: 5`,
- `connection_generation_status: h3maped_0x4a79a3_link_payload_semantics_ported_geometry_roads_guards_pending`,
- `terrain_generation_status: h3maped_0x4a3f27_terrain_grid_materialized_from_clean_port`,
- `town_generation_status: h3maped_0x4a93a2_town_records_adopted`,
- `object_generation_status: h3maped_0x4a9911_0x4a9641_mines_materialized_rewards_guards_pending`,
- `road_generation_status: h3maped_0x4ab52a_0x4ab37f_road_adapter_boundary_recovered_toolkit_pending`,
- `guard_generation_status: h3maped_0x4a79a3_link_guard_payload_ported_guard_object_materialization_pending`.
