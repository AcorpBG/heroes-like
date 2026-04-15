# Screen Wireframes and Visual Design Target

Project: heroes-like
Date: 2026-04-15

## Why this exists

The recent shell passes exposed a real failure mode: we kept improving layout density without changing the underlying screen grammar. That produced cleaner dashboards, not strategy-game screens.

This document is the corrective target.

From this point forward, screen work should follow:
1. define the screen fantasy and player job
2. define the dominant visual surface
3. define command rails and secondary detail
4. define clickable regions and information hierarchy
5. only then implement the shell

## Non-negotiable visual rules

- No screen should read like stacked report columns.
- The player should understand the screen from shape before reading paragraphs.
- One dominant surface per screen.
- Secondary information belongs in compact rails, trays, tabs, or popouts.
- Text supports the visual surface. Text does not replace it.
- Buttons should feel like commands tied to the current surface, not a generic app toolbar.
- Prefer icons, emblems, markers, portraits, banners, frames, and spatial grouping over long prose blocks.
- If a screen can be mistaken for a management dashboard, it is wrong.

## Shared shell grammar

Every major screen should be built from the same family logic, but not the same layout.

Shared family traits:
- top chrome: resources, day, faction banner, hero or commander identity where relevant
- main stage: the actual game surface
- side rail: compact contextual info, not full essays
- bottom rail: primary commands for the current context
- decorative treatment: heraldry, carved frame, map-board, stone, parchment, metal, or painted panel treatment

What must not be shared:
- identical column structures
- identical panel stacks
- identical button groups
- identical reading order

---

# 1. Main Menu

## Reference basis
This wireframe is now grounded in actual Heroes III menu references, not memory-only paraphrase.

Screens checked:
- Restoration of Erathia main menu screenshot, MobyGames
- Shadow of Death main menu screenshot, MobyGames
- Armageddon's Blade main menu screenshot, MobyGames
- Complete menu background without buttons, Heroes III Wiki

Shared pattern across those references:
- the menu is a painted scene with anchored controls, not a dashboard
- the logo lives at the top-left, not centered
- the main art mass lives left to center-left
- the clickable menu lives in a narrow right-side vertical column
- most of the screen is backdrop and atmosphere, not UI container
- the right side is visually quieter or darker so the controls pop
- bottom-left is reserved for branding / footer, not utility clutter

## Screen fantasy
A painted campaign stage with physical, ceremonial menu props anchored onto it. The player is stepping into a legend, not opening an app.

## Primary player job
Pick a starting path immediately from a small set of obvious main commands.

## Dominant surface
A large left-heavy painted hero or world scene, with the controls docked as a separate right-side command column.

## Layout wireframe

```text
┌──────────────────────────────────────────────────────────────────────┐
│ HEROES-LIKE LOGO                                                    │
│ subtitle / campaign tag                                             │
│                                                                      │
│  ┌──────────────────────── PAINTED STAGE ───────────────────────┐    │
│  │                                                              │┌──┐│
│  │  large hero / creature / citadel / war-scene focal art      ││◎ ││
│  │  smoke, sky, banners, cliff, fortress, magic glow           ││New││
│  │  most of the screen belongs to this backdrop                ││  ││
│  │                                                              │├──┤│
│  │                                                              ││◎ ││
│  │                                                              ││Load││
│  │                                                              │├──┤│
│  │                                                              ││◎ ││
│  │                                                              ││Camp││
│  │                                                              │├──┤│
│  │                                                              ││◎ ││
│  │                                                              ││Opts││
│  │                                                              │├──┤│
│  │                                                              ││◎ ││
│  │                                                              ││Quit││
│  └──────────────────────────────────────────────────────────────┘└──┘│
│                                                                      │
│ New World / footer / version area                                    │
└──────────────────────────────────────────────────────────────────────┘
```

## Original-design translation rules
To stay strongly HoMM3-inspired without copying assets:
- keep the asymmetry, not the exact art
- keep icon-first physical command anchors, not flat generic buttons
- keep a left-heavy painted scene and a right-side command spine
- keep the logo in the upper-left quadrant
- keep the command count low on first view, around 4 to 6 items
- keep a darker, calmer gutter behind the menu column

## Required visual ingredients
- large top-left title treatment with subtitle beneath it
- one dominant left-side hero or world illustration
- atmospheric negative space around the focal art
- right-side vertical command column with ornate icon + label pairs
- footer branding or version text tucked away at the bottom-left

## What should be absent
- centered card-stack menu layouts
- equal-width columns across the screen
- giant side panels for save metadata or lore text
- top navigation bars full of utilities
- central dashboard blocks, tab strips, or launcher-style tiles
- lots of buttons spread horizontally across the middle
---

# 2. Overworld

## Reference basis
This section is grounded in actual Heroes III adventure-map screenshots.

Screens checked:
- adventure map screenshot, Lutris
- adventure map screenshot, Might and Magic Wiki
- multiple HD-edition adventure-map screenshots surfaced via Steam / Ubisoft / press coverage

Shared pattern across those references:
- the map owns most of the screen, roughly four-fifths of the surface
- the interface is concentrated into a carved right-side sidebar, not spread everywhere
- the minimap sits high in the right column
- hero or town lists and current selection details live below the minimap in the same right column
- global resources and date live in a slim bottom ribbon, not in giant cards
- the map feels framed, not overlaid by app panels

## Screen fantasy
The world itself in a carved command frame. The player is staring at the terrain first and the controls second.

## Primary player job
Read the terrain fast, move with intent, inspect threats and holdings, then end the day cleanly.

## Dominant surface
A large adventure-map canvas with a single fixed right command spine.

## Layout wireframe

```text
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  ┌──────────────────────── ADVENTURE MAP ────────────────────────┐┌─┐│
│  │                                                               ││M││
│  │  terrain, roads, towns, mines, heroes, pickups, fog          ││i││
│  │  the world takes almost everything                            ││n││
│  │  route and danger are read on-map                             ││i││
│  │                                                               │├─┤│
│  │                                                               ││H││
│  │                                                               ││e││
│  │                                                               ││r││
│  │                                                               ││o││
│  │                                                               ││/││
│  │                                                               ││T││
│  │                                                               ││o││
│  │                                                               ││w││
│  │                                                               ││n││
│  │                                                               │├─┤│
│  │                                                               ││S││
│  │                                                               ││e││
│  │                                                               ││l││
│  │                                                               ││e││
│  │                                                               ││c││
│  │                                                               ││t││
│  └───────────────────────────────────────────────────────────────┘└─┘│
├──────────────────────────────────────────────────────────────────────┤
│ resources / date / kingdom values            core command buttons    │
└──────────────────────────────────────────────────────────────────────┘
```

## Original-design translation rules
- preserve the overwhelming dominance of the map
- use one fixed right sidebar instead of multiple floating context panels
- keep resource and date data in a slim footer ribbon
- show hero, town, and tile context inside the sidebar, not in wide text trays
- let markers, silhouettes, and color carry most meaning before text

## Required visual ingredients
- strong terrain readability and roads that read at a glance
- hero and town markers with unmistakable silhouettes
- high-contrast minimap in the upper part of the sidebar
- compact hero-town roster and selected-object detail below it
- narrow bottom resource ribbon with end-turn and utility actions

## What should be absent
- top-heavy dashboard bars
- big floating reports over the map
- large narrative panes stealing width from the world
- multiple equal-size panels competing with the map

---

# 3. Town

## Reference basis
This section is grounded in actual Heroes III town-screen references.

Screens checked:
- Castle / town screenshots from HD-edition press captures
- Fen town screenshot, heroes3wog
- additional town references surfaced via Bing image results for HoMM3 town screens

Shared pattern across those references:
- the upper half to two-thirds is an immersive town illustration
- buildings are the interface, not just decoration
- management is pushed into a lower tray instead of side columns
- creature stacks and visiting-garrison management live in dense horizontal slot groups
- the scene above stays mostly free of text panels
- leaving town and core town actions sit as anchored edge buttons, not broad toolbars

## Screen fantasy
A living faction stronghold above a command desk. The player reads the settlement by looking at it and then manages it from the tray below.

## Primary player job
Inspect the town, click a district, recruit or build, compare garrison and visiting forces, then leave.

## Dominant surface
An upper town tableau with clickable buildings, supported by a lower management tray.

## Layout wireframe

```text
┌──────────────────────────────────────────────────────────────────────┐
│  ┌──────────────────────── TOWN SCENE ───────────────────────────┐   │
│  │                                                              │   │
│  │  skyline / courtyard / dwellings / mage tower / fort         │   │
│  │  buildings themselves are the click targets                  │   │
│  │  faction identity lives in the art, not in text blocks       │   │
│  │                                                              │   │
│  └──────────────────────────────────────────────────────────────┘   │
├──────────────────────────────────────────────────────────────────────┤
│ town info │ garrison creature slots │ visiting hero creature slots  │
│ income    │ 7 slots                 │ 7 slots                       │
│ build     │ compact stats           │ compact stats                 │
│ tavern    │                         │                               │
│ market    │                         │                               │
│ mage      │                         │                               │
│ exit      │                         │ next/prev town / confirm      │
└──────────────────────────────────────────────────────────────────────┘
```

## Original-design translation rules
- keep the town art as the first read and the tray as the second read
- make buildings the primary click targets in the scene itself
- use a bottom management deck for units, economy, and hero visitation
- keep detail text reactive and local, not permanently expanded everywhere
- let faction architecture do the heavy lifting for identity

## Required visual ingredients
- a strong faction skyline with readable district silhouettes
- direct clickable building hotspots on the town illustration
- bottom creature-slot management for garrison and visiting hero
- compact income, build, and service actions grouped into the lower tray
- a clear leave-town anchor that does not dominate the scene

## What should be absent
- side dashboards taller than the town art
- prose-first descriptions of districts
- detached card stacks replacing the settlement view
- large utility ribbons splitting the scene into many equal bands

---

# 4. Battle

## Reference basis
This section is grounded in actual Heroes III battle-screen references.

Screens checked:
- battle screenshot, Lutris
- battlefield screenshot, Heroes III combat reference imagery
- additional HD-edition battle screenshots surfaced via press captures and store media

Shared pattern across those references:
- the hex battlefield sits in a framed tactical window and clearly dominates the screen
- opposing hero panels or force readouts flank the battlefield like bookends
- direct battle commands live low and close to the field, not far away in separate sidebars
- the combat log is narrow and subordinate
- the screen feels enclosed and tactical, unlike the open adventure map

## Screen fantasy
A framed duel board with two commanders facing each other across a living battlefield.

## Primary player job
Read the field state instantly, pick the active stack's action, and execute with minimal mouse travel.

## Dominant surface
A central hex battlefield framed by left and right commander bookends and a bottom combat strip.

## Layout wireframe

```text
┌──────────────────────────────────────────────────────────────────────┐
│ left hero / army      ┌────────── BATTLEFIELD ──────────┐ right hero│
│ morale / luck / mana  │                                  │ / army    │
│                       │  hex field, obstacles, stacks    │ morale /  │
│                       │  active unit highlight            │ luck /    │
│                       │  target preview and retaliation   │ mana      │
│                       │                                  │            │
│                       └──────────────────────────────────┘            │
├──────────────────────────────────────────────────────────────────────┤
│ spellbook  wait  defend  action help / short combat log  auto/retreat│
└──────────────────────────────────────────────────────────────────────┘
```

## Original-design translation rules
- preserve the framed duel-board feeling instead of turning combat into an overlay dashboard
- keep hero context as left-right bookends around the field
- keep the bottom strip close to the battlefield for fast action selection
- use a short combat log, not a tall report pane
- make stack silhouettes, spacing, and targeting cues do the main communication work

## Required visual ingredients
- a highly legible battlefield with strong stack silhouettes
- flanking commander panels or force summaries on both sides
- bottom command strip with core combat actions clustered tightly
- concise combat text feedback integrated into the bottom strip
- clear active-stack and target-state emphasis

## What should be absent
- giant side inspectors wider than the battlefield margins
- persistent essay-length combat analysis
- separate dashboard cards for every stack
- top bars that break the duel-board composition
---

# 5. Outcome

## Screen fantasy
A victory or defeat banner in a war chronicle, with one clear next move.

## Primary player job
Understand result, rewards or losses, then continue.

## Dominant surface
A result banner and reward or consequence display.

## Layout wireframe

```text
┌──────────────────────────────────────────────────────────────────────┐
│ crest / chronicle header                                            │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌──────────────────────── RESULT BANNER ────────────────────────┐  │
│   │ Victory / Defeat / Pyrrhic / Chapter Cleared                 │  │
│   │ key art, heraldry, major reward iconography                  │  │
│   └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│   rewards card        casualties card       next chapter / result    │
│   carryover card      unlocked card         save / retry card        │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│ continue  retry  return to menu  inspect carryover                   │
└──────────────────────────────────────────────────────────────────────┘
```

## Required visual ingredients
- strong banner treatment
- reward and consequence iconography
- one clear next-action row

## What should be absent
- wall of recap prose
- long vertical report sections
- multiple competing primary actions

---

# Asset buckets the image pipeline should support

These are the things image generation should produce.

## High priority
- hero portraits
- faction heraldry and crests
- decorative borders and corner ornaments
- town backdrop paintings and district plates
- menu tableau art
- outcome banners
- resource and building icons

## Medium priority
- battlefield prop art
- terrain embellishments
- spell cards or spell emblems
- campaign chronicle illustrations

## Low priority for now
- final polished unit sprites
- full-screen finished splash cinematics
- highly specific animation sheets

## Asset style target
- readable at game scale
- painterly, high-contrast, strong silhouette
- original fantasy world, not literal Heroes asset copying
- decorative enough to feel like a shipped game, simple enough to integrate fast

---

# Implementation gating rules

Before another shell implementation pass starts, the pass should answer:

1. What is the dominant surface?
2. What is the first thing the player reads without text?
3. Which actions belong in the bottom rail?
4. Which info is secondary and can hide behind tabs or cards?
5. Which generated assets are needed for this screen to stop feeling like a dashboard?

If those answers are weak, the implementation should not start yet.

## Immediate follow-up
- use this doc to sketch asset lists per screen
- generate first supporting art set in ComfyUI
- rebuild one screen at a time against this target, starting from the screen with the clearest wireframe acceptance criteria
