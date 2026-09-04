# Overworld Town Vision And Command Roster Requirements

Task: #10234

Parent: Phase 6 - Production Alpha Layer

Status: completed and validated

## Problem

Owned towns are strategic holdings but do not currently contribute to the permanent-exploration fog source set. The right rail technically creates hero-switch and town-center text buttons, but it does not present the readable paired hero/town roster visible in the supplied classic adventure-map reference.

## Required behavior

- Every player-owned town contributes a Manhattan-radius-five permanent exploration source centered on its authoritative town entry coordinate.
- Neutral and enemy towns do not reveal terrain for the player. Capturing a town adds its vision on the same authoritative action completion; losing ownership stops future source refreshes without erasing tiles already explored.
- Normalization, movement refresh, capture refresh, save/load, the main map, and minimap continue to share `session.overworld.fog.explored_tiles`; no second fog authority is introduced.
- The persistent right rail displays all player heroes and all player-owned towns as two compact labeled icon columns below the minimap. Larger rosters remain fully reachable through a bounded scroll region.
- Hero controls use the existing original portrait assets. Town controls use existing original town scenic art. Missing art must fail focused coverage rather than becoming procedural UI geometry.
- Activating a reserve hero routes through the existing authoritative hero-switch action and centers the new active hero. Activating the already active hero centers it without spending movement. Activating a town selects its entry tile and centers the map through the existing town-rail path.
- Active hero and selected town states are visually distinguishable. Every icon has a useful tooltip, accessibility name/description, and keyboard/controller focus.
- The selected-hero identity, army management, short status, drawers, minimap, dominant map, and footer remain visible and unclipped at 1920x1080 and 1280x720.

## Preserved authority

This slice does not alter hero scouting radii, town footprints, ownership/capture conditions, town or hero content, movement, pathing, interaction, AI, economy, construction, recruitment, Native RMG output, generated packages, save version 9, camera controls, or input bindings.

## Validation

- A focused core/runtime report covers player, neutral, enemy, newly captured, and save/reloaded town vision against exact expected coordinates.
- A focused rendered report covers icon source/loading, one-control-per-record coverage, active/selected state, hero switch and town-center routing, overflow reachability, accessibility, and 1920x1080 plus 1280x720 layouts.
- Existing fog, town capture, hero command, map-first layout, generated movement/save, repository, Linux export/package, Windows export/package, and direct packaged generated-entry checks pass.
- Final screenshots are inspected visually before completion.

## Non-goals

No copied Heroes III art or UI, RMG tuning or recovery, broader fog redesign, enemy intelligence/stale-information layer, balance changes beyond the requested player-town source, new content, Battle/Town-screen work, signing, publication, or release-readiness claim.
