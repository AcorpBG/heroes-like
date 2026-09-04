# Overworld Owned Roster Visual Polish Requirements

Task: #10235
Parent: `phase-6-production-alpha-layer`

## Owner direction

The Overworld command roster must show only heroes and towns that are actually owned by the player, and its presentation must read as deliberate game UI rather than thin placeholder bars.

## Runtime requirements

- Hero controls are derived only from the authoritative `player_heroes` roster; enemy, neutral, encounter, and display-only hero records never appear.
- Town controls are derived only from authoritative town placements whose current owner is `player`; enemy and neutral towns never appear.
- Each entry uses its existing original hero portrait or town scenic art inside a compact, centered, square-proportioned ornamental card with a clear active or selected frame.
- Cards retain tooltips, accessibility names and descriptions, keyboard/controller focus, scrolling, authoritative hero switching, and authoritative town centering.
- The map remains the dominant surface and the right rail remains compact at 1920x1080 and 1280x720.

## Evidence requirements

- Normal-play screenshots must use an untouched scenario/session and report the exact authoritative owned hero and town ids shown. They must not promote enemy towns or inject extra heroes.
- Overflow behavior may use a separately labelled synthetic fixture, but synthetic ownership must never be used for normal visual evidence.
- Focused runtime coverage must fail for any displayed id outside the authoritative player-owned sets and must prove the ornamental card proportions, centered icons, loaded original art, active/selected state, accessibility, routing, and overflow reachability.

## Non-goals

- No changes to ownership, capture, hero recruitment, town acquisition, vision, movement, pathing, AI, RMG output, map content, save schema, balance, or package limits.
- No copied Heroes assets or pixels, new generated art, broad rail redesign, Town/Battle UI work, signing, publication, whole-game validation, or release-readiness claim.
