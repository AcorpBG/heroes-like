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
- Broader generated-map quality for large and unsupported templates remains partial-foundation unless separately promoted by future parity work. This report does not claim full HoMM3-re or whole-catalog gameplay parity.
