# Overworld Landmark Readability And Town Scale Requirements

Implementation evidence: `docs/overworld-landmark-readability-and-town-scale-report.md`.

Task: #10229
Slice: `ux-overworld-landmark-readability-and-town-scale-10229`
Phase: 6 - Production Alpha Layer

## Owner intent

Make the live adventure map look substantially more coherent and readable. Towns must feel like dominant settlements rather than ordinary props, and gameplay objects must be distinguishable at normal play zoom. Heroes III adventure-map captures are scale, hierarchy, and readability references only; Aurelion Reach keeps its original art, names, terrain, content, and interaction identity.

## Comparative finding

The supplied and official Heroes III reference captures use a strong semantic size hierarchy: settlements and major structures dominate several terrain tiles, heroes and hostile creatures remain immediately legible, pickups retain recognizable silhouettes, and decorative masses support rather than compete with gameplay objects. The current Aurelion Reach renderer contracts reduce artifacts, pickups, encounters, structures, waypoints, and heroes below one tile and render nominal 3x4 towns at a 2.85-tile painted extent. This suppresses otherwise detailed original raster art and makes unrelated categories converge visually.

## Required behavior

1. Town sprites must read as the dominant map landmark and visibly occupy a deliberate three-tile-wide, approximately four-tile-tall world-space composition while retaining the existing 3x2 logical footprint and bottom-middle entry.
2. Heroes, encounters, artifacts, loose resources, durable sites, waypoints, and major landmarks must use distinct semantic scale bands that remain legible at normal tactical zoom. Interactive objects may visually overhang their logical tile but must not alter hit tests, footprints, blocking, visits, or pathing.
3. Mapped interactive raster sprites must receive a restrained silhouette-separation treatment so their painted edges survive both light and dark terrain. Do not add generic badges, colored boxes, labels, procedural stand-ins, or large UI plates to the world.
4. Decorative ground details must remain subordinate to interactable objects. Renderer emphasis may change, but authored/generated object identities, positions, counts, bodies, and topology must remain exact.
5. All normal gameplay objects continue to resolve through the existing manifest-backed original raster pipeline. Generate new art only if a semantically necessary asset is actually absent; never copy Heroes III assets or protected designs.
6. The visual hierarchy must remain responsive at 1920x1080 and 1280x720, work on authored and deterministic generated Large maps, preserve fog/memory treatment, and keep the new map-first rail unobstructed.

## Preservation invariants

- Preserve town logical footprint, entry coordinate, click routing, ownership, build state, save version 9, and faction/town identity lookup.
- Preserve object coordinates, category/content identity, body/visit masks, passability, interaction, routes, generated package bytes, and deterministic adoption.
- Preserve map zoom/camera policy, terrain topology, RMG generation, AI, balance, economy, battle, Town UI, and package ceiling.
- Keep Linux and Windows package parity and exclude source/reference images from shipping payloads.

## Focused validation

- Capture a deterministic generated Large map before and after at 1920x1080 and after at 1280x720, plus a representative authored map with towns, heroes, encounters, resources, artifacts, sites, and blockers visible together.
- Measure exact semantic scale ordering, town draw bounds, alpha aspect behavior, outline ownership, and interaction/session invariance.
- Prove town clicks and routes retain the exact 3x2 logical footprint and bottom-middle entry despite the larger visual.
- Run focused scale/town/interaction/movement checks, `python3 tests/validate_repo.py`, `git diff --check`, and matching Linux/Windows export/package startup and generated-map entry checks.
- Inspect final screenshots visually; numeric assertions alone do not prove the requested improvement.

## Non-goals

- No copied Heroes III pixels, sprites, towns, map layouts, names, UI skin, or distinctive protected expression.
- No RMG topology/density, object placement/count, terrain generation, gameplay footprint, pathing, movement, interaction, AI, balance, save-schema, Town/Battle UI, or content-rule changes.
- No generic glow/badge/plate system, procedural fallback art, package-limit increase, signing, publication, whole-game validation, or release-readiness claim.
