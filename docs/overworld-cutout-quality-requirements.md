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

## Completion and non-goals

Each cohort completes only after its actual repaired art is integrated and its
validation passes. The parent completes only after the authoritative runtime
pool review is accounted for and all confirmed selected defects are corrected;
one cohort or an automated screening report cannot close it. Update PLAN/tracker,
record concise evidence and remaining ids, then commit/push coherent validated
work. No native/RMG rule changes, gameplay/balance/save migration, Town redesign,
unrelated cleanup, cache deletion or release-readiness claim. Preserve the four
pre-existing unrelated untracked retention files/directories.
