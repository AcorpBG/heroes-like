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

## Ransom Exchange and Mirror Drydock continuation

Original built-in imagegen outputs are preserved as production-named RGBA masters:

- Ransom Exchange: `exec-4b0a32d3-f8dd-47d5-8ff9-32f285d153a8.png`, SHA256
  `95e4fe8730c7c9ae10493a83c6330b92ba2bfdcb8cc2c98052c89e31c2657a1d`.
  References: original village and accepted Salvage Ledger master.
- Mirror Drydock: `exec-309d708a-dea5-47bd-a621-626a64b99cab.png`, SHA256
  `61def7c852073bd01f16aca34660e3cb19233632e53075265559c77438443313`.
  References: original village, original exact Drydock catalog icon (identity
  only), and accepted Salvage Ledger master (material/alpha treatment only).

The adjacent exact prompts and manifest hashes preserve provenance. Sources:
worldbuilding foundation Tone / Veil Coast / Visual Identity and faction bible
Veilmourn Town Feel / Visual Language / Town Building Identity. No external game
art was used. Three Exchange candidates, including one extraction attempt, were
rejected for opaque RGB checkerboard pixels; only the fourth fresh generation
provided real alpha. Prompts and rejected originals remain in the goal-owned
`town_exchange_candidates_20260907/` packet, never in runtime manifests.

The exchange extends the right waterfront below the lodge with covered counters
and a quay ramp. The long mirror-lined working slip follows the foreground-right
quay. Its first framing clipped the bottom edge at 2048x1079 and was rejected.
Final pre-trim bounds: `[1080,515,310,206.6666666667]` and
`[1210,570,350,233.3333333333]`. The sparse view at 1280x720 and actual developed-16
built-id views at 1280x720 and 2048x1079 have been inspected. These detached views
do not prove construction; normal paid-build/input/save/package acceptance is
recorded separately in the art-repair report. Rubric: readability 4, faction
identity 4, scene consistency 4, feasibility 4, originality 5.

The existing alpha-margin/Lanczos/512px/mipmap pipeline is unchanged. Village,
catalog icons and prior five scene-layer rasters stay byte-identical. No costs,
prerequisites, built ids, effects or saves change. Rollback is the coherent two
asset/prompt/source/trim/runtime/import additions plus pipeline/manifest/test
edits; no migration is needed. Normal construction/input/save tests pass 2824
checks at each of 1280x720, 1920x1080 and 2048x1079. Linux and Windows/Wine exports
pass the existing generated Town flow extended to five real daily purchases;
both PCKs are 247312024 bytes. The art-repair report records evidence and limits.
Remaining buildings, upgrades and factions are not accepted by this packet.

## Salt trade and pilot guild continuation

Three original built-in imagegen RGBA outputs are retained unchanged, alongside
their verbatim prompts. Generation date: 2026-09-07; model/version not exposed.

- Salt Counting House: `exec-0c18599c-2e6f-46e7-9978-cf7c41a462a2.png`, SHA256
  `5245eb438fb32cee3d432e09a511602239b2382eabd036ad9aa95ed055b4e19f`.
- Mourner Pilot Guild: `exec-916be8ae-0308-4d19-ad88-c873a735b108.png`, SHA256
  `6b056be68c19e4ad943a63ee9ed49697d6f53c8d31db5439f8a0dd3e9dae6888`.
- Saltwake Factor: `exec-1ef162a1-f0bf-470e-ab8e-272eeae65fec.png`, SHA256
  `08f638373513e882b5d9676c98c652368fb1c91977377d7e97c46406af80b879`.

All three use only the original village panorama (camera, light and waterfront)
and accepted Salvage Ledger master (materials and real alpha) as image inputs.
Brief sources: worldbuilding foundation Veil Coast / Visual Identity and faction
bible Veilmourn Home Region / Visual Language / Economy / Town Building Identity;
the exact authored buildings in `content/buildings.json` retain their names,
costs, prerequisites and effects. No third-party game imagery or copied pixels.
No human pixel painting, background extraction or geometric synthesis was used.

The treasury has paired roof chambers, scales and salt jars; the pilot guild has
a lookout, chart porch and masked skiff; the broad factor warehouse has covered
receiving bays and a lifting wheel. The original village and seven accepted
layers remain unchanged. First preview placement was rejected because the Guild
floated above the right waterfront and the Factor conflicted with the old
Mistgate foreground. The second Guild plot collided with the old Wake Oratory.
Accepted full-source framing is `[530,515,245,163.3333333333]`,
`[1300,500,270,180]` and `[640,585,280,186.6666666667]`, respectively.
The salt buildings extend the left working quay; the Guild joins the right
waterfront behind the later Drydock while leaving its lookout exposed.

Sparse 1280x720 and actual developed-16 2048x1079 detached-view previews were
inspected in `town_salt_candidates_20260907/` under the goal artifact directory.
These view fixtures are not evidence of normal paid construction. Curation:
accept these three source candidates; readability 4, faction identity 4,
scene consistency 4, feasibility 4, originality 5. The source/trimmed/runtime
pipeline still crops only fully transparent margins and downsamples to 512px
with original alpha, aspect and mipmaps. The manifest locks every path, prompt,
hash, trim, normalized bound and depth anchor. Runtime sizes: 512x343, 512x346
and 512x335. Separate catalog/info icons remain unchanged.

Normal six-day purchase, input/save and developed-view checks pass 4476 assertions
at each of three inspected resolutions (1280x720, 1920x1080, 2048x1079), preserving
the exact original saves and purchase records. Fifty-seven focused Python tests,
existing Town layout/progression and Linux/Windows 19-step/eight-day packaged
construction checks pass. Both PCKs are 248145628 bytes; Windows uses headless
Wine, not physical hardware. The old Ledger facade test point correctly belongs
to the foreground treasury; the probe now proves both that overlap and the
exposed Ledger roof rather than changing runtime input priority. Source-backed
failures and accepted screenshots are recorded in the art-repair report.
Rollback comprises these three source/prompt/trim/runtime/import additions and
their pipeline/manifest/test changes, without gameplay or save migration.
Ten layers are not complete Bellwake, upgrade or all-faction acceptance.
