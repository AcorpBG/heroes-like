# Overworld Town Proportion And Environs Requirements

Task: #10236  
Slice: `ux-overworld-town-proportion-and-environs-10236`  
Parent: `phase-6-production-alpha-layer`  
Status: implementation in progress

## Owner Finding

The untouched 1920x1080 Ninefold Confluence capture shows Riverwatch as an unnaturally narrow, detached cutout on open grass. The town's original painted bounds are wider than tall, but the live renderer forces every town into one tall aspect. The starting radius-five town reveal also contains no decorative blocker body, while the waterfront base in the Riverwatch identity has no matching water terrain nearby.

## Required Runtime Outcome

- Preserve the painted alpha-bounds aspect of every manifest-backed town raster. Fit it inside the existing 3x4 visual envelope, center it horizontally, and ground its painted bottom above the unchanged entry tile.
- Keep the authoritative 3x2 logical footprint, bottom-middle entry, town selection/click routing, non-entry blocking, ownership, and save data exact.
- Resolve `town_riverwatch` in this grassland presentation through a new original transparent land-set raster with Embercourt stone, red roofs, banners, beacon, and a grass/dirt contact edge. It must not contain a rectangular plate, bright water base, copied material, or procedural fallback.
- Put explicit grassland blocker clusters inside the player town's normal radius-five explored area. Their authored body masks must remain exact, roads and town approaches must remain open, and the surrounding composition must read as intentional settlement-edge scenery rather than scattered tokens.
- Do not reveal extra fog to make the evidence look denser. Normal evidence must use untouched gameplay state.

## Validation

- Focused Godot report: painted source aspect versus live draw aspect for every town identity/faction asset, visual-envelope containment, bottom grounding, exact town footprint/click routing, Riverwatch asset identity, local blocker visibility, road clearance, and deterministic session state.
- Existing town-scale, town-click, object-art, authored-density/pathing, fog, movement, and save checks relevant to the changed paths.
- Visually inspect fresh normal-play captures at 1920x1080 and 1280x720.
- Run `python3 tests/validate_repo.py`, `git diff --check`, and the established Linux/Windows export/package startup and Overworld-entry smokes. Matching packages must remain below 250000000 bytes.

## Non-Goals

- Native RMG generation or parity behavior; generated topology, placement, density, terrain, roads, guards, rewards, retries, or final payloads.
- Gameplay, economy, AI, balance, movement costs, logical town footprints, save-schema changes, Town/Battle UI, or broad art-family regeneration.
- Copyrighted Heroes material, procedural/SVG placeholders, package-limit increases, signing, publication, or release-readiness claims.
