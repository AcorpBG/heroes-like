# Distinct biome source components

Owner requirement: at least 100 distinct underlying components per biome before
assembling new clusters. Recombinations, recolors, mirroring and rotations do not
count as new source components.

The nine biomes each have four original transparent 5-by-5 source atlases:
25 rock structures, 25 woody forms, 25 deadwood/root forms and 25 undergrowth
forms. The latter contains ten fungal forms, ten shrubs and five wetland forms;
woody forms contain fifteen broad crowns and ten narrow/conifer forms adapted
to each environment. This makes 100 separately identified source components per
biome, with explicit family coverage rather than a shared seven-image pool.

Source prompts, row-major subject identities and generation paths are retained
in `art/overworld/source/generated/terrain/biome_components_20260919/production.json`.
Atlases are generated with the built-in image tool. Runtime cutouts and assembled
clusters retain source-sheet and component references. Source art stays outside
runtime exports. This is original-game presentation work; native generation,
collision, quantities and simulation randomness remain authoritative.

Acceptance requires inspecting component silhouettes, bounded transparent
cutouts, all 100 components used in each biome's cluster recipes, semantic family
adoption and rendered biome samples. File uniqueness alone does not demonstrate
visual variety. Full repository/game/platform suites are outside this slice.

## Delivered implementation

36 active source atlases supply 900 original component cutouts. An additional
900 two-component clusters use every source component as a dominant silhouette;
partners come from the same semantic family. All 1,800 runtime PNGs are unique,
transparent 256-by-256 images with bounded imports. One superseded mire woods
atlas is retained as original production provenance, outside the active count.

`tools/build_biome_components.py --godot <executable>` rebuilds the cutouts,
clusters, recipes, manifest and palettes using Godot alpha-island extraction and
compositing. Python orchestrates production; it does not paint the images.
Source masters are excluded from Godot scanning with `.gdignore`.

`NativeSceneryRules` prioritizes `component_palettes` for version 2 scenery.
Rock, woods, conifers, deadwood, fungi, scrub and wetland each have dedicated
biome pools, including the previously fixed lava barrier families. Restarting
and reloading a version 2 map applies the new art; version 1 save presentation
remains compatible. The older library and its original art remain preserved.
Native generation, blocker quantities, body masks and simulation RNG are not
changed by this presentation expansion.

The rebuilt wiki includes all new component and cluster appearances with names,
previews, biome links and non-interactive blocker explanations (5,899 total
catalog entries, 14,156 media records).

## Focused verification

All source sheets and nine rendered biome samples were visually reviewed. The
isolated Windows Godot selector/render check passed 355,860 assertions across
38 source scenery types and nine biomes, reached all 1,800 new appearances,
checked deterministic selection and retained legacy selection/input masks.
Focused blocker contracts passed for 2,712 assets. Normal Windows Godot import
returned zero with all 1,800 new imported texture caches present.

These samples exercise the live selection methods over a regular review grid;
they are not screenshots of a played random map. No full repository suite,
native parity run, package build, Linux run or manual playtest was performed.
Temporary render images and logs are removed after review; source art, prompts,
recipes, runtime sprites, imports and reproducible tooling are retained.
