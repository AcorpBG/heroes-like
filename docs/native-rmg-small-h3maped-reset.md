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

The clean module now ports the record-construction part of runtime-zone build `0x4a218c` for inspection only. It rebuilds the runtime-zone vector report, derives the scale divisor from h3maped water mode, computes the initial scale reference as `min(min_source_base_size * width, min_source_base_size * height) / divisor`, initializes one runtime-zone record per active source zone using the `0x49b452` field semantics, applies source owner mapping through `generator+0xee4`, interleaves town/faction choices through `0x49b3c1`, previews faction-matched terrain without consuming terrain RNG, and resolves source link endpoints into runtime-zone link seeds. For the seed `1` boundary case this reports 6 runtime-zone records, 5 link seeds, minimum source base size `11`, land divisor `5`, and initial scale reference `79`.

The clean module also ports the `0x4a1f3b` early endpoint-control schedule for inspection only. During runtime-zone construction, h3maped calls `0x4a1f3b` once while each zone is being allocated, when only earlier runtime zones are present in the vector, then runs two full stabilization passes over all runtime zones. The report lists available endpoint-linked runtime zones for each scheduled call and the fallback candidate count if no coordinate candidate survives. For the seed `1` boundary case this reports 18 scheduled calls, 25 endpoint attempts, and 3 possible fallback candidates across creation calls.

The clean module now replays the one-level `0x4a218c` runtime/coordinate RNG order for inspection only. The report exposes `0x49b452`/`0x49b3c1` town RNG, `0x4a17f5` 32-angle candidates from tables `0x58dc28/0x58dd28`, `0x4a1701` spacing validation, `0x4a1ad8` single-level candidate pruning, and `0x4a19ed` bounding-box rescale. For the seed `1` boundary case this produces 4 town RNG calls, 18 coordinate RNG calls, 22 interleaved replay events, 18 candidate-selection steps, and a rescale span of `84` onto the 36-tile small map.

The clean module now ports the `0x4a3a03` per-level footprint phase boundary for inspection only. For the seed `1` boundary case it reports one level, 6 same-level runtime zones, 6 `0x4ccb64` polygon split calls, no synthetic fallback zone for one-level land, `0x4cc788` initial bounds `-200..400`, and the helper sequence `0x4a2777 -> 0x4a325d -> 0x4a3710` scheduled but not executed. Actual footprint cells are still not painted because `0x4a2777`, `0x4a325d`, and `0x4a3710` are still pending; this reset must not invent replacement footprint cells.

The boundary exposes a phase ledger and keeps every unported materialization phase pending:

1. `template_selection` - `0x49f0cd`, `0x4ac597..0x4ac5a4`, `0x4e7276` - ported for inspection only.
2. `player_slot_assignment` - `0x4ac62a..0x4ac6ec` - ported for inspection only.
3. `runtime_zone_build` - `0x4a218c`, `0x4a1f3b`, `0x4a17f5`, `0x4a1701`, `0x4a1ad8`, `0x4a19ed`, `0x49b452`, `0x49b3c1` - runtime records, endpoint control flow, and interleaved coordinate-candidate replay ported for inspection only.
4. `zone_footprint_placement` - `0x4a3a03`, `0x4cc788`, `0x4ccb64`, `0x4a2777`, `0x4a325d`, `0x4a3710` - level collection and polygon seed ported for inspection only; helpers pending clean port.
5. `terrain_fill_repaint` - `0x4a3f27`, `0x4bcff5`, `0x4bd099` - pending clean port.
6. `object_category_placement` - `0x4a8d2c`, `0x4a8db2`, `0x4a8c15` - pending clean port.
7. `guard_reward_monster_placement` - `0x4a9d6a`, `0x4aab7e` - pending clean port.
8. `final_cell_object_passes` - `0x49eb8d`, `0x4ab52a`, `0x4ac4ae` - pending clean port.

`MapPackageService.generate_random_map` now returns `h3maped_small_clean_restart_generation_not_ready` for normal small land `native_catalog_auto` requests. This is intentional: the replacement path must not emit fallback maps until executable-derived phase ports can materialize terrain, owned starting towns, roads, blockers, guards, mines, rewards, and validation from real cells and objects.
