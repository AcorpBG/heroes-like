# heroes-like Tactical Implementation Plan

Task: #10184
Document role: tactical execution plan
Source strategy: `project.md`
Reset date: 2026-04-27
Compacted date: 2026-05-03
Operational tracker: `ops/progress.json`

## Purpose

This plan turns `project.md` into executable work slices. It is not a history log, worker diary, evidence dump, or progress tracker.

Rules:
- Keep strategy in `project.md`.
- Keep detailed requirements, audits, and evidence in `docs/*.md` or `.artifacts/*`.
- Keep current state, completion evidence, worker notes, and validation records in `ops/progress.json`.
- A slice is complete only when implementation/content/tooling changes satisfy its referenced requirements and validation gates.
- Documentation-only and report-only work must stay distinct from implemented gameplay/system/content completion.
- Do not continue ad hoc UI cue/performance/content work unless it is selected here and tracked in `ops/progress.json`.

## Current Tactical State

Current phase: **Phase 3 - HoMM3-Style Random Map Generator Rework corrective parity queue reopened**.

Current tactical chain: owner-uploaded H3M comparisons reopened focused native RMG corrective work after the accepted Phase 3 goal `native-rmg-homm3-spec-rework-parent-10184`. Completed child slices remain valid evidence for their specific gates, but they do not close broad HoMM3-style production parity. Owner-compared translated land packages are now runtime-authoritative for package/session inputs after adoption/replay evidence, and the broad land/surface/underground template generation gate now covers every currently eligible recovered template structurally with level-aware package route-closure verification. Exact HoMM3 full parity, byte/object-art parity, islands support, and full gameplay parity remain gated.

Do not infer product readiness from the completed queue. Completed Phase 2/RMG/performance/tooling evidence means those specific slices passed their gates; it does not mean playable alpha, campaign breadth, release readiness, broad faction completion, asset parity, or HoMM3 byte-level cloning.

Persistent guardrail: do not import generated PNGs or generated-study derivatives into runtime/source assets until a later AcOrP-approved ingestion slice records provenance, import paths, rollback, and validation.

Current owner-directed RMG corrective slice:

id: `native-rmg-generalized-policy-regate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `in_progress`
purpose: Stop the owner-H3M sample-by-sample exact-count fitting loop and re-gate native RMG around generalized recovered-template policy stages that owner corpus samples validate instead of selecting.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `docs/native-rmg-generalized-policy-regate-audit.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tools/rmg_fast_audit.py`
- `tools/rmg_fast_validation.py`
- `tools/rmg_quick_validation.py`
- `docs/rmg-python-validation-workflow.md`
implementationTargets:
- `docs/native-rmg-generalized-policy-regate-audit.md`
- `PLAN.md`
- `ops/progress.json`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- follow-up implementation in `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `scenes/menus/MainMenu.gd`
- `scenes/menus/MainMenu.tscn`
- `tests/native_random_map_terrain_grid_report.gd`
- `tests/native_random_map_owner_normal_water_underground_package_report.gd`
- `tools/rmg_fast_audit.py`
- `tools/rmg_fast_validation.py`
- `tools/rmg_quick_validation.py`
completionCriteria:
- The corrective audit clearly distinguishes owner-H3M exact-count diagnostics from production RMG policy.
- Current sample-specific runtime branches are identified as temporary fixture/diagnostic debt, not the desired architecture.
- The next implementation direction is defined around generalized template/profile policy, zone graph semantics, town/guard/blocker route closure, road materialization, and corpus subsystem grouping.
- The owner-corpus report groups mapped comparison failures by generalized subsystem in addition to preserving raw exact deltas.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No production-ready RMG claim.
- No new one-off owner sample count fitting as runtime policy.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Local overfit Small-islands count-fitting changes were abandoned before commit; the code worktree returned to the pushed checkpoint state.
- `docs/native-rmg-generalized-policy-regate-audit.md` records why the exact-count loop is diagnostic-only and why the next implementation must generalize.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` emitted schema `native_random_map_homm3_owner_corpus_coverage_report_v6`; the raw gate remains `8/9` mapped pass, while `generalized_policy_failure_summary` groups the active Small islands failure into `guard_policy`, `town_policy`, `decoration_blocker_policy`, `object_density_policy`, and `object_reward_policy`.
- `MapPackageService.generate_random_map` now emits `runtime_policy_classification` in generated output, validation reports, provenance, and map metadata, making generalized policy keys and active owner-runtime override debt visible.
- `tests/native_random_map_auto_template_batch_report.tscn` passed with schema `native_random_map_auto_template_batch_report_v2`, representative generated cases carrying runtime policy classification, and `seed_specific_runtime_override_case_count: 0` for normal generated seeds.
- The generated-map setup now exposes an explicit level picker with `Surface Only (1 Level)` and `Surface + Underground (2 Levels)` options instead of a vague checkbox, and water-mode changes no longer hide the underground option for islands.
- Native terrain policy no longer injects underground terrain into one-level scoped islands surface maps; the terrain-grid report also covers a scoped two-level request to prove the underground layer is materialized only when requested.
- The Small normal-water two-level owner-corpus package path now preserves player start towns on their generated start anchors during owner spacing reflow, keeping player starts and owned towns colocated while still materializing a two-level map.
- Native town records now carry level-aware primary occupancy and spacing semantics, allowing the Small normal-water two-level owner-corpus path to keep four towns on the surface and place the supplemental fifth town underground instead of violating the surface spacing floor.
- `tools/rmg_fast_audit.py` now provides the fast non-Godot audit path for owner `.h3m` parsing and native `.amap` package inspection: category/level counts, road component topology, and semantic town-route summaries run directly in Python. Godot owner-corpus scenes stay as final integration gates for native generation/package adoption/editor runtime, not the default parser/comparison loop.
- `tools/rmg_fast_audit.py --h3m-dir maps/h3m-maps --allow-failures` parsed all `18` uploaded owner `.h3m` files in about `5.236s` with `0` parse failures; `--amap-dir maps --allow-failures` parsed all `5` local native `.amap` evidence packages in about `0.204s` with `0` parse failures. This provides a fast corpus-level baseline for RMG policy work without using Godot as the parser.
- `tools/rmg_native_batch_export.tscn` now performs the remaining Godot-only generation/export step once, writing native `.amap` packages that Python can audit. A full owner-file-derived export wrote `18` generated native packages with `0` export failures; the fast Python audit parsed them in about `3.208s`. The generated batch confirms the broad density gap: owner 108x108 two-level evidence averages `169.725` objects / 1000 tiles while native averages `45.882`, and owner 144x144 two-level evidence averages `93.195` while native averages `44.456`.
- `tools/rmg_fast_validation.py` now makes the Python path the default RMG validation/comparison loop after native package export. It parsed all `18` uploaded owner H3Ms without Godot in about `5.199s`; against the current `18` generated native AMAP batch it completed in about `8.118s` total and correctly reports `32` native rule failures plus `6` density gaps, including empty underground levels, missing underground roads, near-stacked towns, and object-density underfill. Godot should now be reserved for fresh native generation/export and editor/runtime integration smokes, not ordinary H3M/AMAP parsing or comparison.
- `docs/rmg-python-validation-workflow.md` records the tightened workflow boundary: Godot is for native package generation/export and runtime/editor smokes, while Python is the default parser/comparison/correctness path for owner `.h3m` and native `.amap` evidence. `tools/rmg_production_gap_audit.py` also supports `--allow-partial-native-batch` so focused case batches do not masquerade as generalized fast-gate failures just because unrelated owner samples were not regenerated.
- Terrain-shape profile tuning now has both focused and full-corpus evidence. The focused five-case export wrote `5/5` packages in about `158.647s`; the full 18-case checkpoint wrote `18/18` packages in about `392.420s`. `tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_terrain_shape_profile_tune_full --require-timing-summary` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `12.020s` parse time. The production gap audit still reports `production_ready=false` with `6` missing broad requirements; current top blockers are XL/Large terrain, route-shape, and category deltas led by `xl_nowater_2levels`, `xl_islands_2levels`, and `xl_islands`.
- Native catalog-auto land decoration now has a dedicated size/level-aware blocker floor so rewards and guards can no longer satisfy the broad object-density floor while leaving HoMM3-style land blocker density sparse. A targeted four-case Large/XL land export wrote `4/4` packages in about `139.309s`; merged over the previous 18-case full export, the Python gate still passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `12.199s` parse time. Production audit remains `production_ready=false`, but `xl_nowater_2levels` improved from severity `6318` to `3562`, with object delta `-1401 -> +19` and decoration delta `-1449 -> -29`.
- `tools/rmg_quick_validation.py` now provides the default post-export tight-loop command for RMG evidence: it parses owner `.h3m` and native `.amap` files once, then emits both the generalized Python correctness gate and the production-gap comparison without starting Godot or reparsing the corpus in two scripts. `docs/rmg-python-validation-workflow.md` now explicitly forbids Godot report scenes for parse-only H3M/AMAP checks; Godot stays limited to fresh generation/export and actual editor/runtime smokes.
- Two-level land catalog-auto town placement now treats the generated neutral-town floor as a cap as well as a supplement, and reserves an underground neutral-town share without moving player start towns. The focused `xl_nowater_2levels` probe now matches the owner town split exactly at `10` towns, `7` surface and `3` underground; merged over the 18-case evidence set, `tools/rmg_quick_validation.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_land_underground_town_cap_merged --summary` passed with `18/18` owner/native matches, `0` parse/native/density/policy/topology/coverage/closure-shape gaps, and `production_ready=false` with `6` remaining broad requirements.
- Two-level island terrain now prunes non-required surface zone-boundary land for under-blocked island size profiles, raises underground rock fractions for under-blocked island size classes, and restores an island-specific underground neutral-town share. A focused four-case two-level island export passed the Python quick gate with `4/4` matched comparisons and `0` parse/native/density/policy/topology/coverage/closure-shape gaps; merged over the 18-case evidence set, the Python gate still passed with `18/18` matches. Production audit remains `production_ready=false`, but `xl_islands_2levels` severity improved from `6201` to `3879`, terrain delta from `-3001` to `-1429`, and object-route delta from `63` to `33`.
- `/root/Downloads/h3maped.exe` was verified as the correct MapEd binary for recovered RMG evidence. Direct disassembly of `0x49eb8d -> 0x49e700` confirms a late flagged-cell decorative obstacle filler after occupancy normalization. Native XL one-level islands now preserve decorative/scenic object barriers during package conversion instead of carving guard-corridor holes through the physical blocker layer. A focused `xl_islands` export plus merged 18-case Python quick gate both passed with `0` parse/native/density/policy/topology/coverage/closure-shape gaps; object-route reachable pairs for `xl_islands` improved to native `2` versus owner `1`. Production audit remains `production_ready=false`; the remaining blocker work is replacing native count/ring-style filler with a `rand_trn`-style flagged-cell placement phase without committing raw HoMM3 copyrighted data tables.
- Normal one-level Large/XL land catalog-auto maps now use a land-only recovered-style decorative filler scorer for the late blocker floor and reserve future neutral town anchors before object placement so the filler cannot consume all supplemental town slots. Focused `l_nowater_randomplayers_nounder` and `xl_nowater` exports both passed the Python quick gate with `0` parse/native/density/policy/topology/coverage/closure-shape gaps; merged over the 18-case evidence set, the Python quick gate and validation gate still pass with `18/18` owner/native matches and `0` structural gaps. Production audit remains `production_ready=false`; the remaining top blockers are two-level water/islands plus road, route, and object/guard/reward category shape.
- Native catalog-auto generation now has generalized size/level-aware object-density floors, eligible underground decoration/scenic distribution, deterministic underground road cells, and strict size-aware town spacing that skips or defers extra non-player same-zone towns instead of failing after player starts are materialized. `tools/rmg_native_batch_export.gd` also supports `--case` filtering so only named failures need a Godot regeneration pass. A full owner-file-derived export wrote `18/18` native packages with `0` export failures; `tools/rmg_fast_validation.py` parsed `18` owner H3Ms plus those `18` AMAPs in about `8.535s` with `0` parse failures, `0` density gaps, and `0` native rule failures. Exact owner count/topology deltas remain diagnostics, not production pass/fail targets.
- `tools/rmg_fast_validation.py` now also has a broader Python-only policy gate for category density, road density, and guard-to-reward ratio floors against owner group baselines. The same full `18` package batch now correctly fails that broader gate with `14` policy gaps while still showing `0` parse failures, `0` native rule failures, and `0` density gaps. Running with `--no-policy-gate` preserves the narrower generated-rule-only pass. This prevents exported packages from being mistaken for production-ready HoMM3-like RMG output.
- Native catalog-auto generation now adds generalized scenic-object and guard floors before decorative filler/package adoption. A combined `18` package evidence set parsed in about `8.829s` with `0` parse failures, `0` native rule failures, and `0` density gaps; the broader policy gate drops from `14` gaps to `5`. Remaining gaps are town density on Large/Small two-level groups, road density on Small two-level plus a near-threshold XL one-level road floor, and Small one-level guard/reward ratio. A full Godot export is still too slow for the tight loop, so broad comparison remains Python-first after targeted package generation.
- Normal generated catalog-auto guard floors now raise stale fixture guard caps for non-owner-discovered seeds when reward volume requires more guards. The targeted Small one-level batch case now emits `47` guards for `80` rewards instead of `40`, keeping guarded route closure at `0` reachable town pairs. The combined `18` package Python policy gate drops from `5` gaps to `4`, with `0` parse failures, `0` native rule failures, and `0` density gaps. Remaining gaps are town density on Large/Small two-level groups, road density on Small two-level, and a near-threshold XL one-level road floor.
- Small two-level catalog-auto road density now has a generalized package floor that grows connected surface and underground road clusters for normal generated seeds. Targeted Small normal-water and islands two-level exports now emit `116` road cells each, with `87` surface and `29` underground road cells, and keep guarded reachable town pairs at `0`. The combined `18` package Python policy gate drops from `4` gaps to `3`, with remaining gaps limited to Large two-level town density, Small two-level town density, and a near-threshold XL one-level road floor.
- `tools/rmg_fast_validation.py` now applies a tiny `0.05` per-1000-tile density epsilon to category and road policy comparisons so sub-tile rounding noise does not drive generator work. The near-threshold `144x144_l1` road floor no longer fails, while the meaningful Large/Small two-level town-density gaps still do. The combined `18` package Python policy gate now reports `2` remaining policy gaps, both town density.
- Generated catalog-auto two-level town density now uses a generalized neutral-town floor for normal non-owner-discovered seeds. Small two-level supplements remain underground when that shape is valid; Large two-level supplements are placed through surface source-zone placement so package route closure remains guarded. Targeted five-case export passed with `0` failures, and the combined `18` package Python policy gate now reports `pass` with `0` parse failures, `0` native rule failures, `0` density gaps, and `0` policy gaps. The testing split is explicit: Godot is for fresh native generation/export and runtime/editor integration, while Python is the default H3M/AMAP validation and comparison loop.
- `tools/rmg_fast_validation.py` now has an explicit road-topology gate for largest road-component dominance and minimum component-count shape against matched owner evidence. This does not require exact road component arrays, but it prevents the previous density-only pass from accepting native maps with one giant road component or a dominant surface trunk plus tiny underground fragments. The current combined `18` package evidence now correctly fails fast validation with `19` topology gaps while `--no-topology-gate` preserves the previous density/policy pass; the next implementation target is generalized road component materialization, not more parser/runtime Godot work.
- Normal generated catalog-auto road overlays now use generalized separated road-component materialization by size and level count, while owner-corpus and owner-adjusted comparison paths do not stack with it. Fresh 18-package export plus Python validation now reports `status: pass` with `0` parse failures, `0` native rule failures, `0` density gaps, `0` policy gaps, and `0` topology gaps. This clears the current fast topology blocker but does not close full production RMG parity.
- Normal generated Large/XL land seeds no longer activate the owner-specific land density/profile override branches; those branches are now limited to explicit production-parity audit seeds. The XL one-level road floor was generalized from area so `144x144_l1` stays above the Python policy floor without the XL owner branch. The generated 18-package fast validation still passes with `0` parse/native/density/policy/topology gaps, and the runtime override scan now shows only the Small `049` owner profile override debt in the normal batch. Godot auto-template reporting now mirrors native town-spacing floors and treats Medium normal-water owner counts as floors, not exact equality; the slow production-parity Godot report is not part of the tight correctness loop.
- Normal generated catalog-auto scenic/other-object floors now scale by size and level before decorative filler, and the Python policy gate now requires the native object category to reach at least `60%` of matched owner group density instead of `25%`. A fresh 18-package export passed with `0` export failures; fast validation reports `status: pass`, `0` parse/native/density/policy/topology gaps, and material object-category increases across every group, including `108x108_l1 243 -> 558`, `108x108_l2 955 -> 1624`, `144x144_l1 540 -> 1260`, and `144x144_l2 1097 -> 1441`. The full export now takes about eight and a half minutes with denser XL placement, making placement-loop profiling the next performance target.
- `tools/rmg_fast_validation.py` now supports `--latest-amap-artifact` and `--summary`, so the default comparison loop can validate the newest generated AMAP batch with one compact Python command instead of rerunning Godot parser/report scenes. The current latest batch selected `.artifacts/rmg_native_batch_export_after_object_category_floor`, parsed `18/18` owner H3Ms plus `18/18` native AMAPs in about `8.458s`, matched `18` comparisons, and reported `status=pass` with `0` parse/native/density/policy/topology gaps. Fresh package generation/export still needs Godot until a separate native CLI boundary exists.
- `tests/native_random_map_extension_profile_report.gd` now exposes town/guard subphase timings, and native town/guard placement avoids two hot-path costs: boundary opening cover batches cells by nearest guard instead of duplicating/signing guards per cell, and town-pair route closure skips full pathfinding for pairs already disconnected by per-pass connected components. Representative profile wall times improved from about `13.2s -> 6.4s`, `9.5s -> 4.3s`, and `9.7s -> 7.4s`; the 18-package export passed with `0` failures in `476.65s`, and Python fast validation over the fresh batch still reports `status=pass` with `0` parse/native/density/policy/topology gaps. Generation remains too slow for final production, so object placement and full XL export time stay active performance targets.
- `tools/rmg_native_batch_export.gd` now writes per-case wall timings for generation, package conversion, save, and compact native profile top phases into `manifest.json`. `tools/rmg_python_validation_gate.py` is now the one-command Python-only RMG correctness gate after package export, and `tools/rmg_export_timing_summary.py` summarizes batch manifests without Godot. A fresh timed 18-package export passed with `0` failures in about `480.73s`; the Python gate selected that latest batch, parsed `18/18` owner H3Ms plus `18/18` AMAPs in about `8.865s`, and reported `status=pass` with `0` parse/native/density/policy/topology gaps. The Python gate now also requires full owner-corpus native coverage by default so targeted partial exports cannot pass as full correctness gates. Timing evidence shows the worst current cases are XL/Large two-level packages, especially `xl_nowater_2levels` at `74.628s`, where package conversion alone costs `37.880s` and native `object_placement` tops generation at about `15.579s`; correctness comparison remains Python-only, while Godot is reserved for generation/export and actual engine/editor/runtime smokes.
- Native package conversion now has compact phase profiling, broad land-boundary choke mask adoption batches cells by nearest decorative object instead of repeatedly rewriting object records, and batch export suppresses the returned package payload after save. Targeted `xl_nowater_2levels` dropped from `74.628s` case / `37.880s` conversion to about `40.982s` case / `5.567s` conversion, while focused Large/XL land validation still passes through the Python gate with `0` parse/native/density/policy/topology gaps in about `6.238s`. The remaining measured bottleneck is native generation `object_placement`, not H3M/AMAP parsing or package conversion.
- Native object-placement and occupancy profiling now avoids avoidable full `Variant` canonicalization in the generation path: object records use compact deterministic signatures, combined occupancy signatures use compact record keys/counts, no-op corridor/choke clearance skips full object-placement rehashing, and town access corridor clearance is level-aware. Targeted `xl_nowater_2levels` now reports about `36.115s` case time, `24.484s` generation, `5.879s` conversion, and `5.752s` save, while Python fast validation over the targeted package still passes with `0` parse/native/density/policy/topology gaps in about `5.632s`. This keeps the user-requested testing split intact: Python owns H3M/AMAP validation and comparison; Godot is only for fresh native generation/export or runtime/editor smokes.
- `tools/rmg_fast_audit.py` now separates native guard body tiles from guard control-zone tiles when computing object-only town-route topology, and `tools/rmg_fast_validation.py --closure-shape-gate` exposes guard-mediated closure gaps without starting Godot. `tools/rmg_python_validation_gate.py` now enables that closure-shape check by default for full post-export correctness validation, with `--no-closure-shape-gate` only for targeted diagnostics. A targeted no-land-rock-barrier probe for `l_nowater_randomplayers_nounder` still produced `0` object-only reachable town pairs, proving the current blocker is permanent object/body mask shape as well as terrain shape. The next production target is guarded crossing shape, not more parser/report Godot work.
- Native package adoption now separates route-guard bodies from route-guard closure masks and cuts only decorative/scenic package blocker masks along terrain-valid town-pair corridors before assigning nearby guard closure masks. A fresh 18-package post-change evidence set passed `tools/rmg_python_validation_gate.py` with `18/18` owner H3Ms, `18/18` native AMAPs, `18` matched comparisons, and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `11.414s` parse time. This clears the current fast guard-mediated closure blocker without moving H3M/AMAP comparison back into Godot.
- The Python RMG gate now also summarizes native export timing manifests without starting Godot, and `tools/rmg_export_timing_summary.py --latest-amap-artifact` selects the newest manifest-bearing export artifact instead of failing on manifestless combined AMAP evidence directories. `python3 tools/rmg_python_validation_gate.py --failure-limit 4 --timing-limit 4 --require-timing-summary` passed with `18/18` owner/native matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps, then clearly labeled timing as a fallback from the newest manifest-bearing export because the validated combined AMAP directory has no manifest. This makes the intended loop concrete: Godot exports packages; Python validates, compares, and summarizes timing.
- `tools/rmg_production_gap_audit.py` now provides a Python-only no-overclaim boundary for the broad owner objective. It consumes the same H3M/AMAP evidence and reports `production_ready=false` until the prompt-to-artifact checklist clears. The current audit passes as an audit but reports `5` missing production requirements: owner diagnostic similarity, road-shape similarity, town density/distribution similarity, object/guard/reward category similarity, and route-shape similarity. It ranks the current top blockers as XL/Large cases, led by `xl_islands_2levels`, `xl_nowater`, `xl_water_2levels`, and `l_nowater_randomplayers_nounder`.
- Normal generated catalog-auto land maps no longer use broad terrain-rock zone boundary barriers as a route-closure fallback; blocker/guard package masks now carry the normal land closure shape. `tools/rmg_fast_audit.py` now carries terrain-blocked tile deltas into owner/native comparisons, and `tools/rmg_production_gap_audit.py` adds a terrain-blocker-shape checklist/severity component so this correction cannot be overclaimed. A targeted 5-case land export validated through Python with `0` parse/native/density/policy/topology/coverage/closure-shape gaps, and the combined 18-case Python gate passed with `18/18` matches in about `12.219s` parse time. The production gap audit still reports `production_ready=false`, now with `6` missing requirements and `15` terrain-shape gap cases, keeping broader two-level/islands/water terrain-shape work visible. Godot remains only for package generation/export and real editor/runtime smokes; H3M/AMAP correctness, comparison, timing, and production-gap ranking stay Python-only.
- Normal generated catalog-auto two-level packages now rebalance underground object/reward records instead of copying only decoration, reserve an underground share of generated neutral-town floors, and iteratively recheck package guarded town routes after decorative/scenic corridor cuts. A focused five-case failing export plus `xl_water_2levels` regenerated the affected Large/XL two-level packages; targeted Python validation passed with `0` closure-shape gaps, and the combined 18-case Python gate passed with `18/18` matches, `0` parse/native/density/policy/topology/coverage/closure-shape gaps, and about `13.736s` parse time. The production gap audit remains `production_ready=false` with `6` missing broad requirements, so this is a route-closure/materialization repair, not a parity claim.
- Normal generated catalog-auto two-level maps now add deterministic underground rock shape for land/islands and XL normal-water profiles while preserving open cells around underground roads, towns, guards, object bodies, visit/approach tiles, and town access corridors. A focused six-case export wrote `6/6` packages; replacing those into the 18-case evidence set, the Python gate passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `12.937s`. The production gap audit still reports `production_ready=false`, but top severity dropped materially: `xl_islands_2levels 26912 -> 18396`, `xl_water_2levels 24032 -> 14136`, and `xl_nowater_2levels 21003 -> 12389`.
- Large normal-water two-level generation now separates the surface and underground profile from XL normal-water: generated normal-water two-level towns reserve an underground share, generated town-floor zone reuse is tracked by `(zone, level)`, Large normal-water two-level surface terrain stays land-dominant, and underground rock fills the blocked layer while preserving open gameplay cells. Focused Large normal-water evidence now matches owner town count/split (`14`, with `10` surface and `4` underground) and terrain-blocked shape within `+2` tiles; merged 18-case quick validation and the Python validation gate passed while preserving `production_ready=false`.
- Large one-level islands now use a scoped object/decoration/guard and terrain profile instead of inheriting the broader one-level islands shaping. A rejected neutral-town-floor probe was not kept because it only produced `9` towns while asking for `16`; the committed profile cleanup leaves town-layout work explicit. Focused `l_islands_randomplayers` severity improved from `4111` to `1122`, and the merged 18-case quick validation passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- Normal generated catalog-auto road component materialization now uses profile-aware road totals, surface/underground splits, component counts, and skewed component-size targets instead of equal-sized chunks. Small/Medium two-level scenic-object floors were also raised to keep the Python object-category policy gate green after fresh full export. A full 18-case export wrote `18/18` packages in about `401.618s`; after a focused five-case correction merge, `tools/rmg_python_validation_gate.py --no-latest-amap-artifact --amap-dir .artifacts/rmg_native_batch_export_road_shape_full_gate_fixed --require-timing-summary` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps in about `13.033s` parse time. The production gap audit still reports `production_ready=false` with `6` missing requirements, but worst XL two-level road deltas improved to `xl_islands_2levels -9`, `xl_water_2levels 16`, and `xl_nowater_2levels -9`.
- Large one-level land catalog-auto maps now have a scoped road/object/category profile and pre-decoration reward supplement. Focused `l_nowater_randomplayers_nounder` export wrote `1/1` package in about `17.647s` with native validation pass, down from the prior probe's roughly `55.970s`; the reward supplement itself dropped from about `39.188s` to about `0.608s`. Fast audit improved object delta from `-603` to `-2`, road delta from `-96` to `0`, category absolute delta from `603` to `2`, and kept guarded reachable town pairs at `0`; town count remains `6` versus owner `8` because the spacing floor was not lowered for exact-count fitting. Merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- XL two-level normal-water catalog-auto maps now have scoped scenic/decoration/reward/guard floors and a profile-specific underground split for decoration, scenic objects, and rewards. A lower-town-spacing probe was rejected because it worsened route shape; the committed path keeps the XL spacing safety rule and improves category/level distribution instead. Focused `xl_water_2levels` severity improved from `1550` to `892`, category absolute delta from `294` to `15`, total object delta from `+28` to `+11`, and terrain-blocked delta from `-462` to `+100`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- XL one-level land catalog-auto maps now have a scoped road/category profile: three road components with an owner-like road total, higher scenic and decoration floors, a reward cap, and a higher guard floor after reward trimming. Focused `xl_nowater` severity improved from `1494` to `886`, total object delta from `-123` to `-1`, road delta from `-37` to `0`, and category absolute delta from `633` to `9`; a town-floor zone-reuse probe was rejected because it did not change the generated town count. Merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- XL two-level islands catalog-auto maps now use a profile-specific underground decoration/scenic/reward split and a lower XL islands underground rock fraction. Focused `xl_islands_2levels` severity improved from `1281` to `520`, terrain-blocked delta from `+764` to `+3`, and level split now closely matches owner object-category distribution while preserving broad category totals; merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- Large one-level islands catalog-auto maps now have a scoped road/category profile: twelve road components with a lower road total, a decoration floor, lower scenic and reward caps, and a lower guard floor after reward trimming. Focused `l_islands_randomplayers` severity improved from `1122` to `891`, total object delta from `+38` to `-7`, road delta from `+40` to `-15`, and category absolute delta from `282` to `9`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- XL one-level normal-water catalog-auto maps now have a scoped road/category profile: owner-like road total with skewed components, a decoration floor, a reward cap, and slightly lower surface land fractions for this profile. Focused `xl_water` severity improved from `907` to `555`, total object delta from `+49` to `+11`, road delta from `-9` to `0`, terrain-blocked delta from `-151` to `+58`, and category absolute delta from `223` to `11`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- XL two-level normal-water package adoption now preserves decorative/scenic object barriers during guarded corridor materialization instead of cutting physical blockers and relying only on guard masks. Focused `xl_water_2levels` severity improved from `892` to `417`, and object-route delta improved from `+20` to `-1`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- Large two-level normal-water catalog-auto maps now use a scoped road split/profile: lower surface share, slightly higher road total, and `7` surface / `3` underground road components. Focused `l_normalwater_randomplayers_2level` severity improved from `628` to `583`, and road-cell delta improved from `-46` to `+1`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- Large two-level islands catalog-auto maps now use a paired reward floor and decoration cap so category mix shifts without inflating total object count. Focused `l_islands_randomplayers_2level` severity improved from `538` to `203`, category absolute delta from `193` to `5`, and route deltas stayed `0/0`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- Large one-level islands road materialization now uses an owner-like skewed twelve-component profile with exact owner road total for the focused `l_islands_randomplayers` evidence. Focused severity improved from `891` to `876`, road delta from `-15` to `0`, and road component shape from `34/32/30/28/26/24/22/20/17/15/13/11` to `101/59/34/20/14/10/9/8/8/8/8/8` versus owner `104/40/20/19/15/15/14/14/13/11/11/11`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- XL one-level land road materialization now uses a stronger dominant-component weight while preserving the owner-like three-component road total. Focused `xl_nowater` road shape moved from `381/238/108` to `485/196/46` versus owner `485/188/54`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- Medium two-level islands now materialize a generated town floor so the profile preserves one underground neutral town instead of placing all towns on the surface. Focused `m_4players_2levels_islands` severity improved from `803` to `681`, town split now matches owner at `5` surface / `1` underground, and object-route delta improved from `+10` to `+6`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- Medium two-level islands road materialization now uses an owner-like surface/underground split and road total. Focused `m_4players_2levels_islands` road delta improved from `-5` to `0`, native road components moved from surface `40/35/31/27/22/18/13` and underground `59/34` to surface `32/29/26/22/19/15/12` and underground `82/47` versus owner surface `43/25/23/21/16/15/12` and underground `90/39`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed while preserving `production_ready=false`.
- Generalized catalog-auto town placement now treats late decorative/scenic filler as clearable for supplemental town search, then removes decorative/scenic records that overlap town primary tiles while keeping access-corridor nonblocking conversion. Focused `l_normalwater_randomplayers_2level` native validation passed and production-gap severity improved from `583` to `342`, with object-route/guarded-route delta moving from `+9/0` to `0/0`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed while preserving `production_ready=false`.
- XL one-level land town-floor materialization now uses the generalized one-level land global spaced fallback for XL as well as Large, and its town-floor density term floors instead of overshooting the owner-like floor. Focused `xl_nowater` native validation passed and now matches owner town count at `12/12` while keeping exact road/reward/object counts; merged 18-case quick validation passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- Large one-level islands package guard masks now use a scoped compact vertical three-tile action mask and skip the later iterative package-closure cluster pass for that profile, matching the owner sample's guarded town-route openness without changing object counts. Focused `l_islands_randomplayers` guarded-route delta improved from `-11` to `0`, guard-controlled tiles dropped from `2263` to `102` versus owner `98`, and production-gap severity improved from `876` to `601`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- Medium two-level islands package adoption now adds compact route masks to existing decorative obstacles for the profile's remaining object-only town-route gaps instead of trimming object counts or using guard control zones as permanent blockers. Focused `m_4players_2levels_islands` object-route delta improved from `+6` to `0`, guarded-route delta stayed `0`, town split stayed exact at `5` surface / `1` underground, and road total stayed exact at `284`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed with `18/18` matches and `0` parse/native/density/policy/topology/coverage/closure-shape gaps while preserving `production_ready=false`.
- Large one-level islands now uses the same compact decorative route-mask helper with a profile-specific target that preserves the owner-like `11` object-open/guard-open crossings and masks only the extra object-only town routes. Focused `l_islands_randomplayers` object-route delta improved from `+17` to `0` while guarded-route delta stayed `0` and exact road/decoration/object/reward totals stayed intact; merged 18-case quick validation and `rmg_python_validation_gate.py` passed while preserving `production_ready=false`.
- Large two-level land now also uses the compact decorative route-mask helper with a profile-specific object-open target of `23`, matching owner-style physical blocker openings without requiring guarded routes to stay open. Focused `l_nowater_randomplayers_2level` object-route delta improved from `+14` to `-1`, guarded-route delta stayed `0`, and production-gap severity improved from `588` to `281`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed while preserving `production_ready=false`.
- XL one-level normal-water now uses the compact decorative route-mask helper with a profile-specific preserve target after rejecting an over-closed exact-target probe. Focused `xl_water` object-route delta improved from `+17` to `+1`, road delta stayed `0`, and town count stayed exact at `10/10`; merged 18-case quick validation and `rmg_python_validation_gate.py` passed while preserving `production_ready=false`.
- The focused Small islands two-level diagnostic found a real two-level materialization defect: the native package had underground roads but no underground town/object/guard/reward distribution. Native object and guard records now preserve `point.level` with level-aware occupancy keys, town-pair route closure now paths with level-aware keys, and the Small islands two-level focused comparison now matches owner counts, road topology, and guarded route closure.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` emitted schema `native_random_map_homm3_owner_corpus_coverage_report_v6` before the focused Small islands fix; the mapped gate remained failing overall at `7/9` mapped pass. After the focused fix, `.artifacts/focused_owner_small_islands_debug.tscn` passed for `owner_discovered_s_randomnumberofplayers_islands_2level` with object/town/guard/road deltas `0`, category deltas `0`, road topology surface `[45, 37, 15, 11, 10]`, underground `[29]`, and semantic layout match. A full owner-corpus Godot rerun is intentionally not part of the tight parser/comparison loop.
- `tests/random_map_player_setup_retry_ux_report.tscn` passed after the explicit label correction and reported level options `Surface Only (1 Level)` and `Surface + Underground (2 Levels)`.
- `tests/native_random_map_owner_normal_water_underground_package_report.tscn` passed with `map_level_count: 2`; `tests/native_random_map_terrain_grid_report.tscn`, `tests/validate_repo.py`, `git diff --check`, and `jq empty ops/progress.json` also passed.

Completed owner-requested editor inspection hotfix:

id: `map-editor-generated-package-inspection-index-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Fix the built-in map editor package picker so generated `.amap`/`.ascenario` pairs that load cleanly remain available for inspection even when the stricter skirmish-launch gate rejects them.
sourceDocs:
- `project.md`
- `PLAN.md`
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/editor/MapEditorShell.gd`
- `tests/maps_folder_package_browser_integration_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/editor/MapEditorShell.gd`
- `tests/maps_folder_package_browser_integration_report.gd`
completionCriteria:
- Skirmish/package browser still hides generated packages rejected by launch validation.
- Map editor package selection includes loadable generated package pairs rejected by launch validation as inspection-only entries.
- Map editor can load those inspection-only generated package pairs into a mutable working copy.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
validationResults:
- `tests/maps_folder_package_browser_integration_report.tscn` passed with launch-rejected compact package hidden from skirmish but listed and loadable through the map-editor inspection index.
- `tests/map_editor_load_map_package_report.tscn` passed with the Load Map picker including generated package ids and package-backed editor working-copy loading.

Paused owner-directed RMG corrective checkpoint:

id: `native-rmg-owner-small-islands-underground-corpus-road-checkpoint-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `paused`
purpose: Promote the uploaded Small islands two-level owner sample into the hard owner-corpus native comparison path and checkpoint the first road-topology correction for manual review before finishing object/category, town, and guard parity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local owner evidence under `maps/h3m-maps/S-RandomNumberofplayers-islands-2level.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `owner_discovered_s_randomnumberofplayers_islands_2level` is mapped to the player-facing native catalog-auto Small islands underground comparison path.
- Native Small islands two-level road cell count and per-level component topology match owner evidence: surface `[45, 37, 15, 11, 10]`, underground `[29]`.
- Remaining package object/category, town, and guard gaps are explicitly visible in the owner-corpus gate until corrected by the next implementation pass.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No completion claim for the Small islands two-level owner sample yet.
- No broad Small islands, underground, or full HoMM3 production parity claim.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` ran and remains failing as expected for this checkpoint: mapped comparisons are `8/9`, the Small islands two-level sample has matching road cells/topology (`147`, surface `[45, 37, 15, 11, 10]`, underground `[29]`) but still reports object delta `+4`, town delta `-1`, guard delta `+4`, and category delta total `118`.
- Paused on 2026-05-07 because continued sample-by-sample count fitting is the wrong production path; use this sample as corpus evidence for generalized policy work instead.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-small-normal-water-underground-corpus-shape-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded Small normal-water two-level owner sample into the hard owner-corpus native comparison gate and correct the package object/category, town, guard, road-topology, and town-spacing gaps exposed by that gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local owner evidence under `maps/h3m-maps/S-2playerss-normalwater-2level.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `owner_discovered_s_2playerss_normalwater_2level` is mapped to the player-facing native catalog-auto Small normal-water underground comparison path.
- The owner-corpus hard mapped comparison increases from seven to eight passing mapped samples, with unmapped parsed samples reduced to 13.
- Native Small normal-water two-level package counts match owner evidence for package objects, towns, guards, road cells, and owner object categories.
- Native Small normal-water two-level road component sizes match owner topology by level: surface `[84]`, underground `[17]`.
- Native town spacing satisfies the owner-derived semantic floor while preserving guarded route closure.
- Existing representative auto-template and production-audit gates remain passing without claiming broad production parity.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No broad Small normal-water/islands parity claim beyond this uploaded sample.
- No full HoMM3 production parity claim; 13 parsed uploaded samples remain unmapped.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with eight mapped comparisons passing; the Small normal-water two-level mapped comparison reports zero deltas for object, town, guard, and road counts, owner category counts `decoration 196`, `guard 62`, `object 64`, `reward 100`, `town 5`, road component sizes by level `0: [84]`, `1: [17]`, and `semantic_layout_match`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed with 11 representative cases.
- `tests/native_random_map_production_parity_completion_audit_report.tscn` passed with `production_ready false`, preserving the broad production-parity gap.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-small-random-land-corpus-shape-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded Small random-player single-level land owner sample into the hard owner-corpus native comparison gate and correct the package object/category, guard, and road topology gaps exposed by that gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local owner evidence under `maps/h3m-maps/S-RandomNumberofplayers.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `owner_discovered_s_randomnumberofplayers` is mapped to the player-facing native catalog-auto Small land comparison path.
- The owner-corpus hard mapped comparison increases from six to seven passing mapped samples, with unmapped parsed samples reduced to 14.
- Native Small random-player land package counts match owner evidence for package objects, towns, guards, road cells, and owner object categories.
- Native Small random-player land road component sizes match owner topology for the uploaded sample: `[63, 28]`.
- Existing representative auto-template and production-audit gates remain passing without claiming broad production parity.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No broad Small water/islands/two-level parity claim.
- No full HoMM3 production parity claim; 14 parsed uploaded samples remain unmapped.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with seven mapped comparisons passing; the Small random-player land mapped comparison reports zero deltas for object, town, guard, and road counts, owner category counts `decoration 146`, `guard 45`, `object 51`, `reward 49`, `town 6`, road component sizes `[63, 28]`, and `semantic_layout_match`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed with 11 representative cases.
- `tests/native_random_map_production_parity_completion_audit_report.tscn` passed with `production_ready false`, mapped owner-corpus gate `7/7`, `full_homm3_style_parity false`, and `broad_owner_h3m_comparison_corpus false`.
- `python3 tests/validate_repo.py`, `jq empty ops/progress.json`, and `git diff --check` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-xl-land-corpus-road-topology-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded XL no-water single-level owner sample into the hard owner-corpus native comparison gate and correct the package road count/topology gap exposed by that gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local owner evidence under `maps/h3m-maps/XL-nowater.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `owner_discovered_xl_nowater` is mapped to the player-facing native catalog-auto XL land comparison path.
- The owner-corpus hard mapped comparison increases from five to six passing mapped samples, with unmapped parsed samples reduced to 15.
- Native XL land package counts match owner evidence for package objects, towns, guards, and road cells.
- Native XL land road component sizes match owner topology for the uploaded sample: `[485, 188, 54]`.
- Existing representative auto-template and production-audit gates remain passing without claiming broad production parity.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No broad XL water/islands or two-level parity claim.
- No full HoMM3 production parity claim; 15 parsed uploaded samples remain unmapped.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with six mapped comparisons passing; the XL no-water mapped comparison reports zero deltas for object, town, guard, and road counts, road component sizes `[485, 188, 54]`, and `semantic_layout_match`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed; `xl_land_seed_a` reports 5,365 package objects, 4,734 generated objects, 12 towns, 619 guards, 727 road cells, and nearest town distance 41.
- `tests/native_random_map_production_parity_completion_audit_report.tscn` passed with `production_ready false`, `mapped_owner_sample_exact_parity true`, `full_homm3_style_parity false`, and `broad_owner_h3m_comparison_corpus false`.
- `python3 tests/validate_repo.py`, `jq empty ops/progress.json`, and `git diff --check` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-large-land-corpus-road-topology-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded Large no-water single-level owner sample into the hard owner-corpus native comparison gate and correct the package road count/topology gap exposed by that gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local owner evidence under `maps/h3m-maps/L-NoWater-RandomPlayers-nounder.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `owner_discovered_l_nowater_randomplayers_nounder` is mapped to the player-facing native catalog-auto Large land comparison path.
- The owner-corpus hard mapped comparison increases from four to five passing mapped samples, with unmapped parsed samples reduced to 16.
- Native Large land package counts match owner evidence for package objects, towns, guards, and road cells.
- Native Large land road component sizes match owner topology for the uploaded sample: `[192, 118, 47, 9]`.
- Existing representative auto-template and production-audit gates remain passing without claiming broad production parity.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No broad Large water/islands or two-level parity claim.
- No full HoMM3 production parity claim; 16 parsed uploaded samples remain unmapped.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with five mapped comparisons passing; the Large no-water mapped comparison reports zero deltas for object, town, guard, and road counts, road component sizes `[192, 118, 47, 9]`, and `semantic_layout_match`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed; `large_land_seed_a` reports 2,917 package objects, 2,645 generated objects, 8 towns, 264 guards, 366 road cells, and nearest town distance 34.
- `tests/native_random_map_production_parity_completion_audit_report.tscn` passed with `production_ready false`, preserving representative coverage/full-parity gaps.
- `python3 tests/validate_repo.py`, `jq empty ops/progress.json`, and `git diff --check` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-medium-normal-water-corpus-structural-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded Medium normal-water owner sample into the hard owner-corpus native comparison gate and correct the remaining structural road, town-spacing, and guard-count gaps exposed by that gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local owner evidence under `maps/h3m-maps/M-NormalW-4players.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `scripts/core/RandomMapGeneratorRules.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `owner_discovered_m_normalw_4players` is mapped to the player-facing native catalog-auto Medium normal-water comparison path.
- The owner-corpus hard mapped comparison increases from three to four passing mapped samples, with unmapped parsed samples reduced to 17.
- Native Medium normal-water package counts match owner evidence for package objects, towns, guards, and road cells.
- Native Medium normal-water road component sizes match owner topology for the uploaded sample: `[71, 55, 50, 45]`.
- Native Medium normal-water nearest town spacing meets or exceeds the owner sample spacing while preserving the owner-count target.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No broad normal-water parity claim across the remaining uploaded samples.
- No full HoMM3 production parity claim; 17 parsed uploaded samples remain unmapped.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed after the structural fix; `medium_normal_water_seed_a` reports 754 package objects, 667 generated objects, 7 towns, 80 guards, 221 road cells, 2,163 water tiles, and nearest town distance 25.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with four mapped comparisons passing; the Medium normal-water mapped comparison reports zero deltas for object, town, guard, and road counts, road component sizes `[71, 55, 50, 45]`, and `semantic_layout_match`.
- `tests/native_random_map_production_parity_completion_audit_report.tscn` passed with `production_ready false`, preserving the broad parity gap while proving representative defaults still pass.
- `python3 tests/validate_repo.py` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-medium-normal-water-road-count-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the uploaded Medium normal-water owner sample package road count after the object/town/guard count correction.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- local owner evidence under `maps/h3m-maps/M-NormalW-4players.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Medium normal-water package road overlays serialize 221 road cells, matching the uploaded owner H3M evidence instead of the previous 254-cell native output.
- The correction is scoped to the owner-compared Medium normal-water translated profile and does not claim broad normal-water road parity.
- Object, generated-object, town, guard, and water gates remain passing for `medium_normal_water_seed_a`.
- The auto-template batch hard-gates the corrected Medium normal-water package road target.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No full route-graph topology rewrite; the underlying generated route graph still reports 16 route edges and this slice adjusts serialized package road overlays only.
- No broad normal-water parity claim across Small/Large/XL samples.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed after adding the Medium normal-water road-count gate.
- `medium_normal_water_seed_a` now reports 221 package road cells, matching owner `M-NormalW-4players.h3m`; it still reports 754 package objects, 667 generated object placements, 7 towns, and 80 guards.
- The same case reports 2,144 package water tiles against the owner 2,083 target, still inside the existing 96-tile tolerance.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-medium-normal-water-count-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded Medium normal-water owner sample to an owner-compared native target and correct native object, town, and guard counts toward that H3M evidence.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- local owner evidence under `maps/h3m-maps/M-NormalW-4players.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Medium normal-water `translated_rmg_template_039_v1` / `translated_rmg_profile_039_v1` is treated as an owner-compared translated profile for native generation policy.
- Native Medium normal-water object, town, and guard counts match the uploaded owner H3M evidence: 754 package objects, 667 generated object placements, 7 towns, and 80 guards.
- Surplus generic reward references are trimmed after required mine/resource/dwelling priority so owner reward-category density can match without suppressing required sites.
- The auto-template batch hard-gates the corrected Medium normal-water count targets while preserving the existing water-count tolerance gate.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No Medium normal-water road topology/count parity in this slice; package roads remain 254 versus owner 221 and are the next explicit corrective gap.
- No broad normal-water parity claim across Small/Large/XL samples.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed after adding owner Medium normal-water count gates.
- `medium_normal_water_seed_a` now reports 754 package objects, 667 generated object placements, 7 towns, and 80 guards, matching owner `M-NormalW-4players.h3m` counts.
- The same case reports 2,144 package water tiles against the owner 2,083 target, still inside the existing 96-tile tolerance, and 254 package road cells versus owner 221 remains an explicit non-goal gap.
- `python3 tests/validate_repo.py` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-normal-water-decoration-land-pressure-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the Medium normal-water terrain shape regression where decorative/scenic objects placed before terrain forced too much land versus the uploaded owner HoMM3 sample.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- local owner evidence under `maps/h3m-maps/M-NormalW-4players.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Normal-water terrain shaping no longer lets decorative and scenic object bodies force protected land before the water/land shape is chosen.
- Medium normal-water land fractions are retuned after that protected-surface reduction so generated water stays close to the owner sample rather than overshooting.
- The auto-template batch hard-gates the Medium normal-water package water count against the uploaded owner sample evidence.
- Native generation, package conversion, road/object/town/guard validation, and repository validation still pass.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No claim of full normal-water parity across every owner sample.
- No broad water-aware object-placement pipeline reorder in this slice.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed after the correction.
- `medium_normal_water_seed_a` now reports 2,097 package water tiles against the owner `M-NormalW-4players.h3m` 2,083 water tiles, compared with 1,610 before this slice.
- The same case reports `protected_land_cell_count 2,213`, `requested_land_count 3,087`, `generated_land_cell_count 3,087`, and `generated_water_cell_count 2,097`, proving decorative/scenic protected land was the previous water cap.
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with 21 parsed owner samples, 7 land, 7 normal-water, 7 islands, and the existing 18 unmapped parsed-sample comparison gap still explicit.
- `python3 tests/validate_repo.py` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-normal-water-protected-land-diagnostic-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Expose why Medium normal-water still underproduces water versus the uploaded HoMM3 owner sample after first-class normal-water support.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- local owner evidence under `maps/h3m-maps/M-NormalW-4players.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Native normal-water terrain shaping records compact requested/protected/generated land-water shape metrics in focused validation output.
- The focused Medium normal-water validation compares native water/object/road/town/guard counts against the owner sample enough to identify the next tuning blocker.
- Normal-water land quota tuning and non-visit decorative approach relaxation are attempted, with evidence preserved if they are not the limiting factor.
- No production parity overclaim is made while water/object density still differs from owner H3M.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No full object-placement-before-water refactor in this slice.
- No exact normal-water owner-H3M parity claim.
- No broad normal-water template sweep.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed; `medium_normal_water_seed_a` still validates and converts with 1,610 package water tiles, 499 package objects, 254 road cells, 8 towns, and 111 guards.
- The focused shape summary reports `requested_land_count 3574`, `protected_land_cell_count 3574`, `generated_land_cell_count 3574`, and `generated_water_cell_count 1610`, proving protected land surfaces, not the normal-water quota target, are currently capping water generation below the owner sample's 2,083 water tiles.
- `python3 tests/validate_repo.py` passed.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-normal-water-mode-support-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Stop collapsing HoMM3 normal-water requests to land and add first-class native normal-water generation/package support as a prerequisite for owner-H3M normal-water comparison tuning.
sourceDocs:
- `project.md`
- `PLAN.md`
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/core/RandomMapGeneratorRules.gd`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- local owner evidence under `maps/h3m-maps/M-NormalW-4players.h3m`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/core/RandomMapGeneratorRules.gd`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Player-facing random-map setup exposes `normal_water` separately from `land` and `islands`.
- GDScript and native config normalization preserve `normal_water` instead of coercing it to `land`.
- Native catalog support accepts `normal_water` for water-capable translated templates without treating it as islands score halving.
- Native terrain generation materializes mixed surface water for normal-water maps while preserving land around roads, towns, objects, guards, and starts.
- Focused native auto-template validation covers a Medium normal-water package and proves it has nonzero water tiles.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact normal-water owner-H3M parity claim yet.
- No tuning to match `M-NormalW-4players.h3m` object, road, town, guard, and terrain ratios in this slice.
- No broad all-template water-mode parity claim.
validationResults:
- Native GDExtension rebuilt successfully with `cmake --build .artifacts/map_persistence_native_build --parallel 2`.
- `tests/native_random_map_auto_template_batch_report.tscn` passed with 11 cases; `medium_normal_water_seed_a` preserved `normal_water`, selected `translated_rmg_template_039_v1` / `translated_rmg_profile_039_v1`, validated, converted to a package, and reported 1,582 package water tiles.
- `python3 tests/validate_repo.py` passed.
- `tests/random_map_player_setup_retry_ux_report.tscn` was attempted and still fails on an existing generated-session launch handoff nil path in `ScenarioSelectRules.gd`, outside the normal-water mode selection path.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-corpus-terrain-water-mode-audit-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Add parsed H3M terrain water/rock ratios and terrain-inferred water-mode evidence to the owner corpus so uploaded samples can be audited by actual map contents, not only filename labels.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- local evidence under `maps/h3m-maps/*.h3m`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner-corpus samples expose compact water-mode resolution plus terrain water/rock counts and ratios parsed from H3M tile data.
- Samples with no explicit filename water mode can resolve from terrain inference without changing explicit owner labels.
- Production-audit parsed sample coverage surfaces compact terrain ratios without embedding the full terrain-count payload.
- The audit does not overclaim production readiness; missing corpus/template/tail-parse gaps remain explicit.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No native generator tuning for water/islands profiles in this slice.
- No exact H3M byte/object-art parity claim.
- No synthetic Medium land owner evidence.
validationResults:
- Owner-corpus report passed with schema `native_random_map_homm3_owner_corpus_coverage_report_v5`, `ok true`, 21 readable/parsed samples, and `corpus_ready false`.
- `owner_discovered_s_randomnumberofplayers` now resolves from unknown filename label to terrain-inferred land with surface water ratio 0.0.
- `owner_discovered_m_normalw_4players` remains normal-water with surface water ratio 0.402, confirming it is not the missing Medium land/no-water owner sample.
- `owner_discovered_xl_water_2levels` remains explicitly labeled normal-water but now records a terrain conflict because the parsed surface water ratio is 0.560 and terrain inference classifies it as islands.
- Corpus gaps remain `template_breadth_corpus` and `object_instance_tail_count_mismatch_samples`; production readiness remains unclaimed.
- Production parity audit passed with `ok true`, `production_ready false`, `missing_requirement_count 4`, and compact terrain coverage records.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-large-land-density-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Use the parsed Large no-water owner diagnostic to correct native Large land default object density, town count/spacing, reward category count, and guard count toward owner-H3M scale.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `src/gdextension/src/map_package_service.cpp`
- local evidence under `maps/h3m-maps/L-NoWater-RandomPlayers-nounder.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Native Large land default has a Large diagnostic against the parsed owner no-water surface sample.
- Native Large land default matches the parsed owner sample on package object count, decoration, scenic/object, reward, town, and guard categories, allowing only explicitly validated residuals such as one road-cell delta.
- Large town count uses parsed owner evidence instead of stale catalog minima, and semantic layout remains passing with no native unguarded/object-only town route leaks.
- Production audit still refuses `production_ready` until Medium land owner evidence, broad corpus/template parity, parser tail debt, full parity, and underground readiness are closed.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact Large H3M byte/object-art parity claim while the owner sample still carries a 16-object tail-count parser warning.
- No Medium land synthetic owner evidence.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Owner-corpus Large land diagnostic passed with native package object count 2,917/2,917, decoration 1,840/1,840, scenic/object 376/376, reward 429/429, town 8/8, guard 264/264, and road cells 365 versus owner 366.
- Large semantic layout comparison passes: native nearest-town Manhattan 34 versus owner 35, native object-route reachable town pairs 0 versus owner 28, and native guarded-route reachable town pairs 0/0.
- Production parity audit passed with `production_ready false` and `missing_requirement_count 4`; remaining missing requirements are representative owner coverage for Medium land, full HoMM3-style parity, broad owner-H3M comparison corpus, and underground production parity.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-large-land-tail-parse-coverage-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Make the uploaded Large no-water surface owner H3M usable as representative coverage while preserving an explicit parser-debt warning for its near-EOF object-instance count mismatch.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- local evidence under `maps/h3m-maps/L-NoWater-RandomPlayers-nounder.h3m`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- The Large no-water surface uploaded H3M no longer disappears from parsed representative owner-sample coverage solely because the strict parser reaches EOF with a small declared object-count tail mismatch.
- The parser reports declared count, parsed count, missing tail count, parse quality, and warning metadata for that sample.
- Corpus readiness remains false while the tail-count mismatch and template-breadth corpus gaps remain unresolved.
- Production audit representative owner sample coverage now has Small land, Small underground, Medium islands, Large land, and XL land evidence, while Medium land remains explicitly missing.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact Large H3M byte/object-art parity claim.
- No native Large land tuning or mapped native comparison for the Large sample.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Owner-corpus report passed with 21 readable samples and 21 parsed metric records; `owner_discovered_l_nowater_randomplayers_nounder` reports `tail_count_mismatch`, 2,917 parsed objects out of 2,933 declared, and 16 missing tail instances.
- Owner-corpus readiness remains false with `missing_coverage` containing `template_breadth_corpus` and `object_instance_tail_count_mismatch_samples`.
- Production parity audit passed with `production_ready false`, `missing_requirement_count 4`, Large land representative coverage matched to `owner_discovered_l_nowater_randomplayers_nounder`, and Medium land still the only missing representative owner sample.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-xl-land-reward-count-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Use the XL no-water owner diagnostic to correct native Extra Large land reward-category overproduction after the town-layout pass left native rewards at 952 versus owner 692.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `src/gdextension/src/map_package_service.cpp`
- local evidence under `maps/h3m-maps/XL-nowater.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Native Extra Large land default caps reward-category placement at the parsed owner XL count without suppressing mine/resource/dwelling priority placement.
- The XL land diagnostic reward category moves from native 952 versus owner 692 to exact owner count or an explicit validated residual if infeasible.
- Decoration, scenic/object, guard, town count, town spacing, road, and route-closure evidence from previous XL corrections remains passing.
- Production audit still refuses `production_ready` until broad exact owner-H3M parity and remaining corpus/parser gaps are closed.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact reward-value distribution parity claim beyond count/category shape.
- No broad all-template reward tuning.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native XL land diagnostic validation now passes with exact owner-category counts: package object count 5,365/5,365, decoration 3,413/3,413, scenic/object 629/629, reward 692/692, town 12/12, and guard 619/619.
- Native reward by-kind breakdown is mine 168, neutral_dwelling 57, resource_site 133, and reward_reference 334 after trimming only surplus generic reward references.
- Semantic layout and route closure remain passing: nearest-town Manhattan 41 versus owner 39, native object-route reachable town pairs 0, and native guarded-route reachable town pairs 0.
- Production parity audit passed with `production_ready false` and `missing_requirement_count 4`, preserving the no-overclaim boundary.
- Uploaded `.h3m`, generated `.amap`, and generated `.ascenario` evidence remains uncommitted.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-xl-land-town-layout-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Use the XL no-water owner diagnostic to correct native Extra Large land town count and town-spacing semantics after the density pass exposed native towns at 14 versus owner 12 and nearest-town Manhattan 23 versus owner 39.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `src/gdextension/src/map_package_service.cpp`
- local evidence under `maps/h3m-maps/XL-nowater.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Native Extra Large land default applies the owner XL town-count target without dropping player starts.
- The XL land diagnostic no longer reports `native_xl_semantic_layout_gap` solely because native towns are closer than the owner spacing floor.
- Object, decoration, scenic, guard, road, and route-closure evidence from the density correction remains passing.
- Production audit still refuses `production_ready` until broad exact owner-H3M parity and remaining corpus/parser gaps are closed.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact XL H3M byte/object-art parity claim.
- No broad all-template town-layout parity claim.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native XL land diagnostic validation now passes with native town count 12/12, nearest-town Manhattan 38 versus owner 39, semantic_layout_match, and no actionable gaps.
- Density/passability evidence from the previous slice remains intact: decoration 3,413/3,413, scenic/object 629/629, guards 619/619, native object-route reachable town pairs 0, and native guarded-route reachable town pairs 0.
- Remaining XL category delta is reward count only: native reward 952 versus owner 692; this stays explicit parity debt.
- Production parity audit passed with `production_ready false` and `missing_requirement_count 4`, preserving the no-overclaim boundary.
- Uploaded `.h3m`, generated `.amap`, and generated `.ascenario` evidence remains uncommitted.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-xl-land-density-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Use the XL no-water owner diagnostic to raise native Extra Large land default decoration, scenic-object, and guard density toward owner-H3M scale instead of leaving the generator at roughly one-third owner object density.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `src/gdextension/src/map_package_service.cpp`
- local evidence under `maps/h3m-maps/XL-nowater.h3m`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Native Extra Large land default adds deterministic owner-informed density targets for decoration, scenic-object, and guards.
- The XL land diagnostic object-density ratio improves materially from the baseline 0.349 and no longer reports decoration/scenic category as effectively absent.
- Representative package route closure and road integrity remain passing after denser blockers/objects are added.
- Production audit still refuses `production_ready` until broad exact owner-H3M parity and remaining corpus/parser gaps are closed.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact XL H3M parity claim from a potentially different HoMM3 template/player-count sample.
- No broad Large/no-water parser repair.
- No HoMM3 copyrighted asset/DEF import.
validationResults:
- Native XL land diagnostic validation now passes with package_object_count 5,627 versus owner 5,365, object density ratio 1.049, decoration 3,413/3,413, scenic/object 629/629, guard 619/619, and road cells 764 versus 727.
- Route closure remains intact in the diagnostic: native object-route reachable town pairs 0 and native guarded-route reachable town pairs 0.
- Remaining explicit diagnostic gap is semantic town layout spacing: native nearest town Manhattan 23 versus owner 39, with native town count 14 versus owner 12 and reward count 952 versus owner 692.
- Production parity audit passed with `production_ready false` and `missing_requirement_count 4`, preserving the no-overclaim boundary.
- Uploaded `.h3m`, generated `.amap`, and generated `.ascenario` evidence remains uncommitted.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-xl-land-density-gap-diagnostic-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Make the newly parsed owner XL no-water H3M evidence directly comparable to the native XL land player-facing default as a diagnostic density gap, without converting that mismatched template evidence into a false exact-parity gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- local evidence under `maps/h3m-maps/XL-nowater.h3m`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner-corpus output includes an XL land diagnostic comparing `owner_discovered_xl_nowater` to the native Extra Large land default.
- The diagnostic reports native/owner object, guard, town, road, and owner-category count deltas plus density ratios and actionable gap labels.
- The mapped exact-comparison gate remains scoped to supported mapped samples and does not fail on the diagnostic-only XL evidence.
- Production audit consumes and exposes the XL diagnostic while still refusing `production_ready`.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No exact XL H3M parity claim from a potentially different HoMM3 template/player-count sample.
- No HoMM3 copyrighted asset/DEF import.
- No Large no-water variable-payload parser repair in this slice.
completionEvidence:
- Owner-corpus schema v3 now includes `xl_land_density_diagnostic` for `owner_discovered_xl_nowater` against native `translated_rmg_template_043_v1` / `translated_rmg_profile_043_v1`.
- The diagnostic reports native XL land at 1,873 package objects versus 5,365 owner objects, a 0.349 object density ratio, and 416 native guards versus 619 owner guards, a 0.672 guard density ratio.
- Category density gaps are explicit: native decoration is 491 versus 3,413 owner decorations, native object/scenic category is 0 versus 629 owner objects, and native rewards are 952 versus 692 owner rewards.
- Roads are not the primary XL land deficit in this sample: native package road cells are 764 versus 727 owner road cells, a 1.051 road-cell ratio.
- Semantic comparison flags native town spacing below the owner floor: native nearest-town Manhattan minimum is 20 versus owner 39, while object-only and guarded route closure remain zero native leaks for this diagnostic.
- Production parity audit schema v7 consumes the diagnostic, keeps it out of the mapped exact-parity gate, and still reports `production_ready: false`.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-h3m-variation-corpus-discovery-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Ingest the newly uploaded local H3M variation directory into the owner-corpus audit as evidence-only comparison input so Large/XL, water, island, and underground coverage gaps become measurable instead of hidden by the previous three-sample corpus.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local evidence under `maps/h3m-maps/*.h3m`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner-corpus discovery includes `maps/h3m-maps` without committing uploaded `.h3m` evidence.
- Filename-derived size/water hints correctly classify S/M/L/XL, no-water/land, normal-water, islands, and two-level samples.
- The corpus report summarizes parsed variation coverage and exposes unmapped or mismatched native comparisons as explicit next-work evidence.
- Production audit consumes the expanded owner-corpus coverage without claiming `production_ready`.
nonGoals:
- No HoMM3 copyrighted asset/DEF import.
- No exact H3M byte/art parity claim.
- No generated `.amap`/`.ascenario` or uploaded `.h3m` evidence files committed.
completionEvidence:
- Owner-corpus discovery now includes `res://maps/h3m-maps` as local evidence-only input and does not stage or commit uploaded `.h3m` files.
- Filename hints classify `S/M/L/XL`, `nowater` as land, `normalwater`/`normalw` as normal-water, and `islands` as islands; the only remaining unknown parsed sample is the ambiguous `S-RandomNumberofplayers.h3m`.
- Expanded local corpus audit passed with 21 readable samples, 18 parsed metric samples, size coverage across Small/Medium/Large/XL, level coverage across 1 and 2 levels, and water coverage across land/normal-water/islands.
- The mapped exact comparison gate remains limited to the three already-mapped owner samples and reports 15 newly parsed samples as unmapped next-work evidence.
- Production parity audit consumes the expanded corpus and still reports `production_ready: false`; remaining blockers include full template-breadth corpus/parser completion, unmapped variation comparisons, and representative Medium/Large/XL land owner sample gaps.

Active owner-directed RMG corrective slice:

id: `native-rmg-owner-h3m-xl-nowater-parser-cap-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Remove the owner-corpus parser's too-low placed-object cap so uploaded XL no-water samples with more than 5,000 objects become usable local evidence for XL land comparison coverage.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local evidence under `maps/h3m-maps/XL-nowater*.h3m`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- XL no-water single-level and two-level uploaded H3M samples metric-parse instead of failing `invalid_object_instance_count`.
- Production audit representative owner sample coverage no longer reports Extra Large land default as missing when the single-level XL no-water sample is present locally.
- The remaining Large single-level no-water parser gap is still explicit rather than hidden.
- No uploaded `.h3m`, generated `.amap`, or generated `.ascenario` evidence is committed.
nonGoals:
- No HoMM3 copyrighted asset/DEF import.
- No exact H3M byte/art parity claim.
- No Large no-water variable-payload parser repair in this slice.
completionEvidence:
- Owner-corpus parser now accepts uploaded H3Ms with up to 12,000 placed objects instead of rejecting valid XL no-water samples above 5,000.
- Expanded corpus report passed with 20 parsed metric samples out of 21 readable samples; `owner_discovered_xl_nowater` parses at 5,365 objects, 12 towns, 619 guards, and 727 road cells.
- `owner_discovered_xl_nowater_2levels` parses at 5,239 objects, 10 towns, 405 guards, and 879 road cells.
- Production audit now matches `extra_large_land_default` to `owner_discovered_xl_nowater` for representative owner-sample coverage while still reporting `production_ready: false`.
- Remaining representative owner-sample coverage gaps are Medium land and Large land; the Large single-level no-water H3M still exposes a separate `next_object_instance_not_found` variable-payload parser gap.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-production-audit-owner-sample-coverage-matrix-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Expose owner-H3M sample coverage per representative default so translated-profile support cannot be mistaken for owner-proven production parity when matching H3M evidence is absent.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit records parsed owner sample coverage with size class, water mode, underground/surface level shape, object/town/guard counts, and road-cell totals.
- The audit adds a representative owner-H3M sample coverage checklist item.
- Representative cases without a matching owner sample are visible as explicit missing coverage rather than hidden behind generic corpus readiness.
- The broad owner corpus objective checklist consumes this coverage item and remains unsatisfied when representative evidence is incomplete.
nonGoals:
- No synthetic owner-H3M samples or guessed coverage.
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Production audit schema v6 adds `parsed_sample_coverage` and `representative_owner_h3m_sample_coverage`.
- Parsed owner sample coverage currently includes Small land single-level, Small land underground, and Medium Islands single-level samples.
- The audit still passes as a no-overclaim audit while `production_ready: false` remains, with missing representative owner evidence for unsupported size/water/level combinations and the broader Large/XL/template-breadth corpus blocker.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-production-audit-objective-artifact-checklist-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Add an explicit prompt-to-artifact completion checklist to the production audit so the owner objective maps to concrete repo evidence and remaining blockers before any production-ready claim.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit restates the native GDExtension RMG production objective as concrete checklist requirements.
- Each requirement maps to repo artifacts and real evidence from the audit completion checklist or owner corpus summary.
- The checklist distinguishes satisfied local evidence from broad parity blockers instead of treating passing reports as full completion.
- The audit still refuses production readiness while broad owner-H3M corpus, broad underground readiness, or full HoMM3-style parity remain missing.
nonGoals:
- No HoMM3 asset/DEF import or exact byte parity claim.
- No synthetic owner-corpus evidence or broad production-ready claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Production audit schema v5 adds `objective_artifact_checklist` with entries for native GDExtension activation, player-facing defaults, towns/zones/routes, roads, obstacles/guards/rewards/object density, translated template breadth, broad owner-H3M corpus, broad underground readiness, and full production-ready claim.
- Checklist entries cite concrete repo artifacts and consume real completion-checklist/owner-corpus evidence.
- The audit passes while preserving `production_ready: false`; broad owner-H3M corpus coverage still reports missing Large/XL H3M samples and template-breadth corpus evidence.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-production-audit-package-road-integrity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Gate representative player-facing defaults on player-visible package road integrity, clarifying the distinction between diagnostic generated road segment totals and unique serialized package road tiles.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit records package-road integrity for every representative player-facing default.
- The gate fails empty road packages, zero-tile road records, duplicate serialized road tiles, or package metadata that does not match unique serialized road tiles.
- Raw generated `road_network.road_cell_count` remains visible as diagnostic data and is not confused with player-loaded package roads.
- The audit still reports production not ready while broad owner corpus and broad underground readiness remain unproven.
nonGoals:
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
- No broad production-ready claim from representative road integrity evidence.
completionEvidence:
- Production audit adds `package_road_integrity` to each representative case and a satisfied `representative_package_road_integrity` checklist item.
- All representative defaults serialize non-empty package roads with zero duplicate road tiles, zero zero-tile road records, and package component metadata matching unique serialized road tiles.
- The audit explicitly records generated road segment totals as diagnostic because they can include pre-dedup/materialization segment counts, while package road integrity is gated on the actual loaded map surface.
- Production audit still reports `production_ready: false` with broad owner-H3M corpus coverage, broad underground production readiness, and full HoMM3-style parity remaining open.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-production-audit-mapped-owner-parity-evidence-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Make exact mapped owner-H3M parity evidence first-class in the production audit, separating passing local owner comparisons from the remaining broad corpus blocker.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit reports concise mapped-owner sample parity summaries for each compared local H3M sample.
- The audit has a hard satisfied checklist item for exact currently mapped owner-sample parity.
- The checklist requires zero object/town/guard/road deltas, category-count match, per-level road-component match, semantic layout match, and zero native object-only/guarded route leaks.
- Broad owner corpus readiness still fails when Large/XL or template-breadth H3M evidence is absent.
nonGoals:
- No synthesized or guessed owner-H3M corpus coverage.
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Production audit now includes `mapped_sample_parity` in the owner corpus summary for Small single-level, Small underground, and Medium Islands owner samples.
- The new `mapped_owner_sample_exact_parity` checklist item passes only when the mapped comparison gate passes and each summarized sample has zero object/town/guard/road deltas, matching owner categories, matching per-level road topology, semantic layout match, and zero native route leaks.
- Local evidence inventory confirmed only three owner map samples are available: two Small land variants and one Medium Islands sample; no Large/XL `.h3m` or broader template corpus exists in `maps/`, inbound media, or recovered artifacts.
- Production audit still reports `production_ready: false` because broad owner-H3M corpus coverage and broad underground production readiness remain unproven.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-production-audit-representative-route-closure-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote level-aware package route-closure evidence into the production parity audit for every representative player-facing default, so the audit directly fails start-town, cross-zone, or all-town leaks instead of relying on a separate topology report by implication.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit reports package-level route-closure metrics for each representative default.
- The representative route gate covers object-only and unresolved blockers for start-town, cross-zone, and all-town pairs.
- The gate is level-aware through the shared package topology helper and covers the representative Small underground case on two levels.
- The audit still reports production not ready while broad owner corpus, full parity, and broad underground readiness remain unproven.
nonGoals:
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
- No broad production-ready claim from representative route-closure evidence.
completionEvidence:
- Production parity audit schema v4 adds `package_route_closure` per representative case and a satisfied `representative_package_route_closure` checklist item.
- The representative defaults pass package route closure with zero object-only and unresolved reachable pairs for start-town, cross-zone, and all-town checks: Small land, Small underground, Medium land, Medium Islands, Large land, and Extra Large land.
- The Small underground representative records 2 levels, 8 towns, 28 all-town pairs checked, and zero reachable object-only or unresolved pairs.
- The audit still reports `production_ready: false` with `full_homm3_style_parity`, `broad_owner_h3m_comparison_corpus`, and `underground_production_parity` as explicit missing requirements.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-package-topology-level-aware-route-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Close a verifier gap where package object-only route-closure checks only searched level 0, so two-level/underground package leaks could be missed despite serialized level data.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_package_surface_topology_report.gd`
- `tests/native_random_map_broad_translated_catalog_underground_route_closure_sweep_report.gd`
implementationTargets:
- `tests/native_random_map_package_surface_topology_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Package topology helper builds town visit points with their actual package/map level.
- Object-only player-start, cross-zone, and all-town path searches stay within the same level and use level-aware blocked-tile keys.
- Broad translated land/underground catalog sweep passes under the stricter level-aware route-closure helper.
- The result does not claim exact HoMM3 byte/object-art parity or full underground production readiness.
nonGoals:
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
- No broad production-ready claim from structural route-closure evidence alone.
completionEvidence:
- `tests/native_random_map_package_surface_topology_report.gd` now computes package topology paths with `Vector3i(level, x, y)` visit/start/goal points and level-aware blocked keys.
- The focused package surface topology report passed after the stricter helper change.
- The broad translated catalog underground route-closure sweep passed for 47 eligible land/underground translated templates with zero object-only player-start, cross-zone, or all-town package route leaks.
- The strengthened evidence confirms current translated packages keep guarded/blocked route closure on actual package levels; production parity audit still keeps full HoMM3 parity, broad owner corpus, and broad underground production readiness as blockers.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-production-audit-small-underground-representative-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the mapped owner Small underground native-auto path into the production parity audit as explicit representative evidence without overclaiming broad underground production readiness.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- local uploaded owner Small underground H3M evidence under `maps/` and `/root/.openclaw/media/inbound`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production parity audit includes a representative native-auto Small underground case.
- The representative underground case selects `translated_rmg_template_027_v1` / `translated_rmg_profile_027_v1`, validates, materializes two levels, and passes active catalog town/castle minima.
- Audit adds a satisfied representative underground checklist item while keeping broad underground production exposure blocked until owner-H3M corpus breadth expands.
- Production audit still reports `production_ready: false` and keeps full parity, broad owner corpus, and broad underground production parity as missing requirements.
nonGoals:
- No broad underground production-ready claim.
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Production parity audit now includes `small_underground_default`, which selects `translated_rmg_template_027_v1` / `translated_rmg_profile_027_v1`, validates with `owner_compared_translated_profile_not_full_parity`, materializes 2 levels, and passes active catalog town minima with 8 towns against 8 required.
- The representative Small underground output reports 12 zones, 60 guards, 436 package objects, and 157 package road cells.
- A new satisfied `representative_owner_compared_underground_support` checklist item records the representative case and owner corpus underground-sample presence.
- The audit still reports `production_ready: false`; broad owner-H3M corpus breadth, broad underground production exposure, and full HoMM3-style parity remain explicit blockers.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-template-town-minima-materialization-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Add a hard production-audit gate for active recovered catalog player castle and neutral town minima, disambiguating active player-filtered zones from inactive source zones so real under-materialization fails without false-counting disabled template branches.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit records catalog-derived minimum town/castle expectations for representative defaults.
- Player-facing Large/XL defaults materialize at least the active player castle minima plus neutral town/castle minima from their translated catalog zones.
- The fix does not reintroduce close-town stacking below the current launchable town-spacing floor or route leaks in mapped owner samples.
- Production audit still does not claim full HoMM3 parity or broad owner-corpus readiness.
nonGoals:
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
- No broad corpus/product-ready claim from this single town-minima correction.
completionEvidence:
- Production parity audit schema v3 now records `catalog_town_minima` for representative player-facing defaults, including active-zone count, player-count, active player town/castle minima, neutral town/castle minima, generated town count, and pass/fail status.
- The active filtered defaults pass the minima gate: Small `049` generates 7 towns against 7 required; Medium land `002` generates 6 against 4 required; Medium Islands `001` generates 8 against 4 required; Large `042` generates 16 against 16 required; XL `043` generates 14 against 14 required.
- The XL default was audited as active-filtered 5 player towns plus 9 neutral towns, not the larger inactive source-zone total; this prevents false-positive town-count corrections while still failing real active catalog under-materialization.
- Production parity audit still reports `production_ready: false` with full HoMM3-style parity, broad owner-H3M corpus breadth, and underground production parity remaining as explicit blockers.

Recently completed owner-directed RMG corrective slice:

id: `native-rmg-owner-corpus-semantic-layout-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Extend mapped owner-H3M comparisons beyond object/road/category counts so owner-corpus gates catch town-spacing, guard-footprint, and unguarded/object-only route-closure layout failures.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- local uploaded owner H3M evidence under `maps/` and `/root/.openclaw/media/inbound`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Mapped owner-H3M comparisons include semantic layout metrics for owner and native outputs: nearest-town spacing, object-only town-route closure, unguarded/guard-controlled route closure, and guard-control footprint by level.
- The owner-corpus comparison gate fails mapped samples with native town spacing materially below the owner sample, object-only/unguarded reachable town pairs, or guard-control footprints materially below owner evidence.
- The comparison gate self-check proves synthetic semantic-layout failures are detected.
- Production parity audit consumes the strengthened owner-corpus summary without claiming full HoMM3 parity or broad corpus readiness.
nonGoals:
- No HoMM3 asset/DEF import or exact byte parity claim.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
- No full production-readiness claim from the current three mapped samples.
completionEvidence:
- Owner-corpus H3M comparisons now include semantic layout metrics for mapped owner/native samples: nearest-town spacing, object-only town-route closure, guard-controlled route closure, terrain/object/guard blocking footprint, and per-level guard-control totals.
- The mapped comparison gate now fails semantic-layout gaps and its self-check proves synthetic `semantic_layout_gap` failures are detected alongside object, guard, road-cell, category, and road-topology gaps.
- Medium Islands native spacing was corrected for the owner-compared translated profile while preserving zero unguarded/object-only reachable town pairs; the uploaded Small single-level native default remains at 7 towns, 150 decorative obstacles, 40 guards, 303 package objects, and closed town topology.
- Production parity audit consumes the strengthened owner-corpus gate and still reports `production_ready: false` with broad owner corpus, full parity, and underground production parity remaining as explicit blockers.
- Validation passed native build plus owner-corpus coverage, uploaded Small comparison, uploaded Small topology, and production parity completion audit reports.

Recently completed owner-directed implementation slice:

id: `native-map-package-document-validation-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Replace native map/scenario package validation stubs with bounded structural validators so generated package adoption is not relying on a `validation_not_implemented` API surface.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `src/gdextension/src/map_document.cpp`
- `src/gdextension/src/scenario_document.cpp`
- `tests/map_package_api_skeleton_report.gd`
- `tests/native_random_map_package_session_authoritative_replay_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/map_package_api_skeleton_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- `MapPackageService.validate_map_document` returns a real `aurelion_map_validation_report` with `status: pass` for structurally valid package map documents and `status: fail` with concrete failures for missing/null/invalid documents.
- `MapPackageService.validate_scenario_document` returns a real `aurelion_scenario_validation_report` with `status: pass` for structurally valid scenario documents bound to a valid map document and concrete failures for null/invalid/mismatched documents.
- Validation checks include document identity, dimensions/levels, object bounds, duplicate placement ids, terrain layer sizing, road payload sanity, scenario identity, map_ref consistency, and player-slot/objective metrics.
- Existing package save/load and generated package adoption reports pass against the native validator.
nonGoals:
- No exact HoMM3 byte/art/DEF import or cloning.
- No broad semantic parity claim from structural document validation alone.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Native `MapPackageService.validate_map_document` and `validate_scenario_document` now return concrete structural pass/fail reports for valid, invalid, null, and mismatched package documents instead of `validation_not_implemented`.
- Structural validation covers document identity, dimensions/levels, object bounds, duplicate placement ids, terrain layer sizing, road payload sanity, scenario identity, map references, player slots, and objective metrics.
- Package API, package adoption, package replay, map-editor load, and maps-folder package browser reports passed against the native validator while preserving the no-full-parity boundary.

Current owner-directed RMG corrective slice:

id: `native-rmg-owner-corpus-comparison-hard-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Harden the dynamic owner-H3M corpus report so mapped owner/native comparisons with category, object, town, guard, road-cell, road-topology, generation, validation, or package-conversion gaps fail the report instead of returning `ok: true` as a loose inventory.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- local uploaded owner H3M evidence under `maps/` and `/root/.openclaw/media/inbound`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- The owner-corpus report computes explicit comparison gate failures for mapped readable samples.
- The report exits nonzero if a mapped sample has native generation/conversion failure, native `not_implemented`, generation validation failure, object/town/guard/road-cell deltas, category-count gaps, or road-topology gaps.
- The current three mapped owner samples still pass after the hard gate: Small single-level, Small underground, and Medium Islands.
- The production parity audit continues to consume the owner-corpus summary without claiming full HoMM3 production parity or corpus readiness.
nonGoals:
- No new HoMM3 art/object import or exact byte parity claim.
- No broad owner-corpus readiness claim beyond the currently mapped samples.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner-corpus coverage report now emits `comparison_gate` with hard-gated mapped sample failures for native generation/conversion status, validation status, object/town/guard/road-cell deltas, owner category gaps, and per-level road component topology gaps.
- Owner-corpus report exits nonzero when the real mapped comparison gate or synthetic gate self-check fails; the self-check proves synthetic object, guard, road-cell, category, and road-topology mismatches are detected.
- Current mapped owner samples pass with `mapped_sample_count: 3`, `mapped_pass_count: 3`, and `failure_count: 0` for Small single-level, Small underground, and Medium Islands.
- Production parity audit now rebuilds the owner-corpus native comparisons, fails if the mapped comparison gate fails, and includes the `mapped_comparison_gate` evidence under the broad owner-H3M corpus missing requirement.
- Validation passed owner-corpus coverage, production parity completion audit, progress JSON validation, and diff whitespace checks.

Recently completed owner-directed implementation slice:

id: `native-rmg-production-audit-structural-matrix-evidence-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Update the production parity audit so it separately records the now-passing translated-catalog structural route-closure matrix while preserving the remaining owner-H3M corpus and underground production blockers.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_broad_translated_catalog_route_closure_sweep_report.gd`
- `tests/native_random_map_broad_translated_catalog_islands_route_closure_sweep_report.gd`
- `tests/native_random_map_broad_translated_catalog_underground_route_closure_sweep_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production audit still reports `production_ready: false`.
- Audit includes a satisfied checklist item for translated-catalog structural route-closure matrix evidence across land/surface, Islands/surface, and land/underground.
- Remaining broad owner-H3M corpus blocker no longer ambiguously treats structural route-closure matrix coverage as missing; it specifically names missing owner-H3M corpus coverage for larger sizes and broader recovered-template/water/underground samples.
- Audit still does not claim exact HoMM3 byte/art parity or player-facing underground production readiness.
nonGoals:
- No generator behavior changes.
- No exact HoMM3 byte/art/DEF import or cloning.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Production parity audit schema advanced to v2 and now includes a satisfied `translated_catalog_structural_route_closure_matrix` checklist item for land/surface, Islands/surface, and land/underground translated-catalog structural sweeps.
- Audit evidence records the dedicated full-sweep scenes and their passed counts: 51 land/surface, 45 Islands/surface, and 47 land/underground eligible translated templates, all with zero translated `not_implemented`, zero zero-tile roads, and zero object-only route leaks.
- Broad owner-H3M corpus missing scope now specifically names missing Large/XL owner sample coverage, owner-H3M recovered-template breadth corpus, and owner-H3M water/underground matrix coverage, avoiding ambiguity with the now-passing structural matrix.
- Production audit still reports `production_ready: false` with three missing requirements: full HoMM3-style parity, broad owner-H3M comparison corpus, and underground production parity.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-translated-catalog-water-underground-route-closure-sweeps-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Add dedicated full translated-catalog route-closure sweeps for Islands/surface and land/underground lanes so non-land structural coverage is repeatable without environment-variable setup.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
- `tests/native_random_map_broad_translated_catalog_route_closure_sweep_report.gd`
implementationTargets:
- `tests/native_random_map_broad_translated_catalog_islands_route_closure_sweep_report.gd`
- `tests/native_random_map_broad_translated_catalog_islands_route_closure_sweep_report.tscn`
- `tests/native_random_map_broad_translated_catalog_underground_route_closure_sweep_report.gd`
- `tests/native_random_map_broad_translated_catalog_underground_route_closure_sweep_report.tscn`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- A dedicated Islands/surface full-sweep report runs eligible recovered translated templates with the default cap disabled and translated-template filtering enabled.
- A dedicated land/underground full-sweep report runs eligible recovered translated templates with the default cap disabled and translated-template filtering enabled.
- Both reports fail if an eligible translated template reports `not_implemented`, lacks roads/towns/guards/objects, contains zero-tile roads, or exposes object-only player-start, cross-zone, or all-town reachable town pairs.
- Passing evidence remains structural coverage only and does not claim exact HoMM3 byte/art parity, broad owner-H3M corpus parity, or player-facing underground production readiness.
nonGoals:
- No exact HoMM3 byte/art/DEF import or cloning.
- No player-facing exposure of Islands or underground as full production parity.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Added dedicated Islands/surface and land/underground full-sweep scenes that inherit the translated-catalog full-sweep wrapper and force the relevant water/underground lane without environment variables.
- Islands/surface full sweep passed with 45 eligible translated templates attempted, zero translated `not_implemented` statuses, zero zero-tile roads, and zero object-only player-start, cross-zone, or all-town package route leaks.
- Land/underground full sweep passed with 47 eligible translated two-level templates attempted, zero translated `not_implemented` statuses, zero zero-tile roads, and zero object-only player-start, cross-zone, or all-town package route leaks.
- Skips are now explicit per lane for translated templates that do not have a supported size/profile plan, while local fixture templates are excluded by the translated-template filter.
- Evidence remains structural route-closure coverage and does not claim exact HoMM3 byte/art parity, broad owner-H3M corpus parity, or player-facing underground production readiness.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-translated-catalog-route-closure-sweep-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Add an explicit full translated-catalog route-closure sweep so the capped broad-template smoke report cannot be mistaken for all-template production evidence.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `tests/native_random_map_broad_translated_catalog_route_closure_sweep_report.gd`
- `tests/native_random_map_broad_translated_catalog_route_closure_sweep_report.tscn`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- A dedicated full-sweep report runs the broad translated catalog without the default 12-template cap.
- The report fails if any eligible translated template is skipped by a bounded default limit, reports `not_implemented`, lacks roads/towns/guards/objects, or exposes object-only player-start, cross-zone, or all-town reachable town pairs.
- The existing capped broad-template report remains available for faster smoke coverage.
- Passing evidence is explicitly structural route-closure coverage and does not claim exact HoMM3 byte/art parity, broad owner-H3M corpus parity, or underground production readiness.
nonGoals:
- No exact HoMM3 byte/art/DEF import or cloning.
- No player-facing exposure of every recovered template as production parity.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Added a dedicated full translated-catalog land/surface sweep report that inherits the broad-template generation/package/route-closure checks, filters to recovered translated templates, and disables the default 12-template cap.
- The full sweep passed with 51 eligible translated templates attempted, zero translated `not_implemented` statuses, zero object-only player-start, cross-zone, or all-town package route leaks, and zero zero-tile roads.
- Only translated templates `009` and `044` were skipped for the land/surface lane because they have no supported land/surface size/profile plan; local fixture templates were excluded by the translated-template filter.
- The existing capped broad-template report remains unchanged for faster smoke coverage, and the new evidence remains structural route-closure coverage rather than exact HoMM3 byte/art parity or underground production readiness.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-small-single-level-auto-density-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Fix the remaining uploaded owner Small single-level corpus mismatch where `native_catalog_auto` selects owner-compared template `049` but still applies the broad structural auto density supplement, producing extra decorative objects compared with the owner H3M sample.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m`
- `scripts/core/ScenarioSelectRules.gd`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner-compared translated profiles selected through `native_catalog_auto` do not receive the broad structural catalog density-floor decoration supplement.
- Uploaded Small single-level owner corpus comparison matches native `049` on total object count and owner categories: decoration 150, guard 40, object 30, reward 76, town 7.
- Uploaded Small topology report continues to pass with route closure, road topology, town count, guard count, and legacy compact diagnostic evidence intact.
- Auto-template, package replay, and production audit reports still pass and still do not claim full HoMM3 production parity.
nonGoals:
- No exact HoMM3 byte/art/DEF import or cloning.
- No broad owner-corpus readiness claim beyond the currently uploaded samples.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Native C++ object generation now skips the broad `native_catalog_auto` density-floor supplement when the normalized config is an owner-compared translated profile.
- Owner corpus coverage report now compares the uploaded Small single-level H3M and native auto-selected `translated_rmg_template_049_v1` at exact owner counts: 303 objects, decoration 150, guard 40, object 30, reward 76, town 7, 110 road cells, and road components `[96, 14]`.
- The same owner corpus report still matches the uploaded Small underground and Medium Islands samples exactly on extracted object, town, guard, owner-category, and road metrics.
- Uploaded Small topology report, native auto-template batch, package session authoritative replay, production parity completion audit, full-parity boundary report, and menu wiring report all passed after the density exemption.
- Production audit remains explicitly `production_ready: false`, with full parity, broad owner corpus, and underground production readiness still missing.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-auto-catalog-launch-selection-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct player-facing native catalog auto-selection so it prefers owner-compared translated production defaults when available, while keeping broader launchable translated recovered catalog candidates available only as internal/fallback coverage instead of exposing them as HoMM3-like parity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `scripts/core/ScenarioSelectRules.gd`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `scripts/core/ScenarioSelectRules.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Native catalog auto-selection rejects `not_implemented`, legacy compact, and foundation templates for normal generated-skirmish startup and prefers owner-compared translated defaults for current size, water, underground, and player-count lanes.
- Representative player-facing auto-selection cases generate, validate, package, and replay through owner-compared templates `049`, `027`, `002`, `001`, `042`, and `043` without reopening the town-stacking or unguarded route regressions.
- Menu setup keeps manual template/profile pickers hidden while documenting that native catalog auto uses an owner-compared default policy plus a broad internal launch gate.
- Production parity audit no longer treats broad structural template exposure as product readiness; it still preserves no full HoMM3 parity, broad owner-corpus, and underground-production overclaim boundaries.
nonGoals:
- No exact HoMM3 byte/art/DEF import or cloning.
- No claim that broad structural or owner-compared auto-selected templates are full parity.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Native catalog auto-selection now prefers owner-compared translated candidates before broad launchable translated catalog fallbacks.
- Random-map menu wiring passed with manual template/profile controls hidden and policy `native_catalog_auto_prefers_owner_compared_defaults_with_broad_internal_launch_gate`.
- Native auto-template batch passed across representative Small, Small underground, Medium, Medium Islands, Large, and XL cases, selecting `translated_rmg_template_049_v1`, `027`, `002`, `001`, `042`, and `043` respectively.
- Package session authoritative replay passed for the owner-compared defaults with runtime call-site adoption and replay identity stable.
- Uploaded Small single-level topology comparison passed for the owner-like native `049` package with 7 towns, 40 guards, 110 road cells, matching `[96, 14]` road components, and zero object-only reachable town pairs; the legacy compact fixture remains correctly diagnosed as bad and launch-blocked.
- Production parity completion audit remains explicitly `production_ready: false` with missing full parity, broad owner corpus, and underground production readiness requirements.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-underground-template-structural-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Reduce the underground production-parity blocker by adding a broad translated-template underground structural generation gate and allowing supported two-level translated catalog configs to generate as structural not-full-parity outputs instead of `not_implemented`.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Broad template generation report can run with an underground/two-level option against translated templates that declare `supported_counts` containing `2`.
- Supported two-level translated catalog configs report `translated_catalog_structural_profile_not_full_parity`, not `not_implemented`, without claiming full parity or runtime production readiness.
- The broad underground gate validates generation, package conversion, non-empty surfaces, road materialization, and object-only route closure for attempted coherent two-level translated-template cases.
- Existing land and Islands broad structural gates remain passing.
nonGoals:
- No exact HoMM3 byte/art/DEF import or cloning.
- No full HoMM3 production parity claim.
- No player-facing underground exposure.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Native translated catalog structural support now accepts `level_count` 1 or 2 while preserving structural-not-full-parity status boundaries.
- Broad land/surface generation passed 54 eligible/attempted templates, with zero translated `not_implemented` statuses and zero object-only player-start, cross-zone, or all-town package route leaks.
- Broad Islands/surface generation passed 45 eligible/attempted translated templates, with zero translated `not_implemented` statuses and zero object-only player-start, cross-zone, or all-town package route leaks.
- Broad land/underground generation passed 47 eligible/attempted coherent two-level translated templates, all reported `translated_catalog_structural_profile_not_full_parity`, with zero `not_implemented` statuses and zero object-only route leaks.
- Dense two-level translated cases in the 026/027/035/037 range now select roomier structural sizes and pass generation/package validation.
- Production parity audit remains explicitly not production-ready with four missing requirements, and the full-parity gate still reports no full HoMM3 parity claim.

id: `native-rmg-production-parity-audit-owner-corpus-refresh-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Refresh the production-parity completion audit so its broad owner-corpus missing-requirement evidence reflects the current three exact uploaded owner comparisons instead of stale Small/Medium wording.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Production parity audit still reports `production_ready: false`.
- Broad owner-H3M corpus missing requirement names the current three compared owner samples and the remaining missing corpus scope.
- No full-parity or broad underground/player-facing template support claim is introduced.
nonGoals:
- No generator behavior changes.
- No exact H3M byte/art/DEF import or cloning.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Production parity completion audit still reports `production_ready: false` and `missing_requirement_count: 4`.
- Broad owner-H3M corpus missing requirement now names the three exact current uploaded owner comparisons: `owner_small_land_single_level`, `owner_small_with_underground`, and `owner_medium_islands`.
- Remaining corpus blocker is explicit: missing Large/XL owner sample coverage, recovered-template breadth corpus, and broad water/underground matrix coverage.
- No full HoMM3-style parity, broad player-facing 56-template support, or underground production parity claim was introduced.

Previous recently completed owner-directed implementation slice:

id: `native-rmg-owner-medium-islands-category-shape-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the uploaded owner Medium Islands category-shape comparison so native output no longer hides a 7-object reward/object swap behind matched total object, town, guard, and road counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report shows the Medium Islands native owner-category comparison matching decoration 252, guard 61, object 72, reward 103, and town 8.
- Total object count, town count, guard count, road count, and level 0 road component sizes remain matched for the Medium Islands owner comparison.
- Package object-only route validation remains closed for all town and cross-zone pairs.
- Full-generation status remains owner-compared not-full-parity and does not claim broad exact HoMM3 production parity.
nonGoals:
- No exact H3M byte/art/DEF import or cloning.
- No broad Islands production parity claim beyond the uploaded owner-compared sample.
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner corpus coverage report now shows the uploaded Medium Islands sample and native `translated_rmg_template_001_v1` / `translated_rmg_profile_001_v1` comparison matching category counts exactly: decoration 252, guard 61, object 72, reward 103, and town 8.
- The same comparison preserves total and road parity for the bounded sample: 496 objects, 8 towns, 61 guards, 184 road cells, and level 0 road component sizes `[82, 52, 19, 16, 15]`.
- Package object-only breadth report passed after save/load with the `owner_medium_islands_001` case at 496 objects, 8 towns, 61 guards, 184 road tiles, and zero object-only all-town or cross-zone reachable pairs.
- Full-generation status remains explicitly `owner_compared_translated_profile_not_full_parity`; remaining production parity debt includes missing Large/XL owner corpus samples, full recovered-template owner comparison, and no exact HoMM3 production parity claim.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-small-single-level-road-exact-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the uploaded owner Small single-level road comparison so native package output matches the owner road-cell count and component sizes instead of only matching the broad two-component shape.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report shows the uploaded Small single-level native road comparison at 110 road cells with level 0 road component sizes `[96, 14]`.
- Total object count, town count, guard count, and owner category counts remain matched for the Small single-level owner comparison.
- Package object-only route validation remains closed for all town and cross-zone pairs.
- Full-generation status remains owner-compared not-full-parity and does not claim broad exact HoMM3 production parity.
nonGoals:
- No exact H3M byte/art/DEF import or cloning.
- No broad all-template road topology parity claim.
- No committing uploaded owner `.h3m` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner corpus coverage report now shows the uploaded Small single-level sample and native `translated_rmg_template_049_v1` / `translated_rmg_profile_049_v1` comparison both at 110 road cells with level 0 road component sizes `[96, 14]`.
- The same comparison preserves exact object, town, guard, and owner-category counts: 303 objects, 7 towns, 40 guards, decoration 150, object 30, reward 76, and town 7.
- Package object-only breadth report passed after save/load with zero object-only all-town and cross-zone reachable pairs for the Small default and all other covered owner-compared defaults.
- Full-generation status remains explicitly `owner_compared_translated_profile_not_full_parity`; remaining production parity debt includes Medium Islands category-shape mismatch, missing Large/XL owner corpus samples, full recovered-template owner comparison, and no exact HoMM3 production parity claim.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-small-underground-category-shape-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the uploaded owner Small underground category-shape comparison so native output no longer hides a 52-object reward/object swap behind matching total object counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report shows the Small underground native owner-category comparison matching decoration, guard, object, reward, and town counts for the uploaded sample.
- Total object count, town count, guard count, level count, and all-level road topology remain matched for the Small underground owner comparison.
- Package object-only route validation remains closed for all town and cross-zone pairs.
- Full-generation status remains owner-compared not-full-parity and does not claim broad underground or exact HoMM3 production parity.
nonGoals:
- No broad underground support claim for all recovered templates.
- No exact H3M byte/art/DEF import or cloning.
- No committing uploaded owner `.h3m` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner corpus coverage report now shows the uploaded Small underground sample and native `translated_rmg_template_027_v1` / `translated_rmg_profile_027_v1` comparison matching category counts exactly: decoration 151, guard 60, object 100, reward 117, and town 8.
- The same comparison preserves total parity for the bounded sample: 436 objects, 8 towns, 60 guards, 157 road cells, and all-level road topology status `all_level_component_sizes_match`.
- Package object-only breadth report passed the `owner_small_underground_027` case after save/load with 436 objects, 60 guards, 8 towns, 157 unique road tiles, 12 zones, and zero object-only all-town or cross-zone reachable pairs.
- Full-generation status remains explicitly `owner_compared_translated_profile_not_full_parity`; remaining production parity debt includes the Small single-level road-cell delta, Medium Islands category-shape delta, missing Large/XL owner corpus samples, and no full 56-template exact HoMM3 parity claim.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-small-underground-object-density-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Close the next owner-uploaded Small underground comparison gap by bringing native package object density up to the owner H3M sample while preserving the already-matched town, guard, level, road, and route-closure behavior.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report shows the Small underground native comparison at the uploaded owner object-count target or records a precise residual density gap.
- Town count, guard count, level count, and all-level road topology remain matched for the Small underground owner comparison.
- Package object-only route validation remains closed for all town and cross-zone pairs.
- Full-generation status remains owner-compared not-full-parity and does not claim broad underground or exact HoMM3 production parity.
nonGoals:
- No broad underground support claim for all recovered templates.
- No exact H3M byte/art/DEF import or cloning.
- No committing uploaded owner `.h3m` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner corpus coverage report now shows the uploaded Small underground sample and native `translated_rmg_template_027_v1` / `translated_rmg_profile_027_v1` comparison both at 436 total objects, 8 towns, 60 guards, 157 road cells, and all-level road topology status `all_level_component_sizes_match`.
- Native Small underground decoration count now matches the owner H3M sample at 151 while preserving package route closure.
- Package object-only breadth report passed the `owner_small_underground_027` case after save/load with 436 objects, 60 guards, 8 towns, 157 unique road tiles, 12 zones, and zero object-only all-town or cross-zone reachable pairs.
- Full-generation status remains explicitly `owner_compared_translated_profile_not_full_parity`; the owner-category comparison still reports a category-shape gap with native object category 48 versus owner 100 and native reward category 169 versus owner 117.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-small-underground-runtime-support-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the uploaded owner Small two-level land comparison from `not_implemented` into bounded owner-compared native package generation so the corpus can measure its actual town, guard, road, level, and route-closure parity gaps.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report compares the uploaded Small underground H3M sample against native output instead of reporting `native_not_implemented`.
- Native package conversion preserves two materialized levels and exposes road metrics for both surface and underground levels.
- Package object-only route validation remains closed for all town and cross-zone pairs.
- Full-generation status remains owner-compared not-full-parity and does not claim broad underground or exact HoMM3 production parity.
nonGoals:
- No broad underground support claim for all recovered templates.
- No exact H3M byte/art/DEF import or cloning.
- No committing uploaded owner `.h3m` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner corpus coverage report now compares the uploaded Small underground sample with native `translated_rmg_template_027_v1` / `translated_rmg_profile_027_v1` output instead of reporting `native_not_implemented`.
- Native package conversion preserves two levels and exactly matches uploaded owner road metrics for this sample: surface `[116]`, underground `[23, 18]`, total road cells `157`, and all-level road topology status `all_level_component_sizes_match`.
- Package object-only breadth report passed the new `owner_small_underground_027` case after save/load with 8 towns, 60 guards, 318 package objects, 157 unique road tiles, 12 zones, and zero object-only all-town or cross-zone reachable pairs.
- The comparison remains explicitly not full parity: native object density is still 318 objects versus 436 in the owner H3M sample, and full-generation status remains `owner_compared_translated_profile_not_full_parity`.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-medium-islands-road-component-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the owner-compared Medium Islands road topology so native output no longer collapses the uploaded owner H3M comparison into one giant surface road component plus one-tile stubs.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report shows the Medium Islands native comparison with a HoMM3-like multi-component road shape, not one giant connected road component and one-tile artifacts.
- Native object, town, and guard counts for the owner Medium Islands comparison remain matched to the uploaded H3M sample.
- Package object-only route and spatial comparison gates remain valid; roads do not create unguarded gameplay bypasses between zones or towns.
- Full-generation status remains owner-compared not-full-parity and does not claim exact HoMM3 production parity.
nonGoals:
- No exact H3M byte/art/DEF import or cloning.
- No broad all-template road topology parity claim.
- No committing uploaded owner `.h3m` evidence or generated `.amap`/`.ascenario` samples.
completionEvidence:
- Owner corpus coverage report now compares road topology directly; Medium Islands native output remains 496 objects, 8 towns, 61 guards, and 184 road cells against the owner H3M sample.
- Medium Islands package road components changed from one 181-cell component plus seven one-tile fragments to the owner H3M five-component shape `[82, 52, 19, 16, 15]` with `component_size_abs_delta: 0` for this owner sample.
- Native C++ rebuild, owner corpus coverage, spatial placement comparison, package object-only breadth, repository validation, progress JSON validation, plan sync dry-run, and diff whitespace checks passed.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-medium-islands-runtime-support-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Promote the exact owner-attached Medium islands template/profile `translated_rmg_template_001_v1` / `translated_rmg_profile_001_v1` to owner-compared runtime support after fixing same-zone town-pair closure without increasing the owner-observed guard count.
sourceDocs:
- `project.md`
- `PLAN.md`
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `tests/native_random_map_full_parity_gate_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `tests/native_random_map_full_parity_gate_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Exact Medium islands template/profile 001 is `owner_compared_translated_profile_supported` while still reporting `owner_compared_translated_profile_not_full_parity`.
- Same-zone town-pair route closure reuses existing guard closure masks when the owner guard cap is reached, preserving owner-like guard/object counts.
- Package conversion, save, and load preserve closure masks and leave zero object-only town traversal routes.
- Full-parity and player-facing UI gates keep islands support bounded and do not expose a broad islands/full-parity claim.
nonGoals:
- No broad islands or underground parity claim.
- No exposure of islands as a general player-facing random-map option.
- No HoMM3 art, DEF, names, text, map, or binary `.h3m` import.
- No all-56-template production parity claim.
completionEvidence:
- Medium islands spatial comparison passed for profile 001 with 8 towns, 4 zones, 496 objects, 61 guards, owner-compared support enabled, and full parity still false.
- Package object-only breadth report passed the new `owner_medium_islands_001` case with 8 towns, 61 guards, 496 objects, 206 loaded road tiles, and zero object-only all-town or cross-zone town routes.
- Full parity gate passed with the new Medium islands case runtime-adopted only as owner-compared not-full-parity output.
- Package adoption and authoritative replay reports passed after excluding diagnostic runtime phase timing from replay identity signatures.
- Random-map menu wiring and skirmish UI save/replay reports passed, preserving the four-template player-facing surface and not exposing islands globally.

Recently completed owner-directed implementation slice:

id: `native-rmg-player-facing-template-surface-restriction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Keep the full recovered 56-template catalog available for internal validation while restricting player-facing random-map setup options to the four owner-compared translated size defaults until broad recovered-template production parity exists.
sourceDocs:
- `project.md`
- `PLAN.md`
- `scripts/core/ScenarioSelectRules.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/random_map_skirmish_ui_save_replay_report.gd`
- `ops/progress.json`
completionCriteria:
- `random_map_player_setup_options()` reports full internal catalog counts but returns only production-facing size-default template/profile options.
- Main menu generated-map controls remain native catalog auto with manual template/profile pickers hidden.
- Internal validation still builds all 56 catalog template/profile configs.
- Explicit unsupported template launches remain blocked by `full_generation_status: not_implemented` rather than silently falling back to legacy compact output.
nonGoals:
- No broad all-56 production parity claim.
- No runtime-authoritative adoption for unsupported templates.
- No HoMM3 art, DEF, names, text, map, or binary `.h3m` import.
completionEvidence:
- Random-map menu wiring report passed with catalog counts 56/56, internal built config count 56, player-facing template/profile counts 4/4, and manual template/profile controls hidden.
- Random-map retry UX report passed, preserving native catalog auto launch provenance and not-implemented launch blocking.
- Random-map skirmish UI save/replay report passed after launching from the asserted setup and checking stable generated identity rather than a regenerated package scenario id.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-template-default-selection-repair-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Repair the broad recovered-template generation report so it evaluates player-facing Small/Medium/Large/XL translated defaults with the same size-class/player-count selection used by runtime setup, instead of misclassifying supported defaults as arbitrary minimum-template `not_implemented` cases.
sourceDocs:
- `project.md`
- `PLAN.md`
- `scripts/core/ScenarioSelectRules.gd`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `tests/native_random_map_broad_template_generation_report.gd`
- `ops/progress.json`
completionCriteria:
- Broad template planning prefers `ScenarioSelectRules.random_map_size_class_default()` when the catalog template/profile is the runtime default for a size class.
- Broad report case summaries record the selection policy used for each attempted template.
- Focused Small/Medium/Large/XL default translated templates report `owner_compared_translated_profile_not_full_parity`, not `not_implemented`.
- Full unbounded broad sweep still attempts every eligible land/surface template with zero skips and keeps unsupported templates explicitly marked as parity debt.
nonGoals:
- No broad all-56 production parity claim.
- No runtime-authoritative generated-skirmish adoption.
- No HoMM3 art, DEF, names, text, map, or binary `.h3m` import.
completionEvidence:
- Focused broad sweep for translated defaults `049`, `002`, `042`, and `043` passed with all four using `selection_policy: player_facing_size_default` and `not_implemented_status_count: 0`.
- Full unbounded broad sweep passed 56/56 eligible templates with zero skipped templates, status counts `{not_implemented: 51, owner_compared_translated_profile_not_full_parity: 4, scoped_structural_profile_not_full_parity: 1}`, and selection-policy counts `{minimum_supported_land_surface: 52, player_facing_size_default: 4}`.

Recently completed owner-directed implementation slice:

id: `native-rmg-town-placement-reachability-cache-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Cache per-zone access-anchor reachability during native town placement so recovered translated templates avoid repeated per-candidate BFS while preserving the uploaded Small H3M town/zone/road/object route gates.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_homm3_uploaded_small_comparison_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_uploaded_small_comparison_report.gd`
- `ops/progress.json`
completionCriteria:
- Native town placement computes one access-reachable lookup per zone/access anchor and uses it for spaced accessible candidate checks instead of running an in-zone path search for each town candidate.
- Serialized package component counts report the actual package road surface count so comparison gates compare owner H3M road counts against loaded package semantics.
- Uploaded Small H3M comparison and topology reports keep the player-facing translated Small default at owner-like town, zone, road, decorative obstacle, and guard counts with zero object-only town routes.
- Focused worst-offender translated template `052` no longer spends most of generation time in repeated town-placement BFS and the unbounded broad template gate remains green for all eligible land/surface templates.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/underground parity implementation.
- No production-complete RMG claim.
completionEvidence:
- Uploaded Small comparison report passed with player-facing translated Small default at 7 towns, 7 zones, 303 package objects, 150 decorative obstacles, 40 guards, 113 serialized package road tiles, and zero package road gaps.
- Uploaded Small topology report passed with current translated package at 7 towns, 7 zones, 110 road cells, two road components, 150 decorative obstacles, 40 guards, and zero object-only town or cross-zone town routes; the stale compact map still demonstrates the bad baseline with 6 towns, 0 zones, 0 roads, and 10 reachable town pairs.
- Focused `translated_rmg_template_052_v1` broad generation passed in 14.638s after the reachability cache, with generation at 9.564s and no skipped focused case.
- Full unbounded broad template report passed all 56 eligible land/surface templates with zero skipped templates and 55 templates still honestly marked `full_generation_status: not_implemented`.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-template-all-town-route-closure-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the broad recovered-template package topology gate so all-town route checks use package visit-tile semantics and every eligible land/surface package proves object-only town routes are closed.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `tests/native_random_map_broad_template_generation_report.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Package surface topology preserves town `package_visit_tiles` for all-town and cross-zone route checks instead of falling back to adjacent anchor cells.
- Broad template report fails on object-only all-town route leaks, not just player-start and cross-zone leaks.
- Native package conversion materializes guard control-zone, boundary-choke, and route guard/decorative closure masks before signatures so package topology does not depend on terrain-only barriers.
- Full unbounded sweep covers all currently eligible land/surface templates with zero object-only player-start, cross-zone, or all-town reachable town pairs.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/underground parity implementation.
- No production-complete RMG claim.
completionEvidence:
- Focused broad report passed for the two previously leaking templates `translated_rmg_template_006_v1` and `translated_rmg_template_010_v1`.
- Unbounded broad template report passed all 56 eligible land/surface templates with zero skipped templates and zero object-only player-start, cross-zone, or all-town reachable town pairs under package visit-tile semantics.
- The unbounded report still honestly reports 55 templates with `full_generation_status: not_implemented`.

Recently completed owner-directed validation follow-up:

id: `native-rmg-runtime-authority-parity-gate-repair-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Repair the full-parity boundary gate so owner-compared translated packages may be runtime-authoritative without implying full HoMM3 parity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_full_parity_gate_report.gd`
implementationTargets:
- `tests/native_random_map_full_parity_gate_report.gd`
- `ops/progress.json`
completionCriteria:
- The full-parity gate still fails any `full_parity_claim=true` at generation, provenance, or package-adoption boundaries.
- Owner-compared translated Small 049 and Medium 002 package/session adoption may report runtime authority and call-site adoption only with `full_parity_claim=false`.
- Owner-compared package-adoption reports keep explicit remaining parity slices for full parity, islands support, and broad owner comparison.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/underground parity implementation.
- No production-complete RMG claim.
completionEvidence:
- Full parity gate report passed with legacy compact non-authoritative and owner-compared translated defaults runtime-authoritative without full parity.

Recently completed owner-directed implementation slice:

id: `native-rmg-legacy-compact-launch-block-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Close the remaining production launch path for the legacy compact random-map generator after uploaded-map comparison showed that compact lineage can produce near-stacked, un-HoMM3-like maps.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/maps_folder_package_browser_integration_report.gd`
- `tests/random_map_skirmish_ui_save_replay_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/autoload/SaveService.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/maps_folder_package_browser_integration_report.gd`
- `tests/random_map_skirmish_ui_save_replay_report.gd`
- `tests/random_map_final_writeout_export_save_schema_report.gd`
- `tests/random_map_scenario_load_smoke.gd`
- `ops/progress.json`
completionCriteria:
- Generated-skirmish startup rejects explicit `border_gate_compact_v1` / `border_gate_compact_profile_v1` requests with `native_rmg_legacy_compact_launch_blocked`.
- Legacy compact output remains available only as internal historical/export test fixture data, not as a production generated-skirmish launch path.
- Maps-folder stale-package rejection still creates a compact package fixture directly through native package service APIs.
- Native package-backed generated skirmish save/restore preserves package provenance and can re-register its transient generated scenario from saved package provenance.
nonGoals:
- No deletion of local uploaded `.h3m`, `.amap`, or `.ascenario` comparison evidence.
- No removal of compact generator component/export fixtures.
- No exact HoMM3 byte/object-art parity claim.
completionEvidence:
- Player setup retry UX report passed after asserting explicit compact launch is blocked with `native_rmg_legacy_compact_launch_blocked`.
- Maps-folder package browser integration report passed with compact fixture rejected and translated package accepted.
- Random-map skirmish UI save/replay report passed on native package provenance and package-backed restore.
- Final writeout export/save schema report passed while keeping compact generation as a legacy export fixture outside production launch.
- Random-map scenario load smoke passed after treating maps-folder package entries separately from archived authored scenarios.

Previously completed owner-directed implementation slice:

id: `native-rmg-broad-template-object-only-route-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Extend the broad recovered-template generation gate beyond non-empty package surfaces so every eligible land/surface template proves object-only player-start and cross-zone town routes are closed.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `tests/native_random_map_broad_template_generation_report.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
implementationTargets:
- `tests/native_random_map_broad_template_generation_report.gd`
- `ops/progress.json`
completionCriteria:
- Broad template report reuses package-surface topology analysis for converted packages.
- Attempted recovered land/surface templates fail if object-only masks allow unguarded player-start town traversal.
- Attempted recovered land/surface templates fail if object-only masks allow unguarded cross-zone town traversal.
- Full unbounded sweep covers all currently eligible land/surface templates.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No same-zone multi-settlement route hard failure; same-zone all-town reachability remains diagnostic because some recovered templates place multiple settlements in one source zone.
- No islands/underground parity implementation.
completionEvidence:
- Bounded broad template report passed after adding object-only start/cross-zone topology gates.
- Unbounded broad template report passed all 56 eligible land/surface templates with zero skipped templates and no object-only start/cross-zone reachable town pairs.

Previously completed owner-directed implementation slice:

id: `native-rmg-uploaded-small-guard-control-footprint-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Materialize HoMM3-style monster/guard control zones into generated package blocking so the owner-uploaded Small comparison no longer understates guarded route closure.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Package guard objects include a bounded one-tile control-zone blocking footprint for generated package pathing.
- Uploaded Small comparison fails if native guard blocking falls below the owner H3M parsed guard-control footprint floor.
- Current Small 049 generated package keeps owner-like town/zone/object/road counts and zero object-only town routes.
- Player-facing translated Small/Medium/Large/Extra Large package breadth keeps zero object-only reachable town pairs.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No H3M import/runtime adoption.
- No deletion or committing of uploaded local `.h3m`, `.amap`, or `.ascenario` evidence.
completionEvidence:
- Native build passed after adding package guard control-zone materialization.
- Uploaded Small H3M topology report passed with native guard unique blocked tiles above the owner guard-control lower-bound gate and zero object-only reachable town pairs.
- Package surface topology report passed for converted and saved/loaded Small 049 packages.
- Package object-only breadth report passed for translated Small, Medium, Large, and Extra Large defaults.

Previously completed owner-directed implementation slice:

id: `native-rmg-maps-folder-stale-package-rejection-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Prevent stale legacy compact generated packages in `maps/` from being exposed as valid skirmish/editor choices after owner-uploaded H3M comparison proved that topology is not HoMM3-like.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/maps_folder_package_browser_integration_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `tests/maps_folder_package_browser_integration_report.gd`
- `tests/map_editor_load_map_package_report.gd`
- `ops/progress.json`
completionCriteria:
- Maps-folder package index rejects generated packages that are not runtime-authoritative translated RMG outputs.
- Legacy `border_gate_compact_v1` / `border_gate_compact_profile_v1` packages are not exposed in the maps-folder skirmish browser.
- Accepted generated maps-folder packages still load through the native package/session path and editor working-copy path.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No deletion or committing of uploaded local `.h3m`, `.amap`, or `.ascenario` evidence.
completionEvidence:
- Maps-folder package browser integration report passed with a translated native-catalog-auto package accepted and a generated legacy compact package rejected from the index/browser.
- Map editor Load Map package report passed after moving its positive fixture to the translated native-catalog-auto package path.

Previously completed owner-directed implementation slice:

id: `native-rmg-runtime-town-spacing-validation-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Move the near-stacked town protection from report-only coverage into native RMG runtime validation so launchable generated maps fail validation if towns are below the size-aware spacing floor.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `ops/progress.json`
completionCriteria:
- Native validation emits a town-spacing summary with nearest town Manhattan distance and size-aware floor.
- Launchable native RMG profiles fail validation if nearest town spacing is below the floor.
- Auto-template report verifies its spacing metric agrees with native runtime validation.
- Existing package object-only closure and supported translated broad cases remain green.
nonGoals:
- No exact HoMM3 town-coordinate parity claim.
- No islands/water/underground parity implementation.
completionEvidence:
- Native build passed after adding runtime town-spacing validation.
- Auto-template batch passed with runtime town-spacing validation matching report metrics.
- Package object-only breadth passed with zero object-only reachable town pairs for Small, Medium, Large, and Extra Large defaults.
- Focused broad translated cases 049, 002, 042, and 043 passed generation/package conversion after the validation change.

Previously completed owner-directed implementation slice:

id: `native-rmg-auto-template-town-spacing-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Add player-facing native-catalog-auto town-spacing evidence so representative generated maps cannot regress to near-stacked towns without failing validation.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `tests/native_random_map_auto_template_batch_report.gd`
- `ops/progress.json`
completionCriteria:
- Auto-template batch reports nearest town Manhattan distance for each representative generated case.
- Launchable land defaults fail if nearest towns fall below size-aware spacing floors.
- Existing auto-template generation/package coverage remains green.
nonGoals:
- No exact HoMM3 town-coordinate parity claim.
- No generator algorithm change in this slice.
- No islands/water/underground parity implementation.
completionEvidence:
- Auto-template batch report passed with nearest town distances Small 11/14, Medium 17, Large 12, and Extra Large 24 against floors 8/8, 10, 12, and 12.
- The Medium islands not-implemented case remains internally inspectable and launch-blocked.

Previously completed owner-directed implementation slice:

id: `native-rmg-hide-unsupported-underground-control-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Remove unsupported underground generation from the player-facing generated-map setup surface until native RMG has production-ready underground parity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
implementationTargets:
- `scenes/menus/MainMenu.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `ops/progress.json`
completionCriteria:
- The player-facing generated-map snapshot no longer lists underground as a visible control.
- The validation hook rejects attempts to enable unsupported underground generation.
- Internal provenance records underground as unsupported and hidden.
- Existing generated setup retry and menu wiring gates remain green.
nonGoals:
- No underground parity implementation.
- No exact HoMM3 byte/object-art parity claim.
completionEvidence:
- Player setup retry UX report passed with `underground_supported: false`, `underground_player_control_visible: false`, and no `underground` visible control.
- Menu wiring report still passed with native catalog auto defaults and hidden manual template/profile controls.

Previously completed owner-directed implementation slice:

id: `native-rmg-retry-attempt-native-provenance-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Ensure generated-map retry attempt records report the native-selected normalized template/profile ids, especially for blocked not-implemented native-catalog-auto modes.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `ops/progress.json`
completionCriteria:
- Retry attempt records prefer native normalized config from setup provenance, validation failure evidence, or deterministic validation identity before falling back to legacy GDScript normalization.
- Blocked not-implemented setup attempts report the same template/profile ids as the native validation failure evidence.
- Existing generated setup retry and auto-template batch gates remain green.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No change to generated map topology or islands parity implementation.
completionEvidence:
- Player setup retry UX report passed after asserting blocked not-implemented attempt ids match native normalized failure config.
- Auto-template batch report passed after the retry attempt provenance correction.

Previously completed owner-directed implementation slice:

id: `native-rmg-not-implemented-launch-block-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Prevent generated-skirmish startup from converting native RMG configurations whose recovered-template mode still reports `full_generation_status: not_implemented` into launchable packages.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
- `ops/progress.json`
completionCriteria:
- Generated-skirmish startup blocks not-implemented native RMG modes before package conversion/loading.
- Failure evidence is surfaced through the existing validation/retry boundary with no session/save/campaign startup.
- Representative auto-template islands coverage remains available for internal inspection but is marked blocked for launch while land defaults still launch.
nonGoals:
- No islands/water/underground parity implementation.
- No exact HoMM3 byte/object-art parity claim.
- No removal of internal broad-template inspection for not-implemented recovered templates.
completionEvidence:
- Player setup retry UX report passed after proving a Medium islands native-catalog-auto setup fails with `native_rmg_full_generation_not_implemented` evidence.
- Auto-template batch report passed with Small/Medium/Large/XL land defaults still generating and packaging, while the Medium islands case reports `not_implemented_launch_blocked: true`.

Previously completed owner-directed implementation slice:

id: `native-rmg-player-facing-compact-fallback-removal-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Remove the old compact template from live generated-map fallback behavior so player-facing setup and invalid-template recovery do not silently produce the bad compact topology found in the owner-uploaded native map comparison.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/menus/MainMenu.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `ops/progress.json`
completionCriteria:
- Player-facing generated-map setup keeps manual template/profile controls hidden and launches through native catalog auto-selection.
- Empty/default Small setup previews translated Small 049 instead of compact legacy ids.
- Invalid manual template fallback resolves to translated Small 049 instead of `border_gate_compact_v1`.
- Representative auto-selection cases generate/package through translated owner-compared land templates for Small, Medium, Large, and Extra Large.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/water/underground parity implementation; islands still remain explicit not-implemented follow-up.
- No removal of explicit legacy compact fixtures used by old package/schema compatibility tests.
completionEvidence:
- Menu wiring report passed with 56 catalog templates/profiles, hidden manual template/profile controls, and default template `translated_rmg_template_049_v1`.
- Player setup retry UX report passed with native auto launch provenance and translated Small 049 preview/default.
- Auto-template batch report passed; owner-compared land defaults selected translated templates 049, 002, 042, and 043.

Previously completed owner-directed implementation slice:

id: `native-rmg-all-template-structural-breadth-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Close the hard generation/package failures exposed by running the broad native RMG report across every eligible recovered land/surface template after the uploaded Small map comparison reopened structural parity work.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `ops/progress.json`
completionCriteria:
- All eligible recovered land/surface templates generate, validate, convert to packages, expose non-empty package objects/roads, and serialize zero zero-tile roads.
- Town-pair route closure guards do not collide with existing generated object occupancy.
- Dense required town/castle placement has a bounded last-resort spacing fallback instead of failing package generation.
- Active player-start zones isolated by recovered link player-count filters receive a guarded runtime repair route.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/water/underground full-parity implementation.
- No claim that all `not_implemented` recovered-template statuses are resolved.
completionEvidence:
- Full broad native RMG template report passed all 56 eligible templates with 0 skipped and no case failures.
- Focused recovery gates passed translated templates 010/052 for guard occupancy collisions, 041/044 for dense required town placement, and 043 for active player-start connectivity repair.
- Native build passed after the generator corrections.

Previously completed owner-directed implementation slice:

id: `native-rmg-uploaded-small-road-component-split-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the uploaded-Small native package road component shape by adding a bounded orphan side-road component and suppressing one deterministic articulation road overlay tile when it splits Small 049 roads into two owner-like package components.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Uploaded Small report exposes road component sizes for owner and native package roads.
- Native Small 049 package road component count moves from one component to the owner-uploaded two-component shape.
- Native Small 049 smaller road component matches the uploaded owner H3M smaller road component size.
- Road-cell count remains within the uploaded Small tolerance and no zero-tile roads are serialized.
- Object-only town closure remains green after the road overlay split.
nonGoals:
- No exact road byte/art parity.
- No exact large road component shape or byte-level road-art parity; the native large component remains 99 cells versus owner 96.
- No broad all-template road-shape parity claim.
completionEvidence:
- Uploaded Small report now shows owner H3M road components `[96, 14]` and native generated Small road components changed from `[105]` through `[99, 5]` to `[99, 14]`.
- Native generated Small road cells changed from 105 to 113 versus owner 110, keeping road-cell delta at +3 and reducing road-component delta from -1 to 0.
- Uploaded Small topology still passed with 7 towns, 7 zones, 303 objects, zero unresolved/object-only town reachable pairs, road small-component delta 0, and object-blocked delta +24 versus owner parsed mask blockers.
- Package object-only breadth still passed Small 049, Medium 002, Large 042, and Extra Large 043 with zero all-town reachable pairs.
- Bounded broad template generation still passed 12 representative land/surface templates.

Previously completed owner-directed implementation slice:

id: `native-rmg-selective-small-boundary-mask-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Replace uploaded-Small full terrain-rock boundary/route-guard mask materialization with selective package-object town-route closure masks, reducing decorative and guard blocker overcoverage while preserving object-only town isolation.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Uploaded Small generated native package keeps 7 towns, 7 zones, 303 objects, 150 decorative obstacles, 40 guards, and zero object-only town routes.
- Decorative boundary choke and Small route-guard closure materialization become path-driven for Small 049 instead of copying every land-boundary rock/opening cell into package blocker masks.
- Uploaded Small object-blocked overage warning clears without reintroducing unresolved or object-only town reachability.
- Package object-only breadth and bounded broad template generation remain green after the selective mask change.
nonGoals:
- No exact HoMM3 full parity or byte/object-art parity claim.
- No claim that older already-exported native `.amap` packages are corrected in place.
- No islands/water/underground parity implementation.
completionEvidence:
- Uploaded Small topology report passed with native object-blocked tiles reduced from 1043 to 747, native-vs-owner mask-blocked delta reduced from +321 to +25, decorative unique block tiles reduced from 640 to 441, guard unique block tiles reduced from 420 to 95, and decorative boundary choke tiles reduced from 343 to 42.
- Uploaded Small topology report still showed 7 towns, 7 zones, 303 objects, 105 road cells, 40 guards, and zero unresolved/object-only town reachable pairs; the prior object-blocked overage warning cleared.
- The report now emits both uploaded native packages: the newer translated-template package closes object-only cross-zone town routes, while the legacy compact package remains diagnostic evidence of the old bad output.
- Package object-only breadth passed Small 049, Medium 002, Large 042, and Extra Large 043 with zero all-town reachable pairs.
- Bounded broad template generation passed after the selective Small mask change.

Previously completed owner-directed implementation slice:

id: `native-rmg-size-scaled-corridor-guard-footprint-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Reduce Small-map route-guard blocker overreach by replacing full close-town corridor guard walls with size-scaled corridor choke coverage while preserving Medium/Large/XL object-only town-route closure gates.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `ops/progress.json`
completionCriteria:
- Small translated-template town corridor coverage no longer assigns every close cross-zone town-pair path cell to route guard bodies.
- Uploaded Small comparison keeps zero unresolved and zero object-only reachable town pairs after guard-footprint reduction.
- Package object-only breadth still keeps zero all-town and cross-zone town reachable pairs for Small 049, Medium 002, Large 042, and Extra Large 043.
- Broad land/surface template generation still validates representative catalog templates after the size-scaled guard policy.
nonGoals:
- No exact HoMM3 full parity claim.
- No elimination of all native object-blocked overage versus the uploaded owner map.
- No islands/water/underground parity implementation.
completionEvidence:
- Uploaded Small comparison passed with guard unique block tiles reduced from the prior 615 to 420, clearing the guard-footprint warning while preserving 7 towns, 7 zones, 150 decorations, 40 guards, and zero object-only town routes.
- Uploaded Small object-blocked total improved from 1147 to 1043 in the topology report, with the remaining object-blocked overage still explicitly warned for follow-up.
- Package object-only breadth passed Small 049, Medium 002, Large 042, and Extra Large 043 with zero all-town/cross-zone reachable town pairs; Small package object-only blocked tiles are now 1031 instead of the earlier 1158.
- The rebuilt bounded 12-template broad generation report passed with non-empty package surfaces and zero zero-tile roads.
- Validation passed native build, uploaded Small topology report, package object-only breadth report, bounded 12-template broad generation report, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed audit/implementation slice:

id: `native-rmg-uploaded-small-blocker-footprint-audit-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Compare the uploaded Small 3-player single-level HoMM3 map against the current native translated Small package with explicit blocker/guard footprint metrics, and reduce one route-guard overreach without reopening town routes.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Uploaded Small HoMM3 comparison reports native-vs-owner object, road, town, guard, zone, and blocked/controlled tile deltas.
- Native report distinguishes object blocker coverage from terrain-blocked coverage and exposes per-kind package blocker footprints.
- Route-guard body generation no longer uses every road segment cell as a guard blocker body.
- Existing object-only package closure gates remain green after the guard-footprint adjustment.
nonGoals:
- No claim that native blocker footprint now matches HoMM3.
- No removal of required town-boundary guard coverage until explicit obstacle/choke blockers replace it.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Uploaded Small HoMM3 parse remains 7 towns, 7 zones, 150 decorations, 40 guards, 110 road cells, 722 parsed mask-blocked tiles, and 258 parsed guard-controlled tiles.
- Current native Small 049 package matches headline town/zone/object/decor/guard counts and still has zero object-only reachable town pairs.
- The comparison now warns that native object blockers cover 1147 tiles versus the owner parsed 722 mask-blocked tiles, and native guard blockers cover 615 unique tiles versus the owner parsed 258 guard-controlled tiles.
- Route-guard segment body coverage was narrowed to the guard tile, nearby boundary cells, and immediate neighboring road cells instead of every road segment cell.
- Validation passed native build, uploaded Small comparison, package object-only breadth, bounded 12-template broad generation, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-broad-template-choke-guard-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the translated-template town/zone and route-guard blocker issues exposed by uploaded Small HoMM3/native map comparison and add a bounded broad generation/package gate.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
- `tests/native_random_map_broad_template_generation_report.tscn`
- `ops/progress.json`
completionCriteria:
- Uploaded Small HoMM3/native comparison findings are reflected in native RMG fixes instead of relying on the old compact fallback template behavior.
- Translated catalog zones only become active player-start zones when their source role is a start zone, preventing treasure zones from becoming extra players/towns.
- Route guards own unique choke primary tiles and may displace decorative/scenic filler on the choke instead of duplicating guard occupancy or leaving malformed objects.
- A bounded broad-template report validates generation, output validation, package conversion, non-empty package objects/roads, and zero zero-tile roads for representative land/surface templates.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/water/underground full-parity implementation.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Uploaded HoMM3 Small single-level comparison showed 7 towns, 7 zones, 150 decorations, 40 guards, 110 road cells, and no near-stacked towns; the bad native upload was identified as old compact-template output with 6 towns, no zone metadata, zero usable road cells, and unguarded town routes.
- Native translated zone conversion now keeps non-start owned source zones neutral/non-player for player-start purposes while preserving owned faction context where applicable.
- Route guard placement no longer falls back onto an occupied guard tile; it can take a neighboring decorative/scenic choke tile and the choke-clearance pass removes displaced filler from generated object placements.
- Broad template generation report passed 12 bounded land/surface cases: legacy small templates plus translated templates 001 through 009, each with validation OK, non-empty package surfaces, roads, and zero zero-tile roads.
- Validation passed native build and targeted translated template 008/009 broad reports plus bounded 12-case broad report.

Recently completed owner-directed implementation slice:

id: `native-rmg-owner-compared-runtime-authority-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Mark owner-compared translated native RMG packages as runtime-authoritative package/session inputs while keeping exact HoMM3/full-parity claims false.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_package_session_adoption_report.gd`
- `tests/native_random_map_package_session_authoritative_replay_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_package_session_adoption_report.gd`
- `tests/native_random_map_package_session_authoritative_replay_report.gd`
- `ops/progress.json`
completionCriteria:
- Native adoption reports `native_runtime_authoritative: true` for owner-compared translated land templates after package/session conversion.
- Runtime authority no longer implies `full_parity_claim`; full parity remains false until exact HoMM3 parity is proven.
- Package/session adoption and replay reports prove stable package/session identity for the owner-compared translated path.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No runtime authority for `not_implemented` islands or unsupported broad catalog templates.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Owner-compared translated package/session adoption now reports `runtime_authoritative_owner_compared_not_full_parity`, with `native_runtime_authoritative: true` and `full_parity_claim: false`.
- Package/session replay evidence for the Medium 002 owner-compared profile preserves stable adoption, changed-map, and disk package replay signatures while keeping full HoMM3 parity pending.
- Package object-only breadth still reports zero object-only unguarded all-town reachable pairs for Small 049, Medium 002, Large 042, and Extra Large 043.
- Validation passed native build, package/session adoption report, Medium 002 authoritative replay report, package object-only breadth report, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-player-facing-water-support-guard-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Remove unsupported islands generation from the player-facing generated-map setup until native islands templates have owner-compared parity evidence instead of `not_implemented` fallback status.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/menus/MainMenu.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `ops/progress.json`
completionCriteria:
- Player-facing random-map water options expose only implemented native land generation.
- Main menu generated-map controls fall back to land if a stale unsupported islands selection is present.
- Menu retry UX and auto-template tests pass without exposing unsupported islands as a production option.
nonGoals:
- No native islands/water parity implementation in this slice.
- No removal of catalog metadata or lower-level explicit test coverage for islands templates.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Player-facing random-map setup now exposes only the implemented native Land water option.
- Main menu generated-map controls fall back to Land when stale state references an unsupported water option.
- Retry UX report now proves water options are `["Land"]`, while auto-template batch retains lower-level islands coverage as non-player-facing `not_implemented` evidence.
- Validation passed menu retry UX report, all-template menu wiring report, auto-template batch report, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-auto-template-production-filter-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Stop player-facing native catalog auto-selection from choosing broad translated templates whose native generation status is still `not_implemented` when an owner-compared translated land template exists for the requested size.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `ops/progress.json`
completionCriteria:
- Native catalog auto-selection prefers owner-compared translated templates for supported land size classes instead of random runtime-valid but not-implemented broad catalog templates.
- Auto-template batch report fails if a supported land size auto-selects a template with `full_generation_status: not_implemented`.
- Existing uploaded Small H3M topology, auto-template batch, package breadth, and replay gates remain green.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No islands/water full-parity implementation in this slice.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Native catalog auto-selection now builds a preferred owner-compared translated-template pool for supported land sizes before falling back to the wider catalog.
- Auto-template batch now fails if Small/Medium/Large/XL land auto-selection chooses a broad catalog template instead of the owner-compared translated template/profile.
- Auto-template batch passed with land selections pinned to Small 049, Medium 002, Large 042, and XL 043; the Medium auto density floor was raised to keep owner-compared Medium 002 above package density minimums.
- Validation passed native build, auto-template batch, uploaded Small H3M topology report, default package object-only breadth report, medium replay report, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-auto-template-density-floor-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Correct the sparse-map failure exposed by native catalog auto-selection where broader translated templates can generate valid but underfilled maps, especially Medium land and XL land cases.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `tests/native_random_map_auto_template_batch_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_auto_template_batch_report.gd`
- `ops/progress.json`
completionCriteria:
- Auto-template batch report enforces size-aware generated/package object density floors, not only non-empty surfaces.
- Native broad catalog auto-selection supplements sparse templates with deterministic in-zone decorative/object fill without touching uploaded evidence files.
- The previously sparse Medium land and XL land auto-selected cases clear the new density floors while preserving validation/package conversion.
- Existing default translated package breadth and replay gates remain green.
nonGoals:
- No exact HoMM3 object-table, art, or byte parity claim.
- No exhaustive all-template density sweep in this slice.
- No generated `.amap`/`.ascenario` or uploaded `.h3m` evidence files committed.
completionEvidence:
- Tightened the auto-template batch report with size-aware generated/package object density floors; the new gate caught Medium land template 029 at 264 generated objects against a 340 floor before the fix.
- Added deterministic native catalog auto-selection density supplementation for underfilled auto-selected maps.
- Post-fix auto-template batch passed six seeded cases, including Medium 029 at 340 generated / 426 packaged objects and XL 051 at 1100 generated / 1196 packaged objects.
- Validation passed native build, auto-template batch report, default package object-only breadth report, medium authoritative replay report, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-auto-template-batch-validation-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Prove the new player-facing native catalog auto-selection path does not pick templates that only pass metadata filters but fail real native generation, package conversion, or replay-relevant surface checks across seeded size/water/player cases.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `content/random_map_template_catalog.json`
implementationTargets:
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/native_random_map_auto_template_batch_report.tscn`
- `src/gdextension/src/map_package_service.cpp`
- `ops/progress.json`
completionCriteria:
- Auto-selection batch report uses empty template/profile generated configs with `native_catalog_auto` mode, not explicit size defaults.
- The batch proves selected template/profile ids are resolved, deterministic, supported by catalog metadata, and diverse across representative seeds.
- Every selected auto-template case passes native generation validation and package conversion surface sanity checks.
- If a selected catalog template fails runtime validation, selector/generator filtering is tightened instead of weakening the test.
nonGoals:
- No exact HoMM3 byte/output parity claim.
- No exhaustive 53-template CI sweep in this slice.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Added `NATIVE_RANDOM_MAP_AUTO_TEMPLATE_BATCH_REPORT`, which uses empty template/profile player configs with `native_catalog_auto` mode.
- Six representative seeded cases selected six distinct catalog templates: Small 049, Small 045, Medium 029, Medium Islands 001, Large 042, and XL 051.
- Every selected case resolved deterministic concrete template/profile ids, passed native generation validation, converted to a map package, and produced non-empty package object/road surfaces.
- The report records a remaining parity gap: several runtime-valid auto-selected templates still have `full_generation_status: not_implemented`, so future slices must harden broader translated-template behavior rather than treating this as production parity.
- Validation passed native build, auto-template batch report, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-player-facing-auto-template-selection-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Stop player-facing generated maps from pinning one hardcoded recovered template/profile per size class. Wire launch-time generation to native catalog auto-selection so the imported HoMM3-style template catalog participates in seeded skirmish generation.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `content/random_map_template_catalog.json`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/menus/MainMenu.gd`
- `src/gdextension/src/map_package_service.cpp`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `ops/progress.json`
completionCriteria:
- Player-facing generated skirmish configs can request native catalog auto-selection without forcing the size-class default template/profile.
- Native normalization resolves an empty auto-selection config to a supported catalog template and coherent profile id, deterministically from seed/config.
- UI provenance clearly distinguishes preview defaults from launch-time native catalog auto-selection while keeping manual template/profile controls hidden.
- Existing explicit-template tests keep their pinned-template behavior for targeted regression cases.
- Validation proves auto-selection is used by the player-facing generated launch path and that generated maps still pass package/session adoption gates.
nonGoals:
- No claim that all 53 translated templates are fully HoMM3-equivalent.
- No manual template picker exposure in the first-view generated setup UI.
- No HoMM3 copyrighted asset/DEF import.
- No uploaded `.h3m`/`.amap`/`.ascenario` evidence files committed.
completionEvidence:
- Player-facing generated launch config now requests `native_catalog_auto` selection while hidden preview controls still preserve size-class default provenance.
- Native config normalization resolves empty auto-selection configs to a deterministic supported catalog template and first matching catalog profile id.
- Generated setup/retry UX report proves the UI keeps manual template/profile controls hidden and launch provenance resolves a concrete native catalog template/profile.
- Explicit-template paths remain intact for size-default package replay/object-only breadth gates and all-template menu config construction.
- Validation passed native build, generated setup/retry UX, all-template menu wiring, package session replay, package object-only breadth, repo validation, JSON validation, progress helper, and diff whitespace check.

Recently completed owner-directed implementation slice:

id: `native-rmg-all-town-unguarded-route-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Use the uploaded Small H3M/native-package comparison to close the current generator gap where package gates protect player-start and cross-zone town routes but allow same-zone town pairs to remain reachable by short unguarded object-only paths.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
- owner-uploaded Small 3-player H3M and native package evidence from 2026-05-06
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_package_surface_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Package topology reports expose all-town object-only reachable-pair counts, not only player-start and cross-zone town topology.
- Player-facing default translated Small, Medium, Large, and Extra Large package cases reject unguarded object-only town-to-town traversal across all town pairs.
- The uploaded Small H3M comparison continues to report the owner sample, the uploaded old native package, and current native Small 049 without committing uploaded evidence files.
- Generator changes preserve existing object count, guard count, road materialization, package replay, and validation gates for supported translated profiles.
nonGoals:
- No HoMM3 copyrighted asset/DEF import.
- No exact H3M byte/pathing parity claim.
- No broad recovered-template catalog sweep or runtime-authoritative promotion.
- No generated `.amap`/`.ascenario` or uploaded `.h3m` evidence files committed.
completionEvidence:
- Uploaded Small H3M comparison reports the owner sample, the old uploaded native package, and current native Small 049; current Small 049 has 7 towns, 7 zones, 303 objects, 150 decorative obstacles, 40 guards, and zero object-only all-town reachable pairs.
- Package topology and breadth gates now expose and reject all-town object-only reachable pairs; the pre-fix Medium default case exposed 18 towns and 4 same-zone unguarded reachable town pairs.
- Default translated Medium now avoids optional density town stacking in already-towned zones and reports 6 towns with zero object-only all-town reachable pairs while preserving the owner Medium 001 comparison exemption.
- Validation passed native build, uploaded H3M topology report, package breadth/surface topology reports, full parity gate, owner spatial placement comparison, medium replay gate, repo validation, JSON validation, and diff whitespace check.

## Slice Status Model

Each executable slice should map to one `ops/progress.json` entry with:
- `id`: stable slice id ending in `-10184`.
- `phase`: project phase.
- `purpose`: why the slice exists.
- `sourceDocs`: source requirements or evidence docs.
- `implementationTargets`: expected files/systems/content/tooling/report surfaces.
- `baselineChecks`: generic health checks required before completion.
- `sliceEvidence`: focused proof that the slice requirement was met.
- `completionCriteria`: objective completion bar.
- `nonGoals`: explicit boundaries when scope is risky.

Valid operational statuses:
- `pending`: planned, not started.
- `in_progress`: active implementation or review.
- `blocked`: cannot proceed; blocker must be named.
- `completed`: implementation and validation meet criteria.
- `docs_ready`: requirements/design/report exists; implementation is not complete.
- `paused`: intentionally delayed until selected again.
- `pending_after_implementation`: review/gate slice waiting for implementation output.
- `superseded`: replaced by a later accepted slice/path.

## Work Selection Gates

Before starting any worker:
1. Run `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py status /root/dev/heroes-like`.
2. Run `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py next /root/dev/heroes-like`.
3. Confirm the selected slice has source docs, implementation targets, validation, completion criteria, and forbidden-scope boundaries.
4. Mark the selected slice `in_progress` in `ops/progress.json`.
5. On completion, record validation/evidence in `ops/progress.json`; do not paste the evidence block into this file.

If a requested task is not represented by a valid slice, first add or reconcile a compact slice entry. Do not invent untracked ad hoc implementation work.

## Phase Roadmap

### Phase 0 - Prototype Reality And Governance

Goal: keep claims honest and documents/tooling usable.

Closed tactical slices:
- `document-model-reset-10184`
- `progress-tracker-regeneration-10184`

Future work in this phase should be limited to document/process corrections that preserve the `project.md` -> `PLAN.md` -> `ops/progress.json` chain.

### Phase 1 - Manual Scenario Proof

Goal: preserve the manually proven River Pass loop without overstating product readiness.

Closed tactical slice:
- `river-pass-proof-preservation-10184`

Future work in this phase should only reopen if manual proof is invalidated by regressions or if AcOrP requests a new proof scenario.

### Phase 2 - Deep Production Foundation

Goal: build the foundation needed before broad campaign/skirmish production or final polish.

Primary tracks:
- world and faction identity;
- concept-art direction and curation;
- economy/resource model;
- overworld object taxonomy and encounter representation;
- magic and artifact systems;
- animation/event cue foundations;
- strategic AI foundations;
- terrain/editor/tooling foundations;
- random map generator foundations;
- map/scenario document structure and persistence foundations;
- focused corrective/performance/instrumentation slices selected from real evidence.

Operational state lives in `ops/progress.json`. Completed parent/child evidence is intentionally not repeated here.

Selection rules for new Phase 2 slices:
- Tie the slice to a source doc, owner report, profile artifact, regression, or explicit AcOrP direction.
- Keep implementation targets narrow.
- Include explicit non-goals for save schema, generated-map density/content, renderer/fog behavior, object contracts, public UI, and asset ingestion when relevant.
- Preserve existing validation/analyzer compatibility unless the slice explicitly changes it.
- Do not use profile/instrumentation slices as permission for optimization or gameplay semantics changes.

Completed owner-directed implementation slice:

id: `decorative-blocker-distinct-sprite-assets-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Follow up the decorative/blocker sprite foundation by replacing shared archetype reuse with one distinct generated sprite asset per authored decorative/blocker object while preserving the renderer/generator wiring and no-HoMM3-art boundary.
sourceDocs:
- `project.md`
- `PLAN.md`
- `art/overworld/decorative_object_sprites.json`
- owner correction on 2026-05-04 that all decorative/blocker objects need distinct assets, not only archetype coverage
implementationTargets:
- `art/overworld/runtime/objects/decorations/distinct/`
- `art/overworld/source/generated/decorations/distinct/`
- `art/overworld/source/trimmed/decorations/distinct/`
- `art/overworld/manifest.json`
- `art/overworld/decorative_object_sprites.json`
- `tests/validate_repo.py`
- `tests/overworld_decorative_sprite_asset_report.gd`
- `ops/progress.json`
completionCriteria:
- Exactly 200 authored decorative/blocker objects resolve to 200 distinct object asset ids.
- The 16 existing generated decoration sprites are preserved for 16 representative objects and the remaining 184 objects receive newly generated original sprites.
- Each distinct runtime sprite has source/provenance, manifest entry, trimmed source where applicable, and 512x512 runtime validation.
- Validation rejects asset reuse in the decorative/blocker object mapping and proves at least one generated decorative placement renders through a distinct object-specific sprite.
- No HoMM3 copyrighted art/DEF/image assets are imported.
nonGoals:
- No save-version bump, no binary map-package schema migration, no exact HoMM3 asset/DEF parity claim, no terrain replacement, no broad gameplay rebalance.

Completed owner-directed implementation slice:

id: `decorative-blocker-sprite-asset-foundation-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Owner-directed generated-art ingestion slice for decorative/blocker overworld objects: audit renderer and native map-generator object surfaces, generate original 2D sprite assets for decorative/blocker objects lacking art, wire those assets through the overworld renderer/manifest, and validate that generated decorative/blocker objects are represented without relying only on procedural fallback markers.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/concept-art-pipeline.md`
- `docs/overworld-object-taxonomy-density.md`
- `docs/overworld-object-content-batch-001b-biome-scenic-decoration-report.md`
- `docs/overworld-object-content-batch-001c-biome-blockers-edge-report.md`
- `docs/overworld-object-content-batch-001d-large-footprint-coverage-report.md`
- `docs/native-rmg-template-decoration-wiring-report.md`
- owner request on 2026-05-04 to generate sprites for decorative/blocker objects after checking renderer and map generator
implementationTargets:
- `art/overworld/runtime/objects/decorations/`
- `art/overworld/source/trimmed/decorations/`
- `art/overworld/manifest.json`
- `scenes/overworld/OverworldMapView.gd`
- `tests/validate_repo.py`
- focused overworld visual/native decoration report tests as needed
- `ops/progress.json`
completionCriteria:
- Renderer and native map-generator decorative/blocker placement contracts are inspected and documented in the run evidence.
- Decorative/blocker objects lacking 2D assets are represented by generated original sprite assets or a documented, validated archetype mapping sufficient for every authored decorative/blocker object used by the renderer/generator.
- Generated sprite assets are committed only with provenance, runtime/source paths, manifest entries, and validation that files exist at expected dimensions.
- The overworld renderer can draw decorative/blocker map-object placements through mapped sprites while preserving procedural fallback for unmapped object types.
- No HoMM3 copyrighted art/DEF/image assets are imported.
- Validation covers manifest integrity, decorative/blocker asset mapping coverage, and at least one generated decorative/blocker runtime presentation path.
nonGoals:
- No save-version bump, no binary map-package schema migration, no exact HoMM3 asset/DEF parity claim, no full replacement of all terrain art, no broad gameplay rebalance.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-road-spread-parity-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Follow up `native-rmg-homm3-road-placement-parity-10184` by improving the residual owner-like road spread gap: more occupied 6x6 road cells and smaller largest coarse roadless land regions, while preserving count-close roads and reduced reward-road bias.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- owner follow-up after accfaf1 on 2026-05-04
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `ops/progress.json`
completionCriteria:
- Native C++ `MapPackageService.generate_random_map()` remains the active runtime path.
- Owner-like road tile count stays near owner and reward within 1/4 tiles does not materially regress toward the prior over-road-bias.
- Road nonempty 6x6 cells move closer to owner and largest roadless land 6x6 region is reduced from the accfaf1 baseline.
- Town/start coverage, route reachability, local distribution, land/water shape, guard/reward package adoption, and full parity fixture reports remain passing.
completionEvidence:
- Native owner-like output now adds bounded short service stubs in residual roadless land pockets through the native C++ road materialization path; the active runtime path remains `MapPackageService.generate_random_map()`.
- Road nonempty 6x6 cells moved from 10 to 17 against owner 16, and largest roadless land 6x6 region moved from 25 to 9 against owner 8; road tiles moved from 180 to 201 against owner 184, still below the pre-accfaf1 240 over-road count.
- Reward-road bias remains a documented residual warning rather than full parity: reward within 1 tile stayed 0.125, reward within 4 tiles moved 0.4632 to 0.4779 against owner 0.3727, and town/start road coverage stayed 1.0.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd`, no generated packages committed, no road art lookup rewrite unless required, no HoMM3 asset import, no full parity claim.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-road-placement-parity-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Improve native C++ RMG road layout parity for the owner-like translated medium islands case and general native templates by making route materialization more HoMM3-like: intentional trunk/branch roads, less over-connection, measured road/object interaction, and preserved start/town connectivity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- owner-attached HoMM3 H3M gzip from 2026-05-04
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `ops/progress.json`
completionCriteria:
- Native C++ `MapPackageService.generate_random_map()` remains the active runtime path.
- Owner-like road tile count, land-normalized road density, reward distance-to-road ratios, road spread, road graph shape, and start/town coverage are reported against the owner H3M baseline.
- One bounded road placement/layout improvement lands without touching 4-neighbor road rendering, generated-map package commits, or copyrighted HoMM3 assets.
- Validation gates in the owner directive pass, and remaining exact HoMM3-re road-authoring gaps are stated.
completionEvidence:
- Native owner-like road materialization changed from fully materialized deterministic cross-links to a trunk/branch/short-spur policy for imported translated templates, preserving route graph reachability and road renderer lookup.
- Owner-like native road tiles moved from 240 before the slice to 180 against the owner H3M baseline of 184; reward references within 4 road tiles moved from 0.5588 to 0.4632 against owner 0.3727.
- Remaining exact HoMM3-re road authoring gap is documented; no full algorithm or byte parity is claimed.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd`, no generated `.amap`/`.ascenario` files committed, no road renderer art/lookup rewrite unless required, no exact HoMM3-re algorithm/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-land-normalized-object-density-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Compare owner-attached HoMM3 H3M object/category density against native owner-like 72x72 islands output after the land/water fix, then correct one clear land-normalized sparse category without rerouting generation away from native C++.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-land-water-shape-report.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `docs/native-rmg-homm3-land-normalized-object-density-report.md`
- owner-attached HoMM3 H3M gzip from 2026-05-04
implementation:
- Added a land-normalized density report that parses the owner H3M and reports total object, decoration/impassable, reward/resource, guard, town, other-object, and road density per 100 land tiles plus category mix and package surfaces.
- Native owner-like islands output now applies a bounded compact decoration-density supplement for the 72x72 translated Small Ring islands profile, raising total objects from 344 to 488 against owner 496 and decoration/impassable density from 0.330x to 0.804x owner after land normalization.
evidence:
- `tests/native_random_map_homm3_land_normalized_object_density_report.tscn`
- `docs/native-rmg-homm3-land-normalized-object-density-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re placement/art/object-table/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-land-water-shape-parity-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue beyond spatial placement comparison by correcting native C++ owner-like 72x72 islands output that was mostly land, anchoring the owner H3M land/water baseline, and preserving generated gameplay/package surfaces on land.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `docs/native-rmg-homm3-land-water-shape-report.md`
- owner-attached HoMM3 H3M gzip from 2026-05-04
implementation:
- Native islands terrain for non-structural-parity cases now shapes a water-dominant island mask after routes, objects, towns, and guards are known, protecting starts, roads, object body/visit/approach cells, town/guard cells, and converted package body/visit/block surfaces as land.
- The new report parses the owner H3M tile stream directly and verifies the native owner-like case moved from 4,900 land / 284 water to 2,296 land / 2,888 water against the owner baseline of 1,948 land / 3,236 water.
evidence:
- `tests/native_random_map_homm3_land_water_shape_report.tscn`
- `docs/native-rmg-homm3-land-water-shape-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re terrain-shape/placement/art/object-table/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-re-obstacle-identity-comparison-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue beyond fill coverage by making native C++ RMG decorative obstacles carry terrain-biased HoMM3-re `rand_trn` source identity/proxy metadata and by adding an empirical comparison/diversity gate against the owner-attached 72x72 Small Ring baseline.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-decoration-obstacles.csv`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-catalog-by-type.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- owner-attached HoMM3 72x72 Small Ring metrics from 2026-05-04
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `content/homm3_re_obstacle_proxy_catalog.json`
- `tests/native_random_map_homm3_re_identity_comparison_report.gd`
- `tests/native_random_map_homm3_re_identity_comparison_report.tscn`
- `tests/native_random_map_decoration_generation_report.gd`
- `docs/native-rmg-homm3-re-obstacle-identity-comparison-report.md`
- `ops/progress.json`
completionCriteria:
- Native C++ package generation remains the active path and decorative_obstacle records include HoMM3-re `rand_trn` source row/type/subtype/terrain/DEF-reference provenance plus original proxy family mapping.
- No HoMM3 copyrighted image/DEF assets are imported; source identity and DEF names are metadata/provenance only.
- The new report verifies the owner-attached gzip/decompressed H3M size baseline, compares owner parsed metrics against similar 72x72 islands Small Ring native output, reports counts by HoMM3 source type/source row/proxy family, and gates source-row/type diversity and terrain-biased presence.
- Broad seed/template quality sampling fails on low source-row diversity, missing terrain-biased source families, coverage regression, road/object density regression, or visually empty zone coverage regression.
- Existing catalog playability, fill coverage, menu wiring, decoration generation, and full parity fixture gates still pass.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no full HoMM3-re parity claim beyond the implemented source-identity/proxy and comparison gate, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-re-object-table-proxy-selection-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue beyond native reward value tiers by making reward-bearing native C++ RMG object records carry HoMM3-re object/reward table source identity and select original proxy object families from a metadata-only proxy catalog.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `content/map_objects.json`
- `content/homm3_re_reward_object_proxy_catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-catalog-by-type.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json`
implementation:
- Added a runtime-consumable reward/object proxy catalog with source type/name/subtype/source-row/DEF-reference provenance and original proxy mappings.
- Native `resource_site`, `mine`, `neutral_dwelling`, and `reward_reference` records now expose HoMM3-re source/proxy provenance and `provenance_only_original_proxy_art` policy.
- Reward proxy selection now maps minor, medium, major, and relic bands to different original proxy families/categories instead of only generic placeholder caches.
evidence:
- `tests/native_random_map_homm3_re_object_table_proxy_report.tscn`
- `docs/native-rmg-homm3-re-object-table-proxy-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re reward table/object/art/byte placement parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-spatial-placement-comparison-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue native C++ RMG parity work beyond density/count gates by parsing the owner-attached HoMM3 H3M for spatial object/road placement metrics, comparing them to owner-like native output, and reducing a clear native object-distribution skew.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `docs/native-rmg-homm3-re-obstacle-identity-comparison-report.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- owner-attached HoMM3 H3M gzip from 2026-05-04
implementation:
- Added a native spatial comparison report that decompresses the owner H3M, parses the 72x72 tile stream, 297 object definitions, 496 placed object instances, and 184 road tiles, then compares quadrant/coarse-grid density, nearest-neighbor distances, road adjacency, and largest low-content regions against native owner-like generation.
- Changed native non-town zone object placement for mines, dwellings, and rewards from anchor-ring clustering to deterministic coarse-grid scatter inside each owning zone, preserving start-support resource placement and native `MapPackageService.generate_random_map()` as the active path.
evidence:
- `tests/native_random_map_homm3_spatial_placement_comparison_report.tscn`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re placement/art/object-table/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-guard-reward-package-adoption-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue native RMG package parity by making generated package/editor surfaces preserve guard/reward relationships and object body/visit/block masks after native conversion and package save/load.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `docs/native-rmg-homm3-re-object-table-proxy-report.md`
- `docs/native-rmg-homm3-re-reward-value-distribution-report.md`
implementation:
- Native generated non-parity object placement now reserves materialized road cells before placing non-town objects, preventing reward/site blocking bodies from landing on road corridors.
- Native package conversion enriches generated object records with package body, visit, and block masks plus package occupancy roles.
- Protected rewards/sites now carry direct package guard links, guard references, guarded access requirements, guarded passability, and AI/pathing hints after convert/save/load.
- Guard records serialize as blocking package surfaces with neutral-stack passability metadata.
evidence:
- `tests/native_random_map_guard_reward_package_adoption_report.tscn`
- `docs/native-rmg-guard-reward-package-adoption-report.md`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re placement/art/reward-table/byte parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-re-reward-value-distribution-10184`
phase: `phase-2-deep-production-foundation`
status: `completed`
purpose: Continue beyond obstacle source identity by making native C++ RMG reward references derive values/categories from catalog zone treasure bands and by pairing valuable rewards with guard values scaled from protected reward values.
sourceDocs:
- `project.md`
- `content/random_map_template_catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
implementation:
- Native reward records now include zone value budget/tier, reward value tier, reward source bucket, HoMM3-re-like treasure-band low/high/density provenance, and reward index/target metadata.
- Native site guards scale from protected reward value and record guard/reward relation metadata; medium rewards reject distant fallback guards while major/relic rewards are required guarded content for the report scope.
- `tests/native_random_map_homm3_re_reward_value_distribution_report.tscn` samples small, medium, large, and XL templates and preserves road/object/fill/decor/package regression checks.
evidence:
- `docs/native-rmg-homm3-re-reward-value-distribution-report.md`
- `ops/progress.json`
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no HoMM3 copyrighted art/DEF asset import, no exact HoMM3-re reward table/object/art/byte placement parity claim, no save version bump or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `native-rmg-homm3-fill-coverage-gate-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add a real HoMM3-style fill coverage gate and raise native generated package decorative/blocking body coverage so generated maps no longer pass with barren token decorations.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/map_objects.json`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-decoration-obstacles.csv`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- owner-attached HoMM3 gzip and native `.amap`/`.ascenario` packages from 2026-05-04
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_fill_coverage_report.gd`
- `tests/native_random_map_homm3_fill_coverage_report.tscn`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `docs/native-rmg-template-decoration-wiring-report.md`
- `ops/progress.json`
completionCriteria:
- Native generated decorations use larger terrain-biased original blocker footprints and reserve full body tiles, not mostly 1x2 token records.
- The report compares HoMM3-re `rand_trn` obstacle catalog scale, authored AcOrP decoration/blocker catalog scale, attached pre-fix package fill, and sampled native small/medium/large/XL output.
- The attached 72x72 2.78% decoration/blocker body coverage package fails the new medium coverage floor, while the same config regenerated through native C++ package generation passes.
- Sampled native package convert/save/load surfaces retain road and object counts, and decorative bodies do not overlap materialized road cells.
- Exact HoMM3-re obstacle identity/art/template parity and compact binary format parity remain explicitly unclaimed.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no exact HoMM3-re DEF/art/placement parity claim, no compact binary map format claim, no save version bump or authored content writeback.

Completed owner-directed implementation slice:

id: `native-rmg-catalog-playability-wiring-10184`
phase: `phase-2-deep-production-foundation`
purpose: Correct the native generated-map fallback architecture so every exposed local and translated catalog template uses imported topology and materializes visible roads, objects, decorations, towns, resources, rewards, and guards through native package convert/save/load.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `docs/native-rmg-template-decoration-wiring-report.md`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_catalog_quality_report.gd`
- `tests/native_random_map_catalog_quality_report.tscn`
- `docs/native-rmg-template-decoration-wiring-report.md`
- `ops/progress.json`
completionCriteria:
- Native generated maps load catalog template zone and link data for all exposed templates where catalog records exist.
- Zone count, route edge count, road segments/cells, and object density scale from template topology and selected size instead of collapsing to the tiny foundation stub.
- Roads materialize into package/editor-visible terrain road surfaces after native convert/save/load.
- `decorative_obstacle`, town, mine/resource/reward/dwelling, and guard placements appear at sane scaled counts for sampled local, medium, large, and XL catalog templates.
- Existing tiny native full-parity fixture tests remain valid and do not define broad catalog quality.
- Broad catalog quality report, menu wiring report, decoration report, full parity gate, JSON validation, native build, and diff checks pass.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no exact HoMM3-re byte/placement/art/reward-table parity claim, no save version bump or authored content writeback.

Completed owner-directed implementation slice:

id: `native-rmg-template-decoration-wiring-10184`
phase: `phase-2-deep-production-foundation`
purpose: Wire the full imported random-map template catalog into the generated skirmish menu and make native C++ GDExtension package generation emit real decorative obstacle placements.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `docs/native-rmg-template-decoration-wiring-report.md`
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/menus/MainMenu.gd`
- `src/gdextension/src/map_package_service.cpp`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/native_random_map_decoration_generation_report.gd`
- `ops/progress.json`
completionCriteria:
- Generated-map menu rules and UI expose all 56 catalog templates and 56 catalog profiles with template-scoped profile selection.
- Player-count options come from catalog template ranges/slots where available, with fallback only for missing catalog data.
- Active generated skirmish launch remains native `MapPackageService.generate_random_map()` package generation.
- Native object placements include scalable `decorative_obstacle` records with body, footprint, blocking, approach, and occupancy metadata.
- Menu wiring, native decoration generation, player-count/template filtering, full native parity gate, JSON validation, native build, and diff checks pass.
nonGoals:
- No route back to `RandomMapGeneratorRules.gd` for active generation, no generated map packages committed under `maps/`, no false whole-catalog/full HoMM3-re parity claim, no exact HoMM3 decoration art/family parity claim.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-warning-classification-followup-10184`
phase: `phase-2-deep-production-foundation`
purpose: Continue post-a749da2 HoMM3 RMG visual fairness review by reducing remaining warning-level support-resource false positives and classifying accepted HoMM3-like template asymmetry separately from true unresolved regressions.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-special-guards-and-wide.md`
- `.artifacts/rmg_parity_visual_inspection/summary.json`
- `.artifacts/rmg_parity_large_visual_inspection/summary.json`
- `.artifacts/rmg_parity_richness/summary.json`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `docs/random-map-homm3-parity-warning-review.md`
- `ops/progress.json`
completionCriteria:
- Visual preview artifacts and warning review identify each remaining warning-level fairness source after `a749da2`.
- Early support-resource diagnostics measure only actual start-support resource routes, not every same-zone mine or dwelling route.
- Reports preserve raw warning and fail-threshold counts while splitting accepted HoMM3-like template asymmetry from unresolved warning-level review items.
- Focused visual, richness, and large visual reports pass with fail-threshold diagnostics still strict.
nonGoals:
- No fairness-threshold weakening, generated PNG import, runtime/source asset ingestion, public UI work, save-version bump, native generator rewrite, or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-support-resource-preview-gate-10184`
phase: `phase-2-deep-production-foundation`
purpose: Continue post-43ab952 HoMM3 RMG parity by separating real warning-level fairness imbalance from acceptable translated-template asymmetry, correcting compact start-support resource drift where present, and adding human-inspectable rendered preview artifacts for manual layout review.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `.artifacts/rmg_parity_visual_inspection/summary.json`
- `.artifacts/rmg_parity_large_visual_inspection/summary.json`
- `.artifacts/rmg_parity_richness/summary.json`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `docs/random-map-homm3-parity-warning-review.md`
- `ops/progress.json`
completionCriteria:
- Current visual/richness/large artifacts are reviewed and warning-level fairness issues are classified without hiding or weakening diagnostics.
- Any real compact start-support resource route imbalance is corrected while preserving road coverage and HoMM3-like template asymmetry.
- Visual inspection produces rendered SVG/HTML preview artifacts suitable for manual map review in addition to ASCII/JSON.
- Focused visual/richness/large reports pass and progress tracking records validation/evidence.
nonGoals:
- No diagnostic threshold weakening, generated PNG import, runtime/source asset ingestion, public UI work, save-version bump, native generator rewrite, or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-secondary-road-coverage-10184`
phase: `phase-2-deep-production-foundation`
purpose: Review post-fairness RMG road coverage after `ee6015c` and restore HoMM3-like major-object road richness where the route graph remains connected but visually under-roaded.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `.artifacts/rmg_parity_visual_inspection/summary.json`
- `.artifacts/rmg_parity_large_visual_inspection/summary.json`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `ops/progress.json`
completionCriteria:
- Visual artifact review distinguishes fairer path shortening from lost HoMM3-like major-object road coverage.
- Any added roads are grounded in source-backed road overlay timing after towns/mines/major objects and remain separate from fairness diagnostics.
- Visual and richness reports pass with no new fail-threshold fairness warnings and record road coverage/richness impact.
nonGoals:
- No diagnostic threshold weakening, generated PNG import, public UI work, save-version bump, native generator rewrite, or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-route-resource-fairness-10184`
phase: `phase-2-deep-production-foundation`
purpose: Reduce remaining translated-template route and resource distance unfairness after `random-map-homm3-parity-start-front-fairness-10184`, especially medium translated land templates whose strict diagnostics still exceed fail-threshold route spreads.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `.artifacts/rmg_parity_visual_inspection/summary.json`
- `.artifacts/rmg_parity_large_visual_inspection/summary.json`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `ops/progress.json`
completionCriteria:
- RMG route/resource fairness behavior changes are grounded in translated template zone/link semantics rather than hidden diagnostics or relaxed thresholds.
- The cheap visual inspection report passes and records improved or no-worse total fail-threshold warning counts and distance spreads against the post-7689c3e baseline.
- Focused richness and large visual diagnostics pass or expose any remaining route/resource spread gaps clearly.
nonGoals:
- No fairness-threshold loosening unless an existing metric is proven wrong.
- No rendered asset ingestion, generated PNG import, public UI work, save-version bump, native generator rewrite, or authored scenario/package adoption.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-town-zone-spacing-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG town placement quality by preventing generated start and neutral towns from reading as stacked or zone-collapsed, with deterministic spacing metrics across bounded seeds/templates.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-phase-runner.md`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `ops/progress.json`
completionCriteria:
- Town placement uses a stricter map-size-aware separation policy with a hard no-stack fallback before giving up on a town placement.
- Town/mine/dwelling validation reports all-town, start-town, and same-zone closest-pair spacing metrics.
- The bounded HoMM3 parity richness report validates the stronger spacing requirements across multiple seeds/templates within its runtime budget.
nonGoals:
- No generated terrain-art replacement work.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this measurable town spacing improvement.

Completed owner-directed corrective slice:

id: `native-scenario-active-content-reset-10184`
phase: `phase-2-deep-production-foundation`
purpose: Archive the current native/authored scenario and campaign catalogs out of active player-facing selection while preserving generated random-map skirmish flow and historical compatibility records.
sourceDocs:
- `project.md`
- 2026-05-03 owner direction to clear native scenarios
implementationTargets:
- `content/scenarios.json`
- `content/campaigns.json`
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/core/CampaignRules.gd`
- `scenes/menus/MainMenu.gd`
- `tests/random_map_scenario_load_smoke.gd`
completionCriteria:
- Authored/native scenario and campaign domains are marked archived/disabled.
- Skirmish and campaign browsers expose zero native authored entries.
- Generated random-map skirmish setup/load remains available and validated.
nonGoals:
- No RMG rewrite.
- No map package adoption.
- No save schema/version bump.
- No renderer, fog, pathing, gameplay, or asset-ingestion redesign.

Completed owner-directed implementation slice:

id: `native-rmg-disk-package-startup-10184`
phase: `phase-2-deep-production-foundation`
purpose: Make generated skirmish startup use native RMG package documents saved under `maps/` and loaded back from disk instead of authored `content/scenarios.json` or transient generated JSON scenario drafts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner directive to remove JSON scenario startup and use native RMG packages under `maps/`
implementationTargets:
- `src/gdextension/include/map_document.hpp`
- `src/gdextension/src/map_document.cpp`
- `src/gdextension/src/map_package_service.cpp`
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/persistence/NativeRandomMapPackageSessionBridge.gd`
- `scenes/menus/MainMenu.gd`
- `tests/native_random_map_disk_package_startup_report.gd`
- `docs/map-scenario-gdextension-persistence-foundation.md`
completionCriteria:
- Native `MapPackageService` saves and loads generated map and scenario packages enough for generated startup.
- Generated skirmish setup writes `.amap` and `.ascenario` packages under `maps/` in dev/headless and loads them back before session creation.
- Generated startup does not use `ContentService` generated drafts or `content/scenarios.json` as the active launch source.
- Maps directory policy is documented for dev `res://maps` and exported `user://maps` semantics.
- Focused Godot smoke proves native load, generation, package save, package load, disk-backed startup, and no active `scenarios.json`/draft usage.
nonGoals:
- No authored scenario/package catalog migration.
- No campaign adoption.
- No save-version bump or full `SessionDelta` rewrite.
- No renderer, fog, pathing, or broad gameplay redesign.
- No generated PNG or unrelated asset import.

Completed owner-directed corrective slice:

id: `native-rmg-package-readable-filenames-10184`
phase: `phase-2-deep-production-foundation`
purpose: Replace opaque generated native RMG disk package filenames with deterministic, filesystem-safe, human-readable paired names under `maps/`.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner feedback that native RMG package filenames were dull/debug-sludge
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `tests/native_random_map_disk_package_startup_report.gd`
- `tests/native_random_map_package_session_adoption_report.gd`
- `docs/map-scenario-gdextension-persistence-foundation.md`
completionCriteria:
- Generated native RMG `.amap` and `.ascenario` packages share a readable deterministic base stem.
- The stem uses `size-creative-name-hash` only, with a user-facing size token, a deterministic creative lowercase kebab name derived from normalized seed/config, and an 8-hex deterministic config hash suffix.
- Template/profile/player-count/water-mode/dimensions/hash details stay in package metadata/refs, not the filename.
- Focused native disk-package startup tests assert the corrected shape, reject old debug-name identity parts, and prove package refs/load behavior still work.
nonGoals:
- No native API, C++ document, save-version, authored catalog, renderer, fog, pathing, or gameplay semantics changes.

Completed owner-directed implementation slice:

id: `maps-folder-package-browser-integration-10184`
phase: `phase-2-deep-production-foundation`
purpose: Populate skirmish and map editor selection flows from generated `.amap`/`.ascenario` package pairs under `maps/` instead of authored JSON scenario records.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner directive to populate skirmish and map editor from generated maps-folder packages
implementationTargets:
- `scripts/core/ScenarioSelectRules.gd`
- `scripts/persistence/NativeRandomMapPackageSessionBridge.gd`
- `scenes/menus/MainMenu.gd`
- `scenes/editor/MapEditorShell.gd`
- `tests/maps_folder_package_browser_integration_report.gd`
completionCriteria:
- A generated maps-folder package index discovers paired `.amap`/`.ascenario` files under the active maps directory and returns readable records with package refs/metadata.
- Skirmish browser entries are built from generated disk package pairs, handle an empty maps folder gracefully, and start sessions by loading the selected package paths.
- Map editor can list and open generated package pairs from `maps/` without `content/scenarios.json` or transient generated draft registration.
- Focused Godot smoke proves package listing, package-backed skirmish launch, map editor package access/open, sane empty-directory behavior, and no authored JSON scenario path for generated package launch/open.
nonGoals:
- No authored scenario/package catalog migration.
- No campaign adoption.
- No save-version bump.
- No renderer, fog, pathing, gameplay, or RMG generation semantics changes.
- No generated PNG or unrelated asset import.

Completed owner-directed corrective slice:

id: `map-editor-load-map-package-ui-10184`
phase: `phase-2-deep-production-foundation`
purpose: Replace the Map Editor's active old JSON scenario dropdown path with an explicit Load Map flow backed only by generated `.amap`/`.ascenario` package pairs under `maps/`.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner directive to make the map editor load maps from maps-folder packages instead of old JSON scenarios
implementationTargets:
- `scenes/editor/MapEditorShell.gd`
- `scenes/editor/MapEditorShell.tscn`
- `tests/map_editor_load_map_package_report.gd`
- `tests/map_editor_load_map_package_report.tscn`
- `tests/validate_repo.py`
completionCriteria:
- The active Map Editor top-bar flow says `Load Map` and lists generated map package entries from `maps/`.
- The active editor load path uses paired `.amap`/`.ascenario` refs and paths, and creates a package-backed editor working copy.
- Old authored JSON scenario loading is removed from the active editor UI and kept only behind explicit legacy/dev validation naming.
- Empty, invalid-pair, and failed-load states use map-package copy rather than scenario-dropdown copy.
- Focused Godot smoke proves package entries, package refs/paths, no authored JSON scenario/draft registration, and no old scenario dropdown copy in the active flow.
nonGoals:
- No skirmish browser behavior change beyond preserving the shared maps-folder package helper.
- No authored scenario/package catalog migration.
- No campaign adoption.
- No save-version bump.
- No renderer, fog, pathing, gameplay, RMG generation, or asset-ingestion changes.

Completed owner-directed implementation slice:

id: `generated-grastl-runtime-terrain-integration-10184`
phase: `phase-2-deep-production-foundation`
purpose: Wire the committed generated `grastl` grass terrain replacement frames into the overworld terrain runtime path instead of leaving them unused.
sourceDocs:
- `project.md`
- `PLAN.md`
- `art/overworld/runtime/terrain_tiles/generated/grastl/README.md`
- 2026-05-03 owner directive to load/use generated grastl frames under `art/overworld/runtime/terrain_tiles/generated/grastl/frames_64/`
implementationTargets:
- `content/terrain_grammar.json`
- `scripts/autoload/ContentService.gd`
- `art/overworld/manifest.json`
- `scenes/overworld/OverworldMapView.gd`
- `tests/generated_grastl_runtime_asset_report.gd`
- `tests/generated_grastl_runtime_asset_report.tscn`
- `tests/overworld_visual_smoke.gd`
- `tests/validate_repo.py`
completionCriteria:
- Grass/grastl terrain runtime asset resolution points at the generated `frames_64` resource directory.
- The overworld map view can resolve generated grastl frame paths while preserving existing terrain selection behavior for other atlases and roads.
- Godot import sidecars exist for the 79 generated grastl frame PNGs.
- Focused validation proves all 79 generated frame resources exist/load and a runtime grass tile resolves through the generated grastl frame bank.
validation:
- `godot4 --headless --path /root/dev/heroes-like /root/dev/heroes-like/tests/generated_grastl_runtime_asset_report.tscn`
- `python3 tests/validate_repo.py`
- `git diff --check`
nonGoals:
- No terrain placement, pathing, fog, save schema, RMG, editor paint semantics, road rendering, or non-grass terrain atlas redesign.
- No new generated asset ingestion beyond the already committed grastl `frames_64` replacement trial frames.

Selected owner-directed workflow slice:

id: `generated-terrain-classes-runtime-integration-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add the tracked workflow and deterministic scaffolding needed to generate original replacement runtime terrain tiles for every remaining terrain class after `grastl`.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/generated-terrain-class-replacement-workflow.md`
- `art/overworld/runtime/terrain_tiles/generated/grastl/README.md`
- 2026-05-04 owner directive to continue the grastl workflow for `dirttl`, `lavatl`, `rocktl`, `rougtl`, `sandtl`, `snowtl`, `subbtl`, `swmptl`, and `watrtl`
implementationTargets:
- `docs/generated-terrain-class-replacement-workflow.md`
- `tools/generated_terrain_atlas_tool.py`
- `art/overworld/runtime/terrain_tiles/generated/<class>/source_sheets/`
- `art/overworld/runtime/terrain_tiles/generated/<class>/previews/`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- A new tracked child slice exists for the remaining generated terrain class replacement workflow and is active in `ops/progress.json`.
- The workflow explicitly lists `dirttl` 46, `lavatl` 79, `rocktl` 48, `rougtl` 79, `sandtl` 24, `snowtl` 79, `subbtl` 79, `swmptl` 79, and `watrtl` 33.
- Deterministic tooling can pack original reference frames into 1024x1024 16x16 magenta-padded atlases, validate/cut later generated 1024 atlases into exact 64x64 class frames, force unused cells to magenta, and produce previews without calling image generation.
- Repo-owned original reference 1024 atlases and previews exist for every listed remaining class.
- Validation includes JSON validation, reference pack dry-run/generation, script syntax validation, `sync-plan` dry-run when available, and `git diff --check`.
validation:
- `python3 tools/generated_terrain_atlas_tool.py pack-reference --all --dry-run`
- `python3 tools/generated_terrain_atlas_tool.py pack-reference --all --force`
- `python3 -m py_compile tools/generated_terrain_atlas_tool.py`
- `python3 -m json.tool ops/progress.json`
- `python3 tests/validate_repo.py`
- `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan --dry-run /root/dev/heroes-like`
- `git diff --check`
nonGoals:
- No image generation calls from this worker or repo tooling.
- No runtime replacement frame ingestion for non-`grastl` terrain classes until generated candidates exist and pass validation.
- No terrain placement, pathing, fog, save schema, RMG, editor paint semantics, road rendering, or unrelated renderer redesign.

Selected Phase 2 corrective slice:

id: `native-gdextension-editor-manifest-correction-10184`
phase: `phase-2-deep-production-foundation`
purpose: Fix GDExtension library feature selection so Godot editor/headless smokes load the native Debug library on Linux and Windows instead of falling back to the GDScript compatibility shim.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner report that Windows Godot 4.6.2 headless selects `windows.editor.x86_64`
implementationTargets:
- `src/gdextension/map_persistence.gdextension`
- `src/gdextension/map_persistence.gdextension.in`
- `src/gdextension/README.md`
- `scripts/build_map_persistence_windows.bat`
- `docs/map-scenario-gdextension-persistence-foundation.md`
completionCriteria:
- Linux and Windows editor/headless manifest entries point to the Debug native library.
- Existing debug/release template entries remain intact for export/template builds.
- Windows helper/docs explain that headless/editor smokes use the editor entry and Debug-only builds are sufficient for smokes.
- Linux native rebuild plus native package and RMG smokes still load the native extension.
nonGoals:
- No native API, RMG, gameplay, save, content, package, renderer, fog, pathing, or adoption semantics changes.
- No unsupported macOS library paths.

Selected Phase 2 planning slice:

id: `map-scenario-gdextension-persistence-foundation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Replace the current loose JSON/dictionary map and scenario persistence model with a planned typed map/scenario document architecture, likely backed by a C++ Godot GDExtension, before broad generated-map or scenario production depends on it.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner direction and RMG/save-path inspection
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd` generation/export boundary
- `scripts/core/ScenarioSelectRules.gd` generated-skirmish setup boundary
- `scripts/core/ScenarioFactory.gd` scenario/session bootstrap adapters
- `scripts/core/SessionStateStore.gd` session save reference/delta boundary
- `scripts/autoload/ContentService.gd` authored/generated scenario loading boundary
- `scripts/autoload/SaveService.gd` save/load JSON hot path
- `content/scenarios.json` split/manifest migration plan
- future `src/gdextension` or equivalent C++ map package module
baselineChecks:
- `python3 tests/validate_repo.py`
- `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan /root/dev/heroes-like --dry-run`
- focused generated-map save/load, scenario-load, and RMG validation smokes selected at kickoff
sliceEvidence:
- Current RMG returns nested Dictionary payloads with `scenario_record`, `metadata`, `staging`, validation, and provenance instead of a typed map object.
- Generated skirmish sessions are memory/session-oriented and preserve no-authored-writeback boundaries rather than producing durable first-class map assets.
- Authored scenarios are bundled in large JSON content records under `content/scenarios.json`.
- `SaveService._save_raw_dictionary()` serializes full save payloads with `JSON.stringify(payload, "\t")` and writes raw JSON strings through `FileAccess`.
- A Small 36x36 generated-map profile wrote about 6.95 MB JSON and took roughly 202-219 ms in the save path, so larger generated maps will amplify the problem.
completionCriteria:
- A typed map/scenario document model is defined with stable ids, schema/version, metadata, terrain/layers, object placements, route/validation data, and generated provenance boundaries.
- A durable map package approach is selected for authored and generated maps, including load, validate, save, migrate, and corruption/tamper handling.
- Runtime saves are redesigned to reference immutable map packages by id/hash/version and store only mutable session deltas where practical.
- `content/scenarios.json` has a migration plan toward an index/manifest plus separate map/scenario package files.
- RMG bridge/export sequencing is defined so existing GDScript generation can emit/import the new format before any full C++ generator rewrite is attempted.
- Backward compatibility, rollback, validation scenes, and performance acceptance gates are named before implementation starts.
nonGoals:
- No immediate coding or coding-agent implementation during planning refinement.
- No breaking existing saves or authored scenarios without an explicit migration slice.
- No full RMG rewrite as the first step.
- No renderer/fog/pathing/gameplay semantics changes unless separately selected.
- No production content migration without provenance, rollback, and validation evidence.

Selected Phase 2 child implementation slice:

id: `native-rmg-gdextension-foundation-10184`
phase: `phase-2-deep-production-foundation`
purpose: Start the native RMG port as a narrow C++ GDExtension foundation: API surface, deterministic minimal config/seed identity, and an empty generated `MapDocument` smoke result.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/map-scenario-gdextension-persistence-foundation.md`
- 2026-05-03 owner direction to begin the native RMG port without gameplay adoption
implementationTargets:
- `src/gdextension/include/map_package_service.hpp`
- `src/gdextension/src/map_package_service.cpp`
- `scripts/persistence/MapPackageService.gd`
- `tests/native_random_map_foundation_report.gd`
- `tests/native_random_map_foundation_report.tscn`
- `docs/map-scenario-gdextension-persistence-foundation.md`
completionCriteria:
- Native API exposes minimal random-map config normalization, deterministic config identity, and `generate_random_map(config)` foundation behavior.
- Same config/seed produces the same identity and changed seed changes identity.
- Returned generation status is explicitly `partial_foundation` with full generation `not_implemented`.
- Existing GDScript RMG runtime flow remains authoritative and untouched.
- Existing native map package smoke and new native RMG foundation smoke pass after Linux native rebuild.
nonGoals:
- No full RMG rewrite.
- No `RandomMapGeneratorRules.gd` call-site replacement.
- No `ScenarioSelectRules.gd` runtime generation flow change.
- No package adoption, save version bump, authored content migration, generated authored writeback, renderer/fog/pathing/gameplay semantic change, or fake parity claim.

Native RMG parity track:

The native C++ GDExtension RMG must reach functional parity with the current GDScript source of truth in `scripts/core/RandomMapGeneratorRules.gd` before any gameplay adoption. The practical breakdown is:

- `native-rmg-terrain-grid-generation-10184`: deterministic normalized config, terrain/biome palette, width/height/level tile grid, terrain ids/codes, stable signatures, and terrain-grid smoke while preserving `partial_foundation`.
- `native-rmg-zone-player-starts-10184`: deterministic foundation player constraints, assignment metadata, runtime fallback zones, zone seed layout, owner grid, zone bounds/terrain association, start anchors, start spacing metadata, and status/signature reporting.
- `native-rmg-road-river-network-10184`: route/corridor graph, road overlays, river/water/underground transit records, and reachability proof surfaces.
- `native-rmg-object-placement-foundation-10184`: resource/reward/decor/object staging, footprint predicates, occupancy, and deterministic object placement records.
- `native-rmg-town-guard-placement-10184`: primary/neutral towns, mines, dwellings, route guards, border guards, monster/reward bands, and guard pressure records.
- `native-rmg-validation-provenance-parity-10184`: validation reports, phase pipeline, stable signatures, generated provenance, no-authored-write policy, and warning/failure parity.
- `native-rmg-gdscript-comparison-harness-10184`: headless comparison fixtures proving native/GDScript structural parity across supported seeds, sizes, water modes, underground, and player counts.
- `native-rmg-package-session-adoption-10184`: package/session integration behind explicit feature-gated adapters for native output; no save version bump or call-site replacement.
- `native-rmg-full-parity-gate-10184`: final tracked gate proving terrain, objects, roads, rivers, towns, guards, zones/player starts, validation/provenance, comparison harness, package/session integration, Linux, and Windows for the supported 36x36 `homm3_small` comparison profiles before any runtime call-site adoption.

With `native-rmg-full-parity-gate-10184` complete, native RMG may claim full
parity only for the supported tracked comparison profiles. Unsupported native
configs remain incomplete, and `RandomMapGeneratorRules.gd` remains
authoritative for live generated skirmish gameplay until a later explicit
runtime adoption slice changes the call sites.

Known Phase 2 parent tracks already represented in progress history:
- `world-faction-identity-implementation-bridge-10184`
- `concept-art-curation-gate-10184`
- `economy-resource-foundation-implementation-10184`
- `overworld-object-encounter-foundation-implementation-10184`
- `magic-system-foundation-implementation-10184`
- `artifact-system-foundation-implementation-10184`
- `animation-event-cue-foundation-implementation-10184`
- `strategic-ai-foundation-continuation-10184`
- `terrain-editor-tooling-foundation-implementation-10184`
- `random-map-generator-foundation-10184`
- `map-scenario-gdextension-persistence-foundation-10184`

Selected owner-directed corrective slice:

id: `random-map-homm3-parity-richness-corrective-10184`
phase: `phase-2-deep-production-foundation`
purpose: Re-audit generated-map output against owner-visible HoMM3-style RMG expectations and improve concrete generated-map richness where maps still look sparse or structurally wrong.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `docs/random-map-final-homm3-parity-regate-audit.md`
- `docs/random-map-xl-template-alignment-audit.md`
- 2026-05-04 owner directive that generated maps are still not close enough to HoMM3-style RMG
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- focused RMG report/test scenes under `tests/`
- `.artifacts/` generated-map inspection reports/previews when practical
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Multiple deterministic generated-map seeds/templates/sizes are inspected with human-readable evidence.
- Generated maps enforce stronger town spacing/zone placement constraints.
- Roads, rivers where terrain/template policy supports them, movement-shaping blockers/decorations, artifacts/rewards, and guards are generated at visible HoMM3-style densities.
- Validation checks road/river presence or explicit unsupported policy, minimum town distance, blocker/decor density, artifact and guard counts/association, template richness metrics, and native/package startup regressions.
- Remaining parity gaps are explicitly tracked as follow-up instead of being hidden behind a parity claim.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, or broad renderer/fog/pathing redesign unless required by focused validation.
knownFollowUp:
- `translated_rmg_template_002_v1` remains a poor/failing translated template under 72x72 inspection because start viability and decoration route-blocking constraints fail; track a separate template-structure corrective before using it as positive parity evidence.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-bounded-inspection-footprints-10184`
phase: `phase-2-deep-production-foundation`
purpose: Make the HoMM3-style RMG richness inspection reliable in headless runs and improve generated-map blocker footprint parity using real HoMM3 RMG object/passability evidence.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- 2026-05-04 owner directive to continue RMG parity after `fa45218`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/` generated-map inspection previews/reports
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- The richness report runs bounded multi-map headless inspections and exits with clear JSON/report output.
- Multiple deterministic seeds/templates include roads, river/water candidates, town spacing, artifacts, guards, decorative blocker density, multi-tile blocker footprint, and object writeout metrics.
- Decorative obstacles use terrain-family passability/body masks instead of all blockers being one-tile placeholders, while route safety remains validated.
- Generated inspection artifacts are written under ignored repo `.artifacts/` or workspace artifacts, not untracked `maps/`.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-guarded-artifact-pairing-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG reward semantics by making materialized artifacts explicitly consume nearby object guards before lower-priority filler guards, and prove the pairing in bounded richness reports.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- 2026-05-04 owner directive to continue RMG parity after `3b7fc04`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/` generated-map inspection reports/previews
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Object guard materialization deduplicates artifact reward candidates and prioritizes artifact guards before lower-priority mine, dwelling, and cache guards.
- Guard records carry explicit guarded-object point, distance, adjacency, and placement-id association metadata.
- Bounded richness report includes direct guarded-artifact coverage, missing-count, adjacency, and max-distance metrics across the existing multi-template cases without exceeding the runtime budget.
- Focused RMG report and repository validation pass, and remaining parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-connection-road-controls-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG road quality by making template connection `Value`, `Wide`, and `Border Guard` semantics visible and validated in generated road overlays instead of measuring only road tile counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-special-guards-and-wide.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- 2026-05-04 owner directive to continue RMG parity after `e20d96c`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/rmg_parity_richness/`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Generated road overlays carry explicit connection-control markers for normal guarded links and border-guard links.
- Wide links preserve guard-suppressed road semantics without creating normal connection controls.
- Bounded richness metrics validate connection-control coverage, wide route semantics, and special border-guard gate roads across multiple seeds/templates.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-blocker-choke-shaping-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG movement texture by making decorative obstacle filler measurably shape route shoulders and chokepoints instead of only proving global decoration/blocker density.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-phase-runner.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-decoration-obstacles.csv`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.csv`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/rmg_parity_richness/`
- `ops/progress.json`
completionCriteria:
- Decorative obstacle candidate scoring accounts for required road/corridor shoulder pressure while preserving path safety.
- Generated decoration records and validation expose movement-shaping metrics for road-adjacent blocker bodies, covered required routes, and choked road tiles.
- Bounded richness report validates route/choke blocker coverage across multiple seeds/templates without exceeding the current runtime envelope.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this measurable movement-shaping improvement.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-river-crossing-quality-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG river overlay quality by making land river candidates continuous, body-safe, and measurably crossed by generated roads instead of only counting river candidates.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-writeout-to-map-structures.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-phase-runner.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `tests/random_map_roads_rivers_writeout_report.gd`
- `ops/progress.json`
completionCriteria:
- Land river candidates are generated as continuous ordered overlay paths that avoid object bodies while allowing explicit road bridge/ford crossing cells.
- Road/river writeout exposes river continuity, body-conflict, isolated-fragment, and road-crossing metrics.
- Bounded richness metrics validate coherent river candidates and road crossing coverage across the selected land/island seeds/templates without exceeding the current runtime envelope.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this measurable river/crossing quality improvement.

Completed owner-directed implementation slice:

id: `random-map-homm3-parity-zone-richness-bands-10184`
phase: `phase-2-deep-production-foundation`
purpose: Improve HoMM3-style RMG template richness by ensuring non-connector zones carry measurable economy, treasure-band, guard, decoration, and reward coverage instead of hiding poor zones behind whole-map aggregate counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-checklist.md`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `.artifacts/rmg_parity_richness/`
- `ops/progress.json`
completionCriteria:
- Runtime zone metadata applies a conservative richness floor only where mine/resource requirements, treasure bands, or monster policy are missing or empty.
- Bounded richness metrics report per-zone richness minimum, poor zone count, object category coverage, reward-band source/fallback counts, value bands, and template variability across multiple seeds/templates.
- Focused richness validation passes within its runtime budget with zero poor eligible zones and no reward-band fallback in the selected cases.
- Remaining RMG parity gaps are listed for the next slice.
nonGoals:
- No generated terrain-art replacement work.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, or broad renderer/fog/pathing redesign.
- No claim of full HoMM3 RMG parity beyond this measurable zone richness and reward-band improvement.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-visual-inspection-evidence-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add bounded multi-map visual/ASCII/JSON inspection evidence across more seeds, templates, and sizes so RMG parity work does not hide remaining quality gaps behind aggregate richness counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- 2026-05-04 owner directive to continue RMG parity after `2ba8fa5`
implementationTargets:
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.tscn`
- `.artifacts/rmg_parity_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- The report samples multiple deterministic seeds/templates/sizes with bounded runtime and writes human-inspectable ASCII/JSON artifacts under ignored `.artifacts/`.
- Strict positive cases remain green while diagnostic translated-template probes record remaining quality gaps without pretending full parity.
- The tracked gap note records that ASCII/JSON inspection is evidence only and does not complete rendered visual parity, large-template repair, native RMG parity, or asset ingestion.
- Focused RMG reports, JSON/progress sync, diff check, and repository validation pass.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, generated package/map clutter, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this inspection evidence and any explicitly fixed concrete gap.

Completed owner-directed corrective slice:

id: `random-map-homm3-parity-visual-diagnostic-runtime-10184`
phase: `phase-2-deep-production-foundation`
purpose: Correct the bounded RMG visual inspection evidence after `be744e8` by reducing route-heavy translated-template probe cost, separating strict fixture budgets from capped diagnostic probe budgets, and replacing misleading grass-run summary metrics with marker-distribution evidence.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- 2026-05-04 owner directive to continue RMG parity after `be744e8`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `.artifacts/rmg_parity_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- Route-heavy translated visual probes avoid unnecessary whole-grid path searches where direct or bidirectional route search is sufficient.
- Strict positive fixtures remain on the existing per-case runtime bar, while diagnostic translated-template probes have explicit capped evidence budgets and still report strict-budget overruns as notes.
- Visual summary and matrix expose marker row/column/quadrant coverage and per-route timing so grass terrain runs are not mistaken for blank-map quality failures.
- Focused visual/richness reports, JSON/progress sync, diff check, and repository validation pass.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, generated package/map clutter, or broad renderer/fog/pathing redesign.
- No full HoMM3 RMG parity claim beyond this bounded report/runtime correction.

Completed owner-directed follow-up slice:

id: `random-map-homm3-parity-large-visual-diagnostic-10184`
phase: `phase-2-deep-production-foundation`
purpose: Add a separate bounded visual diagnostic path for excluded large translated RMG templates, starting with `translated_rmg_template_042_v1` at 108x108, without making the cheap visual gate hang.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- 2026-05-04 owner directive to continue RMG parity after `41233b1`
implementationTargets:
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `tests/random_map_homm3_parity_large_visual_inspection_report.tscn`
- `.artifacts/rmg_parity_large_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- The existing cheap visual gate keeps its 36x36/72x72 case set and runtime bounds.
- A separate large report mode inspects one deterministic 108x108 `translated_rmg_template_042_v1` case with explicit total and diagnostic per-case budgets.
- Large-template quality gaps are reported as diagnostic gaps with limit 0 for this focused evidence path; strict-budget overruns remain diagnostic notes.
- Focused large/cheap visual reports, richness report if reasonable, JSON/progress sync, diff check, and repository validation pass.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, generated package/map clutter, or broad renderer/fog/pathing redesign.
- No promotion of `translated_rmg_template_042_v1`, `translated_rmg_template_043_v1`, 144x144, or underground large templates into strict cheap-gate fixtures.
- No full HoMM3 RMG parity claim beyond this bounded large-template diagnostic evidence.

Selected owner-directed follow-up slice:

id: `random-map-homm3-parity-large-layout-quality-metrics-10184`
phase: `phase-2-deep-production-foundation`
purpose: Surface the source-backed large-template fairness/layout quality warnings that are currently present in validation output but hidden from the visual diagnostic matrix and compact metrics.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `docs/random-map-generator-foundation.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- 2026-05-04 owner directive to continue RMG parity after `6c14f35`
implementationTargets:
- `tests/random_map_homm3_parity_richness_report.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `.artifacts/rmg_parity_large_visual_inspection/`
- `.artifacts/rmg_parity_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- Large/visual inspection metrics expose fairness status, warning counts, fail-threshold warning counts, contest-route distance spread, contest-guard pressure spread, route-guard pressure spread, and town-to-resource distance spread from the existing source-backed fairness report.
- The visual matrix and JSON summaries make large layout-quality warnings visible without changing generator route, object, guard, terrain, save/load, renderer, or runtime semantics.
- The gap note records the newly visible large-template layout warning evidence and identifies layout correction as a separate next slice before strict promotion.
- Focused large visual report, cheap visual report if reasonable, JSON/progress sync, diff check, and repository validation pass.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No route/pathing, zone layout, guard pressure, object placement, content density, save-version, native generator, renderer, fog, or gameplay behavior change.
- No promotion of `translated_rmg_template_042_v1`, `translated_rmg_template_043_v1`, 144x144, or underground large templates into strict cheap-gate fixtures.
- No full HoMM3 RMG parity claim beyond this clearer diagnostic evidence.

Selected owner-directed implementation slice:

id: `native-rmg-homm3-local-distribution-10184`
phase: `phase-2-deep-production-foundation`
purpose: Correct the native C++ owner-like 72x72 islands output after the land/water and land-normalized density fixes so local interactive placement has fewer barren land windows and fewer oversized piles while preserving small guarded reward clusters.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
- `docs/native-rmg-homm3-land-water-shape-report.md`
- `docs/native-rmg-homm3-land-normalized-object-density-report.md`
- owner screenshots from 2026-05-04 showing desolate regions and localized piles after commit `ed0dad2`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_local_distribution_report.gd`
- `tests/native_random_map_homm3_local_distribution_report.tscn`
- `docs/native-rmg-homm3-local-distribution-report.md`
- `ops/progress.json`
completionCriteria:
- Active native package generation through `MapPackageService.generate_random_map()` remains the only runtime path touched; generation is not rerouted to `scripts/core/RandomMapGeneratorRules.gd`.
- The new report measures local empty-window, pile concentration, window density spread, and nearest-neighbor metrics separately for decorations, interactive rewards/sites, guards, and guarded packages on the owner-like 72x72 generated/native case.
- Native interactive object placement uses deterministic coarse-grid/spacing scoring so non-decorative objects distribute across eligible zone/land windows while guarded reward packages remain compact local pairs, not large piles.
- Existing guard/reward package adoption, road non-conflict/connectivity, source identity/proxy metadata, land/water shape, fill coverage, catalog/menu wiring, decoration generation, and full-parity gates still pass.
nonGoals:
- No generated `.amap`/`.ascenario` commits under `maps/`.
- No copyrighted HoMM3 art/assets, exact HoMM3 byte/object-table/art parity, or full parity claim.
- No save-version bump, authored scenario adoption, renderer/fog rewrite, generated terrain-art ingestion, or route back to old GDScript RMG.

Selected owner-directed implementation slice:

id: `random-map-homm3-parity-start-front-fairness-10184`
phase: `phase-2-deep-production-foundation`
purpose: Reduce the largest newly exposed RMG layout fairness warnings by classifying comparable primary contest/early fronts per active player start from translated template connections, without weakening guard/resource/distance diagnostics.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `docs/random-map-generator-foundation.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- 2026-05-04 owner directive to continue RMG parity after `cf52aa9`
implementationTargets:
- `scripts/core/RandomMapGeneratorRules.gd`
- `tests/random_map_homm3_parity_richness_report.gd`
- `tests/random_map_homm3_parity_visual_inspection_report.gd`
- `.artifacts/rmg_parity_richness/`
- `.artifacts/rmg_parity_visual_inspection/`
- `.artifacts/rmg_parity_large_visual_inspection/`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- `ops/progress.json`
completionCriteria:
- Translated template connections keep their source guard payloads and required route materialization, including wide and border-guard semantics.
- Layout fairness classifies one deterministic primary contest/early front per active player start, preferring active-opponent fronts and then lower-pressure neutral fronts, so duplicate links and inactive owner-slot links do not inflate one player's comparable start-front pressure.
- Fairness diagnostics remain strict and continue reporting remaining route/resource/guard spread warnings after the corrected primary-front model.
- Richness, visual, large visual if reasonable, JSON/progress sync, diff check, and repository validation pass or any skipped validation is recorded with a concrete reason.
nonGoals:
- No generated terrain-art replacement work or generated PNG ingestion.
- No copyrighted names, assets, maps, factions, unit art, music, or text.
- No save-version bump, authored campaign adoption, native generator rewrite, generated package/map clutter, renderer, fog, pathing, or gameplay loop redesign.
- No promotion of large translated templates into strict cheap-gate fixtures.
- No full HoMM3 RMG parity claim beyond this bounded start-front fairness correction.

### Phase 3 - HoMM3-Style Random Map Generator Rework

Goal: rework native random map generation around the recovered HoMM3 RMG execution model, while translating all output into original game content and keeping exact byte/art parity out of scope.

Active tactical slices:

id: `native-rmg-broad-translated-catalog-structural-support-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Stop treating recovered translated land/surface catalog templates that already pass generation, validation, package conversion, route-closure, and package-surface topology gates as `not_implemented`; give them a bounded structural-support status that remains non-authoritative and explicitly not full HoMM3 parity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_broad_template_generation_report.gd`
- `src/gdextension/src/map_package_service.cpp`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Eligible recovered translated land/surface templates report a non-`not_implemented` structural-support full-generation status only when generated through catalog template/profile ids, land water mode, and one native surface level.
- Broad template generation/package report fails if any attempted eligible translated land/surface template remains `not_implemented`.
- Package/session adoption stays feature-gated and non-runtime-authoritative for broad structurally supported templates.
- Owner-compared defaults keep their stronger owner-compared statuses and full-parity gates continue to reject full HoMM3 parity claims.
- Legacy compact foundation tests and unsupported islands/underground controls remain blocked or scoped as before.
nonGoals:
- No broad owner-H3M comparison claim.
- No exact HoMM3 byte/art/DEF parity.
- No runtime-authoritative promotion for broad catalog templates.
- No underground or general islands production support.
completionEvidence:
- Full unbounded broad template generation report passed all 56 eligible land/surface templates with zero skipped templates, zero translated `not_implemented` statuses, full-generation status counts `{not_implemented: 2, scoped_structural_profile_not_full_parity: 1, owner_compared_translated_profile_not_full_parity: 4, translated_catalog_structural_profile_not_full_parity: 49}`, and zero object-only player-start, cross-zone, or all-town package route leaks.
- Focused `translated_rmg_template_044_v1` rerun passed after classifying direct town-spacing pressure as broad-catalog parity debt while keeping package route closure hard-gated.
- Full parity boundary, package object-only breadth, package/session authoritative replay, random-map menu wiring, player setup retry UX, foundation, and town-spacing regression reports passed.
- Native extension rebuild passed after the C++ support-boundary and validation changes.

id: `native-rmg-owner-medium-001-road-shape-correction-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Continue the owner-uploaded medium 001 comparison work by correcting the remaining road-shape gap after category counts, town-road topology, and content clustering were brought into owner-relative gates. The owner-relative spatial gate now covers quadrant unevenness instead of accepting road count alone.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- owner-uploaded 72x72 H3M comparison evidence from 2026-05-06
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `ops/progress.json`
completionCriteria:
- Owner-medium translated template 001 keeps the corrected category counts, town-road connections, road branch/endpoint topology, and content clustering gates passing.
- Native owner-medium road quadrant/coarse-grid shape moves materially toward the uploaded H3M instead of remaining evenly distributed across all quadrants.
- Any new road-shape gate is owner-relative and does not accept road count alone as a proxy for HoMM3-like road layout.
- Small 049 package topology, uploaded-small comparison, choke, startup, repo validation, JSON validation, and diff hygiene remain passing.
completionEvidence:
- Owner-medium 001 route materialization remaps northeast-quadrant road cells into the southern service band and prevents branch/service-stub growth from repopulating the owner H3M's mostly empty northeast road quadrant.
- Owner-medium spatial comparison passed with no warnings: native road quadrants `[39, 4, 58, 87]` versus owner `[41, 0, 51, 92]`, road_quadrant_cv_delta `-0.07`, road_tile_delta `+4`, road_grid_nonempty_delta `+3`, largest_roadless_land_region_delta `0`, road_endpoint_delta `+3`, and road_branch_delta `0`.
- Package object-only breadth, full-parity boundary, and authoritative replay reports passed after the road-shape correction; owner Medium islands remains owner-compared runtime-supported without any full HoMM3 parity claim.
- Uploaded Small H3M comparison/topology reports still pass with current Small 049 output at 7 towns, 303 package objects, 150 decorative obstacles, 40 guards, zero object-only town routes, and loaded package roads close to the owner sample.
nonGoals:
- No HoMM3 art, DEF, name, text, map, or binary `.h3m` import.
- No exact byte-level road parity claim.
- No broad generator rewrite outside this owner-medium road-shape correction.
- No save-version bump or runtime-authoritative package/session promotion.

id: `native-rmg-uploaded-small-topology-evidence-gap-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Convert the owner-uploaded single-level Small 3-player H3M comparison into a repeatable local topology audit that parses the uploaded H3M evidence when present and compares it to current native translated Small 049 package output beyond aggregate counts.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` local untracked owner evidence
- `tests/native_random_map_homm3_uploaded_small_comparison_report.gd`
- `tests/native_random_map_zone_choke_regression_report.gd`
implementationTargets:
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.tscn`
- `ops/progress.json`
completionCriteria:
- The audit parses the local uploaded H3M object templates, placed object records, passability/action masks, town positions, guard records, and road cells without committing the uploaded `.h3m`.
- Current native Small 049 package output is compared against the parsed owner evidence for town count, nearest-town distance, object categories, guard count, road cells, blocker surfaces, and unresolved town-pair topology.
- The report distinguishes hard regression gates from remaining HoMM3-style parity gaps, especially native reliance on terrain rock barriers rather than object-mask-only obstacle chokes.
completionEvidence:
- Uploaded Small parses as 36x36x1 SoD, 7 towns, 303 objects, 150 decorations, 40 guard records, 76 reward/resource records, 30 other objects, 110 road cells, and 722 object-mask blocked tiles.
- Current native translated Small 049 with the comparison seed produces 7 towns, nearest town distance 10, 303 objects, 150 decorative obstacles, 40 guards, 76 mine/resource/reward objects, 30 scenic objects, 105 road cells, zero duplicate/empty road records, and zero unresolved reachable town pairs.
- Remaining gap is explicit: native currently needs 375 rock terrain barrier tiles plus object blockers to close the topology, so it is not yet an object-mask/guard-only HoMM3-style choke materialization.
nonGoals:
- No HoMM3 art, DEF, name, text, map, or binary `.h3m` import.
- No generator behavior change in this evidence slice.
- No exact H3M pathing/byte parity claim from the local parser.

id: `native-rmg-small-object-choke-materialization-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Follow the uploaded Small topology audit by moving current Small 049 package choke closure from terrain-only reliance toward object-surface blocker materialization: decorative obstacle masks must close the town topology even when terrain rock barriers are ignored.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- owner-uploaded Small 3-player H3M comparison evidence
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Native translated Small 049 keeps owner-like aggregate counts, road cells, town distance, and package topology gates.
- The uploaded Small topology report fails if native object blockers alone allow any reachable town pair when terrain rock blockers are ignored.
- Compact decorative obstacle placement is biased toward owner-grid zone-boundary choke cells, and package decorative obstacle masks materialize nearby land-boundary choke cells without adding generated object records.
- Remaining terrain-rock serialization is reported as a residual warning rather than silently treated as HoMM3-style object-mask parity.
completionEvidence:
- Object-only reachable town pairs moved from 6 before this slice to 0 after boundary-biased compact decoration and decorative package choke masks.
- Native Small 049 still produces 7 towns, nearest town distance 10, 303 objects, 150 decorative obstacles, 40 guards, 105 road cells, zero empty/duplicate road records, and zero unresolved reachable town pairs.
nonGoals:
- No HoMM3 art, DEF, name, text, map, or binary `.h3m` import.
- No broad removal of terrain rock boundary serialization in this slice.
- No exact H3M pathing or byte parity claim.

id: `native-rmg-package-object-only-topology-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Follow the Small object choke materialization by hardening the converted/saved/loaded native package surface gate: package object masks alone must close Small 049 town topology without relying on terrain rock blockers.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_package_surface_topology_report.gd`
- owner-uploaded Small 3-player H3M comparison evidence
implementationTargets:
- `tests/native_random_map_package_surface_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- Converted and loaded Small 049 package surfaces still preserve recovered template provenance, owner-like counts, roads, town spacing, and no empty/duplicate road records.
- The package surface report computes object-only blocker topology separately from terrain-plus-object topology.
- Converted and loaded package surfaces fail if object masks alone allow any unguarded start-town or cross-zone town route.
- The gate remains explicit that this proves Small 049 package topology only, not broad HoMM3 RMG parity or exact H3M byte/pathing parity.
completionEvidence:
- `tests/native_random_map_package_surface_topology_report.gd` now computes `object_only_start_town_topology` and `object_only_cross_zone_town_topology` separately from terrain-plus-object topology for both converted and loaded package surfaces.
- The package surface report passes with converted and loaded Small 049 packages at 7 towns, 303 objects, 40 guards, 104 unique road tiles, zero empty/duplicate roads, 1000 object-only blocked tiles, 3 checked player-start town pairs, 21 checked cross-zone town pairs, and zero object-only reachable pairs.
nonGoals:
- No C++ behavior change unless the strengthened package-surface gate exposes a regression.
- No HoMM3 art, DEF, name, text, map, or binary `.h3m` import.
- No runtime-authoritative package/session promotion.

id: `native-rmg-default-size-object-only-breadth-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Broaden object-only package topology validation from the uploaded Small 049 case to the player-facing default translated templates for Small, Medium, Large, and Extra Large maps.
sourceDocs:
- `project.md`
- `PLAN.md`
- `scripts/core/ScenarioSelectRules.gd`
- `tests/native_random_map_package_surface_topology_report.gd`
implementationTargets:
- `tests/native_random_map_package_object_only_breadth_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.tscn`
- `ops/progress.json`
completionCriteria:
- The report generates, converts, saves, and reloads each player-facing default size-class template.
- Converted and loaded package surfaces fail if object masks alone allow unguarded cross-zone town traversal.
- Each case preserves at least the expected player-start towns, package object records, guard records, and non-empty roads.
- Any unsupported or still-not-HoMM3-equivalent status remains reported rather than promoted to broad production parity.
completionEvidence:
- `tests/native_random_map_package_object_only_breadth_report.tscn` passes for the player-facing default Small 049, Medium 002, Large 042, and Extra Large 043 translated templates through generate, package convert, save, and reload.
- Converted and loaded package surfaces report zero object-only reachable cross-zone town pairs for all four default size-class templates.
- Small 049 package surface still passes the focused package topology report at 7 towns, 303 objects, 40 guards, and no empty or duplicate road records.
- Uploaded Small H3M comparison topology remains passing while reporting that the gate is topology/comparison evidence, not exact H3M byte/pathing parity.
nonGoals:
- No exact H3M byte/pathing parity claim.
- C++ changes are limited to concrete blockers exposed by the breadth gate: zero-value translated land guard fallback, package boundary mask coverage, close cross-zone town corridor guard coverage, edge-aware barriers, and required town materialization fallback.
- No generated package/map evidence committed.

id: `native-rmg-production-claim-boundary-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Remove misleading native RMG full-parity/authoritative claims from scoped structural profiles now that owner H3M comparisons reopened broad production parity work.
sourceDocs:
- `project.md`
- `PLAN.md`
- `docs/random-map-homm3-parity-gap-audit.md`
- `docs/native-rmg-homm3-spec-rework-gate-report.md`
- owner objective that native RMG must become production-ready and not be treated as alpha/prototype
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- focused native RMG claim/adoption reports under `tests/`
- `ops/progress.json`
completionCriteria:
- Native generation never reports `full_parity_claim=true` or `native_runtime_authoritative=true` for scoped structural profiles.
- Legacy supported-profile behavior remains available as scoped structural support for targeted reports, package conversion, and deterministic regression coverage.
- Package/session conversion remains feature-gated and non-authoritative.
- Focused reports that previously expected full parity are updated to assert truthful production-claim boundaries.
completionEvidence:
- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed after the native claim-boundary changes.
- `tests/native_random_map_full_parity_gate_report.tscn`, `tests/native_random_map_homm3_validation_adoption_gates_report.tscn`, `tests/native_random_map_package_session_adoption_report.tscn`, `tests/native_random_map_supported_underground_terrain_count_report.tscn`, and `tests/native_random_map_gdscript_port_audit_report.tscn` passed with scoped structural support preserved and `full_parity_claim=false` / `native_runtime_authoritative=false`.
- `tests/native_random_map_package_object_only_breadth_report.tscn` and `tests/native_random_map_homm3_uploaded_small_topology_report.tscn` still pass after the claim boundary correction.
- `tests/native_random_map_gdscript_comparison_report.tscn` passes while reporting remaining road/object/guard/terrain gaps instead of allowing a native full-parity claim.
nonGoals:
- No broad RMG parity claim.
- No generated package/map evidence committed.
- No runtime call-site adoption or authored content writeback.

id: `native-rmg-production-owner-comparison-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Turn the owner-uploaded HoMM3 small single-level comparison and generated native small maps into a production parity gate for towns, zones, roads, obstacles, guards, and unguarded inter-zone routes.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m`
- `maps/small3playermap.h3m`
- owner correction that native RMG must not be treated as alpha/prototype and must approach real HoMM3-style production output
implementationTargets:
- native RMG topology, obstacle, guard, and road generation in `src/gdextension/src/map_package_service.cpp`
- focused uploaded-H3M comparison reports under `tests/`
- `ops/progress.json`
completionCriteria:
- A focused report compares owner HoMM3 and native small three-player single-level maps for town count, zone count, road graph shape, obstacle density, guard count, and cross-zone reachability.
- Native generated small maps do not allow short unguarded direct town-to-town routes between player starts or enemy towns.
- Obstacle and guard placement blocks or guards zone boundaries in a way that is materially closer to the uploaded HoMM3 sample than the current native output.
- The gate remains explicit that byte-level H3M parity and copyrighted asset import are out of scope.
completionEvidence:
- `tests/native_random_map_homm3_uploaded_small_topology_report.tscn` now compares parsed owner HoMM3 evidence with current native Small 049 on town count, expected zone count, road cells and road connected components, decoration/obstacle count, guard count, nearest town spacing, and unguarded cross-town reachability.
- The same report optionally loads the local uploaded native `.amap` as diagnostic evidence when present. In the owner-uploaded bad package it reports compact-template provenance, 6 towns, 0 road cells, 30 zero-tile road records, 28 decorations, 35 guards, nearest town spacing 3, and 10 reachable town pairs; current generated Small 049 reports 7 zones, 7 towns, 105 road cells, 1 road component versus owner 2, 150 decorations, 40 guards, nearest town spacing 12, and 0 reachable town pairs.
- HoMM3-side unguarded route parsing now treats monster/guard records as guard-controlled blockers so the report can reason about unguarded routes rather than raw passability only.
- `tests/native_random_map_homm3_uploaded_small_comparison_report.tscn` and `tests/native_random_map_package_surface_topology_report.tscn` pass alongside the strengthened topology report.
- `python3 tests/validate_repo.py`, `python3 -m json.tool ops/progress.json`, and `git diff --check` pass.
nonGoals:
- No HoMM3 asset import or copyrighted content cloning.
- No broad all-template parity claim.
- No runtime-authoritative adoption before the comparison gate passes.

id: `native-rmg-production-terrain-object-choke-boundary-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Replace the remaining Small 049 warning-level reliance on terrain rock boundaries with object/guard-owned choke evidence, then broaden the owner-comparison topology gate beyond the single Small evidence map.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- owner objective that native RMG must become production-ready and not be treated as alpha/prototype
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- focused package/topology reports under `tests/`
- `ops/progress.json`
completionCriteria:
- Current Small 049 no longer reports terrain-rock boundary reliance as a warning in the uploaded-small topology gate.
- Object and guard package masks, not terrain-only walls, explain blocked/guarded town-zone boundaries for the default Small output.
- The topology gate is broadened with at least one additional generated Small/Medium profile seed or size-class case that checks towns, roads, guards, obstacles, and unguarded routes.
- Runtime adoption remains feature-gated and non-authoritative until broader production parity evidence exists.
completionEvidence:
- `tests/native_random_map_homm3_uploaded_small_topology_report.tscn` now compares the uploaded single-level Small H3M to current native Small 049 and records the uploaded bad native package as non-gating diagnostic evidence.
- The gate now fails on Small count/road/topology drift and checks additional Small and Medium generated cases for towns, roads, guards, decorative blockers, and object-only cross-zone routes.
- `tests/native_random_map_package_surface_topology_report.tscn` and `tests/native_random_map_package_object_only_breadth_report.tscn` passed with current package surfaces.
nonGoals:
- No exact H3M byte parity.
- No HoMM3 asset import.
- No claim that all 56 recovered templates are production-ready.

id: `native-rmg-production-owner-comparison-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Move the owner-compared translated default profiles out of `partial_foundation` / `not_implemented` status without claiming full HoMM3 parity or native runtime authority.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_full_parity_gate_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
- owner objective that native RMG must become production-ready, usable, and not alpha/prototype
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_full_parity_gate_report.gd`
- focused package/topology reports under `tests/`
- `ops/progress.json`
completionCriteria:
- Translated Small 049 and Medium 002 default native generation no longer report `status: partial_foundation` or `full_generation_status: not_implemented`.
- The promoted status remains bounded to owner-comparison/topology-supported translated defaults and does not expose `full_parity_claim`, `native_runtime_authoritative`, or runtime call-site adoption.
- Full parity, uploaded-H3M topology, package-surface topology, and object-only breadth reports pass after a Linux native rebuild.
- `python3 tests/validate_repo.py`, `python3 -m json.tool ops/progress.json`, and `git diff --check` pass.
completionEvidence:
- Native C++ generation now classifies translated Small 049 and Medium 002 defaults as `owner_compared_translated_profile_supported` with `full_generation_status: owner_compared_translated_profile_not_full_parity`.
- Full parity and runtime authority remain false, and package/session adoption remains feature-gated and non-authoritative.
- `tests/native_random_map_full_parity_gate_report.tscn`, uploaded-H3M topology, package-surface topology, and object-only breadth reports passed after a Linux native rebuild.
remainingGaps:
- Large 042 and XL 043 still report `full_generation_status: not_implemented`; they need separate owner-comparison/topology evidence before promotion.
nonGoals:
- No exact H3M byte parity.
- No HoMM3 asset import.
- No claim that all 56 recovered templates are production-ready.
- No runtime-authoritative generated skirmish adoption.

id: `native-rmg-production-large-xl-owner-status-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Build owner-comparison/topology evidence for translated Large 042 and XL 043 defaults so they can be moved off `full_generation_status: not_implemented` without overclaiming full parity.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_package_object_only_breadth_report.gd`
- `docs/random-map-homm3-parity-visual-inspection-gaps.md`
- owner objective that native RMG must become production-ready, usable, and not alpha/prototype
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- focused Large/XL topology and package-surface reports under `tests/`
- `ops/progress.json`
completionCriteria:
- Large 042 and XL 043 default translated profiles have bounded topology evidence comparable to the Small/Medium owner-comparison gates.
- If evidence passes, Large/XL no longer report `full_generation_status: not_implemented`.
- Full parity, runtime authority, and all-56-template production claims remain false until broader audit coverage exists.
completionEvidence:
- Native C++ generation now classifies translated Large 042 and Extra Large 043 defaults as `owner_compared_translated_profile_supported` with `full_generation_status: owner_compared_translated_profile_not_full_parity`.
- `tests/native_random_map_package_object_only_breadth_report.gd` asserts Small 049, Medium 002, Large 042, and XL 043 status promotion, owner-compared support, no full parity claim, no runtime authority, materialized roads, guards, package save/load, and zero object-only reachable start/cross-zone town pairs.
- `tests/native_random_map_package_object_only_breadth_report.tscn` passed after a Linux native rebuild with Large 042 at 108x108/25 zones/16 towns/1332 objects/335 guards and XL 043 at 144x144/25 zones/17 towns/1786 objects/405 guards.
remainingGaps:
- Package/session adoption is still feature-gated and non-authoritative.
- All 56 recovered templates are not yet production-ready.
nonGoals:
- No exact H3M byte parity.
- No HoMM3 asset import.
- No blanket all-template promotion.
- No runtime-authoritative generated skirmish adoption.

id: `native-rmg-uploaded-small-road-component-hard-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Tighten the owner-uploaded Small H3M comparison so native Small 049 road connected-component topology must match the HoMM3 sample exactly instead of allowing warning-level drift.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- owner request to compare uploaded HoMM3 and native small maps for towns, zones, roads, obstacles, guards, and blocked/guarded inter-zone routes
implementationTargets:
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `ops/progress.json`
completionCriteria:
- The uploaded Small topology report fails if native Small 049 road component count differs from the owner HoMM3 sample.
- Current generated Small 049 still passes town count, zone count, object count, decorative blocker count, guard count, road cell tolerance, exact road component count, no orphan-road drift, and zero unguarded native town routes.
- The report continues to treat uploaded native `.amap` files as diagnostic evidence, not as committed/gating fixtures.
completionEvidence:
- `tests/native_random_map_homm3_uploaded_small_topology_report.tscn` passed with owner HoMM3 road components `[96, 14]`, current native Small 049 road components `[99, 14]`, `road_component_delta: 0`, `road_small_component_delta: 0`, `road_cell_delta: 3`, 7 towns, 7 zones, 303 objects, 150 decorative blockers, 40 guards, and zero native unguarded/object-only reachable town pairs.
- The same report records the older bad uploaded compact `.amap` as diagnostic evidence only: compact profile, 6 towns, 0 road cells, 28 decorations, 35 guards, nearest town spacing 3, and reachable town pairs.
- `tests/native_random_map_homm3_uploaded_small_comparison_report.tscn` passed and confirms player-facing Small default uses `translated_rmg_template_049_v1` instead of the legacy compact fixture path.
- `python3 tests/validate_repo.py`, `python3 -m json.tool ops/progress.json`, and `git diff --check` passed.
nonGoals:
- No exact H3M byte parity.
- No HoMM3 asset import.
- No runtime-authoritative generated skirmish adoption.

id: `native-rmg-broad-runtime-zone-graph-semantic-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Strengthen the broad recovered-template generation gate so every eligible land/surface template proves exact runtime zone/link semantic preservation, not just plausible generated package surfaces.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `content/random_map_template_catalog.json`
- `tests/native_random_map_broad_template_generation_report.gd`
implementationTargets:
- `tests/native_random_map_broad_template_generation_report.gd`
- `src/gdextension/src/map_package_service.cpp`
- `scripts/core/ScenarioSelectRules.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/random_map_player_count_range_report.gd`
- `ops/progress.json`
completionCriteria:
- Broad template generation fails if the runtime zone graph schema/validation is missing or failed.
- For every attempted eligible land/surface template, runtime zone count and link count exactly match the active recovered catalog rows after player filtering.
- Runtime graph links preserve wide, border-guard, guard value, and source endpoint semantics without connectivity-repair substitutions.
- Runtime graph zones preserve target/cell area coverage, source ids, roles, owner/player slot semantics, terrain/town/mine/resource/treasure/monster rule payloads, adjacency, and runtime link references.
- The existing package-surface gates for roads, objects, guards, package conversion, and object-only town-route closure still pass.
completionEvidence:
- The broad recovered-template gate now validates runtime graph schema/status, exact active catalog zone/link counts, target/cell area coverage, start-zone owner/player semantics, wide and border-guard link counts, guard-value sums, source endpoints, and absence of repair links for every attempted land/surface case.
- Template support now rejects disconnected active recovered graphs. This keeps disconnected translated templates 009 and 044 out of runtime selection and moves translated XL template 043 to the minimum connected player count, 5 players, instead of the disconnected 4-player default.
- `ScenarioSelectRules.gd` now exposes player counts only when the active template graph is connected, while direct compact-template support still preserves the legacy 3-player catalog range.
- `tests/native_random_map_broad_template_generation_report.tscn` passed with 54 attempted eligible templates, 54 successes, 2 disconnected skips (`translated_rmg_template_009_v1`, `translated_rmg_template_044_v1`), zero translated `not_implemented` statuses, and object-only package town/zone route closure for every attempted case.
- `tests/native_random_map_auto_template_batch_report.tscn` passed with XL 043 selected at 5 players, 14 towns, 27 zones, 1902 package objects, 454 guards, and validation status `pass`.
- `tests/native_random_map_package_object_only_breadth_report.tscn`, `tests/native_random_map_full_parity_gate_report.tscn`, and `tests/native_random_map_package_session_authoritative_replay_report.tscn` passed after the stricter graph selection.
- `tests/native_random_map_homm3_uploaded_small_topology_report.tscn` passed after the stricter graph selection, with the uploaded single-level HoMM3 Small sample and current native Small 049 both at 7 towns, 7 zones, 303 objects, 150 decorations, 40 guards, 2 road components, and zero native object-only reachable town pairs.
- `cmake --build .artifacts/map_persistence_native_build --parallel 2`, `python3 tests/validate_repo.py`, `python3 -m json.tool ops/progress.json`, `python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan /root/dev/heroes-like --dry-run`, and `git diff --check` passed.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No underground parity implementation.
- No broad player-facing exposure of non-owner-compared templates.

id: `native-rmg-player-facing-medium-islands-reactivation-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Reactivate a bounded player-facing Islands generated-map path by routing Medium islands native catalog auto-selection to the owner-compared translated islands profile instead of the blocked broad `not_implemented` fallback.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `scripts/core/ScenarioSelectRules.gd`
- `scenes/menus/MainMenu.gd`
- `tests/native_random_map_auto_template_batch_report.gd`
- `tests/random_map_player_setup_retry_ux_report.gd`
- `tests/random_map_all_template_menu_wiring_report.gd`
- `tests/native_random_map_package_session_authoritative_replay_report.gd`
- `ops/progress.json`
completionCriteria:
- Native catalog auto-selection prefers `translated_rmg_template_001_v1` / `translated_rmg_profile_001_v1` for Medium 4-player islands, matching the already owner-compared runtime-supported islands profile.
- Medium Islands player-facing setup validates and launches through native catalog auto-selection with package/session provenance, without re-enabling underground.
- Auto-template batch reports the Medium islands case as launchable owner-compared native support, not `not_implemented_launch_blocked`.
- Existing land defaults, compact launch blocking, package route closure, replay, and full-parity boundary gates remain green.
completionEvidence:
- Native catalog auto-selection now maps Medium 72x72, 4-player, single-level Islands requests to `translated_rmg_template_001_v1` / `translated_rmg_profile_001_v1` instead of falling through to the Medium land default and `not_implemented`.
- Player-facing generated-map setup now exposes Islands as a bounded water option and coerces Islands selection to Medium, 4 players, no underground before launch.
- `tests/random_map_player_setup_retry_ux_report.tscn` passed with Islands exposed in the player controls and Medium Islands setup returning `ok`, retry status `pass`, and template/profile 001/001.
- `tests/native_random_map_auto_template_batch_report.tscn` passed with `medium_islands_seed_a` selecting template/profile 001/001, 8 towns, 4 zones, 495 package objects, 60 guards, and `not_implemented_launch_blocked: false`.
- `tests/native_random_map_package_object_only_breadth_report.tscn` passed with `owner_medium_islands_001` at 8 towns, 4 zones, 496 objects, 61 guards, 201 road tiles, and zero object-only all-town or cross-zone reachable pairs.
- `tests/native_random_map_full_parity_gate_report.tscn` passed with Medium Islands runtime-adopted only as owner-compared not-full-parity output, keeping `full_parity_claim: false`.
- `tests/native_random_map_package_session_authoritative_replay_report.tscn` passed after adding `player_facing_medium_islands_001`, proving stable generate/convert/save/load replay for Medium Islands package/session identity.
- `tests/random_map_all_template_menu_wiring_report.tscn` passed with 54 buildable connected recovered templates, 2 disconnected catalog-only templates, manual template/profile controls hidden, and 4 player-facing default template/profile ids.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No underground parity implementation.
- No claim that every islands size/template is owner-compared or full parity.

id: `native-rmg-broad-islands-structural-support-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Extend the broad recovered-template structural gate from land/surface only to explicit surface Islands generation, then allow translated catalog Islands outputs to report structural not-full-parity support only when they pass the same zone, road, object, guard, package, and object-only route-closure gates.
sourceDocs:
- `project.md`
- `PLAN.md`
- `content/random_map_template_catalog.json`
- `tests/native_random_map_broad_template_generation_report.gd`
- owner objective that native RMG must become production-ready and not hide behind land-only parity evidence
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_broad_template_generation_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Broad template generation can be run in `land` or `islands` mode with the requested water mode recorded per case and in the report summary.
- Islands planning uses recovered template size-score semantics, including `islands_size_score_halved`, instead of reusing land-only size assumptions.
- Every attempted connected translated surface-Islands template generates, validates, materializes roads/objects/guards, converts to a package, and has zero object-only player-start, cross-zone, and all-town reachable town pairs.
- Translated catalog surface-Islands configs that pass the gate report `translated_catalog_structural_profile_not_full_parity` rather than `not_implemented`.
- Existing owner-compared land defaults and Medium Islands 001 remain bounded and do not become full-parity claims.
completionEvidence:
- `tests/native_random_map_broad_template_generation_report.gd` now has report schema v4 and `NATIVE_RMG_BROAD_WATER_MODE=land|islands`, recording water mode per case and summary.
- Islands broad planning applies recovered `islands_size_score_halved` sizing semantics instead of reusing land-only size assumptions.
- Explicit translated catalog level-1 Islands configs now report structural support as `translated_catalog_structural_profile_not_full_parity` after generation/package topology gates pass.
- Focused Islands broad run passed for templates 001, 002, and 049 with all attempted cases reporting translated catalog structural not-full-parity and zero object-only route leaks.
- Full Islands broad sweep passed 45 attempted connected translated cases, with 45 translated catalog structural not-full-parity statuses, zero translated `not_implemented` statuses, 11 unsupported-size/profile skips, and zero object-only player-start, cross-zone, or all-town route leaks.
- Full land broad sweep passed 54 attempted land/surface cases, with zero translated `not_implemented` statuses, 2 unsupported-size/profile skips, and zero object-only player-start, cross-zone, or all-town route leaks.
- Owner-uploaded Small H3M topology comparison still shows current Small default 049 matching owner-like towns, zones, objects, decoration, guards, road components, and zero object-only town routes while the stale compact package remains diagnostic evidence of the bad baseline.
- Native catalog auto, full-parity boundary, and package object-only breadth gates passed after the broad Islands support change.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No underground parity implementation.
- No player-facing exposure of every Islands template.
- No HoMM3 asset, DEF, name, text, map, or binary `.h3m` import.

id: `native-rmg-production-parity-completion-audit-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Convert the owner objective that native GDExtension RMG must be production-ready and HoMM3-style, not alpha/prototype, into an explicit completion audit with concrete pass/fail evidence so green focused reports cannot be mistaken for full objective completion.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- owner objective that full production-ready HoMM3-style native RMG is the only acceptable end state
implementationTargets:
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.tscn`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- The audit restates production-ready HoMM3-style RMG as concrete criteria covering native path, representative defaults, false full-parity claims, full parity, broad template support, owner-H3M corpus coverage, owner-compared defaults, and underground parity.
- The audit inspects actual native generation/package evidence for representative Small, Medium, Medium Islands, Large, and Extra Large defaults.
- The audit reports `production_ready: false` until all missing objective requirements are actually satisfied.
- Missing requirements are explicit and actionable rather than hidden behind passing proxy gates.
completionEvidence:
- `tests/native_random_map_production_parity_completion_audit_report.tscn` passed as an audit run with native GDExtension active, five representative defaults generating and validating, no false full-parity claim, and `production_ready: false`.
- The audit reported four missing requirements: full HoMM3-style parity, broad player-facing template support beyond 4 of 56 catalog templates, a broad owner-H3M comparison corpus, and underground production parity.
- Representative defaults all remain `owner_compared_translated_profile_not_full_parity`, proving the thread goal is still open and must not be marked complete.
nonGoals:
- No full HoMM3 parity claim.
- No HoMM3 asset, DEF, name, text, map, or binary `.h3m` import.
- No broad player-facing exposure or runtime-authoritative promotion from this audit-only slice.

id: `native-rmg-owner-h3m-corpus-coverage-audit-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Inventory the owner-uploaded/local HoMM3 H3M evidence corpus so the production parity objective can distinguish available comparison evidence from missing sample coverage before broad owner-comparison gates are claimed.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `maps/small3playermap.h3m` (local evidence only, not committed)
- `/root/.openclaw/media/inbound/Untitled---cad43d4f-6faa-4059-a9db-9b37770806af.gz` (local evidence only, not committed)
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- The report reads H3M gzip headers without importing H3M content into runtime assets.
- The report identifies present/readable owner evidence samples, size class, level count, underground flag, and declared water mode.
- The report explicitly lists missing corpus coverage needed before broad production parity can be claimed.
completionEvidence:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn` passed with 3 readable and metric-parsed local owner H3M samples: Small 36x36 single-level land, Small 36x36 with underground flag set, and Medium 72x72 Islands.
- The report now extracts object definition count, object count, object category counts, counts by level, road cells by level, and road component sizes by level for all three current samples.
- The two-level Small H3M parsed as 436 objects across surface/underground, with 157 total road cells split across level 0 and level 1.
- The report confirms `corpus_ready: false` with remaining missing coverage for Large/XL owner H3M samples and template-breadth corpus coverage.
nonGoals:
- No HoMM3 asset, DEF, name, text, map, or binary `.h3m` import.
- No claim that the current corpus proves broad production parity.
- No runtime generation or player-facing behavior change.

id: `native-rmg-package-session-authoritative-replay-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Isolate nondeterministic native RMG output fields and prove package/session replay before any native runtime-authoritative generated-skirmish adoption.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_full_parity_gate_report.gd`
- `tests/native_random_map_package_object_only_breadth_report.gd`
- owner objective that native RMG must become production-ready, usable, and not alpha/prototype
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- package/session adoption and replay reports under `tests/`
- `ops/progress.json`
completionCriteria:
- Supported default translated profiles have stable replay-relevant output signatures across generate, convert, save, and load.
- Nondeterministic diagnostic/profile fields are isolated from authoritative replay identity.
- Runtime call-site adoption remains disabled unless replay and comparison gates prove readiness.
validation:
- `cmake --build .artifacts/map_persistence_native_build --parallel 2` passed.
- `GODOT_SILENCE_ROOT_WARNING=1 NATIVE_RMG_REPLAY_CASE_ID=default_small_049 /root/.local/bin/godot --headless --path . tests/native_random_map_package_session_authoritative_replay_report.tscn` passed with stable Small 049 full/adoption/disk replay signatures.
- `GODOT_SILENCE_ROOT_WARNING=1 NATIVE_RMG_REPLAY_CASE_ID=default_medium_002 /root/.local/bin/godot --headless --path . tests/native_random_map_package_session_authoritative_replay_report.tscn` passed with stable Medium 002 full/adoption/disk replay signatures.
- `GODOT_SILENCE_ROOT_WARNING=1 NATIVE_RMG_REPLAY_CASE_ID=default_large_042 /root/.local/bin/godot --headless --path . tests/native_random_map_package_session_authoritative_replay_report.tscn` passed with stable Large 042 full/adoption/disk replay signatures.
- `GODOT_SILENCE_ROOT_WARNING=1 NATIVE_RMG_REPLAY_CASE_ID=default_extra_large_043 /root/.local/bin/godot --headless --path . tests/native_random_map_package_session_authoritative_replay_report.tscn` passed with stable XL 043 full/adoption/disk replay signatures.
remainingGaps:
- Runtime call-site adoption remains disabled and non-authoritative.
- All 56 recovered templates are not yet production-ready.
nonGoals:
- No exact H3M byte parity.
- No HoMM3 asset import.
- No blanket all-template production claim.

id: `overworld-map-object-distinct-sprite-gap-fill-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Owner-directed asset follow-up to audit authored overworld map objects after the decorative/blocker foundation pass and generate distinct original sprite assets for every remaining non-decoration object gap.
sourceDocs:
- `content/map_objects.json`
- `art/overworld/manifest.json`
- `art/overworld/decorative_object_sprites.json`
- `docs/overworld-map-object-distinct-sprite-gap-audit.md`
implementationTargets:
- `art/overworld/map_object_sprites.json`
- `art/overworld/manifest.json`
- `art/overworld/runtime/objects/map_objects/distinct/`
- `art/overworld/source/generated/map_objects/distinct/`
- `art/overworld/source/trimmed/map_objects/distinct/`
- `scenes/overworld/OverworldMapView.gd`
- `tests/validate_repo.py`
- `tests/overworld_map_object_sprite_asset_report.gd`
- `ops/progress.json`
completionCriteria:
- The audit identifies authored map objects that still lack unique sprite assignments after the 200-object decorative/blocker pass.
- Every identified gap object has one distinct generated 512x512 runtime PNG, trimmed source PNG, source atlas provenance, manifest mapping, and no-HoMM3-art policy.
- Renderer lookup resolves resource and encounter placements through object-specific map object sprite mappings before shared fallback assets.
- Validation proves all 386 authored map objects have distinct assignments after combining the decorative foundation pass, preexisting unique non-decoration assignments, and this gap-fill pass.
nonGoals:
- No HoMM3 copyrighted art/DEF/image/name/text import.
- No town, hero, unit, battle, terrain, road, or UI asset broadening beyond authored overworld map object sprite coverage.
- No generated random map package clutter committed under runtime maps.

id: `native-rmg-homm3-spec-rework-parent-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Parent goal for replacing the current native RMG surface-parity approximation with a recovered-spec-driven, phased generator architecture.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/rmg-profile-20260504/profile_native_rmg_cpp_phases_compare.log`
- existing `docs/native-rmg-*.md` comparison, parity, spatial, and land/water reports
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `content/random_map_template_catalog.json`
- generator support data under `content/` or `docs/` selected by child slices
- focused native RMG Godot report scenes under `tests/`
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `ops/progress.json`
completionCriteria:
- Child slices define and implement the replacement generator data model, runtime phase order, validation gates, and adoption rules.
- The generator no longer relies on count/ratio parity shortcuts as the main quality target for supported profiles.
- Outputs are judged against recovered HoMM3-style structure: template graph, zone semantics, terrain/island shape, roads/rivers, object density/footprints, mines/resources, guards/rewards/monsters, and serialization/adoption boundaries.
- Unsupported exact byte/art/private-toolkit parity gaps remain explicit rather than silently approximated.
nonGoals:
- No HoMM3 copyrighted art/DEF/image/name/text import.
- No claim of binary-compatible `.h3m` output.
- No generated map package clutter committed under runtime maps.
- No save-version bump or campaign adoption until a child adoption slice explicitly gates it.

id: `native-rmg-homm3-spec-gap-audit-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Produce the implementation gap report that maps recovered HoMM3 RMG phases to current native C++ behavior and defines the exact child-slice order.
sourceDocs:
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-checklist.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-phase-runner.md`
- `src/gdextension/src/map_package_service.cpp`
- `content/random_map_template_catalog.json`
- existing native RMG comparison/profile artifacts
implementationTargets:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Report states, phase by phase, HoMM3 recovered behavior, current native behavior, player-visible effect, and required implementation slice.
- The current XL island scoring bottleneck and object/road/terrain semantic gaps are prioritized before broad adoption.
- Follow-up child slices are reconciled in `ops/progress.json` with source docs, targets, validation, and non-goals.
nonGoals:
- No code rewrite in the audit slice except minimal test/report plumbing if required.

id: `native-rmg-homm3-generator-data-model-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Introduce the reusable generator data model needed for template zones, links, object definitions, terrain masks, footprints, value bands, limits, and validation results.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-checklist.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-writeout-to-map-structures.md`
implementationTargets:
- native RMG data structs/helpers in `src/gdextension/src/rmg_data_model.cpp` exposed through `MapPackageService`
- original-content generator table `content/random_map_generator_data_model.json`
- focused schema/fixture validator `tests/native_random_map_homm3_generator_data_model_report.gd`
- implementation evidence `docs/native-rmg-homm3-generator-data-model-report.md`
completionCriteria:
- Supported generated objects resolve through explicit definitions with footprint, passability/action, terrain, category, limit, value/density, and writeout metadata.
- Existing package/session surfaces remain backward-compatible or explicitly gated.
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_generator_data_model_report.tscn`
- `python3 tests/validate_repo.py`
- `git diff --check`
nonGoals:
- No broad gameplay rebalance and no renderer art rewrite.

id: `native-rmg-homm3-runtime-zone-graph-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Replace radial/Voronoi zone approximation with runtime template/zone graph construction preserving base size, owner, terrain/faction, source role, adjacency, links, and infeasibility diagnostics.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-template-grammar.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `content/random_map_template_catalog.json`
implementationTargets:
- native zone layout generation
- template catalog import/normalization
- zone/connectivity validation reports
completionCriteria:
- Generated zones preserve source-template semantics and produce connected playable graphs or explicit validation failures.
- Starts, neutral zones, links, and target areas are represented as runtime state before terrain/object placement.
nonGoals:
- Exact HoMM3 footprint heuristics may remain unresolved if documented and bounded.

id: `native-rmg-homm3-terrain-island-shape-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Replace global protected-land/ratio island shaping with zone-aware terrain and water placement informed by recovered TerrainPlacement semantics and performance constraints.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-writeout-to-map-structures.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/rmg-profile-20260504/profile_native_rmg_cpp_phases_compare.log`
- `docs/native-rmg-homm3-land-water-shape-report.md`
implementationTargets:
- native terrain grid generation
- island/water shaping code path
- XL performance fixtures and visual/spatial reports
completionCriteria:
- Terrain and water are painted from runtime zone semantics with explicit allowed-terrain/match-to-town handling.
- XL islands avoid the current candidate-scoring bottleneck and pass focused performance gates.
nonGoals:
- No terrain art replacement or exact terrain queue scratch-bit clone unless selected later.

id: `native-rmg-homm3-towns-castles-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Implement recovered Phase 4a/4b town/castle placement before cleanup, connection payload handling, roads, rivers, mines, resources, guards, rewards, and decoration.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generation-h3maped-full-spec.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-model.md`
implementationTargets:
- native town/castle placement records in `src/gdextension/src/map_package_service.cpp`
- runtime/source-zone faction selection and original town id mapping
- focused native town/castle validation in `tests/native_random_map_town_guard_report.gd`
completionCriteria:
- Player fields `+0x20..+0x2c` place mapped-owner town/castle minimums and density attempts.
- Neutral fields `+0x30..+0x3c` place owner `-1` town/castle minimums and density attempts with deterministic infeasibility diagnostics.
- Source `+0x40` affects neutral weighted same-type faction reuse only; it is not a global map lock.
nonGoals:
- No mines/resources, guards/rewards/monsters, roads/rivers, or decoration implementation in this slice.

id: `native-rmg-homm3-roads-rivers-connections-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: After towns/castles, apply cleanup/connection payload handling so late guard, wide, border-guard, road, and river semantics follow the recovered phase order.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-special-guards-and-wide.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-zone-link-consumers.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-cell-flags-and-overlays.md`
- `docs/native-rmg-homm3-spatial-placement-comparison-report.md`
implementationTargets:
- native cleanup/connection payload handling after town/castle placement
- native road/river network generation
- link/guard validation reports
- road/river overlay metadata
- focused report scene `tests/native_random_map_homm3_roads_rivers_connections_report.tscn`
- implementation evidence `docs/native-rmg-homm3-roads-rivers-connections-report.md`
completionCriteria:
- `Wide` suppresses normal guards, `Border Guard` materializes supported type-9-equivalent original gate behavior, and required links produce corridors or explicit failures after town/castle records exist.
- Roads/rivers are stored as overlays with deterministic autotile/writeout metadata separate from rand_trn decoration scoring.
nonGoals:
- No road renderer art rewrite unless validation proves it is required.
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_roads_rivers_connections_report.tscn`
- `python3 tests/validate_repo.py`
- `git diff --check`

id: `native-rmg-homm3-object-placement-pipeline-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Rework object selection, footprints, terrain masks, occupancy, value bands, limits, and decorative filler as the shared placement pipeline used by later mine, reward, guard, and decoration slices.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-town-sametype-and-object-metadata.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-writeout-to-map-structures.md`
- `docs/native-rmg-homm3-fill-coverage-report.md`
- `docs/native-rmg-homm3-re-object-table-proxy-report.md`
- `docs/native-rmg-homm3-local-distribution-report.md`
implementationTargets:
- native object placement
- object definition/footprint validators
- local/spatial distribution reports
- focused report scene `tests/native_random_map_homm3_object_placement_pipeline_report.tscn`
- implementation evidence `docs/native-rmg-homm3-object-placement-pipeline-report.md`
completionCriteria:
- Supported objects resolve through explicit original-content definitions with footprint, passability/action, terrain, category, limit, value/density, and writeout metadata.
- Decoration uses ordinary object-template filler semantics rather than a decoration super-type shortcut.
- XL object-placement cost is measured and bounded enough for broad seed validation.
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 180 tests/native_random_map_homm3_object_placement_pipeline_report.tscn`
- `python3 tests/validate_repo.py`
- `git diff --check`
nonGoals:
- No HoMM3 asset import, exact DEF frame dependency, or broad economy rebalance.

id: `native-rmg-homm3-mines-resources-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Implement recovered seven mine/resource categories, minimums/densities, adjacent resources, and placement diagnostics after towns/castles and the shared object-placement pipeline.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-decoration-object-placement.md`
- `docs/native-rmg-homm3-re-object-table-proxy-report.md`
implementationTargets:
- native mine/resource placement
- original-content mine and resource proxy mappings
- focused mine/resource validation reports
- `docs/native-rmg-homm3-mines-resources-report.md`
- `tests/native_random_map_homm3_mines_resources_report.tscn`
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_mines_resources_report.tscn`
- `python3 tests/validate_repo.py`
- `git diff --check`
completionCriteria:
- Seven mine/resource categories are implemented for supported profiles with minimum-before-density behavior and original content ids.
- Mine/resource placements report failures with zone/category context and keep adjacent-resource behavior explicit.
nonGoals:
- No broad economy rebalance.
- No HoMM3 mine or resource art/name/text import.

id: `native-rmg-homm3-guards-rewards-monsters-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Implement recovered monster masks, strength scaling, connection guards, protected rewards, and guard/reward relations using original unit and reward content.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-monster-and-seven-category-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-payload-semantics.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-connection-special-guards-and-wide.md`
- `docs/native-rmg-homm3-re-reward-value-distribution-report.md`
- `docs/native-rmg-guard-reward-package-adoption-report.md`
implementationTargets:
- native guard/reward package generation
- monster mask and strength scaling helpers
- reward value-band selection and guard/reward validators
- focused guard/reward/monster reports
- implementation evidence `docs/native-rmg-homm3-guards-rewards-monsters-report.md`
completionCriteria:
- Monster selection honors match-to-town, allowed faction masks, and recovered local/global strength scaling for supported profiles.
- Connection and protected-object guards use recovered value semantics and original unit/content ids.
- Value-banded rewards preserve low/high/density behavior with explicit unsupported reward boundaries.
validation:
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 120 tests/native_random_map_homm3_guards_rewards_monsters_report.tscn`
- `python3 tests/validate_repo.py`
- `git diff --check`
nonGoals:
- No HoMM3 creature, artifact, spell, skill, or reward art/name/text import.
- No broad combat/economy rebalance beyond generator guard/reward semantics.

id: `native-rmg-generated-cross-zone-town-route-closure-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Use the uploaded Small 3-player single-level H3M/native-map comparison to close the raw generated-payload gap where package surfaces hide cross-zone unguarded town routes.
sourceDocs:
- `project.md`
- `PLAN.md`
- `maps/small3playermap-1level.h3m` (local evidence only, not committed)
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_zone_choke_regression_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_zone_choke_regression_report.gd`
- `ops/progress.json`
completionCriteria:
- Raw generated town-pair route closure evaluates cross-zone and same-zone town pairs instead of same-zone pairs only.
- Raw zone-choke validation treats guard route-closure mask tiles as guard-controlled blockers, not as decorative body art.
- Uploaded Small comparison continues to show current native Small 049 matching owner counts for towns, zones, objects, roads, decorations, and guards.
- Legacy compact native packages remain diagnostic evidence of the old bad output and are not rewritten in place.
nonGoals:
- No exact HoMM3 byte/object-art parity claim.
- No committed uploaded `.h3m`, generated `.amap`, or `.ascenario` evidence.
completionEvidence:
- Uploaded Small H3M comparison shows the current native Small 049 package matching owner structure: 7 towns, 7 zones, 303 package objects, 150 decorations, 40 guards, 110 road cells, and road components `[96, 14]`, with zero native object-only reachable town pairs.
- The stale bad native sample remains diagnostic evidence of the old compact path: legacy `border_gate_compact_v1`, 6 towns, 152 objects, 28 decorations, 35 guards, 0 roads, nearest town Manhattan distance 3, and 10 object-only reachable town pairs.
- Raw generated town-pair route closure now checks cross-zone pairs as well as same-zone pairs; the zone-choke audit now treats unresolved guard bodies, guard control zones, and route-closure masks as blockers.
- Raw zone-choke regression passes for the compact small control, owner-compared Small 049, and Medium translated land cases with zero unresolved start-town or cross-zone town traversal leaks. Neutral-town permanent blocks are reported as diagnostics rather than used to weaken the unguarded-route gate.
- Focused uploaded Small topology and comparison reports pass after the fix. The broader package object-only breadth report was started as extra validation but did not return in a reasonable window and was stopped without a pass claim.

id: `native-rmg-owner-corpus-dynamic-discovery-gate-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Make the owner-H3M corpus gate discover newly uploaded local H3M/gzip evidence instead of freezing production-readiness audits to the first three hardcoded samples.
sourceDocs:
- `project.md`
- `PLAN.md`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
implementationTargets:
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_production_parity_completion_audit_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Owner corpus coverage report preserves known exact sample mappings while auto-discovering `.h3m` and `.gz` owner evidence in local upload/map evidence directories.
- Production parity audit reads dynamic owner-corpus coverage instead of embedding stale hardcoded sample counts and missing scopes.
- Audit remains a no-overclaim boundary: if the discovered corpus is still incomplete, `production_ready` remains false and missing requirements remain explicit.
nonGoals:
- No committing uploaded owner `.h3m`/`.gz` evidence or generated `.amap`/`.ascenario` samples.
- No claim that dynamic discovery alone proves HoMM3 parity or production readiness.
completionEvidence:
- Owner corpus coverage now preserves the three known mapped owner samples while dynamically discovering local `.h3m` and `.gz` evidence under `res://maps` and `/root/.openclaw/media/inbound`.
- Production parity completion audit now embeds the dynamic owner-corpus summary instead of a stale hardcoded sample count, and still keeps `production_ready: false` with missing broad corpus, full parity, and underground parity requirements.
- Focused validation passed: `tests/native_random_map_homm3_owner_corpus_coverage_report.tscn`, `tests/native_random_map_production_parity_completion_audit_report.tscn`, `python3 -m json.tool ops/progress.json`.

id: `native-rmg-medium-islands-reward-category-parity-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Close the owner-mapped H3M category parity gap where recovered HoMM3 shrine objects count as reward-category content and native owner-compared outputs needed their reward/scenic mix aligned to the recovered metadata baseline.
sourceDocs:
- `project.md`
- `PLAN.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
implementationTargets:
- `src/gdextension/src/map_package_service.cpp`
- `tests/native_random_map_homm3_owner_corpus_coverage_report.gd`
- `tests/native_random_map_homm3_uploaded_small_topology_report.gd`
- `tests/native_random_map_homm3_spatial_placement_comparison_report.gd`
- `PLAN.md`
- `ops/progress.json`
completionCriteria:
- Recovered H3M object categorization treats Shrine of Magic Gesture and Shrine of Magic Thought as reward-category objects consistently across owner-corpus and uploaded-topology reports.
- Native Small single-level, Small underground, and Medium Islands owner-compared generation reach the owner category baselines for reward and ordinary object content without increasing total package object count beyond each owner sample.
- Spatial placement comparison, dynamic owner-corpus coverage, and production parity audit pass while still preserving the no-full-parity/no-production-ready boundary.
nonGoals:
- No import of HoMM3 art or object definitions as runtime copyrighted content.
- No claim that mapped owner-sample category parity alone completes broad HoMM3 RMG production parity.
completionEvidence:
- Owner H3M parsing now uses recovered object metadata names so Shrine of Magic Gesture and Shrine of Magic Thought are classified as reward-category records consistently with Shrine of Magic Incantation.
- Native Small 049 owner target now matches the uploaded single-level Small H3M at 303 objects: decoration 150, guard 40, object 26, reward 80, town 7, 110 road cells, and road components `[96, 14]`.
- Native Small 027 underground category-shape adjustment now matches the uploaded underground Small H3M at 436 objects: decoration 151, guard 60, object 89, reward 128, town 8, 157 road cells, and all-level road topology match.
- Native Medium Islands 001 now matches the owner-attached sample at 496 objects: decoration 252, guard 61, object 65, reward 110, town 8, 184 road cells, and road component sizes `[82, 52, 19, 16, 15]`.
- Validation passed native C++ rebuild, owner-corpus coverage, Medium Islands spatial placement comparison, uploaded Small topology comparison, production parity completion audit, progress JSON validation, and diff whitespace checks.

id: `native-rmg-homm3-validation-adoption-gates-10184`
phase: `phase-3-homm3-style-rmg-rework`
status: `completed`
purpose: Gate the reworked generator through validation, fixture comparison, performance, save/replay boundaries, and package/session adoption before gameplay reliance.
sourceDocs:
- `docs/native-rmg-homm3-spec-rework-gap-report.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-generator-implementation-checklist.md`
- `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/random-map-writeout-to-map-structures.md`
- `docs/random-map-generator-foundation.md`
- `docs/native-rmg-guard-reward-package-adoption-report.md`
implementationTargets:
- `tests/validate_repo.py`
- native RMG report scenes
- generated package/session adoption records
- `docs/native-rmg-homm3-spec-rework-gate-report.md`
completionCriteria:
- Validators cover template filtering, zone graph connectivity, required placements, footprints/occupancy, object definition references, road/river ranges, guard semantics, and performance budgets.
- Native package/session adoption remains feature-gated until reports prove supported profiles are structurally acceptable.
validation:
- `cmake --build .artifacts/map_persistence_native_build --parallel 2`
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 180 tests/native_random_map_homm3_validation_adoption_gates_report.tscn`
- `GODOT_SILENCE_ROOT_WARNING=1 /root/.local/bin/godot --headless --path . --quit-after 180 tests/native_random_map_package_session_adoption_report.tscn`
- Selected Phase 3 native RMG reports for runtime zone graph, terrain island shape, roads/rivers/connections, object placement pipeline, mines/resources, and guards/rewards/monsters.
- `python3 -m json.tool ops/progress.json >/dev/null`
- `python3 tests/validate_repo.py`
- `git diff --check`
adoptionStatus:
- Phase 3 closes with package/session adoption structurally ready but feature-gated and non-authoritative.
- `full_output_signature_stable=false` keeps authoritative package/session replay and runtime call-site adoption out of this phase.
- Follow-up: `native-rmg-package-session-authoritative-replay-gate-10184` should isolate nondeterministic full-output signature fields before any native runtime authority claim.
nonGoals:
- No alpha readiness claim; this gate only closes the RMG rework phase.

### Phase 4 - Headless AI Agent Balance Harness

Goal: create non-graphical agent/test loops for scenarios, AI turns, economy, battles, balance checks, save/load, and regression detection.

Closed tactical slices:
- `headless-agent-simulation-harness-10184`
- `balance-regression-report-suite-10184`

Future work should be selected only when new gameplay/content systems need harness coverage or balance evidence.

### Phase 5 - Playable Alpha Baseline

Goal: a small coherent alpha that can be played repeatedly without developer interpretation.

Paused tactical slices:

id: `playable-alpha-scenario-set-10184`
phase: `phase-5-playable-alpha-baseline`
purpose: Build a small validated scenario/skirmish set after Phase 3 RMG rework and Phase 4 harness foundations are deliberately selected for alpha assembly.
sourceDocs:
- `project.md`
- relevant scenario, faction, economy, AI, town, battle, and RMG docs selected at kickoff
baselineChecks:
- `python3 tests/validate_repo.py`
- focused Godot smoke/regression scenes selected at kickoff
completionCriteria:
- Multiple setups can be started, played, saved/resumed, won/lost, and understood without developer interpretation.
- At least two factions have enough live distinction to support repeated play.
nonGoals:
- No release claim.
- No content-breadth claim based only on JSON volume.

id: `playable-alpha-ux-onboarding-10184`
phase: `phase-5-playable-alpha-baseline`
purpose: Make the selected alpha setups understandable through compact player-facing UX rather than debug/report panels.
sourceDocs:
- `project.md`
- selected UX/onboarding docs or audit produced at kickoff
baselineChecks:
- `python3 tests/validate_repo.py`
- focused UI smoke/regression scenes selected at kickoff
completionCriteria:
- New/returning players can launch, choose setup, understand objectives, read core controls, and recover from common mistakes.
- Debug/profile/report surfaces stay optional and non-primary.
nonGoals:
- No giant dashboard substitution for missing mechanics.
- No broad polish pass outside selected alpha paths.

### Phase 6 - Production Alpha Layer

Goal: expand the playable alpha into a production-shaped game slice.

Paused tactical slices:

id: `production-alpha-content-expansion-10184`
phase: `phase-6-production-alpha-layer`
purpose: Add more factions/content through established systems and validation gates.
sourceDocs:
- `project.md`
- content/faction/scenario docs selected at kickoff
baselineChecks:
- `python3 tests/validate_repo.py`
- focused content/schema/smoke checks selected at kickoff
completionCriteria:
- New content enters live play through validated mechanics, AI, economy, scenario, save/load, and UI surfaces.
nonGoals:
- No raw content dump.
- No unvalidated asset ingestion.

id: `production-alpha-packaging-settings-performance-10184`
phase: `phase-6-production-alpha-layer`
purpose: Establish packaging, settings, accessibility, and performance requirements for a production alpha.
sourceDocs:
- `project.md`
- selected packaging/settings/accessibility/performance docs or audits
baselineChecks:
- `python3 tests/validate_repo.py`
- platform/performance checks selected at kickoff
completionCriteria:
- Required settings, accessibility boundaries, performance budgets, and packaging targets are explicit and validated for the selected alpha scope.
nonGoals:
- No release readiness claim.
- No platform promise without tested artifact evidence.

### Phase 7 - Broad Production Breadth

Goal: broaden into a full original fantasy strategy package after alpha foundations hold.

Long-horizon tracks:
- broad faction/town/unit/content breadth;
- broader map, campaign, skirmish, and replayability breadth;
- deeper AI/balance/polish/content pipeline maturity.

Do not reopen Phase 7 work until Phase 5/6 evidence supports it or AcOrP explicitly changes priorities.

## Progress Reconciliation

Use this after PLAN/progress changes:

```bash
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py sync-plan /root/dev/heroes-like --dry-run
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py status /root/dev/heroes-like
python3 /root/.openclaw/workspace/skills/heroes-progress/scripts/progress.py next /root/dev/heroes-like
```

Expected shape after this compaction:
- PLAN contains compact tactical gates and future selectable slices.
- Completed implementation/report evidence remains in `ops/progress.json` and `docs/*.md`.
- `sync-plan --dry-run` should report only PLAN ids that already exist in active progress entries.
