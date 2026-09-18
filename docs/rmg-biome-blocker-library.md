# Expanded biome blocker library

Status: completed. The owner approved a mix of separately generated sprites and assembled original-art clusters, with at least 100 new blockers per biome and an emphasis on asset production.

## Live semantic palette adoption

The September 18 semantic scenery selector had bypassed this library: most
families used only a few older sprites, and lava barriers used one fixed raster.
The correction connects all 900 appearances through `native_scenery.json`'s
`library_palettes`. `tools/build_native_scenery_palettes.py` rebuilds those lists
from each recipe's largest layer and its original component family. This keeps
rock, woods, wetland and deadwood clusters appropriate to their scenery roles.
Special scenery such as lava barriers, frozen shelves and fallen trees now has
compatible variation families while retaining its original raster candidates.

Version 2 scenery uses a stable coordinate hash with well-distributed values;
palettes are cached, and no simulation RNG, placement, collision mask or saved
object is changed. Reloading a version 2 map applies the corrected appearance
selection. Version 1 saves retain their old presentation contract. Existing
generated art and provenance are unchanged; this correction adds no new sprites.

`tests/native_scenery_variety_regression.py` exercises the actual map selection
methods and scenery module in an isolated Godot project. Windows checks cover
all 38 source scenery types across nine biomes, all 900 library appearances,
stable reload selection, legacy palettes and unchanged input masks. All nine
biome renders were reviewed. This is a focused selector/render check, not a full
gameplay, native parity, repository or Linux validation run. Temporary render
evidence is removed after review under the owner's retention policy.

## Delivered content

900 new transparent 256px blocker PNGs: 100 for each of the nine biomes, additional to the previous batch. Each biome receives one newly generated dead-tree design and 99 distinct assembled clusters. Of those clusters, 45 include its new dead tree and 54 combine existing biome-compatible original art. Total: 9 new source designs, 891 clusters, and 414 dead-tree appearances.

| Biome | New dead-tree design | New appearances |
| --- | --- | ---: |
| Grasslands | Hollow Dead Oak | 100 |
| Deep Forest | Fallen Forest Giant | 100 |
| Mire Fen | Drowned Cypress Snags | 100 |
| Coast Archipelago | Salt-Killed Mangrove | 100 |
| Highland Ridge | Windblasted Dead Juniper | 100 |
| Rough Badlands | Sun-Bleached Dead Thorn | 100 |
| Snow Frost Marches | Rimebound Dead Pine | 100 |
| Ash Lava Wastes | Charred Blackwood Snags | 100 |
| Subterranean Underways | Petrified Root Crown | 100 |

Every addition has its own PNG and recipe. Recipes use different component combinations across the entire library; all 900 output hashes are distinct. Clusters layer three or four original raster components with compact overlapping silhouettes. They are assembled artwork, not 891 independently generated illustrations. No recoloring, mirroring, copied game pixels or geometric stand-ins are used.

## Runtime and wiki

All 900 IDs are registered in `art/overworld/manifest.json` and the corresponding `generated_body_palette` in `art/overworld/decorative_object_sprites.json`. The live dedicated pool now contains 936 unique appearances. Existing OverworldMapView terrain/coordinate selection consumes these palettes. Native generation, obstacle body masks, collision, routes, RNG and save semantics are unchanged. These additions are scenery appearances, not new interactive adventure sites.

The wiki includes 900 explicit entries, previews, biome links, production method, dead-tree flags and explanations of impassable/non-interactive behavior. Filter map objects by `dead_tree`, `original_dead_tree` or `assembled_cluster`. The rebuilt catalog contains 4,051 entries and 9,785 media assets.

Source masters, full prompts, source-component provenance and reproducible recipes are retained under `art/overworld/source/generated/terrain/biome_blocker_library_20260913/`. Runtime art is under `art/overworld/runtime/objects/decorations/biome_blocker_library_20260913/`. `tools/build_biome_blocker_library.py --godot <Godot executable>` rebuilds the art and registrations using a disposable empty Godot project; it does not launch the game. Python owns the production workflow and Godot performs native alpha compositing. Portable PNGs, resource paths and import settings serve Windows and Linux.

## Bounded verification and cleanup

The build checked counts and rejected duplicate PNGs before registration. All nine 100-image contact sheets were visually inspected. Normal headless Windows Godot import completed without errors or warnings; an asset inventory confirmed all 900 PNG dimensions, imported texture files, mipmap/size settings and live palette registrations. Wiki catalog rebuild passed. No game, repository suite, native parity test, package build or full playtest was run; this is not a claim that every appearance has been observed in a played match or tested on Linux.

Evidence is retained in `.artifacts/biome-blocker-library-20260913/`: nine contact sheets, `build-summary.json`, `build.log`, `import.log` and `import-console.log`. The sandboxed baker emitted a system certificate-store warning after saving its images; the subsequent normal import was clean. Disposable bake projects were automatically removed. The isolated import profile was removed after Godot exited, recovering 3,391 bytes of rebuildable settings. Original art, provenance, caches and evidence were preserved; no task-owned Godot process remains.
