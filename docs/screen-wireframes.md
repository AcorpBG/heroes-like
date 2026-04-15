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

## Screen fantasy
A war table in a command pavilion. The player is choosing where to begin the campaign, not operating a settings dashboard.

## Primary player job
Choose a campaign chapter or skirmish front quickly.

## Dominant surface
A central title tableau or war-table board with 2 to 3 large play choices.

## Layout wireframe

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Crest / Title                    Profile / Settings / Audio         │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌──────────────────────── HERO / WORLD TABLEAU ─────────────────┐  │
│   │                                                               │  │
│   │   painted focal art or animated diorama                       │  │
│   │   campaign emphasis lives here                                │  │
│   │                                                               │  │
│   │   [ Start Campaign ]   [ Skirmish ]   [ Continue ]            │  │
│   │                                                               │  │
│   └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│   left small rail                         right small rail            │
│   campaign chapter card                   save / options / help      │
│   latest chronicle / hook                 compact utility only        │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│ status strip: latest save, unlocked arc, build/version if needed     │
└──────────────────────────────────────────────────────────────────────┘
```

## Required visual ingredients
- big title treatment
- hero portrait or tableau
- map, war table, banners, candles, instruments, or command props
- large campaign and skirmish call-to-action plates
- compact utility wing only

## What should be absent
- repeated navigation rows
- large explanatory text columns
- multi-panel save browser as the visual center
- debug-feeling lists on first view

---

# 2. Overworld

## Screen fantasy
An adventure map framed by command chrome. The map is the truth.

## Primary player job
Move, inspect, route, and decide daily strategy.

## Dominant surface
The map board.

## Layout wireframe

```text
┌──────────────────────────────────────────────────────────────────────┐
│ hero portrait  resources  movement  day/week  faction crest         │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────── ADVENTURE MAP BOARD ─────────────────────┐  │
│  │                                                               │  │
│  │  terrain, roads, towns, mines, heroes, pickups, fog           │  │
│  │  route preview, threat markers, objective markers             │  │
│  │                                                               │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                              ┌───────────────────┐   │
│                                              │ context rail      │   │
│                                              │ tile / town /     │   │
│                                              │ enemy summary     │   │
│                                              │ hero roster tabs  │   │
│                                              │ objective tabs    │   │
│                                              └───────────────────┘   │
├──────────────────────────────────────────────────────────────────────┤
│ move  wait  visit  hero  town  spellbook  end turn  save           │
└──────────────────────────────────────────────────────────────────────┘
```

## Required visual ingredients
- clear tile board and route readability
- strong hero marker and town marker silhouettes
- ownership color language
- objective and threat markers integrated on-map
- bottom command band with obvious core actions

## What should be absent
- the map shrinking to make room for text
- long narrative panels dominating the screen
- stacked readiness reports visible at all times

---

# 3. Town

## Screen fantasy
A living citadel board. The player is looking at a town and touching districts, not reading a municipal spreadsheet.

## Primary player job
Build, recruit, inspect defenses, manage spell or economy lanes, then leave.

## Dominant surface
A town stage with clickable districts/buildings.

## Layout wireframe

```text
┌──────────────────────────────────────────────────────────────────────┐
│ town crest  town name  resources  garrison strength  leave town     │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────────── TOWN STAGE BOARD ──────────────────────┐  │
│  │                                                               │  │
│  │  citadel skyline / courtyard / district markers               │  │
│  │  clickable hall, fort, dwellings, mage tower, market          │  │
│  │  build-state visuals and locked-state visuals                  │  │
│  │                                                               │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                 ┌───────────────────────────────┐    │
│                                 │ active district card          │    │
│                                 │ build / recruit / spell info  │    │
│                                 │ small garrison summary        │    │
│                                 │ pressure / logistics chips    │    │
│                                 └───────────────────────────────┘    │
├──────────────────────────────────────────────────────────────────────┤
│ build  recruit  tavern/hero  spellcraft  market  defense  leave     │
└──────────────────────────────────────────────────────────────────────┘
```

## Required visual ingredients
- town silhouette with faction identity
- distinct district markers
- built versus unbuilt states readable at a glance
- direct click targets on buildings
- garrison, pressure, and economy shown as compact chips or emblems

## What should be absent
- town state rendered primarily as text paragraphs
- build and recruit as separate dense ledgers before the town image
- giant side columns of prose

---

# 4. Battle

## Screen fantasy
A battlefield first, command rail second.

## Primary player job
Read battlefield state, choose a unit action, execute.

## Dominant surface
The battle board.

## Layout wireframe

```text
┌──────────────────────────────────────────────────────────────────────┐
│ commander left    objective / turn / phase    commander right       │
├──────────────────────────────────────────────────────────────────────┤
│ initiative strip / morale / spell-ready / battlefield condition     │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────────── BATTLEFIELD BOARD ─────────────────────┐  │
│  │                                                               │  │
│  │  units, lanes, cover, obstacles, range, threat, objectives    │  │
│  │  active stack highlight and target previews                   │  │
│  │                                                               │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                  ┌──────────────────────────────┐    │
│                                  │ active unit card            │    │
│                                  │ attacks / retaliation /     │    │
│                                  │ effects / hit estimate      │    │
│                                  │ spell or ability timing     │    │
│                                  └──────────────────────────────┘    │
├──────────────────────────────────────────────────────────────────────┤
│ move  melee  shoot  defend  wait  spell  surrender  auto/end turn   │
└──────────────────────────────────────────────────────────────────────┘
```

## Required visual ingredients
- clear board contrast and silhouette readability
- initiative as a visible strip, not buried in text
- active unit and targeting preview strongly highlighted
- commands grouped by action type

## What should be absent
- full combat log dominating first read
- battle summary columns wider than the battlefield
- long tactical essays always visible

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
