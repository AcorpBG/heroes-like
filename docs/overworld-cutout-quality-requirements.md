# Overworld cutout quality recovery

Owner direction: 2026-09-09, repair remaining pink-fringed overworld art and
generate original replacement assets where the existing art cannot look good.
Phase 6 parent: `art-overworld-cutout-quality-20260909`. This is new work after
the bounded full-match quality goal, not a claim that its four earlier cutout
repairs covered all assets.

## Scope and diagnosis

Inventory all authoritative `art/overworld/manifest.json` object assets and their
map-object, decorative, resource, artifact, encounter, town and hero mappings.
Include runtime variants and native/generated adoption paths. Record unresolved
identities explicitly. Color statistics only select review candidates: legitimate
purple flowers, crystals, cloth and magic must not be removed to pass a threshold.
Do not broaden this goal into repainting unrelated clean terrain or Town screens.

The first confirmed cohort is original map-object atlas batch 04. Direct inspection
of Frostwood Cutting Yard, Aetherglass Lens House and Memory Salt Pan shows
magenta edges, retained sheet divider rectangles and missing opaque subject
pixels. The original generated sheet retains those details. Current `.ctex`
imports cannot repair damage already baked into the runtime PNG.

### Initial execution checkpoint (2026-09-09)

All 1,214 manifest-backed raster regions decode. A read-only screen of visible
boundary pixels (`alpha >= 32`, `min(R,B)-G > 50`, `R,B > 140`) finds 191 review
candidates, 174 with `built_in_image_gen_chroma_key_split` provenance. These are
not 191 confirmed defects or an acceptance result; authored purple details need
individual review.

The built-in original-repair attempt and targeted transparency retry for
Frostwood both returned 1254x1254 RGB images with painted checkerboards, not
RGBA cutouts. Neither is installed. Rejected output SHA-256 values:
`03aec8291e4adca517c04025de388d908de25e16078b871dd41f1dbe606fec4d` and
`38e10e7998a207e75feef099758b9a63eb73244f101359095fbe1f16ae1cc8d7`.
Original tool outputs remain under the session's Codex generated-images folder;
they are rejected attempts, not project assets or package inputs. The selected
slice awaits explicit permission for deterministic source-sheet extraction or
the image skill's transparency-capable CLI/API fallback (requires
`OPENAI_API_KEY`). No runtime correction, gameplay validation, export, commit or
push is claimed at this checkpoint.

Owner approval subsequently received on 2026-09-09: use deterministic image
processing to recover the original paintings. This clears the method blocker.
Recover from the intact original sheet, not only the already-damaged alpha;
remove inspected gutters and matte while preserving foreground color/detail.
No external image API/model switch was requested or used.

## Implementation contract

- Preserve exact runtime asset/content ids, manifest mapping keys, object
  positions, footprints, masks, anchors, pathing, interactions, controller/state
  variants, saves and deterministic generation. Never hide a legitimate object.
- Recover the original painting and its fine detail where possible using the
  explicitly approved deterministic original-sheet recovery. Use the built-in
  image workflow for genuinely necessary new original paintings, preserving
  valid generated alpha. No generic shared
  replacements, geometric stand-ins, copied commercial art or indiscriminate
  magenta/white deletion. Normal packaging may trim/resize/place the resulting
  raster on its established canvas without distorting the subject.
- Retain original sheets, exact before rasters and hashes, edit/generation prompt
  and output provenance, and source/trim/runtime derivatives. Replacements must
  match the overworld's camera, materials and lighting, with an appropriate
  grounded silhouette and no sheet lines, matte halos or unwanted detached pixels.
- The first batch covers the 15 still-damaged batch-04 identities; preserve the
  already-repaired Cinder Ore Face as an unchanged control. The original 16 ids
  are obtained by exact `source_generated_atlas` membership, not filename guesses.
- Add authoritative scoped acceptance metadata and tests that fail on missing
  files, stale hashes, swapped identities or reintroduced confirmed edge defects.
  Do not turn candidate color counts into a claim of whole-pool visual acceptance.

## Batch cadence and validation

Do useful art/integration work in coherent cohorts. During assembly inspect
rasters and run lightweight provenance/alpha/geometry checks. At the completed
cohort boundary run one combined strict regression, actual renderer/identity,
save-preservation and Linux/Windows export/gameplay acceptance cycle. Do not
re-export or rerun full gameplay after each individual image.

Reuse existing distinct/decorative sprite, fog/input and exact generated-save
probes, extending Python-owned orchestration without weakening their assertions.
For mixed legacy families, `--batch legacy_families` covers 35 reviewed rows
with full-atlas-before-region import checks and explicitly labeled detached
renderer galleries. Faction-fallback heroes and legacy tree art must not be
injected into a world or substituted for current identity/cohesive art to
manufacture gameplay evidence. Report actual selected-asset occurrence counts;
when absent, the unchanged earned native map is a regression control, not a
corrected-object gameplay capture. The Crownmere controlled/unclaimed switch
must still resolve its exact separate manifest states.
Retain before and after in-context screenshots at 1280x720 and 1920x1080 or
2048x1079. Show corrected native/generated and authored resolution paths with
original placement and complete save comparisons. Clearly label detached visual
fixtures; they are not earned gameplay. Inspect the final screenshots directly.

Commands: new focused Python cutout-preparation/manifest tests, the scoped
rendered cutout batch probe, existing distinct/decorative and affected input/fog
reports, `python3 tests/validate_repo.py`, `git diff --check`, and the established
`tests/packaging_linux_export_smoke.py` /
`tests/packaging_windows_export_smoke.py` startup/generated-map flows.
Packages must contain the repaired textures with matching Linux/Windows content;
there is no fixed package-size ceiling. Windows/Wine is not GPU certification.
Legacy-family preparation uses `tools/prepare_overworld_legacy_cutouts.py
--output <fresh-preview-dir> [--install]`; focused tests use `python3 -B -m
unittest discover -s tests -p 'test_overworld_legacy_cutouts.py'`. Existing
source and packaged cutout drivers accept `--batch legacy_families` with the
same resolution/platform/isolated-release arguments as earlier cohorts.

For enclosed resource-state backing, use `tools/prepare_overworld_passage_cutouts.py
--output <fresh-preview-dir> [--install]` and the existing source/package drivers
with `--batch passages`. Explicit inspected source-component seeds, bounds and
areas restrict removal; white snow, canvas, wind and highlights are not a global
color-removal class. Preserve original crop/resize/offset and every runtime pixel
outside the projected repair support, plus all 16 neighboring atlas regions.
`test_overworld_passage_cutouts.py` covers these invariants. Prove Root Pass Arch
through seven ordinary moves from the unmodified Seedseer Drowned Orchard start;
do not grant position, collection, movement or fog. The unchanged earned native
map remains a separate regression control when none of its current states uses
these seven repaired variants. Historical source manifests retain original
assembly hashes and point to the exact repaired derivative proof.

For palette-damaged recurring encounters, use
`tools/prepare_overworld_recurring_cutouts.py --output <fresh> [--install]`
and both cutout drivers with `--batch recurring_encounters`. Recover the first
24 cells from their immutable original RGBA paintings: original crop, 44-pixel
aspect-preserving fit, bottom alignment for the first six and centered later
cells. No alpha threshold or color key may replace original source coverage.
Actual gameplay inspection rejected a 48-pixel recovery as still too blurry.
Supply the 24 recovered paintings in a separate 192-pixel-per-cell raster atlas,
using exactly four times the original crop-fit/offset coordinates. The renderer's
unchanged world-space draw rectangles, not texture pixel dimensions, own their
on-map size. Preserve the complete original 1488x48 atlas for the seven clean
wave-four alpha controls in this 24-row cohort; do not resample those neighbors
or modify their metadata in this cohort. Their separate resolution-quality
follow-up remains parent work and is not counted as visual acceptance.
Keep every encounter id, map coordinate, footprint, anchor and gameplay rule.
Focused `test_overworld_recurring_cutouts.py` covers source/trim/runtime
reconstruction, smooth alpha, identity and normalized geometry. Show Beacon Wardens
at its original Charter Pyre placement through ordinary scouting; keep the
24-state detached gallery and unchanged earned native map explicitly separate.
Historical atlas hashes remain source evidence, with exact before bytes and
source-reconstructed high-resolution derivative ownership checked by repository
validation. Check the new atlas explicitly in both platform packages.

The subsequent seven-row completion extends that same atlas to 5952x192 for all
31 recurring identities. Preserve the accepted first 24 source/trim pixels and
normalized registrations, as well as the complete original historical atlas.
The seven later sources use explicitly measured alpha-support crop bounds,
42-pixel logical aspect fit and bottom alignment, not the earlier 44-pixel fit.
The support threshold selects crop bounds only: do not threshold or remove
painted pixels within those bounds. Retain the exact prior 24-cell atlas and
per-row hashes as preservation controls. Validate all 31 routes and show an
actual later-wave authored encounter without injecting placement or fog.

For the thirty recurring resource-site originals, retain every site/state mapping
and distinguish base, unclaimed and separately authored claimed art. Recover
source detail into 192-pixel cells on the existing atlas path (5760x192), keeping
its original 1440x48 bytes in the source recovery packet. Preserve documented
44-pixel logical fit: the first five use south anchoring and bilinear resampling;
the later 25 use a two-pixel south inset and Lanczos, proven by reproducing every
old alpha/nontransparent painted pixel. Record exact source crop and resampling
per identity; invisible RGB beneath zero alpha is not visible paint. No blanket removal of
purple crystal or mushroom pigments. Reuse scoped source/package probes with
`--batch recurring_sites`; include all thirty detached identities and exact
actual state-selected sites from the unchanged earned native/authored maps.
Keep separately authored state art unchanged rather than routing around it to
manufacture screenshots. Original source manifests retain historical hashes and
point to the repaired derivative proof. Whole-cohort acceptance only.

For the subsequent 31 separately authored claimed-dwelling paintings, preserve
all three atlas owners and every claimed/unclaimed state mapping. Original
RGBA edits remain immutable: where binary keying erased white foreground,
recover retained source RGB with explicitly inspected backing components, not
blanket white removal. Snow, salt-pan interiors, cloth and pale masonry are
paint. Clear actual enclosed checkerboard backing without erasing these details.
Retain genuine-alpha sources unchanged. Derive 192-pixel cells directly from
the recovered sources with measured original crop/fit/anchor registration;
retain original atlases and record exact source/trim/runtime provenance.
Validate whole-cohort identity, state transitions and save/placement preservation,
including original earned claimed sites where present; do not manufacture claims
or substitute their clean unclaimed images. Reuse dual-resolution/source/package
drivers, existing claim/reward/save cases and both official platform exports.

For the 34 early post-interaction state paintings (major vaults, creature banks,
guarded routes, weekly services, progression shrines and scouting structures),
preserve all six atlas paths and every separate ready/used state mapping. Keep
the measured original 42/44-pixel centered and 46-pixel south-aligned transforms
when projecting original sources into 192-pixel cells. Remove only explicitly
reviewed backing components. Neutral-matte decontamination is limited to their
two-source-pixel boundary (twelve for Ashbarb's inspected diffuse ground edge),
using original foreground/background samples and rejecting inconsistent fits.
All genuine-alpha sources and paint outside that band stay exact. Retain the
historical atlases and reconstructible source/trim/runtime provenance.
Validate with `tools/prepare_overworld_state_cutouts.py`,
`tests/test_overworld_state_cutouts.py`, and source/package drivers using
`--batch early_states`. Earned native records that the unchanged presence rule
considers consumed are not visible-object evidence; never resurrect them for
screenshots. Capture actual remaining state-selected objects and preserve full
saves, compiled owners, masks, coordinates and world-space draw rectangles.

The 40 landmark/state originals span the faction-landmark, road/objective,
fourteen-mark, eightfold-reliquary and border-standard atlases. Preserve 39
genuine RGBA masters exactly; preserve Witness Stone's pale eye/candle paint
while rebuilding its keyed boundary from retained RGB, removing only inspected exterior backing with its two-pixel
original-sample boundary repair. Project all originals through their measured
44-pixel logical fit and centered/south anchors into 192-pixel cells. Preserve
the five paths and all state mappings. The renderer's existing faction-landmark
precedence keeps Granary Lock, Blackwater Shrine and Prism Yard on their live
state art even when unclaimed; do not change that behavior for a test fixture.
Use `tools/prepare_overworld_landmark_cutouts.py`,
`tests/test_overworld_landmark_cutouts.py` and both source/package drivers with
`--batch landmark_states`. Inspect actual earned native cases and four labeled
detached galleries; retain full-save, compiled-owner and original-place controls.

### Integrated Pactwright/Mireglass state follow-up

Replace the seven retained coarse state stamps, not their gameplay states. Use
one approved original generated foreground edit per identity: six wax marks on
the Waydesk ledger and six object-specific attached counterseals. Retain generated
masters/prompts and the frozen predecessor recipe/proof/two atlases. Never ship
the generated opaque checkerboards. Composite only reviewed local foreground
regions into the original RGBA masters; preserve every pixel outside those
regions, all original logical fits, and the seven unmarked neighboring cells.
Keep the other 47 route/arcane paintings exact. The two small attached clasp
extensions are explicit raster-compositing masks, not new procedural paint.

Use the route/arcane preparation tool, its 11 Python tests and the existing
source/package `--batch route_arcane` probe. Capture all seven actual authored
sites after legal scouting, with no synthetic claims or fog grants. The last
two approaches include their ordinary original artifact pickup to reach the
three-step Manhattan vision boundary. Check both resolutions, the exact previous
package, full saves and both current platform packages. Existing frontier-shrine
resolver precedence is out of scope; its state art is selected before collection
too. Do not silently change that rule to obtain a different screenshot.

### Marchland command-site detail recovery

The 34 Marchland warband, grand-route and commander-dominion sources have
genuine RGBA and no confirmed keyed backing. Preserve their original pixels,
including purple cloth, crystals, smoke and magic. Restore fine painted detail
lost by the shipped 48px raster using the original 42px centered logical fit
and Lanczos projection into 192px cells. Keep the three same-path atlas owners,
all site/state routes and gameplay geometry; retain historical atlases and
generation manifests separately from the current reconstruction proof.

Use `tools/prepare_overworld_command_cutouts.py --output <fresh> [--install]`,
`tests/test_overworld_command_cutouts.py` and both existing cutout drivers with
`--batch command_sites`. The earned native save contains none of these sites;
its 2380 blocker bodies are an unchanged control, not affected-object evidence.
Capture original Tollbrand, Cinderquill and Quench landmarks through legal
scouting and normal end turns, with guards, fog and complete site records
preserved. Compare full saves and draw rectangles against the failing-before
source run and both packages. Maintain all three existing domain smokes with
their exact new atlas geometry and separate historical-source/current-runtime
provenance; do not weaken gameplay, battle, claim or save assertions.

### Recruitment/habitat paired-state recovery

Recover all 36 rows in Unbound Wild Concords, veteran company musters and
Frontier Mythic Habitats. Keep the original 44px south, 42px centered and 43px
bottom-46 logical fits respectively, with 192px cells and unchanged gameplay
draw rectangles. Older two-family raster quantization differences must be
reported, not described as exact historical pixel reconstruction; Frontier's
historical base projection is exact. Source masters remain immutable.

Remove only the three individually reviewed disconnected sheet fragments in
the controlled Daybreak Prism and Five-Bough Grove. Repair clipped RGB noise
at alpha 1..4 from nearby original foreground colours, preserving intentional
purple/iridescent material. Replace Frontier's six historical procedural
pennants/rings with approved original generated physical foreground details;
reject generated backing and preserve all paint outside reviewed masks. Retain
full built-in prompts, generated originals, recovered masters, historical
atlases and reconstruction hashes. No procedural RGB replacement drawing.

Use `tools/prepare_overworld_recruitment_cutouts.py --output <fresh> [--install]`,
`tests/test_overworld_recruitment_cutouts.py` and both cutout drivers with
`--batch recruitment_sites`. Inspect every paired state, source compositing
and dual-resolution actual scouting views. The Day97 native checkpoint has
no affected site: its 2380 blockers are unchanged controls, not affected-site
evidence. Use original authored placements and ordinary movement/end turns;
no fog, position, ownership or guard grants for gameplay captures. Existing
three domain smokes separately cover guarded claims, recruitment, weekly
delivery and full saves as labelled controlled fixtures. Validate repository,
diff, Linux/Windows official exports and packaged cohort probes together.

### Veteran mast-top source-sheet completion

The two deferred controlled Foundry/Mooring masters are exact 362px grid crops
of the retained identity sheet, not independent edited paintings. Recover the
connected mast paint crossing their northern crop boundary from that same sheet.
Pin the sheet hash, exact crop equality and component seeds/areas/bounds. Retain
the original body pixels and logical scale/anchor; project the extension through
the same source-to-runtime transform, including only its necessary sampling seam.
Do not shrink or shift the building to make room, copy the neighbouring building,
or fabricate replacement finials. Explicitly measure any low-alpha cell-edge
support and visually inspect the complete opaque tips at both gameplay sizes.
Keep all 34 accepted neighbouring states byte-identical. Retain the predecessor
recipe/proof and two runtime cells, extend the focused reconstruction tests, and
run the consolidated recruitment/source/package/domain/shared acceptance cycle.
Detached state coverage and normal scouting/earned claims must remain separately
labelled; no injected ownership, position, fog or guard removal for screenshots.

### Command/training landmark recovery

The next cohort comprises forty paintings in Commander Doctrine Expeditions,
Eight Commanders Proving Roads, Field Mastery Convocations, Garrison Warrant
Musters, Twin Command Field Councils and Named Rival Banners. Inspect every
original, including clipped source-canvas edges; higher raster density alone
does not repair missing paint. Recover original paint where retained, and use
approved original raster edits for genuinely missing pieces. Preserve unchanged
body registration and exact historical source fit, atlas paths, site/state
routes and gameplay. Keep genuine alpha and intentional purple material;
never ship generated checkerboards or procedural replacement pixels.

Targets: scoped training-site preparation/provenance and source/trim/runtime
packet, focused Python reconstruction tests and the shared source/package cutout
probes. Extend their batch selector without weakening the independent image
oracle, full-save or native controls. Inspect forty state-selected textures and
small/wide actual authored scouting views; label detached galleries and any
controlled claim fixtures explicitly. Preserve the unchanged earned native map
when none of these sites occurs there. Run affected domain and shared sprite/
input/fog reports, repository/diff checks and both official exports with matching
package content. No native/RMG, gameplay, save, Town, unrelated art or cleanup.

Implementation owners: `tools/prepare_overworld_training_cutouts.py`,
`tests/test_overworld_training_cutouts.py`, `tests/overworld_training_cutout_probe.py`
and `cutout_recovery_20260909/training_sites/recipe.json`. Source/package drivers
select `--batch training_sites`; source runs cover `--resolution 1280x720` and
`--resolution 1920x1080`. Retain the original 42-pixel centered fits, the six
44-pixel Twin Council fits and the six bottom-aligned Named Rival fits.
Only alpha 1..4 saturated RGB quantization noise may borrow nearest original
foreground RGB at alpha 128 or higher; alpha, opaque material and every other source pixel stay exact.
Sixteen historical projections reconstruct exactly; twenty-four older filtered
PNGs have bounded cross-filter agreement, not falsely claimed byte equality.
All forty installed rasters must reconstruct exactly from the retained sources
and recipe regardless of those historical filter differences.

### Contract and expedition encounter landmarks

Recover all 52 original paintings in the nine same-path atlases for Dissident
Fronts, Standalone Contracts, Outer Reach Contracts, Mire-Sun Contracts,
Ascendant Companies, Waywatch Trials, Spellwright Expeditions, Ritual Relay
Circuits and Grand Convergence Marches. Read their source manifests and inspect
each original for cropped paint, matte, detached fragments and alpha/RGB damage.
Keep the documented 42/44px centered/south registrations, identity mappings and
commander/identity/faction precedence. An identity available only through a
detached resolver is not evidence that normal gameplay drew it.

Targets: `tools/prepare_overworld_contract_cutouts.py`, the original/recovered
source/trim/runtime packet under `cutout_recovery_20260909/contract_encounters`,
`tests/test_overworld_contract_cutouts.py` and a shared source/package selector
`--batch contract_encounters`. Use original-source recovery first and approved
built-in raster edits when the original cannot supply sound paint. Never turn
legitimate purple into a color key or invent replacement geometry. Validate
exact installed reconstruction, original registration and complete identity
routes. Inspect full-cohort renderer galleries and ordinary scouting of real
authored encounters at 1280x720 and 1920x1080, preserving full saves and original
native-map controls. Do not relocate records or bypass fog/commander priority.
Run affected domain and shared sprite/input/fog regressions, repository/diff
checks and official Linux/Windows export/startup/map-entry checks once the batch
is assembled. Keep new large exports/previews on `/tmp`; preserve existing
evidence/caches. No native/RMG, gameplay, save, Town, unrelated art or cleanup.

Implementation owners: `tools/prepare_overworld_contract_cutouts.py`,
`tests/test_overworld_contract_cutouts.py`, `tests/overworld_contract_cutout_probe.py`
and the cohort's `recipe.json`. Reproject original positive-alpha bounds at
fourfold density, not the old 48px copies. Only the reviewed alpha-1..4 saturated
RGB noise may borrow original alpha-128+ foreground RGB; preserve all alpha and
every other source pixel. Historical cross-filter registration is explicitly
bounded (alpha MAE <=5, opaque RGB MAE <=9), not byte equality. Current installed
pixels, original-source hashes, nine source manifests and all identity routes
must reconstruct exactly. Preserve cleared native encounters as cleared;
never revive them to obtain a screenshot. Focused test command:
`python3 -B -m unittest discover -s tests -p test_overworld_contract_cutouts.py`.

### Remaining encounter paintings and faction controls

Recover 73 atlas paintings in Systemic, Horizon Compact, Horizon Courts, Frontier
Watch, Dormant Roster, rival commanders, finale nemeses, Field Muster, Twin Hold,
Three Relic and Border Oath families, plus six signature encounters. Preserve six
clean 512px faction landmarks byte-for-byte. Freeze source/manifest hashes,
historical rasters and per-family registrations in `remaining_encounters/recipe.json`
under the existing recovery packet. Frontier Watch's nominal sources are 48px
derivatives: recover exact cells from the 1536x1024 generated sheet. Other masters
use genuine RGBA. Preserve source alpha and purple paint; only reviewed alpha-1..4
saturated RGB noise may borrow original opaque foreground RGB. No reduced-source
upscale or invented geometry.

Owners: `tools/prepare_overworld_remaining_encounter_cutouts.py`,
`tests/test_overworld_remaining_encounter_cutouts.py`,
`tests/overworld_remaining_encounter_cutout_probe.py` and shared source/package
`--batch remaining_encounters` routing. Validate exact raster reconstruction,
source registration and complete routes. Run focused Python tests, source probes
at 1280x720/1920x1080, Linux/Windows packaged probes, affected domain and shared
sprite/input/fog reports, repository/diff checks and official exports once the
cohort is assembled. Inspect full galleries and ordinary scouting views; report
commander-prioritized and cleared fronts honestly. Preserve full saves, actual
native placements, fog and unrelated payloads. This cohort advances the
836/1214 baseline to 921/1214 only after consolidated acceptance. No gameplay, RMG, save, Town, unrelated
art, source/cache deletion, or needless replacement of clean assets.

### Artifact atlas paintings and clean field controls

Review all 69 exact artifact field mappings. Recover the 36 low-resolution
paintings in Three Relic Pilgrimages (18), Marchland Retinue Heirlooms (6) and
Command Relic Marches (12) directly from retained original generated RGBA masters.
Preserve the 33 already-clean standalone 512px paintings byte-for-byte; genuine
prismatic purple material is not a matte defect. Inventory icons are separate
surfaces and must remain unchanged. Retain three historical atlases and original
source/icon/provenance hashes. Keep the documented 42px centered logical fit on
48px cells, reprojected at fourfold density; historical two-stage inventory-to-
field filtering/rounding is not claimed pixel-identical to original-source
projection. Explicit source registrations and before/after visual inspection
must distinguish that quantization from a changed world anchor or footprint.

Owners: `tools/prepare_overworld_artifact_cutouts.py`,
`tests/test_overworld_artifact_cutouts.py`, the artifact source/trim/runtime
packet and Python-owned `--batch artifacts` source/package probes. Preserve all
source alpha and opaque paint; any reviewed alpha-1..4 saturated RGB correction
may borrow only original foreground RGB. No broad color key or reduced-icon
upscale. Freeze exact artifact identity routes and all 69 dispositions; reject
missing/mismatched source, crop, atlas, icon or route rather than falling back.
Validate exact reconstruction, original-source and unchanged-control hashes,
full saves, ordinary authored pickup/guard flow and the unchanged native case.
Inspect galleries and earned gameplay at 1280x720 and 1920x1080. Run focused
Python tests, affected artifact/domain and shared sprite/input/fog reports,
repository/diff checks and both official Linux/Windows exports and packaged
cohort probes once the complete batch is assembled. Acceptance stays 921/1214
until that evidence exists. No inventory-icon redesign, gameplay/native/RMG/
save changes, Town work, unrelated art or cleanup.

### Remaining resource-site atlas originals

Recover all 54 paintings in the nine remaining six-cell resource-site atlases:
Triune Arcanum, Great Work, Grand Muster, Relief Route, Fogbreak Survey,
Frontier Treasury, Setbound Regalia, Grand Arcanum and Uncrowned Sovereign Roads.
Use retained original RGBA sources, not upscaled 48px cells. Keep the same runtime
paths and all resource identity/state mappings. Grand Arcanum and Uncrowned
sources are already-curated 512px canvases: preserve their complete registration.
The other families retain their historical 42/44px fit and centered/bottom anchor.
Setbound's old prose says centered, but its retained raster proves bottom-aligned;
preserve actual placement and document this source-metadata discrepancy.

Owners: `tools/prepare_overworld_remaining_site_cutouts.py`, its focused Python
tests, `tests/overworld_remaining_site_cutout_probe.py`, shared source/package
`--batch remaining_sites` routing and the `remaining_sites` source/trim/runtime
packet. Preserve all alpha and opaque paint. Reviewed alpha-1..4 saturated RGB
noise alone may borrow nearest original foreground RGB. Freeze original masters,
provenance, historical atlases, exact registrations and all 54 mappings. Require
fail-closed exact live raster reconstruction and before/after visual inspection;
historical filter differences are not changed world size or alignment.

Assemble the whole cohort before consolidated Python, source dual-resolution,
affected domain/shared, repository/diff and Linux/Windows export/package tests.
Prove state resolver routes, ordinary authored scouting/claiming, native placement
controls and complete save preservation; label absent-native/detached coverage
honestly. No source-color key, alpha deletion, generic state marker, gameplay,
native/RMG, Town, save-schema, unrelated art or cleanup changes. The accepted
baseline remains 990/1214 until evidence supports these next 54 dispositions.

### Hero identity cutouts

Review all 60 authoritative `hero_identity_sprites` rows against their original
generated paintings and portrait identities. Repair the confirmed neutral backing
and pale cutout rims on the three strategic-officer paintings (Nara Graftsibyl,
Orso Nightchart and Thalen); preserve the other 57 reviewed originals byte-for-byte
unless individual source inspection proves another defect. Do not confuse white
hair, pale armour, cloth, crystals or light effects with removable background.
Use explicit inspected source components and bounded edge recovery, with frozen
source hashes, component masks, original canvas registration and unchanged-pixel
controls. Keep 512px runtime paths, identity/faction fallback priority, hero pose,
portrait, world anchor/scale, recruitment, movement, save and native state intact.

Owners: `tools/prepare_overworld_hero_cutouts.py`, focused Python tests,
`tests/overworld_hero_cutout_probe.py` and `--batch heroes` source/package routing,
plus the `heroes` source/trim/runtime provenance packet. Missing/mismatched sources,
identity routes, masks or reconstructed pixels must fail validation. Assemble
repairs and unchanged controls before consolidated Python, source dual-resolution,
existing hero/enemy-commander and shared sprite/input/fog, repository/diff and
official Linux/Windows export/gameplay acceptance. Actual original native/authored
heroes and ordinary movement/recruitment provide gameplay evidence; detached
coverage must remain labeled and must not mutate a map to manufacture captures.
The accepted baseline remains 1044/1214 until all 60 dispositions have evidence.
No portrait redesign, balance, gameplay/native/RMG, Town UI or unrelated cleanup.

## Completion and non-goals

Owner-approved test-control replacement (2026-09-10): the original Day97
autosave under `.artifacts/generated_full_match_quality_20260906` was deleted
by concurrent external cleanup. Use the successful 1280 probe's complete manual
round-trip verbatim as `tests/fixtures/overworld_cutout/native_day97_roundtrip.json`
(SHA256 `d4b6cac54c25fc42456bdb7fdd3d4a9d0ed37fda8115dd63afe29d05b18bb1c1`).
Its adjacent provenance retains the old hash and evidence lineage; this is a
separately approved control, not a byte-identical restoration. Both source and
packaged drivers use the same hash-locked bytes and unchanged gameplay/save
assertions. Reject missing or altered fixtures, never choose a random substitute.
Validate with `python3 -B -m unittest discover -s tests -p
test_overworld_cutout_save_fixture.py`; both exports exclude all `tests/*`.

Each cohort completes only after its actual repaired art is integrated and its
validation passes. The parent completes only after the authoritative runtime
pool review is accounted for and all confirmed selected defects are corrected;
one cohort or an automated screening report cannot close it. Update PLAN/tracker,
record concise evidence and remaining ids, then commit/push coherent validated
work. No native/RMG rule changes, gameplay/balance/save migration, Town redesign,
unrelated cleanup, cache deletion or release-readiness claim. Preserve the four
pre-existing unrelated untracked retention files/directories.
