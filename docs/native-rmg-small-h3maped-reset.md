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

After selection, the boundary resolves the selected recovered source template through `content/random_map_template_catalog.json` by `import_provenance.source_template_index == source_catalog_index + 1`. This is intentionally provenance-based rather than translated-name-based because the source catalog is zero-based in the h3maped inspection report while the imported content records are one-based and preceded by original runtime templates. For seed `1`, selected source `h3maped_template_018` resolves to adapted template `translated_rmg_template_019_v1` with 6 active zones, 5 active links, 4 player-capable start zones, 2 treasure zones, and 4 minimum player castles before the `0x4ac552` player-slot assignment step.

`MapPackageService.generate_random_map` routes normal small land `native_catalog_auto` requests to this boundary and returns `h3maped_small_port_generation_not_ready` instead of producing a fallback map. This is intentional until the main phase sequence (`0x4ac552`) is ported.
