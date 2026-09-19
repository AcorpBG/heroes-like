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

## Plains groves and biome lighting follow-up

Owner screenshot feedback requested smaller trees grouped into patchy plains
forests, fewer rock-heavy appearances, and scenery colours closer to the ground.
The baker now assembles 100 additional grasslands groves from existing original
trees: 60 broadleaf and 40 evergreen compositions, each containing three to five
different components in staggered rows. Individual trees use 47-64% of the
standalone canvas size while the whole grove keeps its original blocker extent.
The original 100 source components per biome remain unchanged.

Groves occupy two thirds of the grasslands woods/conifer appearance pools and
34 of 84 grasslands rock-pool entries (40.5%). These are presentation selection
shares, not promised map-wide object counts. No native source types, masks,
placements, quantities or walkable routes were changed. Other biome appearance
pools remain unchanged. These are assembled clusters, not new source paintings.
The component library now has 900 source sprites and 1,000 assembled sprites.

`native_scenery.json` also owns `grounding_tints`: opaque per-biome lighting for
version 2 scenery, with stronger rock adjustments and gentler vegetation tones.
Warm earth receives warmer stone highlights; forest/mire use muted olive tones;
caverns use cool slate; snow keeps its pale highlights. Runtime modulation
preserves original pixels and alpha, and excludes heroes and interactive sites.
Version 1 scenery keeps its earlier palette and lighting. Restart/reload applies
the changes to existing version 2 maps.

Focused Windows selector/render checks passed 356,744 assertions, including all
1,900 reachable appearances, reload stability, opaque tinting and legacy colour
compatibility. All nine rendered biome samples were reviewed. Focused blocker
contracts passed for 2,812 assets; normal Godot import completed successfully.
The sandboxed baker/probe emitted the Windows certificate-store warning; normal
project import was clean. Wiki rebuilt to 5,999 entries and 14,256 media records.
No full suite, native parity, package/Linux validation or manual game was run.
Task-owned preview images and logs were removed after review; original artwork,
recipes and rebuilding tools remain.

## Native-sized forest and rock formations

The local source packages already contain several obstacle sizes: 1x1, 2x1,
2x2, 3x2, 3x3, 5x3 and, for some scenery, 7x3 blocked footprints. The previous
renderer flattened them into a fresh roughly 1.42-tile appearance per blocked
cell, so source size was lost visually even though collision was correct.

Version 2 rock, woods, conifer and deadwood bodies now retain a connected
formation per source placement and terrain. Broad formations have a dominant
original cluster scaled across multiple tiles, with smaller members around its
edges. The large silhouette fits an entirely blocked interior rectangle so it
is not cut off by ragged exterior masks; the remaining edge art covers the
original outline. Small/narrow bodies and other scenery families retain their
existing treatment. Aspect ratio, biome tints and plains grove choices remain.

`NativeSceneryFormation.gd` owns this presentation geometry. Individual tile
slices sample the same large image, preserving explored-cell rendering, partial
viewport visibility, holes/passages, overlapping-source ownership and the exact
body index. No blocked tiles are added or removed. Native generation, source
records, save data and simulation randomness remain unchanged; version 1 saves
retain their previous appearance. Restart/reload updates existing version 2 maps.
This adopts source-footprint scale using original art; it is not a claim of
pixel-exact H3MapEd rendering or new native-generation parity.

The focused live-method fixture checked 69 body cells and nine large formations,
covering 1x1, 2x2, 3x2 and the source-derived irregular 5x3 mask. Its 213 checks
passed, including unchanged source records, full mask coverage, preserved holes,
overlap ownership, deterministic grouping, legacy behaviour, per-cell clipping
and rendered pixels remaining hidden in a partially fogged formation. The
rendered grass/rough/forest fixture was visually reviewed. Normal Windows Godot
import completed without errors. No full suite, gameplay session, native parity,
Linux or package run was performed. Temporary previews/logs/profiles were removed
under the retention policy; source art and reproducible tooling were retained.

## Distinct sand geology and joined rock foundations

Sand and dirt previously resolved to the same badlands palette. Sand now uses
25 newly painted pale sandstone components and 25 two-component outcrops, with
terrain-specific selection in `NativeSceneryRules.gd`. Dirt and badlands retain
their red weathered rock. Sand foliage uses the coastal component library.
The source atlas, exact prompt, recipes and `tools/build_sand_scenery.py` retain
provenance and reproducibility. These are 25 new stone shapes plus compositions,
not another claim of 100 new source components.

Adjacent version 2 rock cells now share low rubble foundations, including across
separate native source records. Each cell draws its slice of the shared stone
bed beneath the existing large formation and smaller members. Foundations stop
at free cells and terrain boundaries; clipping preserves fog and passages. The
change affects presentation only, with no new blocked tiles or source records.
Existing version 2 maps update after restarting and loading; version 1 stays
unchanged. No native-generation parity claim is made.

The focused sand/dirt/mire render passed 1,429 checks across 69 body cells and
nine large formations, covering cross-record joins, exact masks, holes,
determinism, legacy appearance and fog pixels. The rendered terrain contrast
and connected bases were visually reviewed. All 2,862 generated blocker content
contracts passed, and normal Windows Godot editor import completed without
errors. The wiki catalog includes the new art. No full suite, gameplay, Linux
or package run was performed. Temporary render/log/profile outputs are removed
after review; original art, recipes and build tools remain.

## Irregular mountain masses and overlapping silhouettes

The broad-rock renderer now selects actual original mountain artwork instead
of enlarging two-component boulder clusters. Fifty 512px runtime sprites cover
nine biome palettes plus a separate sand palette (five each). The selected
source sheets use crooked ridges, open crescents, jagged spines, forked massifs
and winding escarpments with transparent, irregular contours. The initial
compact studies remain as provenance; the irregular revision is shipped.
`tools/build_mountain_scenery.py` reproduces extraction and registration from
the source sheets, prompts and recipes in `mountain_masses_20260919`.

Mountain visual coverage is now indexed separately from collision coverage.
The base is anchored to an entirely blocked interior of the original source
footprint. Peaks can rise up to 1.4 tiles above that region; adjoining rock
bodies allow their sides to overlap by 0.45 tiles. A stable back-to-front order
is shared by every drawn tile. This preserves the complete transparent outline
instead of cutting peaks or contours at source-object rectangles. Per-cell
render slicing remains solely for fog and viewport clipping. Mountain tint
comes from its anchor terrain even when a peak projects above another terrain.
Interactable objects and armies retain the existing foreground pass.

No collision tiles, native placement records or generation rules change.
Small bodies retain small rocks, and the wooded plains substitutions remain.
Existing version 2 maps update on restart/reload; version 1 retains its prior
appearance. This is original art and presentation, not native RMG parity work.

The focused overlapping sand/dirt/mire render passed 1,585 checks, including
all 50 selectable mountains, overlap ordering, visual overhang, deterministic
reindexing, original masks, legacy presentation and fog pixels. The irregular
render was visually reviewed. All 2,912 generated-blocker provenance, canvas
and import contracts passed. Windows Godot import completed without errors
after correcting a reset-path indentation error; the wiki includes all new art.
No full suite, gameplay session, Linux or package run was performed. Temporary
renders, logs and the isolated editor profile are removed after review; art,
provenance and rebuild tools remain.

## Large woodland, wetland and fungal formations

Seventy-five original 512px mass sprites extend the overlapping landscape
renderer to vegetation. Fifteen habitat/style groups have five irregular
compositions each: plains groves, deep woods, highland pines, snowy pines,
coastal woods, swamp willows, mangrove roots, reed beds, coastal marsh,
sand thickets, temperate deadwood, drowned groves, dry thornwood, burned groves
and fungal colonies. The masses contain many smaller plants with uneven
canopies, concave edges and tapering roots rather than square stands or giant
individual trees. Source atlases and exact built-in generation prompts live in
`art/overworld/source/generated/terrain/vegetation_masses_20260919`.
`tools/build_vegetation_scenery.py` rebuilds extraction, recipes and routing.

`vegetation_palettes` route broad native bodies by scenery family and biome;
sand has a distinct dry-wash thicket override. Fixed source habitat choices
still take precedence. Existing small art remains where no new mass is approved.
Broad plains rock bodies already chosen as groves use the new plains woodland
art; their existing selection frequency and blocked masks are unchanged.
Wetland, fungal and scrub bodies can now receive large formations too.

Mountains and vegetation share a single deterministic back-to-front visual
index. Canopy overhang and side overlap come from each vegetation profile;
reeds have less height than conifers. Bases remain anchored on fully blocked
interiors, and lateral expansion requires compatible neighboring blocked
vegetation on the same terrain. Fog clipping, viewport coverage, foreground
armies/sites and native collision stay separate from canopy silhouettes.
No native-generation rules, source records, saves or simulation RNG changed.
Restart/reload updates version 2 maps; version 1 appearance is preserved.

The mixed woodland/swamp/deadwood/fungal render passed 340 focused checks,
including reachability of all 75 assets, habitat overrides, exact source masks,
overlap ordering, deterministic reindexing, legacy behavior and fog pixels.
The mountain control retained all 1,585 passing checks. The source sheets and
mixed terrain render were visually reviewed. All 2,987 generated-blocker
provenance/canvas/import contracts and final Windows Godot import passed.
The wiki includes the new assets. No full suite, gameplay, Linux or package
run was performed. Rebuildable temporary renders/logs/editor profile are removed
after review; original art, provenance, caches and existing user files remain.
