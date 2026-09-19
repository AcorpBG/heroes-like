# Unified rare-resource mines

Owner direction, 2026-09-20: redo the rare mines to match the approved common mines, with only one building type per resource. Six original buildings replace the nine dedicated resource-front appearances. Historical site/object IDs remain compatible aliases; every alias for a resource resolves to the same name, painted building, machinery and footprint.

| Resource | Shared building | Moving machinery |
| --- | --- | --- |
| Aetherglass | Aetherglass Mine | Polishing wheel and crystal cradle hoist |
| Embergrain | Embergrain Granary | Mill wheel and grain basket hoist |
| Peatwax | Peatwax Mine | Press flywheel and peat bucket hoist |
| Verdant Grafts | Verdant Graft Nursery | Conservatory drive wheel and plant crate lift |
| Brass Scrip | Brass Scrip Mint | Mint flywheel and stamping press |
| Memory Salt | Memory Salt Mine | Evaporator drive wheel and salt bucket hoist |

Each has a visible chimney plume and independently flickering lamps. Masonry, timber, roofs and foundations remain stationary. Reduced motion freezes the machinery and lamps and removes smoke. All mines use the enlarged ownership flag: grey when uncontrolled, the controlling player's colour after capture, including recapture by a same-faction opponent.

## Scale, footprint and compatibility

The rare buildings use the common mine's 512x640 transparent canvas, fixed ground anchor and 75% painting scale. Their neutral foundations fit every terrain without a baked grass, sand or snow plate. The occupied footprint is three columns by two rows: five solid cells plus the south-middle entrance. Smoke and painting are clipped per explored map cell.

`MineRules.gd` supplies geometry and art identity to gameplay and rendering, using the existing `CommonMineRules.gd` geometry. Only explicitly marked `common_mine_resource` or `rare_mine_resource` sites opt in. Loose resource pickups, mixed-resource exchanges, supporting producers, dwellings and outposts retain their existing roles. A native source object that looks like a common mine still renders using its live rare-resource site identity.

Existing dedicated rare mines keep their production: one rare resource plus 120 gold daily while controlled. Capture rules, rewards and output timing are unchanged. Existing saves/maps gain the new appearance and game-level footprint when loaded; no regeneration is required for the artwork. Historical placements are not moved, so older tightly packed maps may not have reserved all six cells. Native placement rules and source/package masks remain immutable; this is an explicit owner-selected game geometry override, not a native parity change.

## Original art and rebuild

Built-in image generation created the original sheets in `art/overworld/source/generated/mines/rare_20260920/`. `provenance.json` records the six full prompts. `peatwax-edit.json` and `peatwax-alpha-edit.json` record the hoist and transparency corrections; `peatwax-layers-transparent.png` is the selected Peatwax source. Earlier generated sheets remain source provenance.

Run `python tools/pack_rare_mines.py` with Pillow. It crops, scales and registers existing painted layers into six bases, six machinery atlases and six static previews in `art/overworld/runtime/objects/mines/`, plus `art/overworld/rare_mines.json`. It shares packing with the common mines; `OverworldMine.gdshader` animates both. The same resource paths and shader run on Windows and Linux.

The wiki builder presents the shared mine artwork for dedicated sites and map objects while retaining loose resource artwork as associated pickup media.

## Focused verification

`tests/rare_mines_regression.py --godot <executable> --output <temporary directory inside repo>` checks all nine aliases, six identities, unchanged income, five solid cells plus entrance, package-mask precedence, loose pickups and mixed-producer exclusions. An isolated map exercises the actual animated renderer, neutral flags, fog clipping, cached drawing and save-state preservation. GPU samples on grass, sand and snow at 58- and 36-pixel tile sizes check machinery, smoke contrast, lamp changes and reduced motion. Common-mine and ownership-flag regressions cover the shared adapter and recapture. No full repository suite or full game playtest is needed for this slice; generated probe files and captures are disposable after review.

Validated on 2026-09-20: 324 rare-mine checks, 183 common-mine checks and 48 control-flag checks passed. Rendered art was reviewed on grass, sand and snow, including the corrected Peatwax alpha. The full suite was not run, as directed.
