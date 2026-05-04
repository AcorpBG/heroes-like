# RMG HoMM3 Parity Warning Review

Date: 2026-05-04

## Source Basis

This review uses only the local reverse-engineered HoMM3 RMG reference under
`/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/`, especially:

- `random-map-generator-implementation-model.md`
- `random-map-template-grammar.md`
- `random-map-zone-link-consumers.md`
- `random-map-cell-flags-and-overlays.md`
- `random-map-connection-payload-semantics.md`
- `random-map-connection-special-guards-and-wide.md`

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

Post-`a749da2` baseline:

- Standard visual report: passed, 8 fairness warnings, 0 fail-threshold warnings,
  max contest/travel spread 13, max town-resource spread 7, road tiles 3069,
  rendered SVG previews 6.
- Richness report: passed, 10 fairness warnings, 0 fail-threshold warnings,
  max contest/travel spread 13, max town-resource spread 8, road tiles 1792.
- Large visual diagnostic: passed, 2 fairness warnings, 0 fail-threshold warnings,
  max contest/travel spread 17, town-resource spread 1, road tiles 2108,
  rendered SVG previews 1.

Current follow-up result:

- Standard visual report: passed, 6 raw fairness warnings, 6 accepted-asymmetry
  warnings, 0 unresolved review warnings, 0 fail-threshold warnings, max
  contest/travel spread 13, max town-resource spread 7, road tiles 3069,
  rendered SVG previews 6.
- Richness report: passed, 6 raw fairness warnings, 6 accepted-asymmetry
  warnings, 0 unresolved review warnings, 0 fail-threshold warnings, max
  contest/travel spread 13, max town-resource spread 8, road tiles 1792.
- Large visual diagnostic: passed, 2 raw fairness warnings, 2 accepted-asymmetry
  warnings, 0 unresolved review warnings, 0 fail-threshold warnings, max
  contest/travel spread 17, town-resource spread 1, road tiles 2108,
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

The post-`a749da2` early-support warning count also included a report-side
false positive. `_early_resource_support_payload` measured route spread across
every same-zone resource edge, including mines and dwellings, while its warning
text and resource minimums are specifically about the three starting support
sites. The follow-up narrows that diagnostic to support-resource placement ids
only. This reduced the standard visual raw fairness warnings from 8 to 6 and
the richness raw fairness warnings from 10 to 6 without changing thresholds,
resource placement, road generation, or fail-threshold classification.

## Remaining Warning Classification

The remaining compact guard-pressure spread of 500 is accepted as
template/link-payload asymmetry for now. The reference model preserves `Wide`
and `Border Guard` link payloads as later connection consumers; current
diagnostics show expected guarded, wide-suppressed, and special-gate roads are
materialized with zero fail-threshold warnings.

The remaining standard visual warning sources are:

- `small_translated_land_001_visual`: `no contested mine or dwelling pressure
  markers`. Accepted: template 001 is represented as an all-start-zone
  translated template in the current catalog, so guarded source links provide
  the contest surface without a separate contested mine/dwelling marker class.
- `small_translated_islands_001_visual`: same accepted template-001 marker
  warning under islands layout.
- `medium_translated_land_033_visual`: `contest route distances exceed warning
  spread` and `contest route distance spread exceeds warning threshold`.
  Accepted: route topology follows the translated source graph and remains
  below fail threshold.
- `medium_translated_land_002_probe_a`: same two accepted translated-route
  topology warnings.

The richness-only compact warnings in `small_compact_land_b` are also accepted
as HoMM3-like compact-template asymmetry: the source-backed connection payload
evidence shows `Wide` suppresses normal guards and `Border Guard` is a special
connection mode rather than a symmetric distance-balancing input. The remaining
local early-support route warning there is accepted only because cross-start
town-resource spread is still 3 and travel-distance resource fairness passes;
raw warning text remains visible in the artifact.

Future reports now preserve raw warning counts and strict fail-threshold counts,
but also emit accepted-asymmetry and unresolved-review counts. Accepted warnings
are not removed from the raw warning total. Any warning containing `fail spread`
or `fail threshold` is always classified as a fail-threshold regression, never
accepted as asymmetry.

## Rendered Review Gate

`tests/random_map_homm3_parity_visual_inspection_report.gd` now emits SVG
previews and a `rendered_gallery.html` beside the existing JSON, text, and matrix
artifacts. These are generated review artifacts only; they are not imported into
runtime/source assets and do not change the generated PNG ingestion guardrail.
