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

Latest focused run, 2026-05-04:
- Visual inspection report passed in 60040 ms.
- Case coverage: 6 total, 5 strict positive cases, 1 diagnostic probe.
- Template coverage: `border_gate_compact_v1`, `translated_rmg_template_001_v1`, `translated_rmg_template_002_v1`, and `translated_rmg_template_033_v1`.
- Size coverage: 36x36 and 72x72.
- Distribution summary: 3889 road tiles, 10 river candidates, 1850 decorative body tiles, 286/286 guarded valuable objects, 0 poor zones, 6 distinct signatures.
- Inspection artifacts: `.artifacts/rmg_parity_visual_inspection/summary.json`, `.artifacts/rmg_parity_visual_inspection/matrix.md`, and per-case `.json`/`.txt` files.
- Concrete correction from this slice: road routing now tries alternate passable visit/approach endpoints only when the primary endpoint path fails, which fixed the translated-template 001 land start/route viability failure without shortening already-valid routes.

## Remaining Gaps

- Automated visual inspection is still ASCII/JSON layer inspection. It does not replace rendered screenshot comparison or manual play-surface inspection.
- Diagnostic large/translated templates remain evidence-only until their failures are either fixed or explicitly accepted as non-parity with source-backed rationale.
- `translated_rmg_template_002_v1` now generates without the prior route validation failure in the diagnostic probe, but still exceeds the cheap visual report per-case runtime budget and needs targeted template-structure/performance correction before becoming a strict positive parity fixture.
- `translated_rmg_template_042_v1` and larger translated profiles are intentionally not part of this cheap gate; prior probing showed 108x108 inspection is too slow for this report and should be handled by a separate large-template inspection/correction slice.
- Native RMG parity is still limited to the tracked native comparison profiles; live generated skirmish RMG remains GDScript-authoritative.
- No final terrain art, object sprite, or generated PNG asset ingestion is implied by this evidence.
