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

Latest focused cheap-gate run, 2026-05-04 after the `41233b1` large-diagnostic follow-up:
- Visual inspection report passed in 56925 ms.
- Case coverage: 6 total, 5 strict positive cases, 1 diagnostic probe.
- Template coverage: `border_gate_compact_v1`, `translated_rmg_template_001_v1`, `translated_rmg_template_002_v1`, and `translated_rmg_template_033_v1`.
- Size coverage: 36x36 and 72x72.
- Distribution summary: 3889 road tiles, 10 river candidates, 1800 decorative body tiles, 286/286 guarded valuable objects, 0 poor zones, 6 distinct signatures.
- Marker distribution summary: minimum row marker coverage 0.944, minimum column marker coverage 0.972, minimum quadrant marker coverage 4/4, minimum marker count 406.
- Runtime summary: 5/5 strict cases passed the strict per-case budget; the `translated_rmg_template_002_v1` diagnostic probe ran in 19552 ms, under its explicit 24000 ms diagnostic cap, with 186.210 ms per route and a recorded note that it exceeds the strict 18000 ms fixture budget.
- Inspection artifacts: `.artifacts/rmg_parity_visual_inspection/summary.json`, `.artifacts/rmg_parity_visual_inspection/matrix.md`, and per-case `.json`/`.txt` files.
- Concrete correction from this slice: road routing now tries alternate passable visit/approach endpoints only when the primary endpoint path fails, which fixed the translated-template 001 land start/route viability failure without shortening already-valid routes.
- Concrete correction from the follow-up slice: route path search now attempts direct axis-aligned passable paths before falling back to bidirectional BFS, reducing route-heavy translated probe cost without changing the generator's object, road, river, guard, or reward contracts.
- Report correction from the follow-up slice: diagnostic probes now have explicit capped diagnostic runtime budgets, strict-budget overruns are retained as diagnostic notes, and the matrix reports row/column/quadrant marker coverage plus per-route timing instead of treating long grass terrain runs as blank-map failures.

Latest large-template diagnostic run, 2026-05-04 after `41233b1` follow-up:
- Large visual inspection report passed in 41445 ms with one bounded diagnostic case.
- Covered `translated_rmg_template_042_v1` / `translated_rmg_profile_042_v1` at 108x108 land, 25 zones, 46 template links, 94 road segments.
- Source basis: the imported catalog preserves the reverse-engineered HoMM3 template grammar fields from `/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/`; template 042 corresponds to a connected large topology with size score range 9..32, 25 zones, 46 links, cyclomatic 22, and 2 wide links.
- Quality metrics: 2376 road tiles, 2 coherent river candidates, 104 river/road crossings, 1608 decorative body tiles, 613 multi-tile decorations, 120/120 guarded valuable objects, 0 unguarded valuable objects, 0 poor zones, per-zone richness minimum 6, 44/44 connection guard road controls, 2/2 wide-suppressed roads, and validation failure count 0.
- Marker metrics: preview 54x54, 801 visual markers, row coverage 1.000, column coverage 1.000, quadrant coverage 4/4, no inspection observations.
- Runtime metrics: generation/inspection case time 41194 ms, report time 41445 ms, 438.234 ms per route segment. This exceeds the strict 18000 ms cheap-gate fixture budget but stays under the explicit 90000 ms large diagnostic budget.
- Outcome: no pathing/runtime quality correction was required for 108x108 template 042 in this seed. The correction in this slice is the bounded large-template report mode itself: one case, separate artifact directory, separate report id, explicit total/case budgets, and diagnostic gap limit 0 so large quality regressions surface without hanging the cheap gate.

## Remaining Gaps

- Automated visual inspection is still ASCII/JSON layer inspection. It does not replace rendered screenshot comparison or manual play-surface inspection.
- Diagnostic large/translated templates remain evidence-only until they are promoted to strict fixtures with explicit source-backed runtime and quality thresholds.
- `translated_rmg_template_002_v1` now generates without the prior route validation failure and without a visual-report diagnostic gap, but remains a diagnostic case because it exceeds the strict 18000 ms fixture budget and uses a denser 105-route translated graph than the strict medium fixture set.
- `translated_rmg_template_042_v1` now has separate bounded 108x108 diagnostic visual evidence, but it remains excluded from the cheap gate because the latest case takes about 41 seconds.
- `translated_rmg_template_043_v1` and 144x144/underground large-profile combinations remain excluded pending their own bounded runtime/quality slice.
- Native RMG parity is still limited to the tracked native comparison profiles; live generated skirmish RMG remains GDScript-authoritative.
- No final terrain art, object sprite, or generated PNG asset ingestion is implied by this evidence.
