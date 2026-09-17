# Natural biome transitions and ground materials

Owner-directed Phase 6 slice: `art-overworld-biome-transitions-20260917`.
Status: completed, 2026-09-17.

## Observed problem

Normal terrain selects original generated `base_generated_v2` materials, each
256×256, sampled across eight tiles. Their preparation mirrors a 128-pixel crop
on both axes, producing obvious bilateral repeats. Generic transition rendering
still uses separate narrow edge images and polygon corner hints rather than the
neighbor's actual world-space ground material. This leaves hard, mismatched edges.
The local HoMM3 prototype path is separate and is not a source of shipped artwork.

## Required implementation

- Original painted raster ground with consistent scale and lighting across all
  currently supported terrain identities; no mirrored/kaleidoscopic production
  materials, copied pixels or procedural geometry as replacement art.
- Organic, continuous biome blending on straight boundaries, diagonal contacts,
  islands, map edges and multi-biome junctions. Preserve material detail and avoid
  broad muddy blur, square seams, abrupt corner cuts or texture swimming on pan.
- Center-of-tile readability, especially water and impassable ground; keep all
  logical terrain, native generation, movement, placement, road and save data exact.
- Retain roads, blockers, scenic props, selection, fog and ambient layers in their
  existing order. Do not reveal unexplored neighboring biomes through blending.
- World-coordinate presentation must remain deterministic across camera movement,
  resizing, zoom, levels and save/load. Cache derived lookup data and avoid rebuilding
  map-sized textures on hero movement, hover or ordinary redraws.
- Keep original generation outputs/prompts/provenance in source; package only
  required runtime rasters/materials through the existing asset pipeline.

## Validation

Inspect a deterministic generated Medium map before implementation, then the same
case after implementation at 1920×1080 and 1280×720. Also inspect a terrain fixture
covering all materials, horizontal/vertical/diagonal/corner joins and narrow shores.
Focused Python-owned Godot coverage checks actual renderer use, missing-art failure,
world sampling continuity, fog isolation, cache behavior, unchanged session/collision
authority and representative Large-map cost. Complete generation/implementation
before the consolidated source/package acceptance pass, not per-asset export loops.

Run focused terrain/render regressions, relevant existing scenery/raster checks,
`python3 tests/validate_repo.py`, `git diff --check`, and official Linux/Windows
export/package smokes with generated-map entry. Record actual package sizes, without
an arbitrary ceiling. Windows Wine is not physical GPU certification. Remove generated
test evidence/packages after results are recorded; preserve source art/provenance,
caches, saves, backups, RMG recovery material and unrelated untracked files.

## Non-goals

No native RMG/parity/topology/placement changes, gameplay/balance/save migration,
town or combat UI changes, copyrighted reference pixels, unrelated asset regeneration,
or whole-game release-readiness claim.

## Implementation

`OverworldGroundSurface.gd` and `overworld_ground_surface.gdshader` own one
world-space painted ground surface, beneath the existing road/detail/prop/fog
layers. Four-neighbor splatting blends the actual adjacent materials, including
diagonals and junctions; bounded irregularity comes from original painted stone.
Texels stay anchored while only boundary weights change. Each logical tile center
keeps its own material. Repeat edges overlap alternate painted samples without
mirroring, and the irregularity field uses that same continuous sampler.

Four new built-in image-generation outputs supply sixteen materials, with
23 explicit terrain/alias mappings in `art/overworld/ground_materials.json`.
This is a separate manifest, like the existing town-biome manifest, so the frozen
historical object-identity/art provenance tables remain byte-for-byte unchanged.
The four 1254-square originals, exact prompts and hashes are retained under
`art/overworld/source/generated/terrain/ground_materials_v3/`. Deterministic
`tools/prepare_overworld_ground_materials.py` crops their quadrants, resizes to
508-square interiors and packs a 2048-square runtime atlas with two-pixel gutters.
This replaces the old 32-source-pixels-per-tile look with about 85, without
regenerating any object, town, unit or blocker artwork.

Only a small RGBA terrain-slot/exploration lookup is uploaded on map/level or
exploration changes. Ordinary refresh, selection and animation reuse it; camera
movement/resizing updates the visible quad and world coordinates. Unknown ground
is identity-silent, and unexplored neighbors cannot contribute to blending.
Missing material mappings fail validation and emit an error, never silently
switching normal gameplay to legacy polygon/corner rendering. Static grain and
water ripple strokes are disabled for the new painted surface; existing ambient
animation, roads, ground details and object/fog ordering remain intact.

Repository checks now validate the new ground/matte/road layer order and the
deliberate legacy-only grain path. The older blocker report uses an isolated user
profile, a caller-selected capture directory and the established portable GL/
accessibility-disabled launch flags. No historical cutout recipes, identity tables,
canvas requirements, native-generation checks or report-retention rules were relaxed.

## Reproduction and inspected evidence

The Python-owned probe generates native Medium seed
`medium-random-screenshot-10230` and native Large seed
`biome-surface-large-20260917`, both using translated template/profile 042,
four players and one land level. It also draws all sixteen materials and an
explicit shoreline/diagonal/inlet/island fixture. Revealed biome-review captures
are labelled diagnostics, not claimed to be normal fogged gameplay.

```bash
python3 -B -m unittest discover -s tests -p test_overworld_ground_materials.py -v
python3 -B tools/prepare_overworld_ground_materials.py --check
python3 -B tests/overworld_biome_surface_regression.py --label review --render --resolution 1280x720 --timeout-seconds 300
HEROES_TERRAIN_CAPTURE_DIR=res://.artifacts/biome-surface-20260917/blockers python3 -B tests/overworld_raster_terrain_blocker_mass_report.py
HEROES_BATTLE_READABILITY_ARTIFACT_DIR=.artifacts/biome-surface-20260917/scenery python3 -B tests/overworld_living_scenery_regression.py --label review --render --resolution 1280x720 --timeout-seconds 360
python3 tests/validate_repo.py
git diff --check
```

Run `packaging_linux_export_smoke.py` and `packaging_windows_export_smoke.py`
sequentially with `HEROES_PACKAGING_LINUX_ARTIFACT_DIR` and
`HEROES_PACKAGING_WINDOWS_ARTIFACT_DIR` set to task-owned directories (their shared
lossless-import cache has a single-writer lock). Then run the terrain probe with
`--platform linux|windows --binary <export executable> --pack <matching PCK>`.
Linux uses `--render --resolution 1920x1080`; Windows needs a new task-owned
`--wine-prefix` and uses headless assertions, not a claimed Windows GPU screenshot.

Inspected original atlases and real Medium captures before/after integration,
plus final source 1280×720 and isolated Linux-package 1920×1080 captures: improved
fine ground detail, feathered material boundaries, continuous rounder corner joins,
legible roads/props, retained fog and unclipped existing UI. The all-material
fixture and shore/island fixture were inspected separately from gameplay, as was
the real Large map view. Final reviewed biome images had SHA-256:

- Source small: `b30276e5c2846b1660a56824a66a36c0b8497b090b71dca2fe7f05fcf134a48b`.
- Linux package wide: `7d2a9686a119757c1928226664e2cb511355fb9e89c7b15323501d959ff4795f`.

No pixel artifacts are required to remain on disk after review; source paintings,
provenance, native seeds and the capture harness remain reproducible. Capture hashes
identify reviewed outputs, not cross-driver byte-equality promises.

## Validation results (2026-09-17)

- Original-art/provenance and corruption controls: seven Python tests pass,
  including exact reproducible atlas packing, missing mappings, invalid slots,
  generic-all-material fallback, missing raster and stale-source-hash rejection.
- Focused real Godot probe: source small and isolated Linux-package wide pass
  71 checks each. Windows/Wine package passes all 38 non-render assertions.
  GPU pixel tests run on Linux GL compatibility/llvmpipe, not Windows hardware.
- Blending is measured against the two actual unmixed painted materials;
  all sampled tile centers remain pure. Changing hidden neighboring water to lava
  produces identical visible pixels. Camera translation differs by at most one
  8-bit rounding step; mean channel difference is about `0.00000058` in source.
  Mean repeat-seam delta `0.06189` is below ordinary adjacent detail `0.06412`.
- Real 108×108 Large lookup uploads: 6,903 µs source, 6,000 µs Linux package,
  6,128 µs Windows package. Ten selection refreshes trigger no new lookup upload.
  These are lookup CPU measurements, not hardware frame-rate or whole-game claims.
- Native Medium terrain hash remains
  `0b87a3d85a5cb77e7b1fe7117215a28ab4383724178079d3dc259249e5836f4d`;
  collision hash remains
  `10567142109b668531b348088ae1de74fbb0d0786de699efdae284bca29d7e91`.
  Session/save dictionaries remain exact through rendering on both platforms.
- Existing blocker report passes: 2,324 body cells, 405 distinct body assets,
  no uncovered cells, unchanged collision/session authority and zero procedural
  terrain microtexture. Existing scenery/travel/fog/save/AI regression passes 459.
- Official Linux and Windows release export/boot checks pass; Windows additionally
  completes its generated Overworld-to-Town construction flow. Final terrain
  probes load only isolated packages. Both PCKs are 645,179,852 bytes; all 8,852
  entry names match, with byte-identical payloads except `project.binary` platform
  settings. Packed ground JSON is semantically identical after normal minification;
  shader bytes match source exactly. Source art is excluded from both packages.
  PCK SHA-256: Linux `83111c52b08cacf5f0903d17b54810e7573ce4fee974a335a9821ae1467b88ec`,
  Windows `0fdfc39a54e25b1d113de26215bfb288ca930ca8e30bdaff265d9227a55ebb61`.

Initial diagnostics caught an invalid direct draw call in the new capture probe
(removed; its timing was discarded), an over-strict bit-exact camera assertion
(now bounded to one quantization step), and legacy validator coupling to the old
single-layer layout/frozen manifest. The final code corrects those causes. The old
blocker launcher initially hit the host accessibility-service crash; its portable
launch now passes. Concurrent export preparation was rejected by its cache lock;
subsequent serialized preparation passed without bypassing the lock.

Final full `python3 -B tests/validate_repo.py` passes with exit 0, as do the
two directly affected validator owners and `git diff --check`. The full validator
explicitly discloses 26 absent historical non-RMG reports; it does not claim those
old runtime smokes were rerun. An earlier shell-wrapped invocation printed PASS
but returned 143; the final direct Python invocation confirms a clean exit.

Completion cleanup removed approximately 3.9 GB of task-owned rebuildable test
exports, captures and logs after these results were recorded. No active process
held the deletion targets. Disposable source probe profiles self-cleaned; existing
unrelated `/tmp` profiles were not swept. Retained original/generated art,
provenance, caches, saved Wine user data and map dependencies, all native RMG
recovery material, and the pre-existing unrelated untracked retention files.
No release-ready claim or next gameplay slice is implied.
