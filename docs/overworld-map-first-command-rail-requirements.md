# Overworld Map-First Command Rail Requirements

Task: #10228
Slice: `ux-overworld-map-first-command-rail-10228`
Phase: 6 - Production Alpha Layer

## Owner intent

Recompose the live Overworld using the supplied Heroes III adventure-map screenshot as structural inspiration: the world map must dominate, while navigation and management controls live in one compact right rail and a shallow footer. Aurelion Reach must keep its original art, terminology, rules, and interaction identity.

## Required behavior

1. The map is the dominant surface beneath only a restrained frame. At 1920x1060 it should occupy at least 78 percent of the available width before the right rail and at least 86 percent of the height above the footer. At 1280x720 the right rail remains present and usable rather than disappearing.
2. One fixed right rail contains, from top to bottom, a functional minimap, compact hero/town roster controls, selected hero identity and army, short contextual status, and compact direct actions. Long Command and Frontier detail remains drawer-owned and replaces rail content temporarily rather than competing beside it.
3. The minimap uses live map terrain and exploration state, shows towns and heroes with readable original markers, outlines the current viewed tile range, and lets pointer activation recenter the visual map camera. Recentring must not move a hero, spend movement, mutate the session, or bypass fog.
4. The bottom ribbon exposes the current resources, date, primary contextual action, end-turn, save slot/save, settings, and menu without the current tall card treatment. Resource details remain available through the existing stockpile menu.
5. Mouse, keyboard, and controller focus paths remain deterministic. Icon-scale or abbreviated controls require tooltips and accessibility names; existing modal and debug-input ownership remains authoritative.
6. Layout must adapt to 1920x1060 and 1280x720 without clipping or overlap, including supported UI scaling. The map, rail, footer, and transient debug performance overlay must remain legible.

## Preservation invariants

- Preserve all Overworld movement, pathing, encounter, town-entry, save/load, enemy-turn, route-cursor, and debug-overlay behavior.
- Preserve current drawers and all existing actions; the slice changes composition and routing surfaces, not domain rules.
- Preserve authored and generated map payloads, save version 9, current package limit, and Linux/Windows parity.
- Use existing original Aurelion Reach raster UI assets. The supplied external image is reference evidence only and must never be packaged or copied.

## Focused validation

- A Godot runtime report must measure map/rail/footer proportions and bounds at 1920x1060 and 1280x720.
- The same report must verify minimap terrain/marker/viewport output and presentation-only recentering on representative authored and generated sessions.
- It must exercise the hero/town selection surfaces, Command and Frontier drawers, primary action, End Turn confirmation, resource popup, Save, Settings, and Menu reachability.
- Capture and visually inspect both required resolutions.
- Run relevant Overworld regression coverage, `python3 tests/validate_repo.py`, `git diff --check`, and matching Linux/Windows export/package startup and Overworld-entry checks.

## Non-goals

- No copyrighted Heroes III asset, pixel, name, or copied interface skin.
- No RMG topology or placement changes, gameplay or balance changes, save migration, Town/Battle redesign, unrelated art generation, or broad cleanup.
- No signing, publication, package-limit change, whole-game validation, or release-readiness claim.
