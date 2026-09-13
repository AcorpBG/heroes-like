# Biome-aware overworld towns

Owner-approved slice: `art-overworld-town-biome-fit-20260913`, Phase 6. Status: completed. On 2026-09-13 the owner explicitly approved offline cutout/trim processing of generated backgrounds; implementation and source/Linux/Windows acceptance are complete.

## Source-backed problem

`OverworldMapView._town_sprite_asset_id` resolves town identity, then faction, then the default sprite without consulting terrain. In native Medium seed `medium-random-screenshot-10230`, Riverwatch's bright grassy base visibly clashes with volcanic terrain. Existing generated blocker palettes do consult the biome; town presentation does not.

## Required behavior

- Town architecture and individual identity remain recognizable across supported terrain. Ground contact, vegetation, snow and weathering must fit the actual local biome rather than introduce a baked grass/water island everywhere.
- Audit all 32 authored town identities, six faction fallback appearances and the default compatibility path. Explicit metadata governs supported terrain aliases and per-town art resolution; no random appearance choice or owner-based faction swapping.
- Use original generated raster art for missing visual variants. Preserve source masters, prompts, hashes, alpha and historical assets through the existing source/trimmed/runtime pipeline. No copyrighted game pixels, broad color wash, generic castle substitution or procedural terrain plate.
- Terrain selection is presentation only: use the town's actual level and local ground at its footprint/entrance through existing authoritative coordinates. Do not rewrite native terrain, town placement, entry, collision, route, fog, simulation RNG or save state to make art fit.
- Keep aspect-preserving fit, existing town click and hero entrance behavior. Bound caching to selected visible assets and invalidate appearance after applicable editor terrain changes.

## Validation and completion

- Focused Python-owned asset/runtime regressions: every town and biome mapping resolves through manifest-backed art; corrupt/missing mappings fail validation; dimensions, alpha and provenance checked; deterministic selection, level/terrain aliases, mixed edges, ownership changes and unchanged session/collision/entrance/click authority exercised.
- Fresh generated Medium map before/after captures at 1280x720 and 1920x1080, plus representative faction/biome visual review. Inspect actual images, not only report counts.
- `python3 tests/validate_repo.py`, relevant existing town proportion/grounding and generated-map tests, and `git diff --check`.
- Official `tests/packaging_linux_export_smoke.py` and `tests/packaging_windows_export_smoke.py`, packaged town/Overworld entry and matching package contents. Report measured sizes; project.md has no arbitrary content-size ceiling.
- Complete only after live behavior, approved-quality art and validation are real; preserve unrelated files, clean only task-owned disposable intermediates and push the coherent validated work.

## Non-goals

Native RMG recovery/generation/placement changes; faction balancing or terrain affinity rules; town interior scenes/buildings; overworld density; UI redesign; art families other than overworld towns; save-schema changes; release-readiness claims.

## Implementation

The renderer keeps logical town identity separate from its terrain-selected raster. `TownBiomeArtRules.gd` reads `art/overworld/town_biome_sprites.json`; all raster assets remain registered in the main Overworld manifest. `OverworldMapView` samples the source-owned entrance in the active level's terrain and uses the existing aspect-fit, silhouette, ownership, grounding and entrance path. Selection has no per-town cache, so terrain edits cannot leave a stale skin. Diagnostics expose logical identity and actual render path.

There are 39 logical entries: 32 named towns, six faction fallbacks and the default. They use 33 historical architectures: six named entries have distinct logical asset IDs but share the exact faction raster. Explicit `shares_architecture_with` metadata carries the matching variant to those named entries; validation checks historical path/atlas equality before accepting sharing. No unrelated faction substitution is permitted.

All 39 entries explicitly cover nine biomes and 22 terrain names, including plains/hills/ridge/ice/shore/subterranean aliases. Missing entries, biome mappings, variant assets or unproven architecture sharing fail focused validation. Unknown future/custom terrain retains the original identity as a compatibility behavior; current supported terrain does not rely on that fallback.

### Art treatment and visual review

19 original generated variants are registered. Two preserve successful generated-alpha canvases; 17 use the owner-approved offline background extraction/trim pipeline. All import at 512 square.

| Identity / architecture | Treatment |
| --- | --- |
| Riverwatch | Original grassy apron on grass/forest; basalt/ash variant on volcanic terrain; neutral structural foundation elsewhere. |
| Duskfen, Blackfen Gate, Murkward Ford, Reedbarrow Ferry | Original water on mire/coast; distinct land-supported timber/masonry versions elsewhere. |
| Bellwake Harbor, Fogchart Mooring, Gloamwake Anchorage, Rainwrit Bastion, Hollowreed Sanctuary, Pale Sounding Harbor | Original wetland/coastal versions retained; dry foundations, paved interiors and supported piers on other terrain. Each keeps its own architecture. |
| Cinderlock Bastion | Original molten canal only on volcanic terrain; paved gatehouse elsewhere. |
| Blackbell Foundry | Cooling water contained within structural troughs on land, snow, ash and underground; original discharge retained on mire/coast. Bronze bell, furnaces, pipes and basalt foundations remain. |
| Embercourt, Mireclaw, Sunvault, Thornwake, Veilmourn faction sprites and their six named aliases where applicable | Distinct land versions remove external water/terrain islands. Exact historical raster aliases share the appropriate variant; Brasshollow/Whitegauge need no new variant. |
| Highwater Keep, Prismhearth, Halo Spire, Nightglass Redoubt, Dawnmirror Observatory, Meridian Choirhold | Existing structural foundations retained after cross-biome review. Contained pumps, fountains, crystals and planted terraces are architectural features, not exterior terrain. |
| Graftroot Caravan, Rootgate Nursery, Briarwheel Enclave, Crownroot Refuge | Existing living roots, trees, wheels, nursery beds and contained pools retained as faction architecture. No generic stone-castle replacement or landscape island added. |
| Orevein Gantry, Clauseworks Depot, Cindercoil Foundry, Brasshollow/Whitegauge, default Frontier Town | Existing industrial or masonry foundations reviewed and retained; machinery and contained furnaces remain. |

Seven labeled review sheets in `.artifacts/town-biome-fit-20260913/art-review/` composite the actual registered rasters onto the game's nine generated ground materials. These are explicitly art-review composites, not gameplay screenshots. Visual inspection caught and corrected matte speckles, white edge fringes, Embercourt's enclosed checkerboard gap, a cropped Veilmourn finial and Blackbell's exterior discharge. The review also corrected Riverwatch's mire/coast choice and the six named faction-raster aliases.

The built-in imagegen skill/workflow supplied the original edits; no API/CLI image-generation fallback or copyrighted pixels were used. Immutable masters, prompts, intermediate edit hashes, extraction parameters, alpha cutouts, trimmed/runtime hashes and import bounds are under `art/overworld/source/generated/towns/biome_fit/`. `tools/package_town_biome_art.py` reproduces the 17 offline jobs from `offline_recipe.json` through `tools/prepare_town_biome_art.py`. Processing removes background alpha and neutral matte fringes, crops and aspect-fits; it does not paint new town geometry.

Historical art and gameplay mapping tables remain byte/structure protected. The biome table is deliberately separate: putting it into the frozen main manifest envelope initially broke 30 historical mapping assertions; moving it to its own presentation manifest fixed that integration error.

## Validation evidence

Evidence root: `.artifacts/town-biome-fit-20260913/`.

- `python3 -B tests/town_biome_art_regression.py`: source runtime passes; 39 logical entries × 22 aliases, loaded resources, exact native Medium volcanic selection, mixed-edge entrance sampling, editor terrain changes, ownership independence, aspect/grounding/footprint containment and unchanged session/collision/fog authority.
- `python3 -B tests/town_biome_art_regression.py --assets-only --reproduce-processing`: passed provenance and pixel-exact alpha/packing reproduction for all 17 offline jobs, including Blackbell; `processing-reproduction.json`.
- `python3 -B tests/town_biome_art_regression.py --assets-only --clean-import`: passed all 19 imports/512px loads in a disposable project with no import cache. The 19 runtime `.png.import` files are retained through a narrow `.gitignore` exception; fresh Windows/Linux checkouts do not depend on this machine's cache for the two preserved 1254px sources' 512px import bounds.
- `python3 -B tests/town_biome_art_regression.py --proportion`: existing town proportion/environs test passes with isolated profile/evidence.
- Native Medium seed `medium-random-screenshot-10230`, 72×72, four players: 2,324 blocker body cells and 405 distinct blocker appearances remain unchanged. Inspected normal-fog `medium_generated_1280x720.png` and wide Duskfen land review. The wide Duskfen capture temporarily reveals fog for art inspection and restores it afterward.
- `tests/town_biome_release_regression.py` extends the existing real-input town-entry probe with all biome resource checks and native Medium generation. Source preflight and both final release packages pass 1,014 checks each, including actual roster double-click → TownShell entry with unchanged hero position, movement and resources. Reports: `release-entry/{source-preflight,linux-reviewed,windows-reviewed}/report.json` and packaged receipts. Both packages execute the exact same SHA-locked probe; no assertion is omitted on Windows. Windows is headless Wine coverage, not a Windows GPU certification.
- `python3 -B tests/validate_repo.py`: **VALIDATION PASSED**, exit 0; `repository-validation-final.log`. This final batch covers the completed runtime/art set. The later narrow import-retention guard and clean-cache test were also run and passed. The earlier interrupted full run is not acceptance evidence.
- Official `tests/packaging_linux_export_smoke.py` and `tests/packaging_windows_export_smoke.py`: passed; `linux/report.json`, `windows/report.json`. Includes Linux boot, Windows startup/native DLL loading and fresh generated-map → Town/build flow. Final refreshed packages include the reviewed policy metadata.
- `tests/town_biome_package_parity.py`: passed; `package-parity.json`. Both PCKs are 516,821,036 bytes with 8,517 members and all 19 town variants. Exact current art/biome manifests, textures and compiled render owners are present; only platform-specific `project.binary` differs. Original/generated/trimmed source art is excluded. Increase over baseline: 7,553,524 bytes (about 7.6 MB). No arbitrary package ceiling is imposed by `project.md`.
- Final Linux package `native-medium-town.png` and `opened-town.png` at 1920×1080 were visually inspected, alongside source 1280×720/1920×1080 maps and all seven cross-biome sheets. Existing Town interiors and their art are intentionally unchanged.
- `git diff --check`: passed. All historical main-manifest mappings and asset entries are unchanged; exactly 19 new object assets are added. This slice does not claim product release-readiness.

## Retention

Immutable/generated sources, provenance, final screenshots/reports/logs and release packages are retained. Removed three superseded, reproducible extraction previews: 1,068,756 bytes. Disposable probe/clean-import projects were automatically removed. Both official and focused Wine prefix cleanup receipts pass, with user data retained before system-prefix removal. Caches are preserved. Pre-existing unrelated `docs/artifact-retention-policy.md`, `reports/`, `tools/__pycache__/` and `tools/artifact_retention.py` remain untouched and unstaged.
