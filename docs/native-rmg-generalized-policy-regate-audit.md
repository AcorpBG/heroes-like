# Native RMG Generalized Policy Re-Gate Audit

Status: corrective audit, not implementation completion.
Date: 2026-05-07.
Slice: `native-rmg-generalized-policy-regate-10184`.

## Decision

The current native RMG must not continue as a sample-by-sample exact-count fitting loop.

Exact owner-H3M counts are useful as diagnostics because they expose concrete subsystem failures, but they are not the production algorithm. The production target is a generalized HoMM3-style generator translated into original game systems:

- template selection from recovered template/profile fields;
- zone graph construction from template roles, ownership, player filters, size/water/level support, and link semantics;
- terrain/water/underground shaping from zone policy;
- town, mine, dwelling, reward, guard, road, river, and decoration phases using reusable data-driven rules;
- validation that rejects maps with near-stacked towns, unguarded inter-zone/town routes, broken object footprints, or unreachable required paths;
- owner-H3M corpus comparisons used as regression evidence, not as runtime branch selectors.

## Why Exact Counts Were Used

The uploaded owner H3Ms exposed failures that visual inspection could not make precise. A parsed owner map can say that a native output has the correct road topology but wrong town count, guard count, object category mix, or unguarded-route closure. That makes it useful as a hard diagnostic harness.

The mistake is letting those diagnostics become production policy. Matching one uploaded Small map by hardcoded object/town/guard counts does not prove the native generator can make good Medium, Large, XL, islands, water, or underground maps.

## Current Evidence

The strategic project goal already says Phase 3 RMG must be data-driven and phase-ordered, not count/ratio-only:

- `project.md` Phase 3 requires recovered template, zone, connection, object, terrain, guard, reward, mine, road, river, validation, and serialization semantics.
- `docs/random-map-homm3-parity-gap-audit.md` correctly warned that the earlier generator was not close to HoMM3-style parity and listed a general implementation queue.
- `docs/random-map-final-homm3-parity-regate-audit.md` later claimed the functional gate was met, but the current owner-H3M corpus work has disproved that claim for current native behavior.

Current code evidence in `src/gdextension/src/map_package_service.cpp` shows too many sample-specific runtime branches:

- owner-specific predicates such as `native_rmg_owner_small_random_land_case`, `native_rmg_owner_small_normal_water_2level_case`, `native_rmg_owner_small_islands_2level_case`, `native_rmg_owner_large_land_density_case`, and `native_rmg_owner_xl_land_density_case`;
- road adjustment functions keyed to individual owner samples;
- category shape adjustments keyed to individual owner samples;
- town/guard supplement limits keyed to individual owner samples;
- spacing/reflow behavior keyed to individual owner samples.

These are acceptable only as temporary comparison fixtures or diagnostic bridges. They are not acceptable as the production RMG architecture.

Current corpus evidence from the pushed checkpoint:

- mapped owner-corpus comparisons: `8/9` passing;
- newly mapped Small islands two-level sample has road topology matching but still exposed object/town/guard/category gaps before the abandoned local count-fitting pass;
- 12 parsed uploaded samples remain unmapped;
- `production_ready` remains false in the production parity audit by design.

## Correct Re-Gate Criteria

Before native RMG can be considered production-ready, the following must be true:

1. Runtime generator logic does not select behavior by uploaded owner sample id or seed, except inside explicit comparison fixtures/tests.
2. Template selection is driven by recovered catalog fields: size score, player ranges, water modes, supported level counts, and fixed-owner/faction constraints.
3. Zone graph generation preserves template role semantics across map sizes and levels, including start zones, treasure zones, junctions, neutral zones, and connection payloads.
4. Town placement uses generalized spacing, zone ownership, start/neutral town rules, same-type behavior, and reachability constraints; it rejects stacked-town outputs.
5. Guard placement uses generalized connection/object reward policy, guard value scaling, wide/border guard semantics, and route-closure validation.
6. Decoration/blocker placement uses object footprint/passability/action masks and barrier scoring so obstacles close unguarded routes without deleting required access.
7. Road and river placement is generated from route graph/link semantics and validated for topology, not patched to fixture component sizes.
8. Water/islands/underground generation is handled as first-class zone/terrain policy, not inferred from one sample.
9. Owner-H3M corpus reports aggregate failures by generalized subsystem and template class, not just by individual sample delta.
10. Production audit stays false until all mapped and representative corpus gates pass without sample-specific runtime overrides.

## Implementation Pivot

Stop adding new sample-count branches. Use the uploaded H3Ms to derive reusable rules and to validate them.

Next implementation order:

1. Add a native RMG policy classification layer that derives a policy key from normalized template/profile fields, not owner sample ids.
2. Move owner-H3M comparison-specific exact counts into test fixtures or report metadata only.
3. Replace per-sample town/guard/object limits with size/water/level/template-family formulas derived from catalog fields and recovered spec docs.
4. Replace road component patch functions with a route-graph materializer that produces HoMM3-like trunk/branch/topology behavior from links.
5. Replace post-hoc category shaping with a phase-ordered object placer: mines/resources, towns, rewards, guards, decorations/blockers.
6. Add a corpus regression report that groups failures by subsystem: template selection, zone graph, roads, towns, guards, blockers, rewards, water/underground.
7. Only then map additional uploaded H3Ms; each new sample should validate general policy or expose a missing generalized rule.

## Non-Goals

- No HoMM3 copyrighted asset import.
- No byte-identical `.h3m` cloning.
- No claim that exact object counts are the product goal.
- No more hardcoded sample-count fitting as production runtime logic.

## Immediate Action

The current active RMG work should be re-scoped from `native-rmg-owner-small-islands-underground-corpus-road-checkpoint-10184` to a generalized policy re-gate. The Small islands sample remains useful as one corpus diagnostic, but it should not drive another one-off runtime patch.

## Implemented Report Re-Gate

`tests/native_random_map_homm3_owner_corpus_coverage_report.gd` now emits `generalized_policy_failure_summary` alongside the raw exact comparison gate.

The raw gate still preserves exact owner-H3M deltas. The new summary maps those deltas to reusable subsystems:

- `generation_validation_policy`;
- `object_density_policy`;
- `object_reward_policy`;
- `decoration_blocker_policy`;
- `decoration_blocker_route_closure_policy`;
- `town_policy`;
- `town_spacing_policy`;
- `guard_policy`;
- `guard_route_closure_policy`;
- `road_materialization_policy`.

Validation evidence after rebuilding the native extension from restored source:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 240 tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` emitted schema `native_random_map_homm3_owner_corpus_coverage_report_v6`.
- The exact mapped gate remains `fail`, `8/9` mapped samples passing, with the Small islands two-level sample exposing object, town, guard, and category deltas.
- The generalized failure summary groups that failure under `guard_policy`, `town_policy`, `decoration_blocker_policy`, `object_density_policy`, and `object_reward_policy`.

This is the correct diagnostic posture: the sample remains evidence, while the next implementation target is generalized RMG policy.

## Implemented Runtime Policy Classification

`MapPackageService.generate_random_map` now emits `runtime_policy_classification` in generated output, validation reports, provenance, and map metadata.

The classification records:

- a generalized policy key derived from normalized template/profile/size/water/level/player fields;
- whether current generation used translated recovered templates or legacy/foundation templates;
- active owner-runtime override debt records, grouped by selector kind and subsystem;
- a seed-specific override count, so normal generated seeds can be guarded against owner-corpus seed branches;
- an implementation direction that says owner exact counts must migrate back into reports/fixtures while runtime behavior moves to reusable template/profile/zone/object/guard/road policy.

`tests/native_random_map_auto_template_batch_report.gd` schema `native_random_map_auto_template_batch_report_v2` now requires that classification for representative player-facing generated cases and rejects seed-specific owner override activation for normal generated seeds. The first validation run passed with `seed_specific_runtime_override_case_count: 0`; most owner-compared lanes still report non-seed owner runtime override debt, which is now explicit rather than hidden.

## Implemented Level Selection Correction

The player-facing generated-map setup now exposes the generation depth as an explicit level picker:

- `Surface Only (1 Level)`;
- `Surface + Underground (2 Levels)`.

This replaces the previous ambiguous underground checkbox while preserving the existing internal boolean for generation calls. The islands water-mode option no longer disables or hides underground selection, so players can request one-level or two-level maps consistently across land, normal water, and islands.

Native terrain policy was also corrected so one-level scoped islands maps do not look like an underground-only layer. The scoped islands parity target now keeps terrain on the surface palette and removes the previous underground surface count. Two-level scoped requests bypass the one-level parity count shortcut so the native generator materializes the underground layer through the normal multi-level path.

Validation evidence:

- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 tests/random_map_player_setup_retry_ux_report.tscn` passed and reported visible `level_count` control data with both level options.
- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 tests/native_random_map_terrain_grid_report.tscn` passed with `scoped_islands_counts` containing no `underground` terrain and `scoped_two_level_counts` containing an `underground` layer count.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 tests/native_random_map_town_guard_report.tscn` passed after the same native rebuild.

## Implemented Start-Town Reflow Correction

The Small normal-water two-level owner-corpus path exposed a real regression after the level-selection correction: the owner spacing reflow moved `player_start_town` records away from their generated player start tiles. That produced valid-looking town spacing but broke the stronger production contract that every player starts on an owned town.

The native owner Small normal-water two-level reflow now locks start towns to their `start_anchor` and only reflows the neutral/supplemental towns around those reserved anchors. The focused package test covers generation, validation, package conversion, and confirms the adopted map document has two levels.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 tests/native_random_map_owner_normal_water_underground_package_report.tscn` passed with `map_level_count: 2` and `validation_status: pass`.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 tests/random_map_player_setup_retry_ux_report.tscn` passed and reported visible `level_count` control data with `Surface Only (1 Level)` and `Surface + Underground (2 Levels)`.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 tests/native_random_map_terrain_grid_report.tscn` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 tests/native_random_map_town_guard_report.tscn` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 600 tests/native_random_map_auto_template_batch_report.tscn` passed with all 11 representative cases validating.

## Implemented Two-Level Town Distribution Correction

The same Small normal-water two-level owner sample has four towns on the surface and one town underground. The native placement path was still treating town occupancy and spacing as surface-only, so the strict owner spacing floor either materialized an illegal surface supplement or skipped the fifth town entirely.

Native town records now carry level-aware primary tiles and occupancy keys. Town spacing checks compare towns on the same map level, matching the owner-H3M layout model instead of treating different levels as stacked on one plane. For the owner Small normal-water two-level comparison path, the supplemental neutral town can move to an underground target when every surface candidate violates the strict spacing floor.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused debug inspection for `owner_discovered_s_2playerss_normalwater_2level` produced five towns: four surface towns and one underground town at level `1`, with same-level town spacing passing at the 14-tile owner floor.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 tests/native_random_map_owner_normal_water_underground_package_report.tscn` passed with `map_level_count: 2`, `map_object_count: 427`, and `validation_status: pass`.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 tests/native_random_map_town_guard_report.tscn` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 tests/native_random_map_terrain_grid_report.tscn` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 1200 tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` emitted schema `native_random_map_homm3_owner_corpus_coverage_report_v6`; the mapped gate remains failing overall but improved to `7/9` mapped samples passing. The previous `owner_discovered_s_2playerss_normalwater_2level` failure is gone; the remaining mapped failures are Small islands two-level and XL no-water.

## Fast Audit Loop Correction

Owner review correctly identified that the RMG comparison loop was using Godot for work that is not Godot-specific. H3M parsing, native `.amap` JSON inspection, object/category/level counts, road component topology, and route-closure summaries should be a fast CLI path. Godot should stay on the boundary where it adds real coverage: native GDExtension generation, package conversion/adoption, editor loading, and runtime smoke tests.

`tools/rmg_fast_audit.py` now provides that fast path:

- parses gzip or raw owner `.h3m` files directly;
- reads native `.amap` package JSON directly;
- reports category and per-level object distribution;
- reports road cell totals and component sizes per level;
- reports semantic town-route summaries for object-blocked and guard-blocked paths;
- supports direct owner/native comparison with `--compare`.

Validation evidence:

- `python3 -m py_compile tools/rmg_fast_audit.py` passed.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/S-RandomNumberofplayers-islands-2level.h3m` parsed the owner sample in about `0.067s` and returned the expected counts: decoration `116`, guard `37`, object `56`, reward `102`, town `8`, road cells `147`, and road topology surface `[45, 37, 15, 11, 10]`, underground `[29]`.
- `python3 tools/rmg_fast_audit.py --amap maps/medium-cinder-lantern-bend-34a14dd4.amap` parsed a native package in about `0.086s` and returned the expected owner-medium category counts: decoration `252`, guard `61`, object `65`, reward `110`, town `8`, road cells `184`.

The remaining architectural gap is native generation itself: as long as generation only exists behind the Godot GDExtension API, one Godot invocation is still needed to create fresh packages. The audit/comparison pass after package creation no longer needs Godot.

Focused Small islands two-level validation still uses a narrow Godot smoke because fresh native package generation currently lives behind `MapPackageService`. That smoke now passes after the level-aware object/guard/town pathing correction:

- native object/town/guard/road deltas are all `0`;
- owner category counts match exactly: decoration `116`, guard `37`, object `56`, reward `102`, town `8`;
- road topology matches by level: surface `[45, 37, 15, 11, 10]`, underground `[29]`;
- semantic layout comparison is `semantic_layout_match`, with guarded reachable town-pair count `0`.

This is a focused integration validation, not a reason to return to the slow Godot owner-corpus parser loop.

The same tool now supports batch scans for corpus-level policy evidence:

- `python3 tools/rmg_fast_audit.py --h3m-dir maps/h3m-maps --allow-failures` parsed all `18` uploaded owner `.h3m` files in about `5.236s` with `0` parse failures. The scan covered Small, Medium, Large, and XL maps across one-level and two-level variants.
- `python3 tools/rmg_fast_audit.py --amap-dir maps --allow-failures` parsed all `5` local native `.amap` evidence packages in about `0.204s` with `0` parse failures.
- Owner H3M group densities now provide a fast policy baseline instead of sample-by-sample Godot startup: for example, owner 36x36 one-level evidence is about `229.167` objects / 1000 tiles and `70.216` road cells / 1000 tiles, while owner 144x144 one-level evidence averages about `196.856` objects / 1000 tiles and `34.658` road cells / 1000 tiles.
- The local native AMAP batch is not a matched corpus; it is evidence that parsed package inspection can run quickly and should be fed by future generated package batches.

## Implemented Explicit Level Label Correction

Owner review showed the previous player-facing level selector still read like an ambiguous internal toggle. The level options are now centralized in `ScenarioSelectRules` and rendered by the generated-map menu as literal map-depth choices:

- `Surface Only (1 Level)`;
- `Surface + Underground (2 Levels)`.

The generated setup provenance now reports both the explicit level label and the underground on/off state, while the config path still emits `level_count: 2` only for the two-level option. This is a UX/config contract correction, not a broad underground production-parity claim.

Validation evidence:

- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 tests/random_map_player_setup_retry_ux_report.tscn` passed and reported `level_options: ["Surface Only (1 Level)", "Surface + Underground (2 Levels)"]`.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 tests/native_random_map_owner_normal_water_underground_package_report.tscn` passed with `map_level_count: 2`.
- `GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . --quit-after 360 tests/native_random_map_terrain_grid_report.tscn` passed.
- `python3 tests/validate_repo.py`, `git diff --check`, and `jq empty ops/progress.json` passed.
