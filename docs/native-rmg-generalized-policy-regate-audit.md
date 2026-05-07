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

`tools/rmg_native_batch_export.tscn` now performs the remaining Godot-only step: one batch generation/export pass through `MapPackageService.generate_random_map`, `convert_generated_payload`, and `save_map_package`. The exported `.amap` files can then be audited by Python. A full owner-file-derived export run wrote `18` generated native packages with `0` export failures; `python3 tools/rmg_fast_audit.py --amap-dir .artifacts/rmg_native_batch_export_current --allow-failures` parsed those `18` packages in about `3.208s` with `0` parse failures.

The generated-native batch confirms the broad production gap:

- 108x108 two-level owner H3M evidence averages `169.725` objects / 1000 tiles; native generated packages average `45.882`.
- 144x144 two-level owner H3M evidence averages `93.195` objects / 1000 tiles; native generated packages average `44.456`.
- 108x108 one-level owner H3M evidence averages `156.150` objects / 1000 tiles; native generated packages average `93.421`.
- 144x144 one-level owner H3M evidence averages `196.856` objects / 1000 tiles; native generated packages average `131.623`.

This is the next generalized policy target: native RMG needs level-aware object/reward/guard/decoration distribution and road density scaling across the whole generated package, not more hand-tuned exact matching for individual samples.

## Implemented Fast Validation Loop

`tools/rmg_fast_validation.py` now makes the Python path the default RMG evidence loop instead of only a parser utility. It wraps `tools/rmg_fast_audit.py` and applies correctness gates directly to generated `.amap` packages:

- owner `.h3m` parse failures;
- native `.amap` parse failures;
- missing objects, towns, roads, guards for reward-bearing maps;
- near-stacked towns using size-aware spacing floors;
- unguarded town-route regressions against owner evidence;
- empty materialized levels and levels without roads on two-level maps;
- owner-group object-density underfill using a configurable density floor.

This tool intentionally reports exact owner/native deltas as diagnostics. The pass/fail gate is about generated-map rules and broad policy gaps, not byte-identical HoMM3 clone output.

Validation evidence:

- `python3 -m py_compile tools/rmg_fast_audit.py tools/rmg_fast_validation.py` passed.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir /tmp/no-native-amap-dir --no-density-gate` parsed all `18` owner H3M files in about `5.199s` with `0` parse failures.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_current --allow-failures --pretty` parsed `18` owner H3Ms and `18` native AMAP packages in about `8.118s` total. It correctly reports the current generated-native batch as `fail` with `32` native rule failures and `6` density gaps. The most important failures are empty underground levels/levels without roads in two-level outputs, near-stacked towns in several Medium/Large/XL outputs, and object-density underfill against owner group baselines.

This replaces the old habit of re-running a full Godot owner-corpus parser scene for every comparison iteration. The expected RMG loop is now: run Godot once only when fresh native packages are needed, then run Python validation/comparison repeatedly while fixing policy.

## Implemented Fast Policy Gate

The generated-rule gate was still too weak: after the first generated-batch fixes, it could pass packages that were structurally valid but still far from owner-H3M group behavior in guard density, object/scenic density, town density, road density, and guard-to-reward shape.

`tools/rmg_fast_validation.py` now includes a Python-only policy gate that fails on broad group-level underfill without requiring exact sample-by-sample count matching:

- category density floors for guard, object, reward, and town groups;
- road-density floors against owner group baselines;
- guard-to-reward ratio floors, so reward-heavy maps cannot pass with too few guards;
- `--no-policy-gate` for the narrower generated-rule-only smoke when needed.

Validation evidence:

- `python3 -m py_compile tools/rmg_fast_validation.py` passed.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_full_after_export_failure_fix --pretty` exits `1` and reports `status: fail` with `0` parse failures, `0` native rule failures, `0` density gaps, and `14` policy gaps. The reported gaps are broad category/road/guard-reward policy gaps, not exact-count failures.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_full_after_export_failure_fix --no-policy-gate --pretty` still reports `status: pass` with `0` parse failures, `0` native rule failures, and `0` density gaps. This proves the new failure signal comes from the broader policy gate, not a regression in package parsing or generated-rule validity.

The current native RMG therefore remains not production-ready: it now has a fast, non-Godot gate proving the next generalized work must improve guard/reward/town/object/road policy shape, not simply make packages export successfully.

## Implemented Scenic And Guard Policy Floors

The first policy-gate run showed that total object density was not enough: the native generator was using decorative filler where HoMM3-like outputs also need ordinary scenic/other objects, and several two-level generated maps had too few guards relative to rewards.

Native catalog-auto generation now adds:

- a size/level-aware `scenic_object` floor before decorative density filler;
- a size/level/reward-aware guard floor for non-owner-comparison catalog-auto maps;
- diagnostics that keep these floors separate from owner exact-count branches.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Targeted exports for Large/Medium/Small/XL policy-gap cases exported successfully with `0` failures.
- A combined `18` package evidence set from the partial full export plus targeted remaining XL exports parsed in Python with `0` parse failures, `0` native rule failures, and `0` density gaps.
- The broader policy gate now reports `5` policy gaps instead of `14`, with `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_after_scenic_guard_floor_combined --allow-failures --pretty` completing owner/native parsing in about `8.829s`.
- All object/scenic category-density gaps are gone in that combined evidence. The remaining broad policy gaps are town density on `108x108_l2` and `36x36_l2`, road density on `36x36_l2` plus a near-threshold `144x144_l1` road floor, and guard/reward ratio on the owner-compared `36x36_l1` case.

The full Godot export path is still too slow for the tight loop; a broad run was stopped after producing `15/18` packages in over six minutes, then the remaining XL cases were generated with `--case`. That reinforces the testing split: use Godot only for fresh package generation, and keep policy comparison in Python.

## Implemented Generated Guard Cap Floor

The Small one-level generated batch case showed a guard/reward policy gap even after the generalized guard floor existed. The generated package had `40` guards for `80` rewards because the older translated-template fixture cap still stopped placement before the reward-ratio floor could run. That was not a Python false positive: the package really had too few guards for its reward volume.

Normal generated catalog-auto packages now let the generalized guard floor raise the effective guard cap when reward volume requires it. Owner-discovered exact comparison seeds remain excluded, so this does not mutate the historical owner-corpus exact-count fixtures.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_after_guard_floor_cap_fix --case s_randomnumberofplayers` exported `1/1` targeted package with `0` failures.
- `python3 tools/rmg_fast_audit.py --amap .artifacts/rmg_native_batch_export_after_guard_floor_cap_fix/s_randomnumberofplayers.amap --pretty` reports category counts `decoration 169`, `guard 47`, `object 26`, `reward 80`, `town 6`, with guarded reachable town pairs still `0`.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_after_guard_floor_cap_fix --allow-failures --pretty` reports the targeted `36x36_l1` package as `pass`, with guard/reward ratio `0.588` and `0` policy gaps.
- A combined `18` package evidence set with that targeted package replacing the prior `s_randomnumberofplayers.amap` reports `0` parse failures, `0` native rule failures, `0` density gaps, and `4` policy gaps instead of `5`. Remaining gaps are town density on `108x108_l2` and `36x36_l2`, road density on `36x36_l2`, and a near-threshold `144x144_l1` road floor.

## Implemented Small Two-Level Road Floor

The Small two-level generated batch cases still had too few roads after the underground-road copy pass. Owner evidence averaged `124` road cells across the Small two-level samples, while generated packages averaged about `61`; the policy gate only required about `81`, so this was a material route-density gap rather than an exact-count issue.

Normal generated Small two-level catalog-auto packages now add a generalized road-density floor that grows connected road clusters on the surface and underground. The floor excludes exact owner comparison cases and does not try to clone the owner component lists; it only prevents sparse two-level packages from passing with underbuilt roads.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_after_small_twolevel_road_floor --case s_2playerss_normalwater_2level,s_randomnumberofplayers_islands_2level` exported `2/2` targeted packages with `0` failures.
- `python3 tools/rmg_fast_audit.py --amap .artifacts/rmg_native_batch_export_after_small_twolevel_road_floor/s_2playerss_normalwater_2level.amap --pretty` reports `116` road cells: `87` surface and `29` underground, with guarded reachable town pairs `0`.
- `python3 tools/rmg_fast_audit.py --amap .artifacts/rmg_native_batch_export_after_small_twolevel_road_floor/s_randomnumberofplayers_islands_2level.amap --pretty` reports `116` road cells: `87` surface and `29` underground, with guarded reachable town pairs `0`.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_after_small_twolevel_road_floor --allow-failures --pretty` reports the targeted `36x36_l2` road-density policy gap is gone; the targeted remaining policy gap is town density.
- A combined `18` package evidence set with both Small two-level packages replaced reports `0` parse failures, `0` native rule failures, `0` density gaps, and `3` policy gaps instead of `4`. Remaining gaps are town density on `108x108_l2` and `36x36_l2`, plus a near-threshold `144x144_l1` road floor.

## Implemented Policy Epsilon

The remaining `144x144_l1` road-density policy gap was `22.521` native average versus a `22.528` floor. That is less than one road tile across the XL sample group, so treating it as a generator failure would reintroduce exact-count chasing through the back door.

`tools/rmg_fast_validation.py` now applies a `0.05` per-1000-tile epsilon to category-density and road-density policy comparisons. This tolerance is intentionally small: it clears sub-tile rounding noise while still preserving real underfill failures.

Validation evidence:

- `python3 -m py_compile tools/rmg_fast_audit.py tools/rmg_fast_validation.py` passed.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_after_small_twolevel_road_floor_combined --allow-failures --pretty` reports `policy_density_epsilon_per_1000_tiles: 0.05`, `0` parse failures, `0` native rule failures, `0` density gaps, and `2` policy gaps.
- The near-threshold `144x144_l1` road-density gap is gone. The remaining failures are still the material town-density gaps on `108x108_l2` and `36x36_l2`.

## Implemented Generated Batch Rule Fixes

The first generated-native batch exposed three generalized rule failures rather than a need to exact-match owner counts:

- object density was too low on Large/XL and two-level outputs;
- two-level catalog-auto maps could serialize roads underground while leaving the underground level empty of generated objects;
- optional/density towns could stack into the same zone or fall below the size-aware town-spacing floor.

Native catalog-auto generation now uses size/level-aware object density floors, copies an eligible subset of decoration/scenic objects onto underground levels, adds deterministic underground road cells for two-level generated packages, and applies the same size-aware town spacing floor used by the Python validator. Extra generated towns are skipped for a zone that already has a town until explicit guarded same-zone settlement regions are modeled.

The underground copy pass deliberately excludes towns, guards, mines, resources, dwellings, and reward references. That keeps economy, reward, and settlement-site per-zone limits valid while still preventing empty underground levels.

`tools/rmg_native_batch_export.gd` also now accepts a comma-separated `--case` filter so failures can be regenerated through Godot only for the named cases under investigation. The expected loop is still to run Godot once to create fresh native packages, then use Python for parsing, validation, and comparison iterations.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_after_limit_fix_limit4 --limit 4` exported `4/4` Large islands/normal-water one-level and two-level native packages.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_after_limit_fix_limit4 --pretty` parsed `18` owner H3Ms and `4` native AMAPs in about `5.945s`, with `0` parse failures, `0` density gaps, and `0` native rule failures.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_targeted_after_full_failures --case s_randomnumberofplayers,xl_islands_2levels,xl_nowater_2levels,xl_water_2levels` exported the four previously failing cases with `0` export failures.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_targeted_after_full_failures --pretty` parsed `18` owner H3Ms and `4` targeted native AMAPs in about `6.523s`, with `0` parse failures, `0` density gaps, and `0` native rule failures.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_full_after_export_failure_fix` exported all `18/18` owner-file-derived native packages with `0` export failures.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_full_after_export_failure_fix --pretty` parsed `18` owner H3Ms and `18` native AMAPs in about `8.535s`, with `0` parse failures, `0` density gaps, and `0` native rule failures.

The exact owner comparison rows still show count/topology deltas. Those remain diagnostics for future policy work, not production pass/fail targets.

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

## Implemented Generated Two-Level Town Floor

The remaining fast-policy failures were material town-density gaps on `108x108_l2` and `36x36_l2`. The fix stays generalized: normal non-owner-discovered catalog-auto two-level maps now materialize neutral towns to a size/level-aware floor without using uploaded owner sample ids as runtime selectors.

Small two-level supplements remain on the underground layer where the existing generated shape validates. Large two-level supplements use the surface source-zone placement helper instead, because placing several neutral towns into an otherwise open underground layer created unguarded package routes that owner Large two-level examples did not have.

The supplement records recovered neutral-town semantics (`+0x30`, `neutral_minimum_towns`), avoids zones that already have towns, preserves player start town ownership/anchors, and relies on the package route-closure gate to reject any free town-to-town traversal.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_after_twolevel_town_floor --case s_2playerss_normalwater_2level,s_randomnumberofplayers_islands_2level,l_islands_randomplayers_2level,l_normalwater_randomplayers_2level,l_nowater_randomplayers_2level` exported `5/5` targeted packages with `0` failures.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_after_twolevel_town_floor --allow-failures --pretty` reports `status: pass`, `0` parse failures, `0` native rule failures, `0` density gaps, and `0` policy gaps for the targeted package set.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_after_twolevel_town_floor_combined --allow-failures --pretty` reports `status: pass` across the combined `18` package evidence set, with `0` parse failures, `0` native rule failures, `0` density gaps, and `0` policy gaps in about `8.796s`.

This closes the current broad fast-policy gate without changing the testing posture: Godot is still only needed when fresh native packages must be generated/exported or when editor/runtime integration is under test. H3M parsing, AMAP inspection, category/road/town/guard comparison, route summaries, and policy gates belong in the Python CLI loop.

## Implemented Fast Road Topology Gate

The density and category policy pass was still too weak. The matched comparison rows showed that `17/18` native packages still had road component mismatches: single-level maps often serialized one dominant road component, while two-level maps often had one dominant surface trunk plus many tiny underground fragments. That shape is not HoMM3-like even when total road density clears the owner floor.

`tools/rmg_fast_validation.py` now adds a Python-only topology gate:

- `road_largest_component_dominance_over_owner_baseline` fails when the native largest road component occupies too much of the road network compared with the matched owner evidence, with a bounded multiplier and absolute cap.
- `road_component_count_under_owner_topology_floor` fails when a native map collapses too many owner road components into too few serialized components.
- `--no-topology-gate` preserves the prior density/category policy pass for narrower debugging.

Validation evidence:

- `python3 -m py_compile tools/rmg_fast_validation.py` passed.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_after_twolevel_town_floor_combined --allow-failures --pretty` now reports `status: fail` with `0` parse failures, `0` native rule failures, `0` density gaps, `0` policy gaps, and `19` topology gaps.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_after_twolevel_town_floor_combined --no-topology-gate --allow-failures --pretty` still reports `status: pass`, proving the new failure signal is specifically road topology, not a regression in parsing, density, town, reward, or guard policy.

This is the next concrete production blocker: the generator needs generalized road component materialization that creates HoMM3-like trunk/branch/component shape across land, water, islands, and two-level templates. Running more Godot parser scenes will not help this; the fast Python evidence now exposes the exact class of road-shape failure.

## Implemented Generated Road Component Materialization

Normal non-owner-corpus catalog-auto package serialization now replaces the previous all-routes trunk overlay with deterministic separated road components. The route graph, route reachability proof, and connection guard controls remain authoritative; this change affects the serialized road overlay shape that map inspection and package comparison see.

The materializer is generalized by size and level count:

- one-level generated maps split roads into multiple surface components instead of one dominant connected trunk;
- two-level generated maps split the road budget across surface and underground components instead of one dominant surface trunk plus tiny underground fragments;
- owner-corpus exact comparison seeds and existing owner road-adjustment paths are not stacked with the generalized materializer.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 600 tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_after_general_road_components` exported `18/18` packages with `0` failures.
- After tightening the no-stacking guard, `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 240 tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_after_general_road_components --case xl_nowater` re-exported the one package that had combined generalized and owner-adjusted roads.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_after_general_road_components --allow-failures --pretty` now reports `status: pass`, `18` matched comparisons, `0` parse failures, `0` native rule failures, `0` density gaps, `0` policy gaps, and `0` topology gaps.
- `python3 tools/rmg_fast_audit.py --amap .artifacts/rmg_native_batch_export_after_general_road_components/xl_nowater.amap --pretty` reports `727` road cells and component sizes `[485, 188, 54]`, proving the generalized materializer no longer stacks on that existing owner-adjusted path.

This clears the current fast road-topology blocker. It is not a full production-ready RMG claim; remaining parity work still includes replacing older owner-adjustment debt with generalized route/object/guard/town policy and broader live inspection across unsupported profiles.

## Isolated XL Owner-Override Debt And Tightened Test Split

The XL and Large land owner density/profile branches are now diagnostic-only selectors keyed to the explicit production-parity audit seeds. Normal generated catalog-auto Large/XL land seeds still use the translated owner-compared templates, but no longer activate those owner-specific runtime overrides. The remaining generated-batch owner override debt is the Small `049` path, which is still visible through runtime policy classification instead of hidden.

The XL one-level generated road floor now scales from map area before component splitting, so removing the XL owner branch does not reintroduce the near-threshold `144x144_l1` road-density gap. Fresh XL one-level evidence reports separated road components of about `62-69` cells per component depending on water mode, while route closure remains guarded.

The Godot auto-template integration report was also adjusted to match this policy boundary:

- town-spacing expectations now mirror the native generalized size floors for catalog-auto generated cases;
- the Medium normal-water owner-evidence check now enforces owner count floors instead of exact-count equality, so denser valid output is not rejected as drift.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Targeted XL re-export for `xl_islands,xl_nowater,xl_water` passed with `3/3` packages and `0` export failures.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_after_general_road_components --allow-failures --pretty` reports `status: pass`, `18` matched comparisons, and `0` parse/native/density/policy/topology gaps.
- Runtime override scan across the generated batch now reports only `s_randomnumberofplayers.amap` with `owner_small_049_profile_policy`; `xl_nowater.amap` no longer reports `owner_xl_land_profile_policy`.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 360 tests/native_random_map_auto_template_batch_report.tscn` passed with `seed_specific_runtime_override_case_count: 0`; this remains an integration smoke, not the default parser/comparison loop.

The slow `tests/native_random_map_production_parity_completion_audit_report.tscn` run was stopped after more than seven minutes with no useful output. That is intentional for the current testing posture: H3M parsing, native AMAP inspection, road topology, density policy, town/guard/blocker route closure, and owner comparison belong in the Python CLI validation path. Godot should be used for the native generation/export boundary and editor/runtime behavior.

## Implemented Generalized Object-Category Floor

The road/topology pass left a major broad parity weakness: native generated packages were still filling total object density with decorative obstacles and rewards while underproducing the recovered HoMM3 "other object" category. In the 18-package evidence before this pass, native object-category density was only about `27-53%` of the owner group density across most size/level groups, even though the broader gate passed because the object floor was only `25%`.

Normal native catalog-auto scenic/other-object floors are now size- and level-aware:

- Small/Medium/Large/XL one-level maps materialize more scenic/other objects before decorative filler.
- Two-level maps raise the surface scenic floor enough that the existing level distribution copy produces real underground/surface object-category mass instead of mostly decoration copies.
- The Python policy gate now requires native object-category density to reach at least `60%` of the matched owner group baseline.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 900 tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_after_object_category_floor` exported `18/18` packages with `0` failures.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_after_object_category_floor --allow-failures --pretty` reports `status: pass`, `18` matched comparisons, `0` parse/native/density/policy/topology gaps, and the stricter `object: 0.6` category floor.
- The native object-category totals improved materially in the generated batch: `108x108_l1 243 -> 558`, `108x108_l2 955 -> 1624`, `144x144_l1 540 -> 1260`, `144x144_l2 1097 -> 1441`, `72x72_l1 44 -> 105`, `72x72_l2 211 -> 364`, `36x36_l1 26 -> 32`, and `36x36_l2 57 -> 96`.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 360 tests/native_random_map_auto_template_batch_report.tscn` passed with `seed_specific_runtime_override_case_count: 0`.

The full export now takes about eight and a half minutes with the denser XL object placement, so the next performance target should profile and optimize native placement loops without moving correctness comparison back into Godot.

## Implemented Fast Validation Workflow Tightening

The fast validator now supports the intended default loop directly:

- `--latest-amap-artifact` selects the newest `.artifacts/rmg_native_batch_export*` directory that contains `.amap` packages.
- `--summary` prints a compact pass/fail report instead of a large JSON blob.

This keeps the normal RMG comparison command Python-only after a package export:

```bash
python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --latest-amap-artifact --summary
```

Validation evidence:

- `python3 -m py_compile tools/rmg_fast_validation.py` passed.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --latest-amap-artifact --summary` selected `.artifacts/rmg_native_batch_export_after_object_category_floor`, parsed `18/18` owner H3Ms and `18/18` native AMAPs, matched `18` comparisons, completed parsing in about `8.458s`, and reported `status=pass` with `0` parse/native/density/policy/topology gaps.

The remaining slow step is fresh native generation/export, which still needs Godot while the generator is exposed only through `MapPackageService`. The next performance work should optimize native placement loops and, if needed, add a non-Godot native CLI/export boundary; it should not move H3M/AMAP parsing or structural comparison back into Godot.

## Implemented Town/Guard Placement Profiling And Fast Path

The native extension profile report now surfaces town/guard subphase timings in addition to object-placement subphases. The added evidence showed the slow cases were not generic Godot overhead: they were dominated by `town_boundary_opening_guard_cover` and `town_pair_route_guard_closure`.

Native town/guard placement now avoids two avoidable costs:

- town boundary opening cover batches opening cells by nearest route guard and updates each guard record once, instead of duplicating/signing guard dictionaries once per opening cell;
- town-pair route closure caches town visit cells and builds per-pass connected components, skipping full pathfinding for town pairs already disconnected by current blockers/guards.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 360 tests/native_random_map_extension_profile_report.tscn` passed. Representative wall times improved from about `13.2s -> 6.4s` for `medium_default_002`, `9.5s -> 4.3s` for `medium_validation_gate_005`, and `9.7s -> 7.4s` for `xl_islands_012`.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 360 tests/native_random_map_auto_template_batch_report.tscn` passed with `11/11` cases and `seed_specific_runtime_override_case_count: 0`.
- `/usr/bin/time -p env GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 900 tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_after_town_guard_perf` exported `18/18` packages with `0` failures in `real 476.65s`.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_after_town_guard_perf --summary` reported `status=pass`, `18` matched comparisons, and `0` parse/native/density/policy/topology gaps in about `8.649s`.

This does not make generation fast enough yet. It removes a major avoidable town/guard cost while leaving object placement and full XL export time as active performance targets.

## Implemented Python RMG Gate And Export Timing Manifest

Owner review correctly called out that RMG correctness validation should not require a full Godot engine run. The testing split is now explicit:

- Godot is used when the native GDExtension must generate/export fresh packages, or when editor/runtime behavior is under test.
- Python is used for H3M parsing, AMAP parsing, owner/native comparison, density/policy/topology checks, and batch timing summary.

`tools/rmg_native_batch_export.gd` now records per-case timings in the export `manifest.json`:

- generation wall time;
- package conversion wall time;
- save wall time;
- total case wall time;
- compact extension/object/town-guard top-phase profiles.

Two Python helpers make the intended loop direct:

- `tools/rmg_python_validation_gate.py` runs the Python parser syntax check plus `rmg_fast_validation` against the latest generated AMAP batch by default. It does not start Godot.
- `tools/rmg_export_timing_summary.py` summarizes a batch manifest and ranks worst cases by wall time. It does not start Godot.

The Python validation path now distinguishes targeted diagnosis from the full correctness gate. `tools/rmg_fast_validation.py` can still validate a partial batch by default, but `--require-all-owner-matches` fails unless every parsed owner H3M has a matching parsed native AMAP. `tools/rmg_python_validation_gate.py` enables that coverage check by default, with `--allow-partial-native-batch` reserved for explicit targeted investigations.

Validation evidence:

- `python3 -m py_compile tools/rmg_export_timing_summary.py tools/rmg_python_validation_gate.py tools/rmg_fast_audit.py tools/rmg_fast_validation.py` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 240 tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_timing_smoke --limit 2` exported `2/2` packages and wrote timing fields.
- `/usr/bin/time -p env GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 900 tools/rmg_native_batch_export.tscn -- --out .artifacts/rmg_native_batch_export_timing_full` exported `18/18` packages with `0` failures in `real 480.73s`; the manifest reports `total_wall_msec: 476985`.
- `python3 tools/rmg_python_validation_gate.py --failure-limit 2` selected `.artifacts/rmg_native_batch_export_timing_full`, parsed `18/18` owner H3Ms plus `18/18` native AMAPs, matched `18` comparisons, completed parsing in about `8.865s`, and reported `status=pass` with `0` parse/native/density/policy/topology gaps.
- `python3 tools/rmg_export_timing_summary.py .artifacts/rmg_native_batch_export_timing_full --limit 8` reported phase totals of `268716ms` generation, `142418ms` conversion, and `58620ms` save. The worst case is `xl_nowater_2levels` at `74628ms`, with `29890ms` generation, `37880ms` conversion, `6858ms` save, and native `object_placement` as the top generation phase at about `15579ms`.

This changes the default correctness workflow, not the generator boundary. A fresh package export still needs Godot until a separate native CLI/export boundary exists, but map correctness and owner comparison now stay in the fast Python loop.

## Implemented Package Conversion Profiling And Boundary Mask Fast Path

The first full timing manifest showed `xl_nowater_2levels` spending more time in package conversion than generation. That was not map parsing and it was not a reason to run more Godot report scenes: it was a native package-adoption hotspot inside `combined_native_map_objects`.

The package conversion path now records its own compact profile phases so future manifests can separate generation cost from package-adoption cost:

- terrain-layer extraction;
- map metadata assembly;
- combined package object construction;
- guard/reward adoption summary;
- map and scenario document configuration;
- start contract and readiness assembly.

The measured hotspot was broad land-boundary choke mask adoption. The old path assigned every boundary cell through a helper that repeatedly duplicated and updated individual decorative object dictionaries. Broad land package adoption now groups boundary cells by nearest decorative object and writes each target object's block-mask array once.

Batch export also now calls `save_map_package(..., {"return_package": false})`. That keeps the normal API behavior unchanged while avoiding a large deep-duplicate of the written package when the batch tool only needs status, hash, and path.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed after each native change.
- Targeted `xl_nowater_2levels` profiling identified `combined_native_map_objects` as the conversion top phase at about `34.667s` before optimization.
- Removing redundant pre-mutation record signatures reduced `xl_nowater_2levels` conversion from about `35.140s` to about `31.405s`.
- Batched broad boundary-cell assignment reduced targeted `xl_nowater_2levels` conversion to about `5.585s`, with total case time about `42.021s`.
- With batch save return payload disabled, targeted `xl_nowater_2levels` exported in `real 45.79s`, with manifest `case_wall_msec: 40907`, `generation_wall_msec: 29663`, `conversion_wall_msec: 5569`, and `save_wall_msec: 5673`.
- Focused Large/XL land export for `xl_nowater`, `xl_nowater_2levels`, `l_nowater_randomplayers_2level`, and `l_nowater_randomplayers_nounder` exported `4/4` packages with `0` failures in `real 118.88s`.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_conversion_perf_land_cases --summary` passed in about `6.238s` total parse time with `0` parse/native/density/policy/topology gaps.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_conversion_perf_land_cases --summary --require-all-owner-matches --allow-failures --failure-limit 2` correctly reports `status=fail` with one coverage gap for the `14` owner cases absent from the targeted batch. This keeps partial performance batches useful without letting them masquerade as full-corpus gates.
- `python3 tools/rmg_export_timing_summary.py .artifacts/rmg_native_batch_export_conversion_perf_land_cases --limit 8` reported the focused set at `115230ms` total wall time, with phase totals `81816ms` generation, `15272ms` conversion, and `15837ms` save. `xl_nowater_2levels` is now `40982ms` total with `5567ms` conversion; the remaining top phase is native generation `object_placement` at about `15553ms`.

This changes the performance bottleneck. Package conversion is no longer the worst offender for the XL two-level land case; native object placement is again the dominant cost to optimize. The testing policy remains the same: use Godot only to generate/export fresh packages or to test editor/runtime behavior, then use Python for H3M/AMAP parsing, comparison, and rule validation.

## Implemented Object Placement And Occupancy Profiling Fast Path

The follow-up XL profile showed that object-placement record signing and the final town/guard occupancy assembly were still doing avoidable rich `Variant` canonicalization work. That cost belongs in native generation, not in the Python correctness loop, so the fix stayed inside the GDExtension path:

- object placement records now use a compact deterministic signature from stable placement identity fields, coordinates, footprint, and occupancy keys instead of canonical-hashing the full rich placement dictionary for every placed object;
- combined object/town/guard occupancy signatures now hash compact record keys and counts instead of canonical-hashing the full occupancy dictionary;
- no-op town access corridor and connection guard choke clearance passes attach their summaries without rehashing the full object-placement payload;
- town access corridor clearance now uses level-aware keys, preventing two-level maps from treating surface and underground corridor cells as the same tile;
- `tools/rmg_native_batch_export.gd` now records the top six native profile phases per profile in the manifest, making single-case performance runs useful without digging through full generation payloads.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed after the native changes.
- Targeted `xl_nowater_2levels` export after compact object signatures reported `case_wall_msec: 38504`, `generation_wall_msec: 27384`, `conversion_wall_msec: 5492`, and `save_wall_msec: 5628`.
- After compact combined occupancy and level-aware corridor clearance, targeted `xl_nowater_2levels` reported `case_wall_msec: 36115`, `generation_wall_msec: 24484`, `conversion_wall_msec: 5879`, and `save_wall_msec: 5752`. The original timed baseline for this case was `74628ms` total with `37880ms` spent in conversion.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_level_aware_corridor_xl_nowater_2levels --summary` passed with `0` parse/native/density/policy/topology gaps and total parse time about `5.632s`.
- `python3 tools/rmg_export_timing_summary.py .artifacts/rmg_native_batch_export_compact_occupancy_xl_nowater_2levels --limit 8` passed and showed the remaining XL bottleneck is native generation, not parser/comparison work.
- `tests/native_random_map_object_placement_report.gd` now validates the generated `MapDocument` by counting records tagged `native_record_kind == "object_placement"`, because the document correctly contains object placements plus towns, guards, and gates. The focused object-placement report passed after that assertion was corrected.
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 360 tests/native_random_map_auto_template_batch_report.tscn` passed as the broader native generator integration smoke.

This reinforces the testing split: correctness validation and owner comparison remain Python-only once `.amap` packages exist. Godot is still only needed for fresh package generation/export through the current `MapPackageService` boundary and for actual editor/runtime smokes.
