# Native RMG Template And Decoration Wiring Report

Date: 2026-05-04

## Scope

This report covers the owner-directed implementation slice `native-rmg-template-decoration-wiring-10184`.

The active generated skirmish launch path remains:

`MainMenu` -> `ScenarioSelectRules` -> `MapPackageService.generate_random_map()`

No active generation path was routed back through `RandomMapGeneratorRules.gd`.

## Implemented

- The Skirmish Generated Map menu now builds template and profile options from `content/random_map_template_catalog.json`.
- All 56 imported catalog templates and all 56 catalog profiles are exposed through the generated-map menu rules.
- Template labels, default profile ids, water modes, underground support, and player-count options are derived from catalog records where available.
- The profile picker is rebuilt for the selected template, so catalog profiles stay template-scoped.
- Native generated output now emits `decorative_obstacle` object placements for supported full-parity and partial-foundation native outputs.
- Native decoration placement records include `body_tiles`, `blocking_body`, visitability, approach policy, and occupancy metadata consistent with non-visitable blocking object placement.
- Decoration density scales from zone count and map area. The focused native report produced 30 decorations for the small supported fixture and 358 decorations for the 144x144 catalog template fixture.
- Decoration placement excludes roads and already occupied object bodies, preserving route reachability and required gameplay object/town/guard counts.

## Validation Evidence

- `tests/random_map_all_template_menu_wiring_report.tscn` passed with `catalog_template_count=56`, `catalog_profile_count=56`, `menu_template_option_count=56`, and `built_config_count=56`.
- `tests/native_random_map_decoration_generation_report.tscn` passed with native decorations greater than zero for both the small supported fixture and the larger catalog fixture, with body/footprint metadata present.
- `tests/native_random_map_full_parity_gate_report.tscn` passed after updating the gate to compare native actual core gameplay object placements while treating native decorations as additional generated output.

## Remaining Gaps

- Exact HoMM3-re decoration art/family parity is not complete. Native output uses original terrain-biased `decorative_obstacle` family ids with runtime-safe footprint/body metadata.
- Exact HoMM3-re byte, placement, art-family, and reward-table parity is not complete. The native generator now uses imported catalog topology broadly enough for playable generated-map package output across the exposed catalog, but it still translates that topology into original AcOrP systems and should not be described as full HoMM3-re parity.

## 2026-05-04 Catalog Playability Correction

Owner correction after this slice: all exposed native generated templates were collapsing through the partial/foundation fallback, so generated 72x72 and 144x144 maps both showed `Roads 0` and roughly 26 objects. That was not a map-size-specific defect.

The follow-up implementation now makes the native generator read `content/random_map_template_catalog.json` for every exposed local and `translated_rmg_template_*` template before falling back to synthetic foundation records. Native generated packages now preserve catalog zone counts, catalog link counts, route-derived road cells, scaled object density, scaled `decorative_obstacle` placement, neutral towns, mines, dwellings, resources, rewards, and guards through package convert/save/load surfaces.

Validation is covered by `tests/native_random_map_catalog_quality_report.tscn`, which samples a local small template, medium translated template, large translated template, and XL translated template and asserts generated package/editor-visible roads and object surfaces after native convert/save/load. This broad playability correction does not replace the existing tiny full-parity fixtures and does not claim exact HoMM3-re parity.

## 2026-05-04 HoMM3 Fill Coverage Correction

Owner-attached evidence showed the previous 72x72 native package had 315 objects
but only 144 unique decoration/blocker body tiles: 2.78% map coverage. Object
count alone was not a meaningful fill metric.

The native C++ generator now samples terrain-biased original large-footprint
decoration/blocker families from `content/map_objects.json` proportions, fits
the whole body mask against zone ownership, existing object bodies, and
materialized road cells, and records `fill_coverage_summary` metrics on native
output. Later town/guard placement now reserves against full object body
occupancy, not just primary tiles.

The focused report
`tests/native_random_map_homm3_fill_coverage_report.tscn` compares HoMM3-re
`rand_trn` obstacle catalog scale, our authored decoration/blocker catalog, the
attached barren package, sampled small/medium/large/XL native output, and the
attached medium config regenerated through the active native path. The attached
package fails the new 20% medium decoration/blocker body coverage floor at
2.78%; the regenerated same config passes at 24.96% with 95 decorations averaging
13.621 body tiles. Sampled native coverage now ranges from 21.55% to 33.35%
decoration/blocker body coverage across medium/large/XL, with package
convert/save/load road and object surfaces intact.

Remaining gaps are explicit: broad fill density is improved, but exact
HoMM3-re obstacle identity, DEF art/template parity, byte/placement parity, and
compact binary H3M-format parity are not implemented by this correction.
