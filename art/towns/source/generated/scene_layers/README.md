# Approved Town scene layers

Owner approval: 2026-09-07 full-match presentation continuation. Parent/slice:
`quality-generated-full-match-20260906` /
`ux-generated-full-match-presentation-20260906`.

## Embercourt supply/magic packet (2026-09-08; validated checkpoint)

Five original built-in text-only generations extend the earned Riverwatch
Day-5 scene. Exact prompts and unchanged RGBA masters are in
`faction_embercourt/`; each manifest row records `reference_inputs: []`, its
source/trim/runtime hashes and generation date. The model/version was not exposed.

| Building | Built-in output | Source SHA256 |
| --- | --- | --- |
| River Granary Exchange | `exec-534a0f2e-1079-4230-864e-0f20a5c0eca4.png` | `e017aa529e8b362b4fab272990569a06262670208adddee0d504c1930a80c797` |
| Quartermaster Depot | `exec-b5082753-3dfb-4da2-ac3e-53456aa37596.png` | `44b3994b3cdee69d1540f4cfa51e881574b33442d2258952c2c85ca32c3746cb` |
| Lantern Archive | `exec-b655b21c-a2eb-4f1c-98b7-ca467823c4a2.png` | `4e3f3a2c4281add1f8435e594b8346616f077aa34608aa42ff5b2ec34100fbe5` |
| Starseer Annex | `exec-b512b304-ec17-4beb-b9f2-af451e108020.png` | `a276bcce673d063d35ad5505633a9325d021ac49a6f0344775ce23afcaeb01b0` |
| Citadel Pikehall | `exec-1e6ff2fe-3171-4384-a7f3-522d7ae928c3.png` | `6e0f60dacccf22ff583401c8dc152adf3087c645f40b85c34b6870b867c08306` |

An initial Archive (`exec-85e6721e-d1b4-41fc-aa14-c21d3b16ece0.png`) used a
1312x1199 composition inconsistent with the landscape Annex site. An edit of
the actual Annex (`exec-c5ce4e77-ef52-43b0-a64b-5393067c9cac.png`) produced RGB
with a baked checkerboard. Both and their exact prompts are retained only in
`embercourt_supply_candidates/` under the quality artifacts; neither is
registered or imported. The selected Archive is a fresh original text-only
painting informed by the inspected Annex, not a pixel-identical edit.
Both stages use identical full-master bounds and ground anchor. Derivatives
use only the established transparent-margin crop, 512px Lanczos and mipmap
pipeline. All 29 earlier paintings, villages, catalog icons and runtime/rules
remain unchanged. Three inspected source resolutions and each official
Linux/Windows release pass 16654 paid-growth and 8349 developed-input checks;
complete saves match outside only the save clock. Exact source/package,
preservation and cleanup receipts are recorded in the art-repair report.
Windows is headless Wine, not physical GPU certification. This accepts only
these five paintings; later Embercourt buildings and the wider goal remain open.

## Embercourt early-growth packet (2026-09-08; validated checkpoint)

Four original text-only built-in generations extend Riverwatch's opening.
Exact prompts accompany the unchanged RGBA masters in `faction_embercourt/`;
`reference_inputs: []` is explicit and the model/version was not exposed.
The inspected original village and Muster/Bowyer compositions informed the text
briefs; no external game pixels or API fallback were used.

| Building | Built-in output | Source SHA256 |
| --- | --- | --- |
| Stone Store | `exec-4e28b04a-2f49-4638-9123-8960505330b1.png` | `b2d9736d1fe36502c5eb549bd87f6c0bf6491b0365d9c9eff1802f2708a190f5` |
| Watch Barracks | `exec-f7fb76fd-e2f8-41dd-870e-1c8c3c99fbc2.png` | `285de7e09f4c5c559c2505df5fb40f30041bd2775640ddf6ef8fbb56b0fd7ca3` |
| Bowyer Lodge | `exec-6bb4f54e-4ac0-4d9d-9be5-4ab39e1420f9.png` | `5218717d3845925529be66aae7d0d9da52b6945ca800d2a48d267b490619f752` |
| Beacon Range | `exec-65f72938-c170-4c8a-9c96-e8d95ef68e7a.png` | `dd681cc83638e73a2809f4ad8082d6d08ee0345c20bbfa7d391d39486ccdb0b9` |

An initial edit of the actual Muster master produced RGB with a baked checkerboard
(`exec-38a10c0b-4b4a-456f-bc85-897007e2fdb8.png`). It and its exact edit prompt
are retained only in `embercourt_growth_candidates/`; it is not imported or
registered. The accepted-for-testing replacement is a fresh original painting,
not a pixel-identical edit. Both upgrade pairs use identical full-master scenic
bounds and ground anchors; alpha trims may differ. Only transparent-margin crop,
512px aspect-preserving Lanczos derivatives and mipmap import are applied.
The original villages, earlier 25 layers and separate catalog icons remain
unchanged. Paid-growth, visual and platform acceptance belongs to the art-repair
report. Source growth/developed and all upgrade stages pass at three inspected
resolutions and in both official releases. Complete saves, prior art and package
members are preserved; later Embercourt/other-faction art remains unfinished.

## Embercourt opening packet (2026-09-08)

Three text-only built-in generations supply Riverwatch's original Muster Yard,
Wayfarers Hall and Market Square layers. Exact prompts are adjacent to the
unchanged RGBA masters under `faction_embercourt/`; all three explicitly record
`reference_inputs: []`. Model/version was not exposed. No external game art or
API fallback was used. Original output identities:

| Building | Built-in output | Source SHA256 |
| --- | --- | --- |
| Muster Yard | `exec-5e161a99-f2c8-43d0-ae8a-0a6f49a6976c.png` | `53c09e19ab13788bd7a2d53677ac1efc7772eabfdd80bc316dd960da472f8ce3` |
| Wayfarers Hall | `exec-985defb2-d710-4207-9d97-89689c511757.png` | `b0c926b8109558b555017c8229eff0d0483c038c36a9342fe08ed78116eb3d5a` |
| Market Square | `exec-c3cc0cc1-bc42-492c-86b4-851822f78fa6.png` | `0ebb2935cd503cfc188df7c9e217107de96f253004de1c239aaa77692d345974` |

The pipeline's `--faction faction_embercourt` prepares only selected paintings
and merges exact faction/building rows without resetting earlier factions or
unselected buildings. Default preparation supports both factions. Alpha-margin
crop, 512px Lanczos derivatives and mipmaps remain the only image processing.
Brown RGB shown by the raw preview in alpha-zero pixels is not a visible
backdrop in-engine. The separate RGB checkerboard extraction attempt is rejected
and retained only in `embercourt_opening_candidates_20260908/`, never shipped.

Pre-trim scenic bounds: Muster `[215,355,340,226.6666666667]` on the left-bank
practice court; lodge `[1240,490,305,203.3333333333]` on the right shore;
Market `[85,530,310,206.6666666667]` on the foreground-left working quay.
The initial Muster placement overhanging the quay wall was rejected, as was the
over-raised draft leaving a tent beneath its front edge at 1920x1080. The reviewed
placement meets the quay edge while retaining the complete practice court.
Source village, every accepted Veilmourn layer and separate catalog/info icons
are unchanged. Riverwatch's real developed fixture retains Watch Barracks as
Muster's visible upgrade and Charter Flame in front of the Market's right edge.
Later Embercourt catalog paintings are still visually unaccepted. Exact input,
ordinary 1000-gold Market, complete-save, resolution and platform evidence belongs
to `docs/generated-full-match-art-repair-report.md`; preparation alone is not
acceptance of this packet, the faction or the full-match goal.

## Initial Bellwake packet

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

## Defense and memory continuation

Five original built-in imagegen outputs (2026-09-07; model/version not exposed)
address the remaining old catalog dioramas in the retained developed-16 Bellwake
view. Their production names below own adjacent exact `.prompt.txt` files; the
manifest locks source, prompt, alpha trim, runtime hashes and normalized plots.

| Building | Original output | Source SHA256 |
| --- | --- | --- |
| Harpoon Gantry | `exec-b03d08d9-769e-4c8f-8baf-2abf7ebd1efe.png` | `c12da98f94bfc64eb26e654396e87964dd647991b3172cdc928d4f52dfa7f63b` |
| Bell-Chain Watch | `exec-b3f346c2-f2a6-496b-8db9-067dccab27e0.png` | `f1d58aab18cb5e1b40fdad3789deeeaa95cc390d75aff8ecb9a77c639dcad620` |
| Obituary Vault | `exec-905b36fb-846a-46ee-84f6-722f1683760d.png` | `deffa6c894ad6d79d157c2e27dd81805621227dd9a017877d339767cd47c0d93` |
| Wake Oratory | `exec-9313808f-26b6-4eba-b8d7-0cbb8a9726ca.png` | `296dc225d56ed1c226a14b6575e5e0e370c3e8dc5ee8ebf5ea6b07860c74cccf` |
| Mistgate Slip | `exec-9413f820-ca0f-48e7-81ea-41444dfff237.png` | `d9931a2a94030e9d5dde2f39d300e0586389c1ec99741f56f9cf9e9f981e6674` |

Brief sources: worldbuilding foundation Veil Coast / Visual Identity Guide;
faction bible Veilmourn Home Region / Visual Language / unit ladder / Town
Building Identity; exact authored buildings in `content/buildings.json`.
The first reference-image Gantry/Watch candidates and a Gantry alpha-edit attempt
were rejected: all three were RGB with painted checkerboards, not transparent
art. The accepted five are fresh text-only generations, with no input images;
their rows explicitly record `reference_inputs: []`. Existing village and Ledger
art informed the reviewed brief and comparison, but were not image inputs to
these accepted calls. No third-party game pixels, human pixel painting, background
extraction, geometric synthesis or palette modulation was used.

Gantry/Watch masters are 1254x1254 RGBA; the other three are 1536x1024 RGBA.
Original outputs and rejected candidates remain in
`town_defense_memory_candidates_20260907/` under the goal artifact directory.
The first developed placement was rejected for low Gantry/Vault bases crowding
navigation and a floating Oratory. The second inspected 2048x1079 developed-16
and 1280x720 intermediate-11 compositions lift the foreground bases and seat
the Oratory behind the Pilot Guild. Gantry and Watch form the left defensive
quay; the Vault fronts the Market; the mirror-lined Slip joins the right quay.
Curation: accept these five sources/second placements; readability 4, faction
identity 4, consistency 4, feasibility 4, originality 5. These detached view
fixtures are not paid-construction or completed-match evidence.

The existing pipeline crops only fully transparent outer margins, preserves
alpha/aspect and creates 512px-max mipmapped runtime derivatives. Previous ten
layers, village and catalog/info icons remain unchanged. Normal opening defense
purchases and earned Day-8 memory purchases, full save/input, existing Town tests
and both-platform packages pass for this checkpoint: 9003 defense / 8474 memory
checks at each of three inspected resolutions, plus 8474 exact-save checks in
each official Linux/Windows pack and five bootstrap controls per platform.
Windows is headless Wine; full results and remaining limits are in the report.
Rollback: the five new source/prompt/trim/runtime/import additions and their exact
pipeline/manifest/test records; no gameplay or save migration. Remaining faction,
upgrade and higher-tier Bellwake art is not accepted by these five layers.

## Late-harbor continuation — validated

Five original built-in imagegen outputs, generated 2026-09-08, are preserved as
RGBA masters with adjacent exact prompts. Model/version was not exposed. Source,
trimmed and runtime hashes, source-space bounds and depth anchors are locked by
the existing scene manifest and preparation pipeline.

| Building | Selected original output | Source SHA256 |
| --- | --- | --- |
| Drowned Map Room | `exec-933713c3-5142-44dc-91a1-c91705193fd6.png` | `9379e7472873d31c86fe378b7d318d5cddd9daf059e676b5f077b448d8fed0ac` |
| Memory Anchor | `exec-9c88849a-d536-49b9-8c8e-9d83dbd041e3.png` | `54f74fa81dc09706aeee43ad48cd72c4283f01b971b4ab1635fd2ff27465cb8e` |
| Leviathan Sounding | `exec-02c1d25c-9d10-4d65-a8ef-81e939e1b514.png` | `4a4bf8919b772d8d85812ce1be4146b99b3298a3e1d4c85a1b7618aef317d8e6` |
| Drowned Admiralty | `exec-8188d278-6a3c-4921-bc44-56b3e1c1cb2a.png` | `5620b5cee9a562b6bc27c0fa6fd54c818e857c73b8e2ba1324237f2264f9f91b` |
| Memory-Rite Court | `exec-53724cef-48d9-469c-b880-5b9d21794ebb.png` | `cb03c475af5513a0dc8fcef82b63197cb3ad49db06c06efa107d6b7a76acab8d` |

Brief authority: original Veilmourn village, worldbuilding Veil Coast/visual
identity, faction-bible Veilmourn Town Feel/architecture and exact authored
building identities. The Map Room's first call used the original village,
earned-Day-14 Town screenshot and exact original catalog icon as references;
its selected output is a built-in alpha extraction of that initial RGB painting
(`exec-b774272b-4cdc-414f-a4ad-b6c1bc8fdb16.png`). Both exact prompts are retained.
The other four selected calls were text-only, recorded as `reference_inputs: []`.
No third-party game images or API fallback were used.

Court image-edit/extraction attempts `exec-1da4e887-bc88-45b4-af95-69ec1f99dfaf`,
`exec-6ebb49ee-ade0-4718-9c72-b84f073ce190`,
`exec-d5fc41a4-e914-49e3-96ae-11c070099995` and
`exec-59b518fb-5079-493b-9dbc-93bf450b6242` were rejected as opaque RGB with
painted checkerboards. The selected Court is a fresh transparent painting
specified from the inspected Sounding composition, not a pixel-identical edit.
Both use the same full-master scenic bounds and ground anchor. The thin jetty,
paired acoustic horns and rightward shore approach identify the same site;
the Court adds its central ritual canopy, mirrors and salt rails.

The chart house joins the inner-left shore behind the sail workshop; the narrow
anchor stands on the counting-house quay; the Admiralty rises behind Wayfarers
Hall. Processing remains transparent-margin crop and aspect-preserving 512px
Lanczos reduction with mipmaps; no generated geometry, recoloring or palette
modulation. All seventeen earlier scene rows/paintings, village, separate catalog
icons, building rules and saves remain unchanged. The art-repair report owns
actual composition, paid construction/upgrade, input/save and platform results;
candidate preparation alone is not acceptance or completion of other factions.

Source acceptance: ordinary earned-Day-14-to-30 construction passes 51490 checks,
including same-site Court replacement and full input/save ownership. Complete
saved bytes match the old-renderer control except its one wall-clock field.
All three developed resolutions and actual paid construction/upgrade captures
were visually inspected. Existing Town reports and 88 focused Python tests pass.
The same complete replay passes 51490 checks in each official Linux and
Windows/Wine release. All four final saves match byte-for-byte except the single
save timestamp. Normal platform startup/generated-entry, repository/diff and
5180-member package checks pass; both PCKs are 243281500 bytes. Windows omits
only paired frame/capture operations and is not physical GPU certification.
The art-repair report records exact commands, hashes and limits. All 22 Bellwake
scene layers are accepted; other factions and the full presentation goal remain
unfinished. Embercourt candidates remain separate preparation, not shipped art.
