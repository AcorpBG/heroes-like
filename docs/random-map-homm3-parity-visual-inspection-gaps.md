# Random Map HoMM3 Parity Visual Inspection Gaps

Task: #10184  
Status: active evidence note for `random-map-homm3-parity-visual-inspection-evidence-10184`

## Reference Basis

Use only the local reverse-engineered reference under `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/`.

Relevant preserved requirements:
- `random-map-generator-implementation-model.md` requires visual smoke inspection of terrain, road, river, and object overlays for disconnected corridors and impossible objects.
- The same model preserves separate terrain, road, river, and object layers as first implementation requirements.
- `random-map-template-grammar.md`, `random-map-zone-link-consumers.md`, and `random-map-decoration-object-placement.md` remain the source basis for template/zone/link/object semantics.

## Current Evidence Surface

`tests/random_map_homm3_parity_visual_inspection_report.tscn` generates deterministic multi-map inspection artifacts under:

`res://.artifacts/rmg_parity_visual_inspection/`

The report writes:
- `summary.json`: metrics, diagnostic gaps, strict gate status, and per-case JSON payloads.
- `matrix.md`: a compact human-readable table plus ASCII previews.
- `<case>.json` and `<case>.txt`: per-case inspection details and ASCII map previews.

The ASCII previews are evidence, not final visual parity. They expose layer composition for quick inspection without importing generated images or writing generated maps into `maps/`.

Large translated-template inspection is intentionally separate from the cheap gate:

`tests/random_map_homm3_parity_large_visual_inspection_report.tscn`

It uses the same ASCII/JSON inspection implementation in `large` mode and writes:

`res://.artifacts/rmg_parity_large_visual_inspection/`

Latest focused cheap-gate run, 2026-05-04 after the start-front fairness correction:
- Visual inspection report passed in 56650 ms.
- Case coverage: 6 total, 5 strict positive cases, 1 diagnostic probe.
- Template coverage: `border_gate_compact_v1`, `translated_rmg_template_001_v1`, `translated_rmg_template_002_v1`, and `translated_rmg_template_033_v1`.
- Size coverage: 36x36 and 72x72.
- Distribution summary: 3889 road tiles, 10 river candidates, 1800 decorative body tiles, 286/286 guarded valuable objects, 0 poor zones, 6 distinct signatures.
- Marker distribution summary: minimum row marker coverage 0.944, minimum column marker coverage 0.972, minimum quadrant marker coverage 4/4, minimum marker count 406.
- Runtime summary: 5/5 strict cases passed the strict per-case budget; the `translated_rmg_template_002_v1` diagnostic probe ran in 19418 ms, under its explicit 24000 ms diagnostic cap, with 184.933 ms per route and a recorded note that it exceeds the strict 18000 ms fixture budget.
- Layout-quality summary: the visual matrix exposes source-backed fairness warning counts and route/resource/guard spread metrics. Current cheap coverage has 11 total fairness warnings, 5 fail-threshold warnings, max contest-route spread 38/38, max contest-guard pressure spread 500, max route-guard pressure spread 500, and max town-to-resource spread 38. Before this correction, the same evidence surface exposed 18 total fairness warnings, 8 fail-threshold warnings, max contest-route spread 40/66, max contest-guard pressure spread 18000, max route-guard pressure spread 500, and max town-to-resource spread 38.
- Start-front fairness correction: translated template connections now keep all source guard payload and required route materialization, but only one deterministic primary front per active player start is tagged as the comparable `contest_route`/`early_reward_route` fairness contract. This is grounded in the reverse-engineered reference: connection rows are topology plus guard payloads, while `Value`, `Wide`, and `Border Guard` are later connection guard semantics rather than an instruction to charge every duplicate or inactive-slot link to a start's comparable contest-front pressure.
- Inspection artifacts: `.artifacts/rmg_parity_visual_inspection/summary.json`, `.artifacts/rmg_parity_visual_inspection/matrix.md`, and per-case `.json`/`.txt` files.
- Concrete correction from this slice: road routing now tries alternate passable visit/approach endpoints only when the primary endpoint path fails, which fixed the translated-template 001 land start/route viability failure without shortening already-valid routes.
- Concrete correction from the follow-up slice: route path search now attempts direct axis-aligned passable paths before falling back to bidirectional BFS, reducing route-heavy translated probe cost without changing the generator's object, road, river, guard, or reward contracts.
- Report correction from the follow-up slice: diagnostic probes now have explicit capped diagnostic runtime budgets, strict-budget overruns are retained as diagnostic notes, and the matrix reports row/column/quadrant marker coverage plus per-route timing instead of treating long grass terrain runs as blank-map failures.
- Report correction from the large-layout-quality slice: visual/richness metrics now preserve the existing `resource_encounter_fairness_report` status, fail-threshold warning counts, contest-route distance spreads, contest-guard pressure spreads, route-guard pressure spreads, and town-to-resource spread in logs, JSON summaries, and matrix columns.

Latest large-template diagnostic run, 2026-05-04 after the start-front fairness correction:
- Large visual inspection report passed in 41429 ms with one bounded diagnostic case.
- Covered `translated_rmg_template_042_v1` / `translated_rmg_profile_042_v1` at 108x108 land, 25 zones, 46 template links, 94 road segments.
- Source basis: the imported catalog preserves the reverse-engineered HoMM3 template grammar fields from `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/`; template 042 corresponds to a connected large topology with size score range 9..32, 25 zones, 46 links, cyclomatic 22, and 2 wide links.
- Quality metrics: 2376 road tiles, 2 coherent river candidates, 104 river/road crossings, 1608 decorative body tiles, 613 multi-tile decorations, 120/120 guarded valuable objects, 0 unguarded valuable objects, 0 poor zones, per-zone richness minimum 6, 44/44 connection guard road controls, 2/2 wide-suppressed roads, and validation failure count 0.
- Marker metrics: preview 54x54, 801 visual markers, row coverage 1.000, column coverage 1.000, quadrant coverage 4/4, and one source-backed layout fairness observation.
- Layout-quality metrics: fairness status remains warning, with 3 total fairness warnings and 1 fail-threshold warning. The matrix now exposes contest-route distance spread 18/18, contest-guard pressure spread 0, and town-to-resource route spread 42. Before this correction, the same large case had 4 total fairness warnings, 4 fail-threshold warnings, contest-route spread 39/56, contest-guard pressure spread 3000, and town-to-resource spread 42.
- Runtime metrics: generation/inspection case time 41183 ms, report time 41429 ms, 438.117 ms per route segment. This exceeds the strict 18000 ms cheap-gate fixture budget but stays under the explicit 90000 ms large diagnostic budget.
- Outcome: the start-front correction resolves the largest guard-pressure parity gap for this case. The next highest-value large-template correction is now same-zone town-to-resource route placement or road/resource endpoint balancing, because town-to-resource spread remains 42.

## Remaining Gaps

- Automated visual inspection is still ASCII/JSON layer inspection. It does not replace rendered screenshot comparison or manual play-surface inspection.
- Diagnostic large/translated templates remain evidence-only until they are promoted to strict fixtures with explicit source-backed runtime and quality thresholds.
- Several translated visual cases now expose source-backed layout fairness fail-threshold warnings despite passing route, guard, river, decor, and richness counters. Correcting contest-route distance spread, contest-guard pressure spread, and town-to-resource spread is the next qualitative RMG parity slice before strict promotion claims.
- `translated_rmg_template_002_v1` now generates without the prior route validation failure and without a visual-report diagnostic gap, but remains a diagnostic case because it exceeds the strict 18000 ms fixture budget and uses a denser 105-route translated graph than the strict medium fixture set.
- `translated_rmg_template_042_v1` now has separate bounded 108x108 diagnostic visual evidence, but it remains excluded from the cheap gate because the latest case takes about 41 seconds and has 4 source-backed fairness fail-threshold warnings.
- `translated_rmg_template_043_v1` and 144x144/underground large-profile combinations remain excluded pending their own bounded runtime/quality slice.
- Native RMG parity is still limited to the tracked native comparison profiles; live generated skirmish RMG remains GDScript-authoritative.
- No final terrain art, object sprite, or generated PNG asset ingestion is implied by this evidence.
