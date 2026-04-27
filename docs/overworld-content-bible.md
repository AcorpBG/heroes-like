# Overworld Content Bible

Status: design source, not implementation proof.
Date: 2026-04-18.
Slice: overworld-content-bible-10184.

## Purpose

Define the basic content grammar for the adventure map layer: biomes, pickups, flaggable economy, neutral structures, faction outposts, landmarks, blockers, transit objects, and scenario authoring rules.

This is the next design source after the six-faction bible. It should help the project grow from "a few scripted nodes on a small map" into an overworld that feels legible, varied, and strategically rich.

## Inspiration Signals from Heroes III map editor / wiki

Used as inspiration only, not as a copy target.

Key takeaways from Heroes III map-editor references:
- Terrain-specific object palettes matter. Different terrains should not only recolor the same object set.
- Object footprint matters. Large blockers, visitable cells, passability, and approach direction shape route-planning as much as the reward does.
- Overworld objects fall into a few strong gameplay families:
  - one-shot treasure and pickup objects
  - repeatable utility objects
  - flaggable economy structures
  - recruit/dwelling structures
  - guarded reward sites / banks
  - transit and layer-connection objects
  - gating / quest / border objects
  - pure decoration and obstacle objects
- Random-map/template guidance values object density and object size mix. A zone needs enough small one-cell rewards mixed with larger blockers and major sites, or the map either feels empty or becomes unreadable.
- Flaggable structures are a major part of the strategy loop. Mines, yards, shipyards, lighthouses, and dwellings turn map control into daily or weekly value instead of one-time loot.
- Terrain-specific variants of the same strategic function are useful. A mine, shrine, or watch post can keep its gameplay family while changing silhouette, route role, and faction/biome flavor.

Sources consulted:
- `heroes.thelazy.net/index.php/Map_Editor_-_Objects`
- `heroes.thelazy.net/index.php/List_of_adventure_map_objects`
- `heroes.thelazy.net/index.php/Template_Editor`

## Current heroes-like overworld audit

Current repo state is still narrow.

### Terrain / biome coverage now
- Scenario map tiles currently use only:
  - `grass`
  - `forest`
  - `water`
- Encounter battle terrain currently uses:
  - `grass`
  - `forest`
  - `mire`

### Object-family coverage now
Current `content/resource_sites.json` families are only:
- `one_shot_pickup`
- `neutral_dwelling`
- `faction_outpost`
- `frontier_shrine`

That is enough to support River Pass, but it is too thin for a broad strategy map. The current layer lacks a mature vocabulary for:
- mines and steady resource extraction
- guarded treasure sites and banks
- scouting / visibility structures
- roads, ferries, bridges, gates, and hard route-control objects
- repeatable stat or progression sites
- water/coastline-specific structures
- biome-specific landmarks and blockers
- strategic neutral settlements and trade structures

## Design goals

1. Make the overworld readable at a glance.
2. Give each biome its own visual and strategic identity.
3. Separate one-shot pickups from lasting map control.
4. Make route control, scouting, and economy worth fighting over.
5. Support handcrafted scenarios first, while leaving room for template-driven or semi-random generation later.
6. Keep object roles original, faction-aware, and production-friendly.

## Biome roster

These are the target adventure-map biome families.

### 1. Grasslands
Role:
- baseline roads, farms, riverlands, open marches

Feel:
- fastest readability, clean route planning, visible threat lanes

Common content:
- supply wagons
- mills
- signal posts
- shrines
- open ruins
- farms and levy grounds

### 2. Deep Forest
Role:
- ambush lanes, vision denial, side-path treasure pockets

Feel:
- slower movement grammar, denser blockers, hidden reward pockets

Common content:
- hunter lodges
- grove shrines
- overgrown ruins
- barrows
- wood camps
- beast dens

### 3. Mire / Fen
Role:
- pressure terrain, chokepoints, attritional route control

Feel:
- narrow channels, reed roads, bog outposts, dangerous shortcuts

Common content:
- reed shrines
- kennel yards
- sluice camps
- swamp barrows
- tar pits
- ferry crossings

### 4. Highland / Ridge
Role:
- scouting, watch control, defended approach lanes

Feel:
- cliffs, quarries, switchbacks, outlook points

Common content:
- watchtowers
- quarries
- beacon keeps
- pass forts
- wind shrines
- eagle roosts

### 5. Rough Badlands
Role:
- aggressive expansion, risky treasure concentration, poor recovery

Feel:
- exposed roads, raider camps, cracked earth, salvage fronts

Common content:
- scavenger yards
- war camps
- scrap vaults
- burn shrines
- siege remnants

### 6. Ash / Lava Wastes
Role:
- high-risk magic and siege territory

Feel:
- scorched ground, unstable routes, high-value guarded sites

Common content:
- ash forges
- magma fissures
- cinder shrines
- obsidian vaults
- infernal gates

### 7. Coast / Archipelago
Role:
- alternate mobility layer, logistics pivots, fragile flank routes

Feel:
- shore towns, shipyards, coves, reefs, lighthouse control

Common content:
- shipyards
- fisheries
- lighthouses
- smuggler coves
- tide shrines
- wreck fields

### 8. Subterranean / Underways
Role:
- hidden movement network, mining pressure, dangerous shortcuts

Feel:
- tunnels, fungus caverns, crystal seams, gate chambers

Common content:
- tunnel gates
- fungus groves
- ore vaults
- crystal labs
- buried sanctums

### 9. Snow / Frost Marches
Role:
- distance pressure, visibility tradeoffs, elite frontier sites

Feel:
- sparse routes, harsh supply strain, strong landmark silhouettes

Common content:
- storehouses
- ice shrines
- wolf camps
- frozen cairns
- signal braziers

## Object families

These are the core gameplay families the overworld should support.

### A. One-shot pickups
Purpose:
- immediate reward, low persistence, pacing filler

Examples:
- coin cache
- wood wagon
- ore crates
- ration cart
- salvage drift
- relic bundle

Rules:
- cheap to author
- usually one-tile or very compact
- should help keep empty travel from feeling dead

### B. Flaggable economy structures
Purpose:
- durable control points that change daily income or strategic capacity

Examples:
- sawmill
- quarry
- alchemical extractor
- fishery
- peat pit
- salt pan
- crystal orchard
- salvage foundry

Rules:
- should be fought over repeatedly
- terrain/biome variants are encouraged
- each should have a clear output identity, not just generic gold income

### C. Neutral dwellings
Purpose:
- external troop access and faction pressure on the map

Examples:
- frontier barracks
- hunter lodge
- kennel yard
- lens house
- graft nursery
- boiler yard
- lantern dock

Rules:
- some should be neutral and cross-faction
- some should be faction-linked or biome-linked
- should support weekly recruit flow and local map identity

### D. Shrines and spell sites
Purpose:
- spell access, utility unlocks, map-specific knowledge, movement tools

Examples:
- roadside sanctum
- reedscript shrine
- stormglass shrine
- cinder altar
- tide chapel
- undercrypt whisper gate

Rules:
- split into utility shrines, battle shrines, and rare high-tier sanctums
- should not all behave as one generic spell dispenser

### E. Guarded reward sites / banks
Purpose:
- high-risk fights for meaningful treasure or momentum swings

Examples:
- barrow vault
- watch ruin
- drowned reliquary
- abandoned works
- ash crypt
- leviathan wreck
- quarry cistern

Rules:
- big reward sites should anchor subregions
- each bank family should telegraph what kind of risk and reward it represents

### F. Scouting and route-control structures
Purpose:
- shape information warfare and map tempo

Examples:
- watchtower
- beacon post
- drum outpost
- relay lens
- lighthouse
- listening cairn

Rules:
- scouting should be a real strategic layer, not only a hero stat
- these structures should change what routes feel safe

### G. Transit and traversal objects
Purpose:
- create meaningful alternative routes and layer transitions

Examples:
- bridge
- ford
- ferry stage
- rope lift
- tunnel gate
- shipyard
- monolith-like paired gate

Rules:
- route objects should be scenario-shaping pieces, not decoration
- some can be fixed, some unlockable, some conditionally repaired

### H. Gates, blockers, and conditional locks
Purpose:
- structure progression without feeling arbitrary

Examples:
- customs gate
- sealed pass
- bramble wall
- floodgate
- ward obelisk
- contract checkpoint

Rules:
- prefer grounded progression logic over abstract key-color gating clones
- blockers should tie into factions, biomes, or scenario stakes

### I. Repeatable support sites
Purpose:
- give heroes recurring utility without permanent ownership

Examples:
- infirmary camp
- training ring
- scribe house
- market caravanserai
- mercenary board
- cartographer tower

Rules:
- these are good for scenario texture and return-path choices
- should have cooldowns, visit limits, or price gates where needed

### J. Decoration and obstacle sets
Purpose:
- sell biome identity and shape passability

Examples:
- forests, cliffs, deadfall, ruins, marsh pools, ridge walls, reefs, lava cracks, driftwood, fence lines, standing stones

Rules:
- should exist in small, medium, and large footprints
- must support both handcrafted readability and future template placement rules

## Resource design

The game should eventually support both town-building resources and map-control resources.

### Core build resources
- gold
- wood
- ore

These remain the baseline economy materials.

### Rare / strategic resources
Use these sparingly and tie them to faction identity, advanced buildings, elite recruitment, or spell institutions.

Candidate set:
- crystal
- sulfur
- mercury
- gems
- emberglass
- peat resin
- star salt
- black powder

Rule:
- the project does not need eight generic HoMM-copy rares by default.
- prefer a mixed model:
  - a small shared rare set
  - a few faction or biome-flavored strategic materials layered on top

## Overworld building grammar

These are map structures, not town-screen buildings.

### Strategic buildings
- mines, mills, quarries, fisheries, extractors
- held for income or output

### Frontier buildings
- outposts, watch posts, beacon towers, customs houses, gatehouses
- held for vision, pressure control, or route control

### Service buildings
- inns, markets, shrines, training grounds, infirmaries, shipyards
- visited for utility, not long-term ownership

### Reward buildings
- vaults, tombs, reliquaries, abandoned works, sealed workshops
- fought for treasure or rare progression

### Faction landmarks
- each faction should have map structures that are visibly theirs even outside towns
- examples:
  - Embercourt: signal braziers, levy yards, lantern chapels
  - Mireclaw: drum posts, reed shrines, sluice camps
  - Sunvault: lens relays, shard houses, halo beacons
  - Thornwake: graft nurseries, root altars, regrowth circles
  - Brasshollow: foundry depots, boiler yards, contract pylons
  - Veilmourn: bell harbors, lantern docks, fog masts

## Scenario authoring grammar

Each scenario region should mix object scales.

### Region recipe
Every meaningful zone should usually include:
- 2 to 4 small pickups
- 1 to 2 durable economy structures
- 1 scouting or route-control structure
- 1 service or shrine site
- 0 to 2 guarded reward sites
- blocker/deco objects that define the lane silhouette

### Lane recipe
A route should usually answer at least one of these questions:
- Is this the fast lane?
- Is this the safe lane?
- Is this the treasure lane?
- Is this the scouting lane?
- Is this the reinforcement lane?
- Is this the late unlock lane?

### Readability rule
A player should be able to tell, from silhouettes and placement alone:
- what is worth visiting now
- what is probably guarded
- what can be owned
- what is likely a route-control structure
- what is just scenery

## Content-structure recommendation

Near-term content implementation should move toward these authored domains.

### Keep and expand
- `content/resource_sites.json`
- `content/encounters.json`
- `content/artifacts.json`
- `content/scenarios.json`

### Add soon
- `content/biomes.json`
  - movement cost
  - sight modifiers
  - encounter palette tags
  - allowed object families
  - decoration/blocker palette
- `content/map_objects.json`
  - canonical object definitions for pickups, utilities, blockers, and landmarks that do not fit neatly into the current site model
- `content/transit_links.json` or scenario-authored transit blocks
  - bridges, ferries, tunnel gates, lifts, paired gates

### Likely split later
Current `resource_sites.json` is doing too much. It will probably want a cleaner split later into:
- pickups
- control sites
- dwellings
- shrines
- utility/service sites

Not mandatory immediately, but the design should expect it.

## Implementation order

1. Add `docs/overworld-content-bible.md` as the design source.
2. Add `content/biomes.json` with the target biome roster and gameplay hooks.
3. Expand the current site/object vocabulary beyond the four current families.
4. Build a first neutral economy layer:
   - sawmill / wood equivalent
   - quarry / ore equivalent
   - one rare extractor
   - scouting structure
   - guarded bank family
5. Add faction landmark families so each faction can claim map identity outside towns.
6. Upgrade scenario authoring to place object mixes by biome and lane role instead of only a few scripted nodes.
7. Only after that, widen the scenario set and map sizes.

## Reality note

This document is a design source. It does not mean the repo already has mature biome variety or HoMM3-class adventure-map object breadth.

Current reality is still:
- prototype / pre-alpha
- River Pass manual gate passed
- six-faction scaffold started
- overworld object and biome grammar still much thinner than the target
