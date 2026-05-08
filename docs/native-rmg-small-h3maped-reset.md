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

The `0x4a2777` footprint helper is now disassembled into the boundary report but is not materialized. The report records its executable-backed dependencies: endpoint clipping through `0x4a2b33`, cell-buffer line writes through `0x4a261a`, flagged jittered/interpolated line writes through `0x4a2413`, footprint vertex appends to `runtime_zone+0x3f4`, 48-byte map-cell stride, zone-id writes through `cell+0x20 & 0x00ff0000`, and reserved-cell marking through `cell+0x2b |= 0x10`. It also reports the exact missing runtime memory layout that must be recovered before painting cells: phase item node fields at `+0x08/+0x10/+0x1c/+0x20`, the source rectangle copied from `runtime_zone+0x10`, the source-zone adjacency payload used through `source_zone+0x0c/+0x10`, and the mapping from h3maped cell zone ids to this project’s terrain/object buffers. The helper therefore reports `materialized_cell_count: 0`; this is intentional until the runtime layout is ported without invented connector geometry.

The remaining footprint helpers are also disassembled into the boundary report without materialization. `0x4a325d` is the cell-span fill helper called from `0x4a3ee8..0x4a3eef`; it locates source polygons with `0x4cca55`, uses `0x00ff0000` as the unassigned zone-word sentinel, fills horizontal spans by writing the current zone id into `cell+0x20`, marks reserved state through `cell+0x2b`, and queues above/below unassigned runs as follow-up spans. `0x4a3710` is the adjacency finalizer called from `0x4a3efc..0x4a3f05`; it locates same-level source polygon/list nodes, clips edges through `0x4a2b33`, inserts bidirectional adjacency records into `runtime_zone+0xc4`, and rebuilds order/depth state through `0x49b61b` and `0x4a3554`. Both helpers still report zero materialized project cells/adjacencies until the exact h3maped span records, adjacency records, ordering vectors, and source polygon/list schemas are ported.

`MapPackageService.generate_random_map` routes normal small land `native_catalog_auto` requests to this boundary and returns `h3maped_small_port_generation_not_ready` instead of producing a fallback map. This is intentional until the remaining post-level-collection phase sequence, starting with the `0x4a2777/0x4a325d/0x4a3710` footprint helper trio, is ported.
