# Native RMG GDScript Port Audit

Date: 2026-05-04

Active runtime path remains native package generation:
`MainMenu.gd::_on_start_generated_skirmish_pressed()` -> `ScenarioSelectRules.build_random_map_skirmish_setup_with_retry()` -> native `MapPackageService.generate_random_map()`.
`scripts/core/RandomMapGeneratorRules.gd` is reference/history for this audit, not the active implementation target.

Supported full-parity scope is the tracked `homm3_small` comparison fixture set:
`border_gate_compact_v1` three-player land, `translated_rmg_template_001_v1` four-player islands, and `translated_rmg_template_001_v1` four-player land with underground. Adjacent or larger configs can still report `partial_foundation`; runtime-relevant behavior below is ported only where it applies to native supported or foundation generation surfaces.

| Commit | Classification | Native evidence | Notes |
| --- | --- | --- | --- |
| `fa45218` Improve random map parity richness | `ported_to_native` | `MapPackageService.generate_random_map()` now emits richer native object rewards, artifact candidates, support resource policy records, town spacing, zone richness metadata, and object guard summaries. Covered by `tests/native_random_map_gdscript_port_audit_report.tscn`. | Broad runtime richness behavior is ported for native supported/foundation scope. |
| `3b7fc04` Complete bounded RMG parity inspection | `ported_to_native` | Decorative obstacles now carry multi-tile `body_tiles`, `blocking_body`, occupancy keys, and `decoration_route_shaping_summary`. | Visual inspection/report-only parts are diagnostic-only; runtime blocker footprint/body-mask behavior is native. |
| `e20d96c` Improve RMG guarded artifact pairing | `ported_to_native` | Native reward references include artifact ids; `sorted_object_guard_candidates()`, `object_guard_point_for_target()`, and `materialized_object_guard_summary` prioritize artifact rewards and record adjacent guard linkage. | Active launch remains native; no GDScript generator path restored. |
| `67879f8` Improve RMG connection road controls | `ported_to_native` | `generate_road_network()` emits `road_class`, `road_type_id`, `connection_control`, route `layout_contract_roles`, and top-level `connection_road_controls`. | Supported border-gate fixture records a `special_guard_gate_road`. |
| `202a1fa` Improve RMG town zone spacing | `ported_to_native` | Native town placement uses `find_spaced_object_point()`, `town_spacing_policy_payload()`, and `town_spacing_summary()` with per-town `town_spacing_policy`. | Audit smoke asserts `town_spacing.ok` and scoped pass statuses. |
| `4927cd9` Shape RMG blocker chokes | `ported_to_native` | `decoration_route_shaping_summary()` records route shoulder/choke coverage, multi-tile decoration count, and blocking body tile total. | Choke metadata is staged native evidence; it does not mutate authored terrain. |
| `3fb8168` Expand RMG guarded site coverage | `ported_to_native` | Native guard placement sorts guardable objects by artifact/mine/dwelling/cache priority and records `candidate_counts_by_kind` plus `materialized_counts_by_kind`. | Runtime guard association coverage is native. |
| `93e2f2b` Improve RMG river crossing quality | `ported_to_native` | Native non-supported land foundation generation uses `land_river_cells_with_crossing()` and `river_quality_record()` with road crossing counts and continuity status. | Supported full-parity fixtures intentionally preserve the zero-river structural targets where applicable. |
| `2ba8fa5` Improve RMG zone richness bands | `ported_to_native` | `zone_richness_floor_metadata()` is attached to native zone `catalog_metadata` with `richness_floor`, mine requirements, treasure bands, and monster policy. | The metadata is native evidence for later materialization and validation. |
| `be744e8` Add RMG visual inspection evidence | `obsolete_due_to_native_design` | Native route/object records use staged 1x1 anchors, explicit `visit_tile`, `approach_tiles`, and deterministic path/route metadata instead of the old visual inspection harness. | The changed GDScript inspection evidence is not active launch behavior. |
| `41233b1` Fix RMG visual diagnostic runtime evidence | `obsolete_due_to_native_design` | Native roads are generated from deterministic route cells and `straight_route_cells()`-style path construction; the old GDScript visual diagnostic BFS repair path is not part of active native generation. | No active native runtime behavior remains to port from this diagnostic path. |
| `7689c3e` Improve RMG start-front fairness | `ported_to_native` | Native route graph edges include `fairness_start_front_zones`, `fairness_front_policy`, and `layout_contract_roles`. | Audit smoke asserts those fields on supported native route edges. |
| `ee6015c` Improve RMG route resource fairness | `ported_to_native` | Translated-template zone seeds use route-link-aware seed layout helpers and native route/resource metadata avoids neutral-town endpoint assumptions. | Applies to translated supported profiles and foundation route layout. |
| `43ab952` Improve RMG secondary road coverage | `obsolete_due_to_native_design` | Native road generation happens before object materialization and emits `secondary_road_summary` as a reserved structural surface. Supported full-parity scope is 36x36, below the old GDScript large-map secondary-road threshold. | No missing supported runtime behavior for active native launch. Larger-map secondary service roads remain out of current full-parity scope. |
| `a749da2` Improve RMG support resource previews | `ported_to_native` | Native resource sites expose `placement_policy = strict_start_zone_support_resource_path_scored` and `support_route_path_length`. | Audit smoke asserts path-scored support resources in native generated object placements. |
| `f6c5bd5` Classify RMG warning-level fairness asymmetry | `native_irrelevant_diagnostic_only` | Native support resources already expose explicit support policy/resource metadata; old warning classification changed report interpretation, not active map materialization. | No runtime generation behavior to port. |

Validation evidence added for this audit:

- `tests/native_random_map_gdscript_port_audit_report.tscn` proves the native surfaces above without routing launch generation back through `RandomMapGeneratorRules.gd`.
- The tracked comparison and full-parity gate scenes remain the structural parity authority for the supported `homm3_small` fixture set.
