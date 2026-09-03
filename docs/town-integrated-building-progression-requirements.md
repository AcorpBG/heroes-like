# Integrated Town Building Progression Requirements

Task: #10226
Slice: `ux-town-integrated-building-progression-10226`
Parent: `phase-6-production-alpha-layer`

## Player Outcome

The Town remains one coherent painted place. Its faction village panorama is the stable base; each completed building appears at a deliberate location that follows the scene's perspective, ground plane, scale, depth, and architecture. Construction must never read as a row of cards or randomly scattered icons. Clicking or focusing a visible building explains what that exact authored building does.

## Runtime Authority

- `town.built_buildings` remains the sole visibility authority. No duplicate progression field or save migration is allowed.
- Each faction owns explicit normalized plot metadata. A building id maps to exactly one plot; upgrade-chain members share that plot and the most advanced built member replaces its predecessor.
- The same cover-crop transform used to draw the 1600x900 scenic source maps both raster layers and hit regions at every supported viewport.
- Missing plot ownership or a missing exact building texture is a focused validation failure. Normal play must not invent a random plot, procedural building, construction stake, or generic art fallback.
- Existing construction, costs, prerequisites, daily limit, resource mutation, action presentation, save version 9, and route authority remain unchanged.

## Presentation And Interaction

- Use the village development panorama as the stable base so individual construction changes are persistent and legible.
- Draw exact original transparent building paintings in explicit faction-aware plots, depth sorted by authored ground anchor. Scale and placement must avoid the appearance of a detached icon row and preserve the Town scenery as the dominant surface.
- Every visible building owns a transparent button aligned to its painted bounds. Hover and focus provide a restrained outline/tint without covering the art.
- Buttons expose meaningful tooltip, accessibility name, and accessibility description. Keyboard/controller focus follows the current Town conventions.
- Activation opens a compact information surface with the building's name, description, category, cost, prerequisites, and all authored effects relevant to the player (income, unit unlock/growth/discount, spell tier, readiness, market, defense, recovery, or other existing fields). It does not mutate gameplay.
- The existing prominent main-building hotspot continues to open Construction through its authoritative route; exact building hotspots open information only.

## Art And Originality

- Consume the existing manifest-backed original raster building catalog where it is visually suitable. Any replacement or missing raster must follow the approved generated-art source/runtime/provenance pipeline.
- Do not copy Heroes art, layouts, names, or pixels. Classic Heroes games are interaction inspiration only.
- Do not generate GDScript, SVG, Polygon, ColorRect, or PIL stand-ins for buildings.

## Validation

- Focused Godot report covering every authored town/building mapping, exact textures, stable plot/depth ownership, upgrade replacement, cover-crop hit alignment, and all visible-building information routes.
- Live construction plus save/resume proof with unchanged resources, built ids, save version, and action authority.
- Captures at 2048x1079 and 1280x720 for sparse, mid-development, and developed faction examples; inspect them for grounded composition, clipping, overlap, detached-row appearance, and readable controls.
- Existing Town development/layout/input/save tests, `python3 tests/validate_repo.py`, `git diff --check`, and established Linux/Windows release export/package startup checks.

## Non-Goals

No balance or authored building data changes; no new construction timing; no AI, campaign, Overworld, battle, RMG, or save-schema work; no broad Town-shell redesign; no signing, publication, hardware certification, whole-game validation, or release-ready claim.
