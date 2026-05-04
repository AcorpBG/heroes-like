# RMG HoMM3 Parity Warning Review

Date: 2026-05-04

## Source Basis

This review uses only the local reverse-engineered HoMM3 RMG reference under
`/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/`, especially:

- `random-map-generator-implementation-model.md`
- `random-map-template-grammar.md`
- `random-map-zone-link-consumers.md`
- `random-map-cell-flags-and-overlays.md`

The relevant source model is graph-first and layered: template zones and links
are selected, towns/mines/resources/guards are placed, and road/river overlays
are written as a later layer over generated cells and object records.

## Reviewed Artifacts

Baseline after `43ab952`:

- Standard visual report: passed, 9 fairness warnings, 0 fail-threshold warnings,
  max contest/travel spread 13, max town-resource spread 19, road tiles 3153.
- Richness report: passed, 9 fairness warnings, 0 fail-threshold warnings,
  max town-resource spread 8, road tiles 1787.
- Large visual diagnostic: passed, 2 fairness warnings, 0 fail-threshold warnings,
  max contest/travel spread 17, town-resource spread 1, road tiles 2108.

Current slice result:

- Standard visual report: passed, 8 fairness warnings, 0 fail-threshold warnings,
  max contest/travel spread 13, max town-resource spread 7, road tiles 3069,
  rendered SVG previews 6.
- Richness report: passed, 10 fairness warnings, 0 fail-threshold warnings,
  max contest/travel spread 13, max town-resource spread 8, road tiles 1792.
- Large visual diagnostic: passed, 2 fairness warnings, 0 fail-threshold warnings,
  max contest/travel spread 17, town-resource spread 1, road tiles 2108,
  rendered SVG previews 1.

## Finding

The compact standard visual town-resource spread was a real generator placement
issue, not just acceptable template asymmetry. Start support resources used the
generic nearest-free helper, which can relax the preferred zone once the local
search radius grows. The resource record still names the start zone, so fairness
can measure a long same-zone support road even when a stricter same-zone support
candidate exists.

The implemented fix keeps the existing generic placement when it already lands
inside the owning start zone. Only if that generic result drifts out of-zone does
the generator search strict same-zone candidates and choose one by passable path
length back to the town. This reduced the standard visual max town-resource
spread from 19 to 7 without weakening diagnostics.

## Remaining Warning Classification

The remaining compact guard-pressure spread of 500 is accepted as
template/link-payload asymmetry for now. The reference model preserves `Wide`
and `Border Guard` link payloads as later connection consumers; current
diagnostics show expected guarded, wide-suppressed, and special-gate roads are
materialized with zero fail-threshold warnings.

The translated-template contest/travel spreads of 13 in standard/richness and
17 in the large diagnostic are not accepted as solved. They remain warning-level
manual review targets because translated HoMM3 template graphs intentionally
carry asymmetric route topology, but the current renderer evidence is still a
review artifact rather than a live-client visual judgement.

The richness report warning count increased from 9 to 10 while preserving
fail-threshold warnings at 0. That is not hidden; it remains a follow-up watch
item. The improvement is strongest on the standard compact rendered cases where
the observed town-resource spread fell from 19 to 7.

## Rendered Review Gate

`tests/random_map_homm3_parity_visual_inspection_report.gd` now emits SVG
previews and a `rendered_gallery.html` beside the existing JSON, text, and matrix
artifacts. These are generated review artifacts only; they are not imported into
runtime/source assets and do not change the generated PNG ingestion guardrail.
