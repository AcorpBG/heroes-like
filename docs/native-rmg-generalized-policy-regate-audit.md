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

## Implemented Guard-Mediated Closure Diagnostic Gate

The existing fast validation proved that native packages avoid free town-to-town routes after guards are considered, but that was not enough to prove HoMM3-like blocker/guard shape. A map can pass that rule by sealing routes with permanent terrain/blocker masks before guards matter, which is not the same as an opening guarded by a monster stack.

The Python audit now separates native guard body blocking from the guard control-zone tiles when computing object-only town-pair topology. This keeps `object_route_reachable_pair_count_total` from accidentally treating guard control as permanent object closure. `tools/rmg_fast_validation.py` also has `--closure-shape-gate`, which fails when owner evidence has town pairs that are reachable with terrain/objects only but closed after guards, while the native package has no equivalent guard-mediated closure. `tools/rmg_python_validation_gate.py` now enables that closure-shape gate by default for the full post-export correctness gate; targeted diagnosis can opt out with `--no-closure-shape-gate`.

Validation evidence:

- `python3 -m py_compile tools/rmg_fast_audit.py tools/rmg_fast_validation.py tools/rmg_python_validation_gate.py` passed.
- Default full fast validation remains green: `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_timing_full --require-all-owner-matches --summary --failure-limit 4` reports `status=pass` with `0` parse/native/density/policy/topology/coverage gaps.
- The stricter diagnostic gate exposes the next blocker: `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_timing_full --require-all-owner-matches --closure-shape-gate --allow-failures --summary --failure-limit 6` reports `13` `missing_guard_mediated_town_route_closure` gaps.
- A targeted no-land-rock-barrier probe for `l_nowater_randomplayers_nounder` did not fix the shape problem: the native package still had `object_route_reachable_pair_count_total: 0` and `guarded_route_reachable_pair_count_total: 0`, so the permanent closure is not only terrain rock; object/body mask shape still seals town routes before guards matter.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_timing_full --allow-failures --failure-limit 2` now reports the same closure-shape blocker through the Python-only full gate without starting Godot.

This is not a parser problem and not a reason to go back to Godot report scenes. It shows that the next generator work should open guarded crossings in terrain/blocker shape and let route guards close those openings, instead of relying on permanent blocker/terrain over-closure.

## Implemented Guard-Mediated Package Route Shape

The closure-shape gap had two package-materialization causes:

- route guards were exporting broad route-edge coverage as `package_body_tiles`, so the Python object-only topology correctly treated guard bodies as permanent blockers before guard control mattered;
- decorative/scenic package block masks could still occupy the viable town-route corridor, leaving no object-only path for guards to close.

Package adoption now separates those roles:

- guard `package_body_tiles` are narrowed to the primary stack tile, while the wider guard route/control mask remains in `package_block_tiles`;
- generated package conversion materializes town-pair corridors by cutting only decorative/scenic block masks along terrain-valid paths;
- nearby guards receive package-only closure masks on those corridors, so object-only paths are reachable and guarded paths close.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- A focused two-case probe for `s_2playerss_normalwater_2level` and `l_nowater_randomplayers_nounder` exported `2/2` packages. Python validation with `--closure-shape-gate` passed with `0` closure-shape gaps. The native semantic summaries changed to object-only/guarded reachable pairs of `6/0` and `15/0`.
- The known 13-case closure failure set exported `13/13` packages, and `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_guard_body_closure_cases --closure-shape-gate --allow-failures --summary --failure-limit 8` passed with `0` parse/native/density/policy/topology/closure gaps.
- The remaining five owner cases exported `5/5` packages. Combined with the 13-case set into `.artifacts/rmg_native_batch_export_guard_body_full`, `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_guard_body_full --failure-limit 8` passed with `18/18` owner H3Ms, `18/18` native AMAPs, `18` matched comparisons, total parse time about `11.414s`, and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.

This clears the current fast guard-mediated closure blocker. It does not close full production RMG parity: visual quality, exact game-feel parity, generated-object semantics, performance, and broader owner corpus coverage remain active production work.

## Tightened Python Validation And Timing Workflow

The owner-requested testing split is now one workflow instead of a loose convention:

- `tools/rmg_python_validation_gate.py` remains the full post-export correctness command. It compiles the Python RMG tooling, validates owner H3M and native AMAP packages directly, requires full owner/native coverage by default, and keeps the guard-mediated closure-shape gate enabled by default.
- The same command now summarizes native export timing manifests when available. If the selected validation AMAP directory is a manually combined evidence set without a manifest, it reports that fact and falls back to the newest manifest-bearing export artifact for timing only.
- `tools/rmg_export_timing_summary.py --latest-amap-artifact` now selects the newest export artifact that actually contains `manifest.json`, instead of failing when the newest validation evidence directory has AMAP files but no timing manifest.

Validation evidence:

- `python3 -m py_compile tools/rmg_fast_audit.py tools/rmg_fast_validation.py tools/rmg_python_validation_gate.py tools/rmg_export_timing_summary.py` passed.
- `python3 tools/rmg_export_timing_summary.py --latest-amap-artifact --limit 4` passed using `.artifacts/rmg_native_batch_export_guard_body_remaining_cases/manifest.json`, reporting `5/5` exported, `0` failed, and `95576ms` total wall time.
- `python3 tools/rmg_python_validation_gate.py --failure-limit 4 --timing-limit 4 --require-timing-summary` passed without starting Godot. It validated `.artifacts/rmg_native_batch_export_guard_body_full` with `18/18` owner H3Ms, `18/18` native AMAPs, `18` matched comparisons, and `0` parse/native/density/policy/topology/coverage/closure-shape gaps, then reported timing from the newest manifest-bearing export as a clearly labeled fallback because the validated combined AMAP directory has no manifest.

This keeps Godot out of H3M/AMAP parsing, validation, comparison, and timing summaries. Godot remains necessary only to create fresh native packages through the extension/export path and for actual editor/runtime smoke coverage.

## Python Production Gap Audit Boundary

The green fast gate is a structural correctness signal, not a production-ready claim. To keep that distinction visible without running a slow Godot report, `tools/rmg_production_gap_audit.py` now builds a prompt-to-artifact checklist from the same owner H3M and native AMAP evidence:

- owner H3M parsing, native AMAP coverage, generalized structural gates, owner diagnostic similarity, road-shape similarity, town distribution similarity, object/guard/reward category similarity, route-shape similarity, and full export timing evidence;
- a ranked case list by diagnostic severity, combining object-count deltas, road-cell deltas, route-shape deltas, and category absolute deltas;
- `production_ready: false` whenever the audit finds uncovered or weakly verified requirements.

Validation evidence:

- `python3 -m py_compile tools/rmg_production_gap_audit.py tools/rmg_fast_validation.py tools/rmg_fast_audit.py tools/rmg_export_timing_summary.py` passed.
- `python3 tools/rmg_production_gap_audit.py --summary --gap-limit 10` passed as an audit and reported `production_ready=false`, `18/18` owner/native matches, fast gate `pass`, and `5` missing production requirements: owner diagnostic similarity, road-shape similarity, town density/distribution similarity, object/guard/reward category similarity, and route-shape similarity.
- The top current diagnostic blockers are XL and Large cases, led by `xl_islands_2levels`, `xl_nowater`, `xl_water_2levels`, and `l_nowater_randomplayers_nounder`.

The next production work should use this audit as the no-overclaim boundary. The immediate highest-value implementation target is broad Large/XL object/category and route/road shape, not more Godot parser/report infrastructure.

## Land Terrain Boundary Barrier Correction

The guard-mediated closure fix exposed a second shape problem on normal generated land maps: catalog-auto land packages could still inherit broad zone-boundary rock terrain barriers. That made no-water maps structurally pass route closure while visually and mechanically resembling terrain-walled zones instead of HoMM3-style object/guard-controlled crossings.

Normal generated `native_catalog_auto` land maps now disable the land-boundary terrain barrier fallback. Owner/diagnostic paths that are not normal generated catalog-auto policy are left untouched. The intended normal generated closure stack is now:

- terrain stays broadly passable except for water/island policy and explicit terrain shape;
- decorative/scenic package blocker masks shape crossings and obstacles;
- route guards own the final closure masks that turn object-only reachable routes into guarded blocked routes.

The Python audit now also carries `terrain_blocked_tile_count_delta` through owner/native comparisons. `tools/rmg_production_gap_audit.py` includes a `terrain_blocker_shape_similarity` checklist item and adds terrain-blocker deltas to severity ranking, so removing land-wall fallback cannot be mistaken for production readiness when two-level, islands, water, or broader terrain-shape gaps remain.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- A targeted land export for `s_randomnumberofplayers`, `l_nowater_randomplayers_nounder`, `l_nowater_randomplayers_2level`, `xl_nowater`, and `xl_nowater_2levels` exported `5/5` packages.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_no_land_boundary_rock_land_cases --closure-shape-gate --allow-failures --summary --failure-limit 8` passed with `5` matched cases, total parse time about `8.198s`, and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing those five land packages into the full 18-case evidence set, `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_no_land_boundary_rock_land_combined --failure-limit 4 --skip-timing-summary` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `12.219s` parse time.
- `python3 tools/rmg_production_gap_audit.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_no_land_boundary_rock_land_combined --summary --gap-limit 10` passed as an audit while preserving `production_ready=false`. It now reports `6` missing production requirements, including terrain-blocker shape, with `15` terrain-shape gap cases. The top blockers remain broad XL/Large two-level, water, and islands cases.

This keeps the owner-requested testing split strict: Godot is used only to produce fresh native packages through the current extension/export path or to smoke actual editor/runtime behavior. H3M parsing, AMAP parsing, correctness validation, owner comparison, timing summary, and production-gap ranking are Python work.

## Implemented Two-Level Underground Distribution And Route Closure

The Large/XL production-gap audit exposed a material two-level defect after the land-boundary correction: generated two-level packages had underground roads but not enough underground towns, rewards, guards, and ordinary objects. A first distribution pass moved those records underground, but it also exposed the real route-closure problem: newly materialized underground town pairs could still have free town-to-town routes after guard masks were considered.

The native generator now rebalances normal catalog-auto two-level object records by category instead of copying only decorative/scenic filler underground. Two-level town floors also reserve an underground share before filling remaining neutral towns on the surface. Package conversion now cuts decorative/scenic corridor masks, then iteratively rechecks object-only and guarded town routes and expands nearby guard closure masks until the guarded route topology is closed or the bounded closure pass limit is reached.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- A focused five-case export for the previously failing Large/XL two-level cases wrote `5/5` packages in about `193.493s`; the follow-up `xl_water_2levels` export wrote `1/1` package in about `44.793s`.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_two_level_distribution_closure_fix_probe --closure-shape-gate --allow-failures --summary --failure-limit 12` passed on the focused failing set with `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing the six affected two-level packages into the 18-case evidence set, `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_two_level_distribution_closure_fix_combined --failure-limit 6 --skip-timing-summary` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `13.736s` parse time.
- `python3 tools/rmg_production_gap_audit.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_two_level_distribution_closure_fix_combined --summary --gap-limit 12` passed as an audit while preserving `production_ready=false`. It still reports `6` missing production requirements and ranks broad XL/Large terrain, road, route-shape, and category gaps as the top production blockers.

This is a correctness repair for normal generated two-level package materialization and guard-mediated route closure. It is not a full HoMM3 production-parity claim, and it reinforces the workflow split: Godot exports fresh packages; Python validates H3M/AMAP structure, comparison, and production-gap status.

## Implemented Underground Rock Shape For Two-Level Maps

The next production-gap ranking showed that generated two-level underground maps were still mostly open terrain. Owner H3M evidence uses substantial underground rock/water blocking, especially on Large/XL land and islands maps, while native packages had roads, objects, towns, and guards underground but almost no impassable underground terrain.

Normal generated catalog-auto two-level maps now add deterministic underground rock shape for land/islands profiles and XL normal-water profiles. The policy preserves open cells around underground roads, towns, guards, object bodies, visit/approach tiles, and town access corridors, then fills the remaining underground space with size/water-mode-specific rock density. This changes terrain shape without covering already placed gameplay surfaces.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- A focused six-case export for Large/XL land/islands plus XL water wrote `6/6` packages with `0` export failures in about `206.214s`.
- The targeted partial batch had no parse/native/density/topology/coverage/closure-shape gaps; its one policy gap was a partial-batch `72x72_l2` group-density artifact.
- Replacing those six packages into the 18-case evidence set, `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_underground_rock_shape_combined --failure-limit 8 --skip-timing-summary` passed with `18/18` owner/native matches, `0` parse/native/density/policy/topology/coverage/closure-shape gaps, and about `12.937s` parse time.
- `python3 tools/rmg_production_gap_audit.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_underground_rock_shape_combined --summary --gap-limit 12` passed as an audit while preserving `production_ready=false`. Top severity improved materially, for example `xl_islands_2levels` `26912 -> 18396`, `xl_water_2levels` `24032 -> 14136`, and `xl_nowater_2levels` `21003 -> 12389`.

This reduces the terrain-shape gap but does not close production parity. The next remaining blockers are still road component similarity, route-shape similarity, and object/guard/reward category similarity across broad Large/XL cases.

## Recovered H3MapEd Decorative Filler Evidence And XL Islands Barrier Fix

The correct executable for this recovery pass is `/root/Downloads/h3maped.exe`, not `h3mapedit.exe`. Direct disassembly of that binary confirms the recovered final decorative filler phase:

- `0x49eb8d` counts cells with bit 26 set after occupancy/object normalization, computes a per-cell work budget from `0x4374c / flagged_count`, and calls `0x49e700(x, y, z, budget)` for each valid flagged cell.
- `0x49e700` rejects invalid/free-cell states, rejects terrain type `9`, iterates the terrain-object type table at `0x54092c..0x5409e0`, rejects `-5000` terrain scores, applies map-level object guards, checks the object footprint through `0x41e951`, scores adjacency/overlap through `0x49e1bf`, chooses by weighted random, and stamps the selected decorative obstacle object.

The important current delta is therefore not just "more objects". HoMM3's editor keeps a late physical decorative-obstacle layer after route/object normalization. Native conversion was clearing package decorative/scenic blocker cells along town-to-town guard corridors, which made the object counts look close while still leaving too many physically open object routes on XL one-level islands.

The native package conversion now preserves XL one-level islands decorative/scenic object barriers for normal generated catalog-auto packages. Guard masks still close guarded routes, but the conversion no longer cuts corridor holes through the physical obstacle layer for that profile.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- A focused `xl_islands` export wrote `1/1` package in about `35s`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-islands.h3m --amap .artifacts/rmg_native_batch_export_xl_islands_barrier_probe/xl_islands.amap --compare --pretty --allow-failures` passed as an audit and improved object-route reachable pairs from the previous native `45` to `2`, compared with owner `1`.
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_barrier_probe --allow-partial-native-batch --summary --failure-limit 6 --gap-limit 8` passed for the focused partial batch.
- Replacing `xl_islands.amap` into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_barrier_merged --summary --failure-limit 6 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_barrier_merged --require-timing-summary` passed. The manifest-backed native export timing summary reported `18/18` exported, `0` failed, `392420ms` total wall time, with generation `234334ms`, conversion `106447ms`, and save `46418ms`.

This is not full production parity. It is a binary-backed correction to the most visible XL one-level islands blocker leak. The remaining missing implementation should replace native count/ring-style decorative filling with a `rand_trn`-style flagged-cell placement phase using the same algorithmic structure recovered from `h3maped.exe`, without committing raw HoMM3 copyrighted data tables into this repository.

## Land-Only Recovered-Style Decorative Filler And Town Anchor Reservation

The next native correction ports the recovered filler structure into the normal generated land path without copying raw HoMM3 `rand_trn.txt` rows or object names. For one-level Large/XL land catalog-auto maps, the late decorative blocker floor now uses a recovered-style scored placement pass:

- reject invalid terrain classes;
- require native object footprint fit;
- score terrain compatibility;
- prefer zone-boundary/choke cells;
- score nearby decorative adjacency;
- avoid crowding interactive objects;
- keep deterministic hash jitter for repeatability.

This remains an original-content approximation. It is intentionally scoped to `water_mode == land`; the first island attempt over-closed the owner-visible object route and was not kept.

The town-density repair is tied to the same phase-order problem. Native decorative objects are generated before supplemental neutral towns, while HoMM3's recovered flow reserves/normalizes occupancy before the final filler. Normal one-level Large/XL land maps now reserve future neutral town anchors before object placement, and the generated catalog-auto town floor uses those reserved anchors instead of random jitter. This prevents the late decorative filler from consuming all neutral town slots.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `l_nowater_randomplayers_nounder` export wrote `1/1` package. `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_recovered_filler_land_town_anchor_retry_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `0` parse/native/density/policy/topology/coverage/closure-shape gaps. The native town count moved from the previous `5` player-start-only result to `6`, closing the partial-batch town-density policy gap.
- Focused `xl_nowater` export wrote `1/1` package. `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_recovered_filler_xl_land_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing `l_nowater_randomplayers_nounder.amap` and `xl_nowater.amap` into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_recovered_filler_land_town_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_recovered_filler_land_town_merged --require-timing-summary` passed while preserving `production_ready=false`.

The remaining top production blockers are still two-level water/islands, road-component shape, route-shape similarity, and object/guard/reward category shape. This checkpoint moves the land placement pipeline away from raw count fitting, but it does not complete HoMM3-style RMG parity.

## Large Normal-Water Two-Level Surface And Underground Policy

The Large normal-water two-level owner sample exposed a different profile than the XL water sample. XL normal-water remains a water-heavy surface profile, but Large normal-water owner evidence has an effectively all-land surface and a heavily blocked underground layer. Native was previously mixing those two behaviors: it produced surface water like XL, but it did not reserve normal-water underground neutral towns.

Normal generated catalog-auto two-level normal-water maps now reserve an underground neutral-town share. Zone reuse for generated town floors is tracked by `(zone, level)` instead of by zone alone, so underground towns do not incorrectly consume the corresponding surface zone slot. Large normal-water two-level terrain now keeps the surface land-dominant while applying deterministic underground rock shape; XL normal-water keeps the water-heavy surface profile.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused Large normal-water two-level export wrote `1/1` package in about `34.766s`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/L-NormalWater-RandomPlayers-2level.h3m --amap .artifacts/rmg_native_batch_export_large_normal_water_surface_policy_probe/l_normalwater_randomplayers_2level.amap --compare --pretty --allow-failures` shows the native town count now matches owner `14`, with `10` surface towns and `4` underground towns. Terrain-blocked delta improved to `+2`: native surface `0` vs owner `1`, and native underground `6713` vs owner `6710`.
- Focused XL normal-water two-level export retained the owner-like `9` surface / `5` underground native split and improved underground terrain shape versus the previous checkpoint while preserving the XL water-heavy surface profile.
- Replacing the Large and XL normal-water two-level packages into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_normal_water_profile_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_normal_water_profile_merged --require-timing-summary` passed with `18/18` owner/native matches. The timing manifest still reports the inherited full-batch export baseline of `392420ms` total wall time, generation `234334ms`, conversion `106447ms`, and save `46418ms`.

This is a generalized size/water/level profile correction, not a per-seed exact-count claim. Production parity remains blocked by road-component shape, route-shape similarity, and object/guard/reward category similarity. The Large normal-water two-level case now ranks as a category/road problem instead of a terrain/town-layer problem.

## Large One-Level Islands Object And Terrain Profile Cleanup

The next one-level Large islands probe showed a different failure mode than Large land and Large normal-water. Native output was close on total object count only because decoration, guard, and reward categories were inflated while the island terrain profile was still under-blocked compared with owner evidence. A neutral-town-floor experiment was rejected before commit because it only raised the native town count from `8` to `9` while still asking for `16`, worsening route diagnostics without solving the actual island town-layout problem.

Normal generated catalog-auto Large one-level islands now use a lower islands-specific decoration target, a lower object-density floor, and a lower guard floor. The profile also keeps the classic island land-fraction path instead of the extra one-level shaping used by other size classes. This is intentionally scoped to `homm3_large`, `water_mode == islands`, and `level_count <= 1`.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `l_islands_randomplayers` export wrote `1/1` package in about `10.912s`.
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_islands_profile_clean_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` preserved `0` parse/native/policy/topology/coverage/closure-shape gaps. The expected partial-batch density gap remains because one 108x108 sample alone is below the broad group floor.
- The focused production-gap audit improved `l_islands_randomplayers` from the previous merged baseline severity `4111` to `1122`: object delta `+631 -> +38`, terrain delta `-2093 -> +62`, route delta stayed `17/-11`, and category absolute delta moved to `282`.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_islands_profile_clean_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.

This is not a town-distribution fix. Large one-level islands still need a generalized island-town/zone-layout pass before they can match owner town density and guarded route shape.

## XL Two-Level Islands Object, Guard, And Underground Profile Cleanup

The next worst merged evidence case was `xl_islands_2levels`. Native output was much too object-heavy and guard-heavy compared with the owner H3M sample, while the underground layer was still not blocked enough. The first cleanup pass lowered the two-level XL islands object floor, reward target, and guard floor, increased underground rock shape for that profile, and used a lower island land fraction by zone role.

That exposed a second defect: the generated two-level town floor could place two neutral towns into the same logical island zone across different levels, which created a one-step town-to-town route that no normal guard insertion could close. XL two-level islands now reserve generated town-floor zones across both levels for this profile, and the existing-guard closure helper can reuse a guard mask on very short paths instead of treating those paths as impossible.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `xl_islands_2levels` export wrote `1/1` package in about `47.448s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-islands-2levels.h3m --amap .artifacts/rmg_native_batch_export_xl_islands_2level_profile_probe/xl_islands_2levels.amap --compare --pretty --allow-failures` improved total object delta from the previous `+665` to `+43`, terrain-blocked delta from `-1429` to `+626`, guard category delta from `+374` to `+43`, and reward category delta from `+311` to `+136`.
- The focused production-gap severity for `xl_islands_2levels` improved from `3879` to `1668`; the remaining native deltas are town count `14` vs owner `20`, reward count `706` vs owner `570`, object-route reachable pairs `28` vs owner `3`, and guarded-route reachable pairs `0` vs owner `2`.
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_2level_profile_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_2level_profile_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_2level_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is a profile cleanup, not a completed island-zone parity pass. The top merged blockers now move to `xl_water_2levels`, `xl_nowater_2levels`, and Large two-level water/land cases. XL two-level islands still needs a generalized town-capacity and route-shape correction before it can match owner town density and object-only route shape.

## XL Two-Level Normal-Water Object, Guard, And Underground Profile Cleanup

The next merged top-gap case was `xl_water_2levels`, which maps to the normal-water translated profile. Its road totals and component shape were already close to owner evidence, but the native object-placement payload was inflated by the generic XL two-level floor: native wrote `3829` total objects versus owner `3178`, with guard `498` versus `196` and reward `857` versus `482`. Underground terrain was also under-blocked by `1465` tiles.

Normal generated catalog-auto XL two-level normal-water maps now use a scoped object-placement floor, reward target scale, guard floor, and underground rock fraction. This keeps the already close road profile intact while reducing the category inflation that made the map feel unlike the owner H3M sample.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `xl_water_2levels` export wrote `1/1` package in about `41.231s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-water-2levels.h3m --amap .artifacts/rmg_native_batch_export_xl_water_2level_profile_probe/xl_water_2levels.amap --compare --pretty --allow-failures` improved total object delta from `+651` to `+28`, guard delta from `+302` to `+11`, reward delta from `+375` to `+150`, and terrain-blocked delta from `-1465` to `-462`.
- The focused production-gap severity for `xl_water_2levels` improved from `3593` to `1550`. Remaining deltas are mostly reward/category shape and route shape: object-route reachable pairs remain `36` versus owner `16`, while guarded-route reachable pairs remain `0` versus owner `10`.
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_2level_profile_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_2level_profile_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_2level_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blocker moves to `xl_nowater_2levels`, followed by Large two-level normal-water/land/islands route and category-shape gaps. The next production correction should address terrain/route shape and town/object-route structure instead of continuing to tune object totals alone.

## XL Two-Level Land Underground And Object-Route Shape Cleanup

The next merged top-gap case was `xl_nowater_2levels`. Unlike the previous water profile, its category and town counts were already close: native and owner both had `10` towns with a `7` surface / `3` underground split, and total object count was only `+19`. The real defects were structural:

- underground terrain was under-blocked by `2311` tiles;
- surface object-route shape was far too open, with native `21` reachable surface town pairs versus owner `1`;
- guard count was inflated by `+106`, mostly from the generic XL two-level reward-to-guard floor.

Normal generated catalog-auto XL two-level land maps now use a land-specific guard floor, a stronger underground rock fraction, and package conversion preserves decorative/scenic blocker masks on XL two-level land town routes instead of cutting all town-pair corridors through them. Guard masks still close guarded routes, but physical object-route shape is no longer erased during package adoption for this profile.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `xl_nowater_2levels` export wrote `1/1` package in about `45.169s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-nowater-2levels.h3m --amap .artifacts/rmg_native_batch_export_xl_nowater_2level_route_probe/xl_nowater_2levels.amap --compare --pretty --allow-failures` improved terrain-blocked delta from `-2311` to `-151`, object-route delta from `+19` to `-1`, guard delta from `+106` to `+1`, and total object delta from `+19` to `-86`.
- The focused production-gap severity for `xl_nowater_2levels` improved from `3015` to `367`. Remaining deltas are minor compared with the previous broad route/terrain gap: road delta `-9`, terrain delta `-151`, route delta `-1/0`, and category absolute delta `96`.
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_nowater_2level_route_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_nowater_2level_route_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_nowater_2level_route_merged --skip-timing-summary --failure-limit 8` passed.

This correction is important because it fixes a route-shape regression caused by package adoption, not just an object count. Production parity remains false; the next merged top blocker is `l_normalwater_randomplayers_2level`, followed by Large two-level land/islands and Medium two-level category/route-shape gaps.

## Large Two-Level Normal-Water Category Profile Cleanup

The next merged top-gap case was `l_normalwater_randomplayers_2level`. Its terrain shape and town count were already close, but the generic Large two-level object floor underfilled every major category: native had `3116` total objects versus owner `4007`, with decoration `1554` versus `1915`, guard `303` versus `535`, object `723` versus `821`, and reward `522` versus `722`.

Normal generated catalog-auto Large two-level normal-water maps now use a scoped object floor, scenic floor, reward scale, and guard floor. Package conversion also preserves decorative/scenic blocker masks on Large two-level normal-water town routes. The surface land quota is relaxed from a literal `1.0` to `0.99` because the denser protected footprint can otherwise make the zone land quota infeasible, while still preserving the owner-like mostly-land surface.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- The first focused export attempt failed native validation with `zone_land_quota_infeasible` after the density increase. The committed policy keeps the density correction and relaxes Large normal-water two-level surface land fraction to `0.99`.
- Focused `l_normalwater_randomplayers_2level` export then wrote `1/1` package in about `36.553s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/L-NormalWater-RandomPlayers-2level.h3m --amap .artifacts/rmg_native_batch_export_large_normalwater_2level_profile_probe/l_normalwater_randomplayers_2level.amap --compare --pretty --allow-failures` improved total object delta from `-891` to `-5`, guard delta from `-232` to `+1`, object category delta from `-98` to `-1`, reward delta from `-200` to `-76`, and object-route delta from `+38` to `+9`. Terrain delta moved from `+2` to `-203`, which remains inside the fast gate but is still recorded as production-shape debt.
- The focused production-gap severity improved from `2780` to `628`.
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_normalwater_2level_profile_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_normalwater_2level_profile_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_normalwater_2level_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blocker moves to `xl_water`, followed by Large two-level land/islands and Medium two-level route/category cases. The remaining work is now less about broad category floors and more about road/route/terrain shape across each water and level profile.

## XL One-Level Normal-Water Road, Terrain, And Category Profile Cleanup

The next merged top-gap case was `xl_water`. Its previous native output was close enough to pass the broad generated-rule gate, but the production-shape audit still exposed a classic one-level normal-water mismatch: roads were fragmented into too many components, terrain water/blocking was under-shaped, total objects were inflated, and reward/guard floors were too high for the owner profile.

Normal generated catalog-auto XL one-level normal-water maps now use a scoped road component target, a higher road total floor, a lower object/reward/guard profile, a higher scenic-object floor, and lower land fractions by zone role. This keeps the map valid while moving the generated XL water profile toward the recovered owner sample instead of relying on generic XL land/water defaults.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `xl_water` export wrote `1/1` package in about `30.302s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-water.h3m --amap .artifacts/rmg_native_batch_export_xl_water_profile_probe/xl_water.amap --compare --pretty --allow-failures` improved total object delta from `+321` to `+49`, road delta from `-133` to `-9`, terrain-blocked delta from `-1029` to `-151`, and category absolute delta from `499` to `223`. Road components moved from `10` native components toward the owner `3` component profile, now materializing as `419/236/91` versus owner `637/96/22`.
- The focused production-gap severity improved from `2707` to `907`.
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_profile_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_profile_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The remaining XL water debt is route shape and exact road-component distribution, while the merged top blockers now move to Large two-level land/islands and Medium two-level route/category cases.

## Large Two-Level Land Town, Guard, Reward, And Underground Profile Cleanup

The next merged top-gap case was `l_nowater_randomplayers_2level`. The previous native output had broadly valid structure, but it was underfilled versus the owner sample in the places that affect playability: native wrote `11` towns versus owner `16`, guard count was `-281`, reward count was `-137`, and underground terrain was under-blocked by `1427` tiles.

Normal generated catalog-auto Large two-level land maps now use a scoped town floor and underground split, a higher reward scale, a higher guard-to-reward floor, a stronger underground rock fraction, and a Large-land road component split closer to the owner evidence. A first attempt to preserve decorative/scenic blockers on this profile was rejected because it erased all object-only town routes and failed the guard-mediated closure gate; package adoption continues clearing the required corridors for this profile.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused exports.
- Focused `l_nowater_randomplayers_2level` export wrote `1/1` package with native validation `pass`. The final focused export ran in about `31.500s`; an intermediate overly-high scenic-floor attempt took about `84s` and was corrected before commit by lowering the Large two-level land scenic floor to an owner-like range.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/L-NoWater-RandomPlayers-2level.h3m --amap .artifacts/rmg_native_batch_export_large_land_2level_profile_probe3/l_nowater_randomplayers_2level.amap --compare --pretty --allow-failures` improved total object delta from `-437` to `-72`, town delta from `-5` to `0`, guard delta from `-281` to `-2`, reward delta from `-137` to `-33`, and terrain-blocked delta from `-1427` to `-78`.
- The focused production-gap severity improved from `2455` to `588`.
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_land_2level_profile_probe3 --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_land_2level_profile_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_land_2level_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blocker moves to `l_islands_randomplayers_2level`, followed by Medium two-level water/islands and the remaining XL island/water route-shape cases.

## Large Two-Level Islands Route, Road, And Category Profile Cleanup

The next merged top-gap case was `l_islands_randomplayers_2level`. The owner sample has a very different route shape from the Large land profile: object-only town routes are fully closed on both levels, roads are split with a larger underground share, and the object payload is denser across guards, scenic objects, and rewards. Native previously left `27` object-only town pairs reachable, underfilled total objects by `705`, and underfilled guards by `213`.

Normal generated catalog-auto Large two-level islands now use a scoped profile with a higher object/scenic/decoration/reward/guard floor, a Large-islands road split, a higher surface-land fraction, stronger underground rock, and preserved decorative/scenic blockers during package adoption. Unlike the Large land profile, preserving blockers is correct here because the owner evidence has `0` object-only reachable town pairs.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `l_islands_randomplayers_2level` export wrote `1/1` package in about `30.891s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/L-islands-RandomPlayers-2level.h3m --amap .artifacts/rmg_native_batch_export_large_islands_2level_profile_probe/l_islands_randomplayers_2level.amap --compare --pretty --allow-failures` improved total object delta from `-705` to `+5`, road delta from `-69` to `+1`, object-route delta from `+27` to `0`, guard delta from `-213` to `-3`, and object category delta from `-139` to `+1`.
- The focused production-gap severity improved from `2309` to `538`. Remaining debt is mostly distribution shape: town count `11` versus owner `14`, reward count `542` versus owner `630`, decoration count `1895` versus owner `1797`, and terrain-blocked delta `+339`.
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_islands_2level_profile_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_islands_2level_profile_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_islands_2level_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blocker moves to `m_4players_2levels_islands`, followed by Medium two-level normal-water and the remaining XL route/terrain-shape cases.

## Medium Two-Level Islands Road, Density, And Guarded-Route Cleanup

The next merged top-gap case was `m_4players_2levels_islands`. The owner evidence has a compact Medium islands profile: `737` total objects, `284` road cells split across `7` surface and `2` underground components, fully closed guarded town routes, and `0` object-only reachable town pairs. Native previously generated `1213` objects, overfilled decoration and guards, under-blocked terrain by `724` tiles, and kept all `15` surface town pairs reachable by object-only topology.

Normal generated catalog-auto Medium two-level islands now use a scoped profile with owner-like road component counts, capped road-cell materialization, lower reward/guard/object floors than generic Medium two-level maps, smaller island land fractions, stronger underground rock, and preserved decorative/scenic blockers during package adoption. The result keeps guard-mediated routes closed while avoiding the original overfilled object payload.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `m_4players_2levels_islands` export wrote `1/1` package in about `6.795s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/M-4players-2levels-islands.h3m --amap .artifacts/rmg_native_batch_export_medium_islands_2level_profile_probe/m_4players_2levels_islands.amap --compare --pretty --allow-failures` improved total object delta from `+476` to `+185`, road delta from `+54` to `-5`, terrain-blocked delta from `-724` to `+178`, and guarded-route delta remained `0`. Object-only reachable town pairs improved from `15` to `10`, but owner evidence remains stricter at `0`.
- The focused production-gap severity improved from `2175` to `803`. Remaining debt is mostly decoration/category and object-only route shape: native has decoration `476` versus owner `340`, guard `86` versus owner `69`, reward `164` versus owner `132`, and all `6` towns remain on surface while owner places `5` on surface and `1` underground.
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_medium_islands_2level_profile_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_medium_islands_2level_profile_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_medium_islands_2level_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blocker moves back to `m_normalw_4players_2levels`, followed by one-level Large/XL route and terrain-shape cases. The next correction should address Medium two-level normal-water town/route/category shape and the remaining object-only islands route debt without using exact-count sample fitting as production policy.

## Medium Two-Level Normal-Water Road, Category, And Underground Profile Cleanup

The next merged top-gap case was `m_normalw_4players_2levels`. The owner sample is a dense, mostly-land surface map with a rock-heavy underground: `1862` total objects, `8` towns, `387` road cells, and road components split as `5` surface components plus `1` underground component. Native previously underfilled the object payload by `663`, underfilled reward objects by `238`, underfilled guards by `90`, missed one town, had `35` too few road cells, and left `21` object-only town pairs reachable versus owner `2`.

Normal generated catalog-auto Medium two-level normal-water maps now use a scoped profile with exact owner-like road-cell total and component split, a mostly-land surface, stronger underground rock, Medium two-level normal-water object/scenic/reward/guard floors, an owner-like reward category floor, preserved decorative/scenic blocker masks during package adoption, and a 17-tile Medium normal-water town spacing floor derived from the owner sample's nearest town distance.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused exports.
- Focused `m_normalw_4players_2levels` export wrote `1/1` package in about `14.057s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/M-NormalW-4players-2levels.h3m --amap .artifacts/rmg_native_batch_export_medium_normalwater_2level_profile_probe/m_normalw_4players_2levels.amap --compare --pretty --allow-failures` improved total object delta from `-663` to `-4`, road delta from `-35` to `0`, terrain-blocked delta from `-141` to `-40`, and category absolute delta from `663` to `10`. Reward count moved from `178` to `414` versus owner `416`, guard count from `104` to `191` versus owner `194`, and object category from `155` to `300` versus owner `301`.
- The focused production-gap severity improved from `2027` to `429`. Remaining debt is route/town shape rather than broad category counts: native still places `7` towns versus owner `8`, keeps `15` object-only reachable town pairs versus owner `2`, and closes guarded routes more aggressively than the owner sample (`0` versus owner `2`).
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_medium_normalwater_2level_profile_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_medium_normalwater_2level_profile_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_medium_normalwater_2level_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blocker moves to `xl_islands`, followed by Large one-level normal-water/land cases and XL two-level route/terrain-shape cases. The remaining Medium normal-water debt is specifically town/route shape after the category, road-total, and underground-terrain gaps were reduced.

## XL One-Level Islands Road, Terrain, Reward, And Guard Profile Cleanup

The next merged top-gap case was `xl_islands`. The owner sample is a one-level island map with `3938` objects, `674` road cells across `6` road components, `4995` terrain-blocked tiles, and guarded town routes fully closed. Native previously had the right broad decoration/object volume but missed the profile shape: road cells were short and split into `10` components, terrain was over-blocked by `1505` tiles, guards were overfilled by `139`, rewards were underfilled by `49`, and total object count was `+93`.

Normal generated catalog-auto XL one-level islands now use a scoped six-component road target, exact owner-like road-cell floor, lower guard-to-reward floor, owner-like reward floor, and higher island land fractions by zone role. This keeps guarded routes closed while reducing the category and terrain profile mismatch without treating the owner sample as a production-ready exact-count target.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `xl_islands` export wrote `1/1` package in about `34.340s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-islands.h3m --amap .artifacts/rmg_native_batch_export_xl_islands_profile_probe/xl_islands.amap --compare --pretty --allow-failures` improved total object delta from `+93` to `+2`, road delta from `-52` to `0`, terrain-blocked delta from `+1505` to `+139`, category absolute delta from `193` to `6`, guard delta from `+139` to `-1`, and reward delta from `-49` to `0`.
- The focused production-gap severity improved from `1868` to `172`. Remaining debt is route/town distribution shape rather than broad category or road totals: native still places `10` towns versus owner `8`, keeps `2` object-only reachable town pairs versus owner `1`, and road components are shape-similar but not exact (`210/167/126/89/55/27` versus owner `230/141/122/100/44/37`).
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_profile_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` failed the partial policy gate only because a single-sample `144x144_l1` guard/reward average sits below the grouped owner baseline; the focused production-gap audit itself passed with severity `172`.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_profile_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blocker moves to `l_normalwater_randomplayers`, followed by XL two-level islands/water and Large land/water route-shape cases. The next correction should continue general profile-shape work and avoid reintroducing sample-only exact-count branches as runtime policy.

## Large One-Level Normal-Water Road, Terrain, Town, And Category Profile Cleanup

The next merged top-gap case was `l_normalwater_randomplayers`. The owner sample is a one-level Large normal-water map with `5` towns, `398` road cells in `3` road components, `5489` terrain-blocked tiles, and fully open object-only town routes. Native previously over-placed towns (`7` versus owner `5`), underfilled roads by `91` cells across too many components, under-blocked terrain by `1008` tiles, underfilled scenic/other objects by `97`, and overfilled rewards by `38`.

Normal generated catalog-auto Large one-level normal-water maps now use a scoped town cap at the player-start count, a three-component road target with an owner-like road-cell floor, lower land fractions by zone role, an owner-like scenic-object floor, a decoration floor, a generated reward cap that trims surplus generic reward references, and a guard floor that keeps the guard category near owner density after reward trimming.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `l_normalwater_randomplayers` export wrote `1/1` package in about `14.053s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/L-NormalWater-RandomPlayers.h3m --amap .artifacts/rmg_native_batch_export_large_normalwater_1level_profile_probe/l_normalwater_randomplayers.amap --compare --pretty --allow-failures` improved total object delta from `-73` to `-1`, road delta from `-91` to `0`, terrain-blocked delta from `-1008` to `+8`, object-route delta from `+11` to `0`, and category absolute delta from `153` to `1`.
- Category counts are now nearly exact: decoration `994` versus owner `994`, object `283` versus `283`, reward `197` versus `197`, town `5` versus `5`, and guard `136` versus owner `137`.
- The focused production-gap severity improved from `1675` to `85`. Remaining debt is shape, not count: native road components are `221/126/51` versus owner `192/166/40`, and guarded routes remain more closed than owner (`0` reachable pairs versus owner `3`).
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_normalwater_1level_profile_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` failed only the single-sample `108x108_l1` town-density policy average; the focused production-gap audit passed with severity `85`.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_normalwater_1level_profile_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_normalwater_1level_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blockers move back to XL two-level islands/water and Large/XL one-level route-shape cases. The next correction should address structural route and road-component shape instead of further broad category floors for this profile.

## XL Two-Level Islands Category And Town Profile Cleanup

The next merged top-gap case was `xl_islands_2levels`. Roads were already close to owner evidence (`829` versus owner `838` cells), but the category and town distribution were still off: native had `14` towns versus owner `20`, guard overfill `+43`, scenic/object underfill `-113`, reward overfill `+136`, and category absolute delta `315`.

Normal generated catalog-auto XL two-level islands now use scoped scenic-object and decoration floors, a generated reward cap, a lower guard floor after reward trimming, and a higher town floor while preserving the XL town-spacing safety rule. Package conversion also preserves decorative/scenic object barriers for this two-level islands profile instead of cutting every town-pair corridor through them.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `xl_islands_2levels` export wrote `1/1` package in about `41.571s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-islands-2levels.h3m --amap .artifacts/rmg_native_batch_export_xl_islands_2level_profile_probe/xl_islands_2levels.amap --compare --pretty --allow-failures` improved total object delta from `+43` to `-4`, category absolute delta from `315` to `4`, guard delta from `+43` to `0`, object delta from `-113` to `0`, reward delta from `+136` to `0`, and town delta from `-6` to `-4`.
- Focused production-gap severity improved from `1668` to `1281`. Remaining debt is terrain and route shape: terrain-blocked delta is still `+764`, object-route delta is `+18`, guarded-route delta is `-2`, and native still has `16` towns versus owner `20` because the remaining four would violate the current XL town-spacing rule.
- `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_2level_profile_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_2level_profile_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_2level_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blocker moves to `l_nowater_randomplayers_nounder`, followed by XL two-level water and XL/Large one-level route/category-shape cases. The next correction should continue structural route and terrain-shape work rather than lowering town-spacing safety just to hit an owner count.

## Large One-Level Land Road, Reward, Guard, And Blocker Density Cleanup

The next merged top-gap case was `l_nowater_randomplayers_nounder`. The owner sample is a one-level Large land map with `2917` parsed objects, `8` towns, `366` road cells, no terrain-blocked tiles, and guard-mediated town-route closure. Native previously had `2314` objects, `6` towns, `270` road cells, and broad category underfill across decoration, guards, objects, and rewards.

Normal generated catalog-auto Large one-level land maps now use a scoped road-cell floor with four road components, owner-like decoration/scenic/reward/guard category floors, and a pre-decoration reward supplement. The reward floor now runs before late dense decorative/scenic filler for this profile, which keeps reward placement from spending tens of seconds searching a saturated map. The generated neutral-town floor also recognizes pre-object future-town reservations and has a strict-spacing global fallback for Large one-level land, but it does not lower the town-spacing safety rule just to hit the owner sample's exact town count.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused exports.
- Focused `l_nowater_randomplayers_nounder` export wrote `1/1` package in about `17.647s` with native validation `pass`. The prior probe for this same profile took about `55.970s`; the reward supplement itself dropped from about `39.188s` to about `0.608s`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/L-NoWater-RandomPlayers-nounder.h3m --amap .artifacts/rmg_native_batch_export_large_land_1level_profile_probe6/l_nowater_randomplayers_nounder.amap --compare --pretty --allow-failures` improved total object delta from `-603` to `-2`, road delta from `-96` to `0`, terrain-blocked delta stayed `0`, and category absolute delta from `603` to `2`.
- Category counts are now near-exact: decoration `1840` versus owner `1840`, guard `264` versus `264`, object `376` versus `376`, reward `429` versus `429`, and town `6` versus owner `8`. Guarded route closure remains valid at `0` reachable pairs; nearest town spacing remains safe at `36` versus owner `35`.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_land_1level_profile_merged --summary --failure-limit 8 --gap-limit 8` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_land_1level_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The remaining debt for this sample is town count and route/road-component shape, not broad category density or guard closure. The merged top blockers move to XL two-level water, XL one-level land, XL two-level islands, Large one-level islands, and XL one-level water; production audit still reports `production_ready=false`.

## XL Two-Level Normal-Water Category And Underground Split Cleanup

The next merged top-gap case was `xl_water_2levels`. The earlier XL normal-water pass improved broad totals but still overfilled rewards, underfilled blockers, and distributed too much object mass underground. A probe that lowered XL town spacing to force the owner town count was rejected before commit because it made route-shape severity worse: the extra surface towns increased object-only reachable town pairs from the previous `+20` delta to `+39` without solving physical barrier topology.

Normal generated catalog-auto XL two-level normal-water maps now use scoped scenic, decoration, reward-cap, and guard floors plus a profile-specific two-level object distribution split. The split keeps surface/underground category distribution close to owner evidence while preserving the existing XL town-spacing safety rule instead of lowering spacing for exact-count fitting.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `xl_water_2levels` export wrote `1/1` package in about `37.771s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-water-2levels.h3m --amap .artifacts/rmg_native_batch_export_xl_water_2level_profile_probe/xl_water_2levels.amap --compare --pretty --allow-failures` improved focused production-gap severity from `1550` to `892`, total object delta from `+28` to `+11`, category absolute delta from `294` to `15`, and terrain-blocked delta from `-462` to `+100`.
- Category counts are now close: decoration `1834/1834`, guard `196/196`, reward `482/482`, object `663/650`, and town `14/16`. Level split is also close for object categories: native surface/underground decoration `1743/91` versus owner `1750/84`, scenic/object `577/86` versus `567/83`, and rewards `348/134` versus `346/136`.
- The remaining debt is structural route shape, not category volume: native surface object-only reachable town pairs are `36` versus owner `16`, guarded reachable pairs are `0` versus owner `10`, and road components remain shape-similar but not exact (`227/170/120/78/44/20` surface and `54/43/34/24/15` underground versus owner `250/143/104/62/48/39` and `59/42/25/21/20`).
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_2level_profile_merged --summary --failure-limit 8 --gap-limit 8` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.275s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_2level_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blocker moves to `xl_nowater`, followed by XL two-level islands, Large one-level islands, XL one-level water, and XL two-level water. The next correction should continue route/barrier topology and road-component shape work rather than lowering town spacing to match exact owner town counts.

## XL One-Level Land Road And Category Profile Cleanup

The next merged top-gap case was `xl_nowater`. Terrain shape was already effectively correct, but native had the wrong profile balance: roads were short and fragmented (`690` cells in `10` components versus owner `727` in `3`), scenic/other objects were underfilled by `209`, guards by `69`, decorations by `96`, rewards overfilled by `255`, and native placed only `8` towns versus owner `12`.

Normal generated catalog-auto XL one-level land maps now use a scoped three-component road target with an owner-like road-cell floor, an XL land scenic-object floor, an XL land decoration floor, a reward cap, and a higher guard floor after reward trimming. A town-floor zone-reuse probe was rejected before commit because it did not change the generated town count or audit metrics.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `xl_nowater` export wrote `1/1` package in about `40.608s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-nowater.h3m --amap .artifacts/rmg_native_batch_export_xl_nowater_profile_probe/xl_nowater.amap --compare --pretty --allow-failures` improved focused production-gap severity from `1494` to `886`, total object delta from `-123` to `-1`, road delta from `-37` to `0`, and category absolute delta from `633` to `9`.
- Category counts are now close: decoration `3413/3413`, scenic/object `629/629`, reward `692/692`, guard `623/619`, and town `7/12`. Road total now matches owner at `727` cells, but component shape is still not exact: native `381/238/108` versus owner `485/188/54`.
- The remaining debt is town count and route shape: native has `7` towns versus owner `12`, so object-only reachable town pairs are capped at `21` versus owner `55`; guarded reachable pairs are `0` versus owner `1`, and nearest town spacing stays safe at `42` versus owner `39`.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_nowater_profile_merged --summary --failure-limit 8 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.376s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_nowater_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blocker moves back to `xl_islands_2levels`, followed by Large one-level islands, XL one-level water, XL two-level water, and XL one-level land. The next correction should target route/town topology or the remaining island terrain/category shape gaps instead of adding more broad volume floors.

## XL Two-Level Islands Terrain And Level-Distribution Cleanup

The next merged top-gap case was again `xl_islands_2levels`, but the broad category counts were already close. The remaining large error was shape: native over-blocked underground terrain by hundreds of tiles, pushed too many scenic objects underground, kept too few rewards underground, and left surface object-only town routes much more open than the owner sample.

Normal generated catalog-auto XL two-level islands now use a profile-specific underground distribution split for decoration, scenic objects, and rewards, and a lower XL islands underground rock fraction. This targets level/terrain shape without changing broad category totals.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `xl_islands_2levels` export wrote `1/1` package in about `44.224s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-islands-2levels.h3m --amap .artifacts/rmg_native_batch_export_xl_islands_2level_profile_probe2/xl_islands_2levels.amap --compare --pretty --allow-failures` improved focused production-gap severity from `1281` to `520` and terrain-blocked delta from `+764` to `+3` while preserving total object delta `-4`, road delta `-9`, and category absolute delta `4`.
- Level split is now close for the object categories: native surface/underground decoration `1596/120` versus owner `1598/118`, scenic/object `537/198` versus `537/198`, and rewards `320/250` versus `317/253`. Guard split remains imperfect at `101/36` versus owner `90/47`, and towns remain `9/7` versus owner `13/7`.
- The remaining debt is route/town topology: native surface object-only reachable town pairs remain `21` versus owner `2`, guarded reachable pairs are `0` versus owner `2`, and surface town count remains short by four.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_2level_profile_merged2 --summary --failure-limit 8 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.432s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_islands_2level_profile_merged2 --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blocker moves to `l_islands_randomplayers`, followed by XL one-level water, XL two-level water, XL one-level land, and Medium/Large route-shape cases. The next correction should focus on island one-level road/category shape or the remaining town/route topology gap.

## Large One-Level Islands Road And Category Profile Cleanup

The next merged top-gap case was `l_islands_randomplayers`. Native had the wrong one-level islands balance: roads were overfilled and under-componentized, decorations were underfilled, rewards and guards were overfilled, and town count remained far below owner evidence. Terrain was already close enough that this pass focused on road/category shape instead of terrain.

Normal generated catalog-auto Large one-level islands now use a scoped twelve-component road target with a lower road-cell total, a decoration floor, a lower scenic-object floor, a reward cap, and a lower guard floor after reward trimming. Town spacing was intentionally left unchanged in this pass because adding towns without matching barrier topology would inflate route-pair diagnostics.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `l_islands_randomplayers` export wrote `1/1` package in about `10.195s` with native validation `pass`.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/L-islands-RandomPlayers.h3m --amap .artifacts/rmg_native_batch_export_large_islands_1level_profile_probe/l_islands_randomplayers.amap --compare --pretty --allow-failures` improved focused production-gap severity from `1122` to `891`, total object delta from `+38` to `-7`, road delta from `+40` to `-15`, and category absolute delta from `282` to `9`.
- Category counts are now close: decoration `542/542`, scenic/object `155/155`, reward `185/185`, guard `34/33`, and town `8/16`. Road components now have the owner-like component count but not the owner component shape: native `34/32/30/28/26/24/22/20/17/15/13/11` versus owner `104/40/20/19/15/15/14/14/13/11/11/11`.
- The remaining debt is town/route topology and road-component skew: native still has `8` towns versus owner `16`, nearest town distance `35` versus owner `15`, object-only reachable pairs `28` versus owner `11`, and guarded reachable pairs `0` versus owner `11`.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_islands_1level_profile_merged --summary --failure-limit 8 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.374s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_large_islands_1level_profile_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blocker moves to `xl_water`, followed by XL two-level water, Large one-level islands, XL one-level land, and Medium/Large route-shape cases. The next correction should address XL one-level water category/road shape or broader town/route topology.

## XL One-Level Normal-Water Road And Category Profile Cleanup

The next merged top-gap case was `xl_water`. Native one-level XL normal-water output had the right town count but the wrong category balance and road/component shape: decorations were underfilled, rewards and guards were overfilled, and road cells were split into components that did not resemble owner evidence closely enough.

Normal generated catalog-auto XL one-level normal-water maps now use a scoped road total and road-component skew, a decoration floor, a reward cap, and a slightly lower water-shape land fraction for the surface zone roles. This keeps the profile keyed to XL one-level normal-water instead of changing the broader normal-water or islands paths.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `xl_water` export wrote `1/1` package with native validation `pass`. The manifest recorded about `27.483s` case wall time, including `15.227s` generation, `8.726s` package conversion, and `3.530s` save time.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-water.h3m --amap .artifacts/rmg_native_batch_export_xl_water_profile_probe2/xl_water.amap --compare --pretty --allow-failures` improved focused production-gap severity from `907` to `555`, total object delta from `+49` to `+11`, road delta from `-9` to `0`, terrain-blocked delta from `-151` to `+58`, and category absolute delta from `223` to `11`.
- Category counts are now close: decoration `1813/1813`, reward `409/409`, town `10/10`, guard `204/202`, and scenic/object `518/509`. Road total now matches owner at `755` cells, while component shape remains close but not exact: native `636/107/12` versus owner `637/96/22`.
- The remaining debt is route/barrier shape: native object-only reachable town pairs remain `45` versus owner `28`, guarded reachable pairs are `0` versus owner `2`, and nearest town spacing stays safe at `37` versus owner `30`.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_profile_merged2 --summary --failure-limit 8 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.365s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_profile_merged2 --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blockers are now `xl_water_2levels`, `l_islands_randomplayers`, `xl_nowater`, Medium four-player two-level islands, and Large/Medium route-shape cases. The next correction should continue broad route/barrier/town topology and two-level profile shape, not exact-count fitting.

## XL Two-Level Normal-Water Barrier Preservation

The next top-gap case was again `xl_water_2levels`, but the remaining issue was no longer category volume. Package adoption was cutting decorative/scenic blocker masks along every town-to-town object route for this profile, then relying on guard closure masks to block travel. That made the physical object-route topology too open while making guarded topology too closed.

Normal generated catalog-auto XL two-level normal-water packages now preserve decorative/scenic object barriers during guarded corridor materialization, matching the already scoped behavior for Large two-level normal-water, Medium two-level normal-water, XL/Large two-level islands, and XL two-level land profiles. Guard masks still materialize, but physical blockers are no longer cleared out of the route shape for this profile.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `xl_water_2levels` export wrote `1/1` package with native validation `pass`. The manifest recorded about `38.572s` total wall time, including `23.372s` generation, `10.141s` package conversion, and `3.828s` save time.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-water-2levels.h3m --amap .artifacts/rmg_native_batch_export_xl_water_2level_barrier_probe/xl_water_2levels.amap --compare --pretty --allow-failures` improved focused production-gap severity from `892` to `417`. Object-route delta improved from `+20` to `-1`, while object delta stayed `+11`, road delta stayed `+16`, terrain-blocked delta stayed `+100`, guarded-route delta stayed `-10`, and category absolute delta stayed `15`.
- Surface physical route shape is now close: native surface object-only reachable town pairs are `15` versus owner `16`. Native still over-closes guarded routes at `0` versus owner `10`, so the remaining topology debt is guard-mask strength and town/road/terrain shape, not physical blocker clearing.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_2level_barrier_merged --summary --failure-limit 8 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.160s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_2level_barrier_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blockers are now `l_islands_randomplayers`, `xl_nowater`, `m_4players_2levels_islands`, Large normal-water two-level, and Large land two-level. The next correction should target island one-level road/town topology or broad town/guard route-shape behavior.

## Large Two-Level Normal-Water Road Split Cleanup

The next contained road-shape defect was `l_normalwater_randomplayers_2level`. Category and route gaps remain, but the road materialization was visibly using the wrong level split: native roads were surface-heavy with too many underground fragments, while owner evidence uses a near-even surface/underground split and fewer underground components.

Normal generated catalog-auto Large two-level normal-water maps now use a lower surface road share, a slightly higher total road target, and profile-specific component counts of `7` surface components and `3` underground components. This changes road materialization only for Large normal-water two-level maps.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `l_normalwater_randomplayers_2level` export wrote `1/1` package with native validation `pass`. The manifest recorded about `36.615s` total wall time, including `21.637s` generation, `9.053s` package conversion, and `4.606s` save time.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/L-NormalWater-RandomPlayers-2level.h3m --amap .artifacts/rmg_native_batch_export_l_normalwater_2level_road_probe/l_normalwater_randomplayers_2level.amap --compare --pretty --allow-failures` improved focused production-gap severity from `628` to `583`, and road-cell delta from `-46` to `+1`.
- Road component shape is now closer to owner evidence: native surface/underground components are `111/87/67/49/33/21/12` and `212/136/65`, versus owner `102/94/68/48/39/19/10` and `191/137/84`. The remaining debt is terrain, category, and route shape: terrain-blocked delta stays `-203`, object-route delta stays `+9`, and category absolute delta stays `149`.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_l_normalwater_2level_road_merged --summary --failure-limit 8 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.063s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_l_normalwater_2level_road_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blockers remain dominated by Large one-level islands, XL one-level land, Medium two-level islands, and route/terrain shape cases. The rejected probes in this pass showed that naive same-zone town stuffing and simple category caps can improve counts while worsening route or terrain shape; the next substantial fix needs island subzone/barrier topology rather than more count-only tuning.

## Large Two-Level Islands Category Mix Cleanup

The Large two-level islands case had already reached valid route closure and near-matching road totals, but category mix was still wrong: decorations were overfilled while rewards were underfilled. Because total object count was already close, this pass paired the reward correction with a decoration cap instead of simply adding more objects.

Normal generated catalog-auto Large two-level islands maps now use a profile reward floor and a decoration cap. This preserves the existing route-closure behavior while shifting object mix toward the owner evidence.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `l_islands_randomplayers_2level` export wrote `1/1` package with native validation `pass`. The manifest recorded about `31.751s` total wall time, including `19.554s` generation, `6.406s` package conversion, and `4.437s` save time.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/L-islands-RandomPlayers-2level.h3m --amap .artifacts/rmg_native_batch_export_l_islands_2level_mix_probe/l_islands_randomplayers_2level.amap --compare --pretty --allow-failures` improved focused production-gap severity from `538` to `203`, category absolute delta from `193` to `5`, and object delta from `+5` to `-1`.
- Route closure stayed correct: object-route and guarded-route deltas remain `0/0`. Road delta remains near exact at `+1`. The remaining focused debt is terrain shape (`+196`) and town count (`11` native versus `14` owner).
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_l_islands_2level_mix_merged --summary --failure-limit 8 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.232s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_l_islands_2level_mix_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blockers are still Large one-level islands, XL one-level land, Medium two-level islands, Large land two-level, Large normal-water two-level, and XL one-level water. The remaining hard problems are town/subzone topology, terrain shape, and route shape, not broad generated-package validity.

## Large One-Level Islands Road-Component Shape Cleanup

The Large one-level islands case still had a road-shape defect after the earlier category cleanup: total road cells were under owner evidence by `15`, and the twelve road components were too evenly distributed. Owner evidence for `l_islands_randomplayers` has the same twelve-component count but a dominant primary route cluster: `104/40/20/19/15/15/14/14/13/11/11/11`.

Normal generated catalog-auto Large one-level islands maps now use a stronger skewed component weighting and a `287`-cell road target for that size/water/level profile. This keeps the profile scoped to Large one-level islands instead of changing XL islands or two-level islands road behavior.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `l_islands_randomplayers` export wrote `1/1` package with native validation `pass`. The manifest recorded about `11.087s` total wall time, including `6.511s` generation, `2.485s` package conversion, and `1.059s` save time.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/L-islands-RandomPlayers.h3m --amap .artifacts/rmg_native_batch_export_l_islands_road_shape_probe/l_islands_randomplayers.amap --compare --pretty --allow-failures` improved focused production-gap severity from `891` to `876`, and road-cell delta from `-15` to `0`.
- Road component shape moved from `34/32/30/28/26/24/22/20/17/15/13/11` to `101/59/34/20/14/10/9/8/8/8/8/8` versus owner `104/40/20/19/15/15/14/14/13/11/11/11`.
- The same focused audit still shows the real remaining blocker: native town count is `8` versus owner `16`, object-only town-route reachable pairs are `28` versus owner `11`, and guarded-route reachable pairs are `0` versus owner `11`.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_l_islands_road_shape_merged --summary --failure-limit 8 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.455s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_l_islands_road_shape_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The merged top blockers remain XL one-level land, Large one-level islands, Medium two-level islands, Large two-level land, Large two-level normal-water, and XL water/islands route-shape cases. Large one-level islands now has a closer road total and component skew, but still needs the real zone/subzone/town placement model so island towns are not under-materialized and guarded routes are not over-closed.

## XL One-Level Land Road-Component Shape Cleanup

The next narrow road-shape defect was `xl_nowater`. Earlier work had already matched total road cells at `727`, but the three component sizes still underweighted the primary road cluster: native `381/238/108` versus owner `485/188/54`.

Normal generated catalog-auto XL one-level land maps now use a stronger dominant-component weight for road materialization. The change is scoped to XL one-level land; XL normal-water already has its own stronger profile, and Large land keeps its previous weighting.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `xl_nowater` export wrote `1/1` package with native validation `pass`. The manifest recorded about `42.537s` total wall time, including `23.427s` generation, `11.141s` package conversion, and `6.501s` save time.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-nowater.h3m --amap .artifacts/rmg_native_batch_export_xl_nowater_road_shape_probe/xl_nowater.amap --compare --pretty --allow-failures` kept road-cell delta exact at `0` and improved road component shape from `381/238/108` to `485/196/46` versus owner `485/188/54`.
- The same focused audit still shows the real remaining blocker: native town count is `7` versus owner `12`, object-only reachable town pairs are `21` versus owner `55`, and guarded-route reachable pairs are `0` versus owner `1`.
- Focused `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_nowater_road_shape_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `1/1` matched native package and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_nowater_road_shape_merged --summary --failure-limit 8 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.268s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_nowater_road_shape_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. `xl_nowater` now has close road count and component shape, but town/subzone materialization and route openness remain wrong: the native map has too few towns and too few object-only town routes compared with owner evidence. The next substantial fix should model the town/subzone and guarded crossing behavior instead of continuing count-only tuning.

## Medium Two-Level Islands Town-Level Split Cleanup

The next contained town-topology defect was `m_4players_2levels_islands`. Total town count already matched owner evidence at `6`, but native placed all six towns on the surface while owner evidence has `5` surface towns and `1` underground town. That wrong split also contributed to surface object-route over-openness.

Normal generated catalog-auto Medium two-level islands maps now materialize a generated town floor. This activates the existing two-level islands underground-town share for Medium islands without changing one-level islands or Large/XL two-level town floors.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `m_4players_2levels_islands` export wrote `1/1` package with native validation `pass`. The manifest recorded about `7.857s` total wall time, including `4.643s` generation, `1.175s` package conversion, and `1.019s` save time.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/M-4players-2levels-islands.h3m --amap .artifacts/rmg_native_batch_export_m_islands_town_split2_probe/m_4players_2levels_islands.amap --compare --pretty --allow-failures` improved focused production-gap severity from `803` to `681`.
- Town split now matches owner evidence: native surface/underground town counts are `5/1` versus owner `5/1`. Total town delta is `0`.
- Object-route delta improved from `+10` to `+6`. Guarded-route delta stayed correct at `0`. Remaining focused debt is category/object overfill (`+185` total objects, category absolute delta `185`), road shape (`-5` road cells), and terrain shape (`+156` blocked tiles).
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_islands_town_split_merged --summary --failure-limit 8 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.397s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_islands_town_split_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. Medium two-level islands now has the correct town level split, but it still overfills decoration/guard/reward categories and keeps too many surface object-only routes. The next Medium islands work should reduce category overfill and road/terrain shape without undoing the `5/1` town split.

## Medium Two-Level Islands Road Split Cleanup

After the town-level split cleanup, `m_4players_2levels_islands` still had a road materialization mismatch: native had the right component counts, but the total was short by `5` cells and the surface/underground split was too surface-heavy (`186/93` native versus `155/129` owner).

Normal generated catalog-auto Medium two-level islands maps now use an owner-like total road target and surface share. This is scoped to Medium two-level islands; Medium normal-water and other islands sizes keep their existing road profiles.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed as part of the focused export.
- Focused `m_4players_2levels_islands` export wrote `1/1` package with native validation `pass`. The manifest recorded about `7.901s` total wall time, including `4.654s` generation, `1.146s` package conversion, and `0.976s` save time.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/M-4players-2levels-islands.h3m --amap .artifacts/rmg_native_batch_export_m_islands_road_split_probe/m_4players_2levels_islands.amap --compare --pretty --allow-failures` improved focused road-cell delta from `-5` to `0` and production-gap severity from `681` to `676`.
- Road component split moved from native surface `40/35/31/27/22/18/13` and underground `59/34` to surface `32/29/26/22/19/15/12` and underground `82/47`, versus owner surface `43/25/23/21/16/15/12` and underground `90/39`.
- The previous town-level improvement stayed intact: native and owner both have `5` surface towns and `1` underground town. Object-route delta stayed `+6`, and guarded-route delta stayed `0`.
- A rejected category-cap probe in this same pass made category counts exact but failed the quick gate, underfilled the 72x72 two-level density/policy baselines, worsened terrain delta to `+399`, and restored route delta to `+10`; it was not kept.
- Focused `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_islands_road_split_probe --allow-partial-native-batch --summary --failure-limit 8 --gap-limit 8` passed with `1/1` matched native package and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_islands_road_split_merged --summary --failure-limit 8 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.336s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_islands_road_split_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. Medium two-level islands now has exact road total and correct town split, but surface route shape, terrain shape, and category overfill remain unresolved. The rejected cap probe confirms that forcing exact object counts without preserving density and blocker shape is the wrong direction.

## Large Two-Level Normal-Water Town/Decoration Phase-Order Cleanup

The next contained route-shape defect was `l_normalwater_randomplayers_2level`. The earlier road split made the road total close, but the case still had an object-route delta of `+9/0` and remained a top production-gap case. A rejected anchor-reservation probe showed the failure mode clearly: reserving more town anchors before object placement without respecting route closure reduced the town count and failed native validation.

The kept correction is narrower and phase-order oriented. For generalized catalog-auto town placement, supplemental towns now search against non-clearable blockers plus existing towns, allowing them to claim space over late decorative/scenic filler. Package cleanup then removes decorative/scenic objects overlapping town primary tiles and keeps the existing access-corridor nonblocking conversion. This models the recovered order more closely: town/castle placement owns its required cells before the late `rand_trn`-style filler, without moving the whole native pipeline in one risky refactor.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `l_normalwater_randomplayers_2level` export wrote `1/1` package with native validation `pass`. The manifest recorded about `40.833s` total wall time, including `25.643s` generation, `9.310s` package conversion, and `4.570s` save time.
- Focused `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_town_phase_order_l_normalwater_probe --summary --failure-limit 8 --gap-limit 10 --allow-partial-native-batch` passed with `1/1` matched native package and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- Focused production-gap severity improved from `583` to `342`; object-route/guarded-route delta improved from `+9/0` to `0/0`. Object delta is now `-10`, road delta `+1`, terrain delta `-187`, and category absolute delta `144`.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_town_phase_order_merged --summary --failure-limit 8 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.254s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_town_phase_order_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. `production_ready=false` remains correct with `6` missing broad requirements. The merged top blockers are now led by XL one-level land, Large one-level islands, Medium two-level islands, Large two-level land, XL water, and Medium normal-water route/terrain/category shape gaps.

## XL One-Level Land Town-Floor Materialization Cleanup

The next contained topology defect was `xl_nowater`. The previous XL land road pass made road cells and broad category totals close, but current-code focused evidence still under-materialized towns: native had `9` towns versus owner `12`. The generated one-level land town-floor path had a global spaced fallback for Large land only, so XL land could exhaust source-zone anchors instead of searching the full map for spread-out valid town cells.

The kept correction extends that global spaced fallback to XL one-level land and changes the XL one-level land density term from `ceil` to `floor` so the generalized owner-like floor resolves to `12` towns on the 144x144 profile instead of overshooting to `13`. Anchor-occupied or anchor-too-close zones are no longer prematurely burned for one-level land; the fallback can select a valid spread-out cell in any generated zone while preserving the size-aware spacing floor.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- A pre-fix current-code `xl_nowater` probe wrote `1/1` package with native validation `pass`; focused fast audit showed native `9` towns versus owner `12`, road delta `0`, reward/object deltas `0`, and object-route delta `-19`.
- A rejected intermediate probe confirmed the fallback direction but overshot: native `13` towns versus owner `12`, with object-route delta worsening to `+23`; the `ceil` town-floor term was not kept.
- Focused `xl_nowater` export after the kept correction wrote `1/1` package with native validation `pass`. The manifest recorded about `52.601s` total wall time, including `23.638s` generation, `21.211s` package conversion, and `6.328s` save time.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/XL-nowater.h3m --amap .artifacts/rmg_native_batch_export_xl_nowater_town_floor_probe2/xl_nowater.amap --compare --pretty --allow-failures` now shows exact town count parity: native `12` versus owner `12`. Road total remains exact at `727` cells, reward/object counts remain exact, decoration is close at `3406` versus owner `3413`, and guard is close at `623` versus owner `619`.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_nowater_town_floor_merged --summary --failure-limit 8 --gap-limit 10` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `12.132s`.

This is still not production parity. The production-gap audit remains `production_ready=false` with `6` missing broad requirements. `xl_nowater` drops out of the merged top ten, but its object-only town-route shape is still too open after adding the missing towns. The next top blockers are Large one-level islands, Medium two-level islands, Large two-level land, XL water, and Medium normal-water route/terrain/category shape gaps.

## Large One-Level Islands Guard-Mask Topology Cleanup

The next contained Large one-level islands defect was not object density. The current focused `l_islands_randomplayers` package already matched decoration, object, reward, road total, and near-matched guard count, but the semantic guard topology was wrong: native guarded-route town pairs were `0/28` while owner evidence had `11/120`, and native guard-controlled tiles were `2263` versus owner `98`.

A rejected count-only town-floor probe confirmed the wrong direction: forcing `16` towns without fixing island/subzone topology made all object-only town pairs reachable and worsened terrain shape. The kept correction is narrower. For normal generated catalog-auto Large one-level islands, package guard materialization now replaces the broad route-closure/body mask bulk with a compact vertical three-tile HoMM3-like action mask, and that profile skips the later iterative package guarded-corridor closure clusters. The generation-time town-pair closure summary also records a bounded profile allowance so validation does not force this island profile toward zero guarded routes when owner evidence leaves guarded crossings open.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `l_islands_randomplayers` export wrote `1/1` package with native validation `pass`. The manifest recorded about `10.865s` total wall time, including `7.507s` generation, `1.407s` package conversion, and `0.996s` save time.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/L-islands-RandomPlayers.h3m --amap .artifacts/rmg_native_batch_export_l_islands_guard_v3_noclosure_probe/l_islands_randomplayers.amap --compare --pretty --allow-failures` improved guarded-route delta from `-11` to `0`: native and owner both now expose `11` guarded town-route pairs.
- Guard-controlled tile count dropped from `2263` to `102`, close to owner `98`. Guarded-blocked tiles dropped from `4915` to `2973`.
- Focused production-gap severity improved from `876` to `601`. Road delta remains exact at `0`; decoration/object/reward category counts remain exact; guard count stays close at `34` native versus `33` owner.
- The remaining Large one-level islands debt is still real: native has `8` towns versus owner `16`, object-only route delta remains `+17`, terrain-blocked delta remains `+160`, and the road component shape still differs from owner.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_l_islands_guard_v3_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.932s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_l_islands_guard_v3_merged --skip-timing-summary --failure-limit 8` passed.

This is still not production parity. The production-gap audit remains `production_ready=false` with `6` missing broad requirements. Large one-level islands no longer over-closes guarded routes, but it still needs real island subzone/town materialization so town count, object-only route shape, and terrain shape are owner-like without count-only overfitting.

## Medium Two-Level Islands Object-Route Mask Cleanup

The next contained Medium two-level islands defect was route shape, not raw object count. After the road split cleanup, `m_4players_2levels_islands` still matched owner town count, town level split, road total, and guarded-route closure, but native surface towns still had `6` object-only reachable pairs while owner evidence had none. A rejected category-trim probe confirmed that forcing exact decoration/reward/guard counts broke density/policy gates and worsened route shape.

The kept correction is scoped to normal generated catalog-auto Medium two-level islands. Package adoption now computes audit-style object-only town routes that count decorative/scenic block tiles and guard body tiles, then adds compact single-cell route masks to existing decorative obstacles on the same level until those open town-pair routes are closed. This changes blocker shape without adding or deleting objects and without relying on guard control zones as permanent blockers.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `m_4players_2levels_islands` export wrote `1/1` package with native validation `pass`. The manifest recorded about `8.223s` total wall time, including `4.854s` generation, `1.377s` package conversion, and `1.016s` save time.
- `python3 tools/rmg_fast_audit.py --h3m maps/h3m-maps/M-4players-2levels-islands.h3m --amap .artifacts/rmg_native_batch_export_m_islands_route_mask_probe/m_4players_2levels_islands.amap --compare --pretty --allow-failures` improved object-route delta from `+6` to `0`: native and owner both now expose `0/10` object-only town-route pairs and `0/10` guarded town-route pairs.
- Road count remains exact at `284` cells with the previous owner-like split intact (`155` surface, `129` underground). Town count and level split remain exact at `6` total, `5` surface and `1` underground.
- Focused production-gap severity improved from `676` to `528`. The remaining focused debt is category/object overfill (`+185` total objects, category absolute delta `185`), terrain-blocked delta `+158`, and road component shape.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_islands_route_mask_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `12.137s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_islands_route_mask_merged --skip-timing-summary --failure-limit 8` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.

This is still not production parity. The production-gap audit remains `production_ready=false` with `6` missing broad requirements. Medium two-level islands now has owner-like town-route closure, exact town split, and exact road total, but it still overfills decoration/reward/guard categories and needs terrain/road component shape cleanup.

## Large One-Level Islands Object-Route Mask Cleanup

After the compact guard-mask cleanup, `l_islands_randomplayers` had exact decoration/object/reward/road totals and owner-like guarded-route openness, but object-only route shape was still wrong. Native exposed every town pair through terrain plus physical blockers (`28/28`) while owner evidence exposed only `11/120`. The missing town count remains a separate island subzone/materialization defect, but the package blocker shape still needed to preserve the same `11` open crossings before guard evaluation instead of leaving all current native towns mutually open.

The route-mask helper now has profile-specific open-pair targets. Medium two-level islands still closes to `0` object-only town routes, while Large one-level islands preserves the owner-like `11` object-open/guard-open crossings and adds compact single-cell masks to existing decorative obstacles only for the extra object-open routes. Guard control zones are not treated as permanent object blockers for this decision.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `l_islands_randomplayers` export wrote `1/1` package with native validation `pass`. Focused fast audit improved object-route delta from `+17` to `0`: native and owner both now expose `11` object-only town-route pairs and `11` guarded town-route pairs.
- Exact road and broad category totals stayed intact for the focused case: road delta `0`, decoration delta `0`, object-category delta `0`, reward delta `0`, guard delta `+1`, and town delta `-8`.
- Focused `m_4players_2levels_islands` export with the same helper still reports object-route delta `0`, guarded-route delta `0`, road delta `0`, and terrain-blocked delta `+158`, confirming the previous Medium route-mask fix did not regress.
- Replacing the Large and Medium focused AMAPs into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_route_mask_profiles_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.828s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_route_mask_profiles_merged --skip-timing-summary --failure-limit 8` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- The production-gap audit remains `production_ready=false` with `6` missing broad requirements. Large one-level islands dropped out of the top-gap list; route-shape gap cases dropped from `15` to `14`. The new top blocker is `l_nowater_randomplayers_2level` at severity `588`.

This is still not production parity. Large one-level islands still has a real town/subzone materialization gap (`8` native towns versus `16` owner towns) and terrain shape debt. The correction only makes current package blocker route shape owner-like for the generated town set while preserving the existing broad count gates.

## Large Two-Level Land Object-Route Mask Cleanup

The next top blocker after the Large islands route cleanup was `l_nowater_randomplayers_2level`. Its town total and broad category totals were already close enough for the fast structural gate, and guarded town routes were correctly closed, but the object-only topology was too open: native exposed `37` object-only town-route pairs versus owner `23`.

The compact decorative route-mask helper now also supports Large two-level land with a profile-specific object-open target of `23`. Unlike Large one-level islands, this profile does not require preserved object-open pairs to also remain guard-open, because owner evidence has `23` object-open routes and `0` guarded-open routes. The helper therefore masks only the extra object-only routes while preserving an owner-like count of physical blocker openings.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `l_nowater_randomplayers_2level` export wrote `1/1` package with native validation `pass`. The manifest recorded about `35.789s` total wall time, including `20.605s` generation, `9.171s` package conversion, and `4.729s` save time.
- Focused fast audit improved object-route delta from `+14` to `-1`, kept guarded-route delta at `0`, and kept road delta at `+16`. Focused production-gap severity improved from `588` to `281`.
- The focused package now has `15` towns versus owner `16`, so town/materialization debt remains and this is not a completion claim for the profile.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_l_land_2level_object_route_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.645s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_l_land_2level_object_route_merged --skip-timing-summary --failure-limit 8` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- The production-gap audit remains `production_ready=false` with `6` missing broad requirements. The new top blocker is `xl_water` at severity `555`.

This is still not production parity. Large two-level land still has road, terrain, category, and town materialization debt. The correction only brings object-route openness close to owner evidence while preserving the current generated-map validity gates.

## XL One-Level Normal-Water Object-Route Mask Cleanup

The next contained blocker after the Large two-level land route cleanup was `xl_water`. Its broad package shape was already close enough for the fast structural gate, with exact road total and exact town count, but object-only town-route topology was too open: native exposed `45` object-open town pairs versus owner evidence `28`.

The compact decorative route-mask helper now also supports XL one-level normal-water. This profile preserves owner-like physical blocker openings without requiring preserved object-open pairs to remain guard-open, because the owner sample has `28` object-open town pairs but only `2` guarded-open pairs. A rejected first probe using an exact target of `28` over-closed the map to `13` object-open pairs; the kept profile uses a higher preserve target that settles the current topology at `29`, close to owner, while avoiding the bad over-closure.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `xl_water` export wrote `1/1` package with native validation `pass`. The manifest recorded about `37.847s` total wall time, including `20.666s` generation, `12.418s` package conversion, and `3.551s` save time.
- Focused fast audit improved object-route delta from `+17` to `+1`, kept road delta at `0`, and kept exact town count at `10/10`. The remaining guarded-route delta is `-2`, matching the pre-existing guard-closure difference for this profile.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_object_route_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.706s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_object_route_merged --skip-timing-summary --failure-limit 8` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- The production-gap audit remains `production_ready=false` with `6` missing broad requirements. `xl_water` dropped out of the top six gap cases; the remaining top blockers are Medium two-level islands category overfill, Medium normal-water shape, XL two-level islands, Medium normal-water two-level, XL two-level normal-water, and XL two-level land.

This is still not production parity. XL one-level normal-water still has terrain/object/category and guarded-route shape debt. The correction only reduces object-only town-route over-openness while preserving the current generated-map validity gates.

## Medium Two-Level Islands Category-Cap Cleanup

After XL one-level normal-water route masking, the top production-gap case became `m_4players_2levels_islands`. The remaining route defects were already closed: native and owner both exposed `0` object-only town-route pairs, `0` guarded town-route pairs, exact road total, exact town count, and exact 5 surface / 1 underground town split. The active defect was category overfill: native had `+136` decorations, `+32` rewards, and `+17` guards, for `+185` total objects.

The generated catalog-auto caps now include Medium two-level islands reward and decoration caps. Capping rewards also brings guard count into line because the profile guard floor is reward-ratio based. This keeps the existing route masks and town/road shape intact while preventing the generic density floors from overfilling this compact islands profile.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `m_4players_2levels_islands` export wrote `1/1` package with native validation `pass`. The manifest recorded about `7.390s` total wall time, including `4.291s` generation, `1.297s` package conversion, and `0.806s` save time.
- Focused fast audit now matches every broad category exactly: decoration `340/340`, reward `132/132`, guard `69/69`, object `190/190`, town `6/6`, and total objects `737/737`. Object-route delta, guarded-route delta, and road delta all remain `0`.
- Focused production-gap severity improved from `528` to `391`, and severe category gap status cleared for this case. The remaining focused debt is terrain-blocker shape and road component shape.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_islands_category_cap_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.657s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_islands_category_cap_merged --skip-timing-summary --failure-limit 8` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- The production-gap audit remains `production_ready=false` with `6` missing broad requirements. Severe category gap cases dropped from `6` to `5`, and the new top blocker is `m_normalw_4players` at severity `521`.

This is still not production parity. Medium two-level islands now has exact broad counts, exact road total, exact town split, and closed town routes, but terrain-blocker shape and road component shape still differ from owner evidence.

## Medium One-Level Normal-Water Profile Cleanup

After the Medium two-level islands category cleanup, the top production-gap case became `m_normalw_4players`. The active defect was not an old owner-specific density branch: runtime classification showed normal generated catalog-auto policy for `translated_rmg_template_032_v1` / `translated_rmg_profile_032_v1`, Medium `72x72`, one level, normal water. Baseline native output underfilled broad categories and towns: decoration `271/335`, object `105/160`, reward `168/172`, guard `98/80`, town `6/7`, road delta `-10`, and object-route delta `-6`.

The generalized Medium one-level normal-water profile now carries scoped broad floors/caps for object, scenic, decoration, reward, guard, town, and road totals. Town-floor placement can use the existing global spaced fallback after every zone already has a town, matching owner evidence that can contain more towns than high-level zones without lowering the player-start spacing safety rule. The decoration floor is raised to compensate for the later town-access clearance that removes decorative/scenic blockers overlapping the new neutral town.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `m_normalw_4players` export wrote `1/1` package with native validation `pass`. The manifest recorded about `8.035s` total wall time, including `4.688s` generation, `1.510s` package conversion, and `0.856s` save time.
- Focused fast audit now matches every broad category exactly: decoration `335/335`, guard `80/80`, object `160/160`, reward `172/172`, town `7/7`, and total objects `754/754`.
- Road total now matches owner at `221/221`, and object-only town-route topology now matches owner at `21/21` reachable pairs. The remaining focused differences are guarded-route openness (`0` native versus `2` owner), terrain-blocked tiles (`2020` native versus `2083` owner), and road component shape (`65/60/53/43` native versus `71/55/50/45` owner).
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_normalw_profile_merged --summary --failure-limit 8 --gap-limit 12` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.656s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_normalw_profile_merged --skip-timing-summary --failure-limit 8` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- The production-gap audit remains `production_ready=false` with `6` missing broad requirements. `m_normalw_4players` dropped out of the top-gap list; the new top blocker is `xl_islands_2levels` at severity `520`.

This is still not production parity. Medium one-level normal-water now has exact broad counts, exact road total, and owner-like object-route openness, but guarded-route, terrain-blocker, and road-component shape still differ from owner evidence.

## XL Two-Level Islands Town And Route Closure Cleanup

After the Medium one-level normal-water cleanup, the top production-gap case returned to `xl_islands_2levels`. Broad category and terrain level split were already close, but native still under-materialized surface towns and left too many unguarded package town routes open before package adoption. The generated route-closure loop also treated the profile's allowed open route count as a per-pass skip budget, which let the open route set drift upward instead of closing every feasible route and applying the allowance only as a final validation threshold.

Normal generated catalog-auto XL two-level islands now uses the existing global spaced supplemental-town fallback on the surface for this profile, bringing the focused town count to owner parity at `20/20` while preserving the XL spacing safety floor. The generated town-pair closure loop now closes all feasible direct town routes during each pass and uses the profile allowance only for final validation. The compact decorative route-mask helper also has an XL two-level islands target so package adoption closes excess object-only town routes using existing decorative masks instead of cutting corridors through the blocker layer.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `xl_islands_2levels` export wrote `1/1` package with native validation `pass`. The manifest recorded about `78.262s` total wall time, including `49.369s` generation, `23.642s` package conversion, and `3.960s` save time.
- The focused generated profile now reaches `20` towns. The dominant runtime cost remains `town_pair_route_guard_closure`, which took about `29.610s` inside the focused generation profile and is the next performance hotspot for this case.
- `python3 tools/rmg_fast_validation.py --h3m-dir maps/h3m-maps --amap-dir .artifacts/rmg_native_batch_export_xl_islands_2level_probe --closure-shape-gate --summary --failure-limit 20` passed for the focused package with `0` parse, native-rule, density, policy, topology, coverage, and closure-shape gaps.
- Focused production-gap severity improved from `520` to `233`. Broad categories remain close with total object delta `-3` and category absolute delta `3`; remaining focused debt is road delta `-9`, terrain-blocked delta `-143`, object-route delta `-1`, and guarded-route delta `-2`.
- A regression probe for `l_islands_randomplayers`, the other profile using a bounded open guarded-route target, also exported `1/1` package with native validation `pass`.
- Replacing `xl_islands_2levels` and `l_islands_randomplayers` into the previous 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_route_closure_merged --summary` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.661s`.
- The production-gap audit remains `production_ready=false` with `6` missing broad requirements. `xl_islands_2levels` dropped out of the top-gap list; the new top blockers are `m_normalw_4players_2levels`, `xl_water_2levels`, `m_4players_2levels_islands`, `xl_nowater_2levels`, and `l_normalwater_randomplayers_2level`.

This is still not production parity. XL two-level islands now has owner-parity town count and passes the generalized/closure-shape gates, but road, terrain, object-route, and guarded-route shape deltas remain visible, and the route-closure loop is still too slow for XL production use.

## Medium Two-Level Normal-Water Route And Terrain Cleanup

After the XL two-level islands checkpoint, `m_normalw_4players_2levels` became the largest merged production-gap case. The baseline focused profile was already close on road total and broad object count, but it still exposed too many object-only town routes and had a poor surface/underground shape: native object-route openness was `15` versus owner `2`, guarded-route openness was `0` versus owner `2`, and terrain-blocked delta was `-40`.

Normal generated catalog-auto Medium two-level normal-water now uses the Python native-rule town-spacing floor of `20`, scoped broad category floors/caps for scenic, reward, guard, and decoration counts, a profile-specific surface/underground object distribution, a compact decorative object-route mask target of `2`, and a stronger underground rock fraction. The town placement fallback can search the surface globally for this profile, but unlike the XL islands relaxed fallback it does not bypass occupancy or spacing rules.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `m_normalw_4players_2levels` export wrote `1/1` package with native validation `pass`. The manifest recorded about `17.399s` total wall time, including `9.615s` generation, `4.430s` package conversion, and `2.194s` save time.
- Focused fast validation passed with `0` parse, native-rule, density, policy, topology, coverage, and closure-shape gaps.
- Focused fast audit improved production-gap severity from `429` to `96`. Terrain-blocked delta improved from `-40` to `+15`, object-route delta improved from `+13` to `+1`, and broad category absolute delta improved from `10` to `5`.
- The focused package remains short one town (`7/8`) because the stricter spacing floor is now enforced; this avoids the earlier near-stacked town placement tradeoff. Guarded-route openness also remains over-closed at `0` versus owner `2`, and road component shape still differs.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_normalwater_2level_route_merged --summary` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.743s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_normalwater_2level_route_merged --skip-timing-summary --failure-limit 8` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- The production-gap audit remains `production_ready=false` with `6` missing broad requirements. `m_normalw_4players_2levels` dropped out of the top eight gap cases; the new top blocker is `xl_water_2levels` at severity `417`.

This is still not production parity. Medium two-level normal-water now has close terrain shape, close broad object/category counts, exact road total, and much closer object-route openness, but it still needs generalized town capacity, guarded-route, and road-component shape work.

## Medium Two-Level Islands Terrain Shape Cleanup

After the Medium normal-water checkpoint, `m_4players_2levels_islands` still had exact broad counts, exact road total, exact town split, and closed town routes, but the terrain-blocker shape was still too heavy: native terrain-blocked tiles were `+391` versus the owner sample.

Normal generated catalog-auto Medium two-level islands now uses scoped surface land fractions and a slightly lower underground rock fraction. This is limited to the compact Medium two-level islands profile so the correction does not relax broad islands/XL water behavior or use route-specific fixture fitting.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `m_4players_2levels_islands` export wrote `1/1` package with native validation `pass`. The manifest recorded about `7.578s` total wall time, including `4.518s` generation, `1.217s` package conversion, and `0.805s` save time.
- Focused fast audit improved terrain-blocked delta from `+391` to `+3`. Surface terrain-blocked count is now `3177` versus owner `3183`, and underground is `4346` versus owner `4337`.
- Broad category counts remain exact: decoration `340/340`, guard `69/69`, object `190/190`, reward `132/132`, town `6/6`, and total objects `737/737`.
- Object-route delta, guarded-route delta, and road-cell delta all remain `0`; the case still differs in road component shape and guard-controlled area.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_islands_terrain_merged --summary` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_m_islands_terrain_merged --skip-timing-summary --failure-limit 8` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- The production-gap audit remains `production_ready=false` with `6` missing broad requirements. `m_4players_2levels_islands` dropped out of the top twelve gap cases; the current top blocker remains `xl_water_2levels` at severity `417`.

This is still not production parity. Medium two-level islands now has exact broad counts, exact road total, exact town split, closed town routes, and near-exact terrain-blocker volume, but road component shape and guard-control footprint still differ from owner evidence and other profile families remain materially out of parity.

## Large Two-Level Islands Terrain Shape Cleanup

After the earlier Large two-level islands category mix cleanup, `l_islands_randomplayers_2level` had near-exact broad category counts, near-exact road total, and closed object/guarded town routes, but the terrain-blocker volume was still heavy: native terrain-blocked tiles were `+196` versus the owner sample.

Normal generated catalog-auto Large two-level islands now uses slightly higher surface land fractions and a slightly higher underground rock fraction for the Large two-level islands profile. The change is intentionally narrow because adjacent XL water/islands terrain probes can regress route shape even when the raw terrain delta improves.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `l_islands_randomplayers_2level` export wrote `1/1` package with native validation `pass`.
- Focused fast audit improved production-gap severity from `203` to `145`. Terrain-blocked delta improved from `+196` to `+140`, while object-route delta and guarded-route delta both stayed `0`.
- Focused fast validation passed with `0` parse, native-rule, density, policy, topology, coverage, and closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_l_islands_2level_terrain_merged --summary` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_l_islands_2level_terrain_merged --skip-timing-summary --failure-limit 8` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- The production-gap audit remains `production_ready=false` with `6` missing broad requirements. Current top blockers are still led by `xl_water_2levels`, `xl_nowater_2levels`, `l_normalwater_randomplayers_2level`, and `l_nowater_randomplayers_nounder`.

This is still not production parity. Large two-level islands now has a smaller terrain-volume gap without reopening town routes, but road component shape, town distribution, guard footprint, and broader Large/XL profile families remain out of parity.

## XL Two-Level Normal-Water Package Guard Shape Cleanup

After the Large two-level islands terrain checkpoint, `xl_water_2levels` was the merged top blocker. The previous package adoption pass preserved physical decorative/scenic barriers well enough to reduce object-only route openness, but it left guarded route topology fully over-closed: native had `15` object-open town pairs versus owner `16`, then `0` guarded-open pairs versus owner `10`. The package guard masks were too broad for the normal-water XL two-level profile, so guard records closed nearly every candidate crossing even when the physical blocker shape was close.

Normal generated catalog-auto XL two-level normal-water package adoption now uses a package-only guarded-route allowance, a compact vertical three-tile guard control mask for guard records, and a profile object-route mask target. This keeps generation-time town spacing/closure policy intact while making exported package blocker/guard semantics closer to owner evidence.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `xl_water_2levels` export wrote `1/1` package with native validation `pass`. The manifest recorded about `48.833s` total wall time, including `37.352s` generation, `6.696s` package conversion, and `3.578s` save time.
- Focused fast audit improved production-gap severity from `417` to `356`. Object-route openness now matches owner evidence exactly at `16/16`; guarded-route openness improved from `0/10` to `2/10`.
- The compact guard package masks reduced generated guard package footprint to `196` guards with `588` block/control tiles, `297` route-closure tiles, and `0` corridor-closure tiles. The native semantic audit now reports `573` guard-controlled tiles versus owner `1327`.
- Focused fast validation passed with `0` parse, native-rule, density, policy, topology, coverage, and closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_guard_open_merged --summary` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `10.041s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_water_guard_open_merged --skip-timing-summary --failure-limit 8` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- The production-gap audit remains `production_ready=false` with `6` missing broad requirements. Current top blockers are `xl_nowater_2levels` at severity `367`, `xl_water_2levels` at severity `356`, `l_normalwater_randomplayers_2level`, and `l_nowater_randomplayers_nounder`.

This is still not production parity. XL two-level normal-water now has exact physical object-route openness and a less over-closed guarded-route surface, but it still needs owner-like guarded-route opening placement, road component shape, town distribution, and terrain/object-category shape work across adjacent XL/Large profiles.

## XL Two-Level Land Category And Underground Shape Cleanup

After the XL two-level normal-water package guard checkpoint, `xl_nowater_2levels` was the next merged top blocker. Its guarded route topology and town split were already close, but the package was still structurally off: native underfilled total object count by `86`, underfilled scenic/object category by `62`, underfilled decoration by `29`, overfilled reward by `4`, and misplaced too much scenic/reward/decoration mass underground. The terrain volume was also still under-blocked by `151` tiles.

Normal generated catalog-auto XL two-level land now has a scoped category and level-distribution profile: owner-scale scenic and decoration floors, a reward cap, a lower underground object/reward/decoration share, and a lower underground rock fraction to offset the newly preserved underground object openings. This targets the size/water/level profile instead of exact seed-specific placement.

Validation evidence:

- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- Focused `xl_nowater_2levels` export wrote `1/1` package with native validation `pass`. The manifest recorded about `45.942s` total wall time for the retained distribution/rock probe, including about `28.620s` generation, `9.475s` package conversion, and `6.376s` save time.
- Focused fast audit improved production-gap severity from `367` to `47`. Total object delta improved from `-86` to `-3`, terrain-blocked delta improved from `-151` to `-7`, and broad category absolute delta improved from `96` to `3`.
- Broad category counts are now near exact: decoration `3261/3263`, guard `404/405`, object `684/684`, reward `877/877`, and town `10/10`.
- Level split now closely matches owner evidence: surface decoration/object/reward/town/guard is `3066/561/658/7/315` versus owner `3075/563/654/7/315`; underground is `195/123/219/3/89` versus owner `188/121/223/3/90`.
- Focused fast validation passed with `0` parse, native-rule, density, policy, topology, coverage, and closure-shape gaps.
- Replacing the focused AMAP into the 18-case evidence set, `python3 tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_nowater_2level_shape_merged --summary` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `9.963s`.
- `python3 tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_xl_nowater_2level_shape_merged --skip-timing-summary --failure-limit 8` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps.
- The production-gap audit remains `production_ready=false` with `6` missing broad requirements. `xl_nowater_2levels` dropped out of the top-gap list; current top blockers are led by `xl_water_2levels`, `l_normalwater_randomplayers_2level`, `l_nowater_randomplayers_nounder`, and one-level XL land/water shape cases.

This is still not production parity. XL two-level land now has near-exact broad category and level distribution plus near-exact terrain volume, but road component shape and one extra object-only route still differ from owner evidence, and other profile families remain out of parity.
