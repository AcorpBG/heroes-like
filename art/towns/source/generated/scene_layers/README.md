# Approved Town scene layers

Owner approval: 2026-09-07 full-match presentation continuation. Parent/slice:
`quality-generated-full-match-20260906` /
`ux-generated-full-match-presentation-20260906`.

The production-named PNGs preserve the original generated RGBA masters.
Adjacent `.prompt.txt` files preserve the exact built-in image_gen prompts;
the tool did not expose a model/version. The reviewed studies and generation
identities remain in the concept-review packet under
`.artifacts/generated_full_match_quality_20260906/town_scene_candidates_20260907/`.
No external game art was supplied to generation. References were the original
`town_veilmourn_village.png` panorama and each existing exact building catalog
icon, with the panorama authoritative for camera, materials and lighting.

Scene owner: `content/town_building_scene_art_manifest.json` records every
source/trimmed/runtime hash, alpha crop, normalized scenic bounds, depth anchor,
runtime dimensions and prompt path. `tools/prepare_town_scene_layers.py` crops
only transparent outer pixels and downsamples with Lanczos to maximum 512px,
stripping derivative timestamps/metadata for reproducibility. No geometry,
painted replacement scenery, recoloring, traced pixels or generated placeholders
are introduced by processing. Generated alpha, including fine ropes and smoke,
is retained. Source masters and trimmed intermediates are excluded from both
platform packages; only runtime derivatives, their imports and manifest ship.

Curation against the actual Large08 starting Bellwake scene: Bell Harbor's left
gangway joins the main quay, with pilings in the central harbor. Wayfarers Hall
occupies the right middle-distance shore behind the existing foreground gate.
The initial Hall placement overlapping the gate was rejected. Full-resolution
unfiltered downsampling shimmer was also rejected; runtime derivatives use
mipmaps. Catalog/info icons and the original village panorama remain unchanged.

Applicable review rubric (1–5): game-scale readability 4, faction material and
silhouette 4, building/scene consistency 4, production feasibility 4, originality
5. These are curation judgments, not automatic quality or all-faction acceptance.
This packet has no unit-tier or animation-completion claim. The two structures
are starting buildings in Bellwake, not newly added construction options.

Rollback: revert the coherent art/manifest/renderer/hotspot change together.
No save migration or gameplay/data rollback is needed. Remaining Town buildings
and other factions require their own inspected scene-matched art; this first
packet does not accept the old catalog-icon placement of those structures.

## Constructible Market Square continuation

The additional `faction_veilmourn/building_market_square.png` master is the
unaltered built-in imagegen output `exec-4df482d8-1bf8-46b6-bde9-819a72f7fcf9.png`,
SHA256 `9afc680fe3311278da44f54c069854764ef3f17d2f9020e32925a1b4b27aafe1`.
Its adjacent prompt is verbatim. The original village and the accepted original
Wayfarers Hall master were style/transparency references; no external game art
was supplied. Prompt hashes are now recorded for all scene layers.

Three earlier output candidates were rejected: each returned opaque RGB with a
painted checkerboard; the first also clipped its ramp. Neither extraction attempt
fixed transparency. A fresh render from the original references produced real
RGBA. Rejected images and prompts remain in the goal-owned
`town_market_candidates_20260907/` evidence directory, not the runtime manifest.

The accepted composition uses a low trading arcade, cargo, hanging balance scales,
small amber lamps, wet black timber and supporting pilings. It joins the
foreground-left waterfront below the main tower; the central harbor and tower
door remain clear. The original water-plot placement was rejected. Source-space
framing is `[200,560,375,250]` before transparent-margin trim; final normalized
bounds and ground-depth anchor are authoritative in the manifest. Same curation
rubric: readability 4, faction identity 4, scene consistency 4, feasibility 4,
originality 5. Live paid-build/input/save checks pass at three resolutions;
Linux and Windows/Wine packages also construct the Market and load its exact
scene asset. Source-backed evidence and platform limits are recorded in
`docs/generated-full-match-art-repair-report.md` (Market checkpoint).

Only alpha-margin crop, aspect-preserving 512px Lanczos downsampling and metadata
stripping produce the derivatives. No painted pixels or backgrounds are replaced
by processing. The imported 512x338 layer uses mipmaps; the unchanged generic
catalog/info icon remains available to other factions. The earlier two scenic
runtime raster hashes are unchanged. This is an existing 1000-gold Market Square,
not a new building, discount, construction shortcut or whole-faction completion.

## Fog Buoys and Salvage Ledger growth continuation

The two additional RGBA masters preserve built-in imagegen outputs unchanged:

- Fog Signal Buoys: `exec-9aee1609-05be-4431-867b-56f9140a7f34.png`, SHA256
  `3b4b49e32f73eae6d2f2d0b4c9dc72c45fbbef9f9cc32f2df14fde4498c22075`.
  References: original village and the new original Salvage Ledger master.
- Salvage Ledger: `exec-56f93d9c-847a-471b-a333-822a547347c1.png`, SHA256
  `9dbf801a2053651a467237e38fd01c082b1241aad600505b67e29b7897436467`.
  References: original village and the accepted original Market Square master.

Adjacent prompts are verbatim, hash-locked by the scene manifest. The first buoy
output (`exec-7a9abb76-0bfe-42c6-be2e-70cb01bd4db7.png`) was opaque RGB with a
painted checkerboard and was rejected. All studies/prompts and detached-view
composition reviews remain under `town_harbor_candidates_20260907/` in the goal
artifact directory. No external game art was supplied, and no source panorama,
catalog icon or earlier accepted runtime raster changed.

Curation retains small bell/lantern buoys in the foreground channel below Bell
Harbor and a compact timber claims office extending the left working quay above
the Market. Earlier buoy placements hidden by Bell Harbor, crowding the footer,
or overlapping a later developed building were rejected. The office's initial
preview aspect was corrected before adoption. Final full-source framing is
`[860,650,180,120]` for buoys and `[480,450,260,173.3333333333]` for the office.
Depth anchors and trimmed normalized bounds are authoritative in the manifest.
Both are small functional infrastructure, not new palaces or extra town rules.
Rubric: readability 4, faction identity 4, scene consistency 4, feasibility 4,
originality 5; these are curation judgments, not all-faction acceptance.

The unchanged processing pipeline crops only alpha margins and downsamples to
512px with preserved aspect/alpha and mipmaps. Paid successive-day build and exact
input/save checks pass at three inspected resolutions (2824 checks each). Both
platform packages construct and resolve all three paid layers on Days 1-3;
Windows is headless Wine. Source-backed acceptance and the related immediate
modal-close/departure focus fix are recorded in
`docs/generated-full-match-art-repair-report.md`. Remaining buildings, upgrades
and factions are unfinished; five accepted layers are not whole-Town acceptance.
