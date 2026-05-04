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

Latest focused run, 2026-05-04 after `be744e8` follow-up:
- Visual inspection report passed in 57248 ms.
- Case coverage: 6 total, 5 strict positive cases, 1 diagnostic probe.
- Template coverage: `border_gate_compact_v1`, `translated_rmg_template_001_v1`, `translated_rmg_template_002_v1`, and `translated_rmg_template_033_v1`.
- Size coverage: 36x36 and 72x72.
- Distribution summary: 3889 road tiles, 10 river candidates, 1800 decorative body tiles, 286/286 guarded valuable objects, 0 poor zones, 6 distinct signatures.
- Marker distribution summary: minimum row marker coverage 0.944, minimum column marker coverage 0.972, minimum quadrant marker coverage 4/4, minimum marker count 406.
- Runtime summary: 5/5 strict cases passed the strict per-case budget; the `translated_rmg_template_002_v1` diagnostic probe ran in 19515 ms, under its explicit 24000 ms diagnostic cap, with 185.857 ms per route and a recorded note that it exceeds the strict 18000 ms fixture budget.
- Inspection artifacts: `.artifacts/rmg_parity_visual_inspection/summary.json`, `.artifacts/rmg_parity_visual_inspection/matrix.md`, and per-case `.json`/`.txt` files.
- Concrete correction from this slice: road routing now tries alternate passable visit/approach endpoints only when the primary endpoint path fails, which fixed the translated-template 001 land start/route viability failure without shortening already-valid routes.
- Concrete correction from the follow-up slice: route path search now attempts direct axis-aligned passable paths before falling back to bidirectional BFS, reducing route-heavy translated probe cost without changing the generator's object, road, river, guard, or reward contracts.
- Report correction from the follow-up slice: diagnostic probes now have explicit capped diagnostic runtime budgets, strict-budget overruns are retained as diagnostic notes, and the matrix reports row/column/quadrant marker coverage plus per-route timing instead of treating long grass terrain runs as blank-map failures.

## Remaining Gaps

- Automated visual inspection is still ASCII/JSON layer inspection. It does not replace rendered screenshot comparison or manual play-surface inspection.
- Diagnostic large/translated templates remain evidence-only until they are promoted to strict fixtures with explicit source-backed runtime and quality thresholds.
- `translated_rmg_template_002_v1` now generates without the prior route validation failure and without a visual-report diagnostic gap, but remains a diagnostic case because it exceeds the strict 18000 ms fixture budget and uses a denser 105-route translated graph than the strict medium fixture set.
- `translated_rmg_template_042_v1` and larger translated profiles are intentionally not part of this cheap gate; prior probing showed 108x108 inspection is too slow for this report and should be handled by a separate large-template inspection/correction slice.
- Native RMG parity is still limited to the tracked native comparison profiles; live generated skirmish RMG remains GDScript-authoritative.
- No final terrain art, object sprite, or generated PNG asset ingestion is implied by this evidence.
