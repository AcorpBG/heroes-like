# Overworld Object Taxonomy And Density Foundation

Status: design source, not implementation proof.
Date: 2026-04-25.
Slice: overworld-object-taxonomy-density-10184.

## Purpose

This document defines the target overworld object taxonomy and density model for Aurelion Reach before broad map production, final map art, large JSON migration, or map-editor expansion. The goal is to make the adventure map feel like a strategic world: scenic, readable, route-driven, and dense with original object families that support exploration, economy pressure, neutral threats, faction identity, and worldbuilding.

Heroes 3 map-editor/object breadth, asset class variety, and reverse-engineered placement scale may be used only as inspiration for expected density, category clarity, and production seriousness. They are not source material for names, art, maps, factions, object layouts, object behavior, or text.

## Current Gap

The current content is useful scaffolding, not enough vocabulary for the target game.

Reality check as of this slice:

- `content/map_objects.json` has 43 map objects.
- 25 of those are neutral dwellings.
- Only a few current objects cover pickups, mines, transit, scouting structures, blockers, guarded reward sites, repeatable services, and faction landmarks.
- `content/resource_sites.json` already contains helpful control concepts such as persistent control, claim rewards, control income, repeatable services, transit profiles, scouting structures, and neutral dwelling rosters.
- Footprints are currently presentation hints, not true movement, blocking, occupancy, or visit-target rules.
- Existing objects mostly prove that the data boundary can carry object/site links. They do not yet create HoMM-scale world density, region identity, route choices, or production-map readability.

The missing layer is not just more entries. The project needs a stable taxonomy that tells designers, validators, artists, map authors, and AI systems what an object is for.

## Design Contract

Every overworld object must have one primary class and may have secondary roles.

Primary classes:

1. **Decoration / non-interactable**
   - Scenic, readable world texture.
   - May affect passability if it is a blocker or terrain edge object.
   - Never opens a visit dialog, reward panel, or building screen.
2. **Pickup**
   - One-time small reward or small event.
   - Usually 1x1 and passable or visit-on-enter.
   - Should pace exploration without becoming chores.
3. **Interactable building / site**
   - Visitable overworld object with a clear service, reward, capture, scouting, shrine, transit, or support role.
   - May be one-time, repeatable, persistent, owned, or contested.
4. **Persistent economy site**
   - Capturable or claimable site with daily, weekly, route-linked, or conditional output.
   - Must express resource type, owner/capture state, and strategic value.
5. **Transit / route object**
   - Changes route value, path availability, movement cost, scouting, bypass, or local logistics.
   - May be owned, neutral, blocked, damaged, repaired, or faction-favored.
6. **Neutral dwelling**
   - Persistent or repeatable recruitment source for neutral units.
   - Has a dwelling family, recruit roster, guard expectations, and world/ecology identity.
7. **Overworld neutral encounter**
   - Visible hostile or uncertain neutral unit presence on the map.
   - Exists as an army/encounter object first, not as a building.
   - Can guard routes, rewards, dwellings, pickups, or territory.
8. **Guarded reward site**
   - Higher-value one-time or limited-repeat reward with explicit risk.
   - May be a ruin, vault, shrine, observatory, foundry, wreck, orchard grave, or old mirror structure.
9. **Faction landmark**
   - Non-town object that marks faction presence, identity, influence, or regional control.
   - May be decorative, service-like, capturable, or route-linked depending on subtype.

Secondary roles should use structured tags such as `road_control`, `sightline`, `ambush_lane`, `resource_front`, `recovery`, `spell_access`, `market`, `blocked_route`, `world_lore`, `guarded_reward`, `neutral_recruit_source`, `faction_pressure`, and `scenario_objective`.

## Object Families

Object families are production categories, not just art buckets. A family defines expected scale, footprint, passability, interaction model, rewards, guard norms, biome/faction variants, animation hooks, and validation rules.

Target top-level family groups:

- Regional decoration
- Hard and soft blockers
- Pickups and caches
- Persistent resource fronts
- Civic and support sites
- Shrines and accordance sites
- Scouting and information sites
- Transit and route-control sites
- Neutral dwellings
- Overworld neutral encounters
- Guarded reward sites
- Faction landmarks
- Scenario objective objects
- Ruined infrastructure sets
- Damaged/captured state overlays

Production rule: a map should not solve density by placing many copies of the same object. Density comes from a mixed grammar: visible route structure, sparse decoration clusters, clearly visitable sites, reward pockets, guards, landmarks, and negative space.

## Footprints And Passability

Footprints need to become a gameplay contract later, not only a renderer hint.

Footprint tiers:

| Tier | Typical size | Use |
| --- | --- | --- |
| Micro | 1x1 | Pickups, markers, cairns, small caches, minor shrines, single neutral stack |
| Small | 2x1 or 1x2 | Dwellings, tollhouses, ferry posts, mine heads, small ruins, watch posts |
| Medium | 2x2 | Resource fronts, guarded ruins, observatories, large dwellings, support sites |
| Large | 3x2 | Town-adjacent landmarks, major vaults, bridge bastions, rail yards, harbor objects |
| Region feature | 3x3+ or multi-object cluster | Scenic blockers, ruin fields, wreck fields, root walls, rail networks, objective complexes |

Passability categories:

- **Passable visit-on-enter**: pickups, small cairns, low route caches.
- **Passable scenic**: flowers, low rubble, grass detail, plank debris, shallow reed marks.
- **Blocking visitable**: mines, dwellings, shrines, guarded sites, support buildings.
- **Blocking non-visitable**: cliffs, deep ruins, dense thorn walls, wreckage, rail embankments.
- **Edge blocker**: objects that shape a lane without occupying its center, such as fences, levees, root walls, chain booms, cliff lips.
- **Conditional pass**: transit objects that open, discount, tax, or redirect movement after a visit, ownership change, spell, faction trait, or scenario event.

The future pathing system must distinguish object body tiles from approach tiles. A 2x2 mine can block four tiles while being visited from one or more adjacent approach tiles. Towns keep their separate 3x2 town approach contract.

## Visit And Approach Rules

Every visitable object needs explicit approach rules.

Required visit metadata for future schema:

- Primary approach side: north, east, south, west, or multiple.
- Visit tile offset relative to the object footprint.
- Whether visit triggers on entering the object tile or from an adjacent tile.
- Whether the hero stops before interaction.
- Whether the object remains after visit.
- Whether the object changes state after visit.
- Whether the object can be revisited and on what cadence.
- Whether ownership, faction, hero skill, spell, or route state changes the interaction.

Approach expectations by class:

- Pickups: enter-to-collect unless visual scale makes adjacent visit clearer.
- Mines/resource fronts: adjacent visit from the working entrance, usually lower/front side.
- Dwellings: adjacent visit from gate, slip, den mouth, or contract yard.
- Shrines: adjacent visit, usually 1x1 or 2x1, with clear focal marker.
- Transit: approach from the path side; bridge/ferry/rail/fog/root objects may have two linked approach points.
- Guarded rewards: guard encounter resolves before visit; object entrance should remain legible under guard placement.
- Neutral encounters: the encounter itself is the visit/combat object; if guarding another object, it must not hide the guarded object's class.

## Guard Expectations

Guarding must be visible, fair, and attached to reward value.

Guard tiers:

| Tier | Expected use | Player read |
| --- | --- | --- |
| Unguarded | Low pickups, small scenic sites, first-route pacing | Safe tempo reward |
| Light guard | Better pickups, low dwellings, minor shrines | Early choice, low risk |
| Standard guard | Persistent economy sites, most dwellings, moderate rewards | Normal expansion combat |
| Heavy guard | Rare resource fronts, strong dwellings, major transit chokepoints | Delayed strategic objective |
| Elite guard | Mirror ruins, faction relic sites, capstone rewards | Campaign/skirmish power spike |
| Ambush/uncertain | Mire, Veil, ruins, fog, wrecks, hidden route sites | Explicit uncertainty cue, not invisible punishment |

Guard principles:

- A guard should never be pure UI surprise. The map should show danger by nearby stack, warning silhouette, guarded entrance, hostile camp, fog bank, spoor, patrol marker, or site state.
- Guarded rewards need reward category clarity before combat: resource, artifact, spell, recruitment, scouting, transit, objective, or town support.
- Neutral unit encounters can guard objects, patrol lanes, block chokepoints, or represent ecology. They should not all be static piles beside treasure.
- Faction-flavored guards may appear around faction landmarks, but neutral dwellings and neutral encounters must remain distinct from playable faction rosters unless intentionally authored.

## Reward And Risk Model

Objects should create visible choices, not a flat sequence of clicks.

Reward categories:

- Small resource reward
- Resource choice
- Persistent income
- Weekly yield
- Recruitment or hire access
- Spell access or spell refresh
- Artifact or artifact clue
- Experience or hero progression
- Scouting reveal
- Route opening or movement discount
- Recovery, readiness, or morale support
- Market/trade service
- Town support
- Scenario objective progress

Risk categories:

- Neutral battle
- Movement cost or delay
- Temporary debuff
- Resource payment
- Ownership vulnerability
- Counter-capture target
- Route exposure
- Ambush chance with explicit warning
- Faction reputation or scenario consequence
- Damaged-state recovery timer

Design rule: a high-value object should usually combine risk, route exposure, and future contestability. A low-value pickup should mostly reward exploration rhythm and world texture.

## Density Model

The target map density should create discovery and route planning without turning the map into a cluttered icon board.

Density bands per 16x16 local region:

| Band | Object mix | Use |
| --- | --- | --- |
| Sparse wild | 8-14 decoration clusters, 2-4 pickups, 1-2 interactables, 1 guard/encounter | Frontier, route breathing room |
| Standard adventure | 12-20 decoration clusters, 4-7 pickups, 3-5 interactables, 2-4 guards/encounters, 1 landmark | Normal scenario lanes |
| Contested economy | 10-16 decoration clusters, 3-5 pickups, 4-7 economy/transit sites, 3-5 guards/encounters, 1-2 landmarks | Resource fronts and chokepoints |
| Ruin/reward pocket | 12-22 decoration clusters, 2-4 pickups, 2-4 guarded sites, 3-6 guards, 1 objective/landmark | Delayed reward region |
| Town influence | 8-16 decoration clusters, 2-5 pickups, 3-6 support/economy sites, 2-4 guards, 1-3 faction landmarks | Around towns and faction fronts |

Placement rules:

- Keep major lanes readable first. Decoration should frame paths, not cover them.
- Every dense pocket needs at least one visible reason to exist: resource front, crossing, ruin, settlement, shrine, route junction, battlefield, or objective.
- Avoid placing multiple visitable objects so close that approach tiles become ambiguous.
- Leave negative space near towns, active heroes, road junctions, and major transit objects.
- Object density should taper along travel routes: clear lane, side reward, guarded pocket, landmark, then breathing space.
- A 64x64 skirmish map should have several object-rich local regions, not uniform scatter.

## Concrete Object Family Catalog Target

This is the target breadth for production planning. It is not an instruction to edit JSON in this slice.

### Regional Decoration And Blockers

| Family | Regions/factions | Primary class | Notes |
| --- | --- | --- | --- |
| Lockwall Remnants | Emberflow Basin, Embercourt | Decoration / blocker | Broken weirs, toll chains, low masonry, old road-court stones. |
| Beacon Ash Poles | Emberflow Basin, Embercourt | Decoration | Burned or active signal poles, route readability and civic presence. |
| Levee Cuts | Emberflow Basin | Edge blocker | Shapes river-adjacent paths without becoming a visit site. |
| Reed Sea Clumps | Drowned Marches, Mireclaw | Decoration / soft blocker | Low reed masses, wet route texture, ambush mood. |
| Chainboom Wrecks | Drowned Marches, Mireclaw | Blocker | Rusted ferry chains and broken booms that define marsh lanes. |
| Mudglass Scatter | Drowned Marches | Decoration | Small glints around pickups, shrines, and mire sites. |
| Lens Shard Fields | Glass Uplands, Sunvault | Decoration / hazard blocker | Pale crystal debris, sightline framing, aetherglass context. |
| Prism Road Stones | Glass Uplands, Sunvault | Decoration / route cue | Makes relay roads legible at map scale. |
| Root Braids | Walking Green, Thornwake | Edge blocker | Living root lanes, gated paths, renewal-zone borders. |
| Graft Tag Groves | Walking Green | Decoration | Orchard law texture and living-production hints. |
| Slag Berms | Brass Deeps, Brasshollow | Blocker | Industrial boundaries, furnace valleys, mine lanes. |
| Rail Bed Ruins | Brass Deeps | Decoration / transit cue | Old pressure-rail lines and broken switches. |
| Bell Buoy Lines | Veil Coast, Veilmourn | Decoration / route cue | Coastal path markers and fog-lane identity. |
| Wreck Rib Fields | Veil Coast | Blocker / decoration | Ship ribs, salvage boundaries, memory-salt context. |
| Mirror Anchor Pits | Ninefold Confluence | Decoration / objective frame | Old Measure infrastructure fragments. |
| Shardfall Rubble | Ninefold Confluence | Blocker | Neutral ruin texture for high-value pockets. |

### Pickups And Small Rewards

| Family | Regions/factions | Primary class | Notes |
| --- | --- | --- | --- |
| Writ Bundle | Embercourt, roads | Pickup | Gold, road clue, minor morale/readiness. |
| Granary Sack Cache | Emberflow Basin | Pickup | Embergrain and recovery pacing. |
| Timber Cart | Emberflow, Walking Green | Pickup | Timber/wood compatibility until resource migration. |
| Peatwax Votive | Drowned Marches | Pickup | Peatwax, shrine clue, low-risk mire reward. |
| Reed-Marked Cache | Drowned Marches | Pickup | Resource plus nearby-route reveal. |
| Crystal Lot | Glass Uplands | Pickup | Aetherglass shard, minor guarded variants. |
| Survey Sextant Case | Sunvault lanes | Pickup / scouting | Reveals a site or route junction. |
| Seed Packet | Walking Green | Pickup | Verdant grafts, recovery, Thornwake map identity. |
| Orchard Ration Basket | Walking Green, Emberflow | Pickup | Embergrain/recovery support. |
| Gauge Case | Brass Deeps | Pickup | Brass scrip or repair service clue. |
| Ore Sled | Brass Deeps, highlands | Pickup | Ore, sometimes light guard. |
| Salvage Crate | Veil Coast | Pickup | Gold, memory salt, artifact clue. |
| Obituary Ink Flask | Veilmourn lanes | Pickup | Memory salt or morale hook. |
| Mirror Cairn | Ninefold Confluence | Pickup / clue | Aetherglass, spell clue, objective hint. |
| Battlefield Ration Cairn | Any contested region | Pickup | Recovery/readiness after lane battles. |

### Persistent Economy Sites

| Family | Regions/factions | Primary class | Notes |
| --- | --- | --- | --- |
| Tollhouse Mill | Emberflow, Embercourt | Persistent economy | Gold/embergrain, road-linked income, capture target. |
| Timber Yard | Emberflow, Walking Green | Persistent economy | Timber output, vulnerable to raids. |
| Embergrain Yard | Emberflow | Persistent economy | Supply/recovery pressure, town support. |
| Ore Quarry | Brass Deeps, highlands | Persistent economy | Ore, standard guard, high AI priority. |
| Aetherglass Seam | Glass Uplands, Confluence | Persistent economy | Rare arcane output, heavy guard. |
| Crystal Orchard | Sunvault | Persistent economy | Aetherglass weekly yield, relay synergy. |
| Peat Cut | Drowned Marches | Persistent economy | Peatwax output, Mireclaw value. |
| Graft Nursery | Walking Green, Thornwake | Persistent economy | Verdant grafts, link bonuses, recapture value. |
| Renewal Grove | Walking Green | Persistent economy / support | Growth/recovery, damaged-state candidate. |
| Debt Foundry | Brass Deeps, Brasshollow | Persistent economy | Brass scrip, capital project pressure. |
| Pump House | Brass Deeps | Persistent economy / transit | Ore/scrip support and route repair hook. |
| Memory-Salt Wreck Field | Veil Coast | Persistent economy | Memory salt weekly yield, salvage guards. |
| Salvage Camp | Veil Coast, rough coast | Persistent economy / service | Burst rewards, market/trade hooks. |
| Mirror Shoal | Veil Coast, Confluence | Persistent economy / guarded | Memory salt/aetherglass, fog-route tie. |
| Old Measure Anchor | Confluence | Persistent economy / objective | Rare scenario resource or spell infrastructure. |

### Transit And Route-Control Sites

| Family | Regions/factions | Primary class | Notes |
| --- | --- | --- | --- |
| Toll Bridge Court | Emberflow, Embercourt | Transit / interactable | Crossing control, road income, possible guard. |
| Lock Gate | Emberflow | Transit | Opens or shortens river-adjacent route. |
| Chain Ferry | Drowned Marches, Mireclaw | Transit | Shortcut with toll, capture, or ambush expectation. |
| Drowned Causeway | Drowned Marches | Transit / blocker | Repair/claim to open safe route. |
| Prism Road Marker | Glass Uplands, Sunvault | Transit / scouting | Sightline and movement clarity. |
| Relay Crown | Glass Uplands | Transit / support | Vision/spell infrastructure, capture state. |
| Root Gate | Walking Green, Thornwake | Transit | Conditional movement, route taxation. |
| Living Bridge | Walking Green | Transit / support | Grows or repairs over time. |
| Pressure Rail Switch | Brass Deeps, Brasshollow | Transit | Heavy logistics, repair, AI route value. |
| Slag Road Gate | Brass Deeps | Transit / blocker | Industrial chokepoint, guardable. |
| Fog Slip | Veil Coast, Veilmourn | Transit | Bypass route, scouting/fog rules. |
| Bell Dock | Veil Coast | Transit / scouting | Coastal travel and warning. |
| Mirror Gate Ruin | Confluence | Transit / guarded | Late or scenario-gated route object. |
| Caravanserai Yard | Cross-region | Transit / service | Recovery, market, route midpoint. |

### Shrines, Services, And Support Sites

| Family | Regions/factions | Primary class | Notes |
| --- | --- | --- | --- |
| Beacon Court Shrine | Embercourt | Interactable service | Morale/readiness, route reveal. |
| Public Ration Depot | Emberflow | Repeatable service | Recovery and embergrain sink. |
| Drum Island Shrine | Mireclaw | Shrine / service | Movement pressure, rot/mire magic hook. |
| Sporewake Post | Drowned Marches | Shrine / guarded | Recovery denial spell or risky service. |
| Lens Choir Plinth | Sunvault | Shrine / spell access | Spell refresh, scouting, aetherglass cost. |
| Buried Observatory | Glass Uplands | Scouting / guarded | Reveal, spell clue, artifact chance. |
| Pilgrim Clearing | Thornwake | Support / service | Recovery, root favor, renewal. |
| Graft Hall Outpost | Thornwake | Service / economy support | Verdant grafts and site-link logic. |
| Boiler Chapel | Brasshollow | Service | Repair/readiness, scrip cost. |
| Contract Office | Brasshollow | Market/service | Scrip exchange, hire/repair. |
| Obituary Vault Kiosk | Veilmourn | Service / guarded | Memory salt, morale, salvage clue. |
| Lantern Reef | Veil Coast | Scouting / service | Fog reveal and route safety. |
| Old Measure Shrine | Confluence | Shrine / guarded | Rare magic, artifact clue, scenario state. |

### Neutral Dwellings

The current 25 neutral dwelling families are a strong seed but need production classification, placement rules, art gates, and role spacing.

Target dwelling subfamilies:

| Subfamily | Example Aurelion families | Role |
| --- | --- | --- |
| Road companies | Roadward Lodge, Frostbeacon Bothy, Caravan Guard Yard | Reliable neutral line/ranged recruits near roads. |
| Marsh contracts | Fenhound Kennels, Reedbarge Mooring, Bogchain Den | Fast, ambush, ferry, and wetland route recruits. |
| Ridge and sky posts | Cliffhawk Roost, Windglass Eyrie, Snowmarker Camp | Scouting and mobility flavor, highland gates. |
| Underway crofts | Glowcap Croft, Deep Lantern Ward, Rootcellar Post | Defensive/support recruits in caves and forests. |
| Salvage yards | Dustjack Yard, Tidepool Skiffyard, Wreckhand Camp | Opportunistic ranged or utility neutrals. |
| Furnace auxiliaries | Cinder Kiln, Kilnward Yard, Pumpguard Barracks | Durable industrial neutrals. |
| Orchard militias | Orchard Levy Grounds, Bramble Hedge, Pilgrim Thorn Camp | Defensive, slowing, recovery-linked neutrals. |
| Coast crews | Skiffyards, Bell Buoy Crews, Fog Pole Watch | Transit and route-control neutrals. |

Neutral dwellings must not become a seventh faction ladder. Each family should be local, limited, and strategically useful without replacing playable faction identity.

### Overworld Neutral Encounters

Neutral encounters need their own visible object model separate from dwellings and reward sites.

Target encounter families:

| Family | Regions | Purpose |
| --- | --- | --- |
| Tollbreak Band | Emberflow, roads | Blocks bridges, guards writ caches, punishes road greed. |
| Flood Strays | Emberflow, Drowned Marches | Low/mid beast pressure near water. |
| Reed Ambushers | Drowned Marches | Explicit ambush cue on side lanes. |
| Bogplate Patrol | Drowned Marches | Heavier marsh guard for peat and ferry objects. |
| Shardblinded Pilgrims | Glass Uplands, Confluence | Risk around crystal and mirror ruins. |
| Lens-Mad Sentinels | Glass Uplands | Guard observatories and aetherglass seams. |
| Rootbound Watch | Walking Green | Blocks logging roads and graft sites. |
| Orchard Debt Collectors | Walking Green, Emberflow | Human-scale neutral conflict, not monsters. |
| Railjack Raiders | Brass Deeps | Contest mines, pump houses, rail switches. |
| Slag Furnace Remnants | Brass Deeps | Dangerous industrial guard ecology. |
| Wreckclaim Crews | Veil Coast | Guard salvage and memory-salt sites. |
| Fog-Lost Companies | Veil Coast, Confluence | Morale/memory threat on fog lanes. |
| Mirror-Shard Wardens | Confluence | Elite neutral guards for Old Measure rewards. |
| Charter War Deserters | Cross-region | Flexible neutral army, should carry regional props. |

Encounter placement rules:

- Static guards should visibly face or occupy the route they block.
- Roaming/patrol encounters can come later, but the taxonomy should reserve that role.
- Encounter art must show unit/army presence, not a building silhouette.
- Guarded object plus neutral encounter should read as two linked things, not one confusing pile.

### Guarded Reward Sites

| Family | Regions/factions | Reward direction |
| --- | --- | --- |
| Mirror Calibration Ruin | Confluence, Glass Uplands | Spell, aetherglass, Old Measure artifact clue. |
| Broken Toll Archive | Emberflow | Gold, road reveal, Embercourt artifact hook. |
| Flooded Granary Vault | Emberflow/Drowned Marches | Embergrain, recovery, light artifact chance. |
| Drowned Causeway Treasury | Drowned Marches | Peatwax, ambush risk, route unlock. |
| Mudglass Ossuary | Drowned Marches | Mire Accord spell, morale/risk consequence. |
| Sunken Observatory | Glass Uplands | Scouting, spell, aetherglass. |
| Prism Choir Crypt | Sunvault | Lens artifact, heavy guard. |
| Orchard Grave | Walking Green | Verdant grafts, renewal spell, rootbound guard. |
| Broken Nursery Engine | Walking Green | Site repair, growth, Thornwake artifact clue. |
| Debt Foundry Vault | Brass Deeps | Brass scrip, ore, contract artifact. |
| Pressure Rail Arsenal | Brass Deeps | Unit support, repair, heavy guard. |
| Obituary Vault | Veil Coast | Memory salt, morale magic, Veilmourn artifact clue. |
| Mirror Drowned Wreck | Veil Coast | Salvage spike, fog encounter, hidden reward. |
| Shardfall Crater | Confluence | High-risk rare reward, objective candidate. |

### Faction Landmarks

Faction landmarks should let a player recognize influence before reading text.

| Faction | Landmark families | Map function |
| --- | --- | --- |
| Embercourt League | Beacon Court, Tollstone Weir, Granary Lock Exchange, Road Court Pillar | Road security, recovery, civic economy, visibility. |
| Mireclaw Covenant | War Drum Circle, Chainboom Ferry, Blackwater Shrine, Fen Toll Marker | Ambush pressure, ferry routes, mire services, wounded-prey identity. |
| Sunvault Compact | Relay Crown, Lens Choir Plinth, Prism Yard, Shard Survey Station | Sightlines, spell infrastructure, crystal economy. |
| Thornwake Concord | Root Gate, Graft Nursery Marker, Pilgrim Clearing, Thorn Toll Arch | Route taxation, recovery, living-site links. |
| Brasshollow Combine | Pressure Rail Switch, Boiler Chapel, Contract Office, Pump House | Mine logistics, repair, scrip economy. |
| Veilmourn Armada | Bell Dock, Fog Slip, Obituary Vault Marker, Salvage Claim Mast | Fog lanes, memory salt, scouting, salvage spikes. |

Landmarks may be owned or neutral, but the silhouette must make faction influence clear without becoming a town replacement.

## Biome And Region Variants

Every major object family should support region variants where it appears often.

Variant dimensions:

- Material: pale stone, wet timber, mudglass, blue-violet crystal, pale bark, brass, black lacquer, salt stone.
- Grounding: dry road dust, marsh waterline, ridge shadow, root intrusion, slag bed, fog wash, shard rubble.
- Approach side: front gate, dock side, bridge end, tunnel mouth, root arch, rail switch, stair terrace.
- State: neutral, owned, captured, damaged, depleted, guarded, active, exhausted.
- Animation: fire, water wheel, bell sway, lens glint, reed movement, root pulse, furnace glow, fog drift.

Do not create a new bespoke object for every biome if the core function is identical. Use variants when they improve readability, faction identity, or placement believability.

## Faction Variants

Faction variants are justified when ownership or culture changes how an object looks or behaves.

Examples:

- A generic bridge becomes an Embercourt Toll Bridge Court after ownership: red signal ceramic, public writs, visible patrol.
- A ferry crossing under Mireclaw influence gains chainboom posts, drum markers, and ambush warning cues.
- A scouting tower under Sunvault influence becomes a lens relay with crystal alignment props.
- A timber site under Thornwake influence becomes a graft-managed renewal grove rather than a logging camp.
- An ore quarry under Brasshollow influence gains rail hooks, gauges, and contract banners.
- A coastal dock under Veilmourn influence becomes a fog slip with bells, obituary marks, and salvage lights.

Faction variants should not hide function. The player should still recognize mine, transit, shrine, dwelling, or reward class first.

## Ownership And Capture States

Persistent and route-control objects need state readability.

Minimum states:

- Neutral unclaimed
- Guarded neutral
- Owned by player
- Owned by enemy
- Contested or occupied by neutral encounter
- Damaged / disabled
- Depleted / exhausted
- Recently captured / recovery timer

State visual rules:

- Ownership should use compact banners, lamps, signal details, or material changes, not large UI shields covering the object.
- Damaged state should alter the object silhouette or activity: broken wheel, dark furnace, slack chain, cracked lens, wilted root, silent bell.
- Depleted pickups should usually disappear; depleted sites should visibly exhaust only when they remain tactically relevant.
- Capture state must be readable in hover/selection summaries without requiring a large report panel.

## Animation Hooks

Animation requirements should be planned before final object art.

Object animation categories:

- Idle life: smoke, waterwheel, bell sway, flags, lantern flicker, lens glint, furnace pulse, fog drift, reed movement, root twitch.
- Visit feedback: flash, chime, gate open, cache lift, ferry shift, rail switch throw, shrine pulse.
- Capture feedback: banner raise, lamp change, wheel restart, chain tighten, root bloom, gauge reset.
- Damaged feedback: sputter, broken rotation, cracked lens blink, dim bell lamp, leaking boiler, wilted graft.
- Guard feedback: patrol pacing, campfire, hostile banner, warning glow, circling shape.
- Exhausted feedback: empty crate, closed hatch, dark shrine, collapsed pile, covered cache.

Animation should serve readability first. Small constant motion is useful around interactable sites, but decoration should not animate so much that it competes with heroes, towns, guards, or path cues.

## Concept-Art Stage Gates

This taxonomy depends on `docs/concept-art-pipeline.md`.

Before broad JSON migration, map placement, or final runtime object art:

- Generate regional decoration sheets for Emberflow, Drowned Marches, Glass Uplands, Walking Green, Brass Deeps, Veil Coast, and Ninefold Confluence.
- Generate object-family sheets for pickups, persistent resource fronts, transit objects, shrines/services, guarded reward sites, neutral dwellings, neutral encounters, and faction landmarks.
- For every accepted family, annotate primary class, secondary roles, footprint, approach side, passability, reward/risk read, ownership states, damaged/depleted state, animation hooks, and production feasibility.
- Reject generated studies that read as UI tokens, generic fantasy props, copied map objects, huge scenic paintings with no gameplay function, or clutter that hides pathing.
- Keep generated studies in `art/concept/`; do not treat generated images as runtime assets.

Object art is not approved for implementation until the class is readable at strategy-map scale without text labels.

## Map Editor Implications

The in-project map editor eventually needs object authoring features aligned to this taxonomy.

Future editor requirements:

- Object palette grouped by primary class and filtered by region/biome/faction.
- Placement preview showing footprint, blocked tiles, approach tile, and visit direction.
- Validation overlay for ambiguous approach tiles, blocked paths, unreachable rewards, and overcrowded clusters.
- Guard-link authoring: encounter guarding object, object guarded by encounter, patrol lane, or route block.
- Ownership/capture state authoring for persistent economy and route sites.
- Damaged/depleted state authoring for scenario starts.
- Density diagnostics per local region: decoration count, interactable count, pickups, guards, economy sites, transit sites, landmarks, negative-space warnings.
- Concept-art readiness marker by object family so map authors know which families are placeholders.

Editor composition rule: placement aids may appear in editor overlays, but live gameplay must not show helper grids, footprint glyphs, or approach arrows as permanent scenery.

## Validation And Testing Gates

Before the object model is production-deep, validation should prove:

- Every map object has a primary class, family, footprint, passability, visitability, and role tags.
- Every visitable object has a valid approach rule.
- Every blocking object has valid occupancy and does not isolate required routes unless it is an intentional gate.
- Every persistent economy object has output, ownership state, capture profile, and UI summary metadata.
- Every neutral dwelling links to a neutral dwelling family, recruit roster, guard profile, site id, encounter id, and map object id.
- Every neutral encounter has difficulty, army payload, visible map classification, reward/guard role, and battle routing.
- Every guarded reward site has guard expectation, reward category, and visible risk cue.
- Every transit object has route effect metadata and validation that both endpoints remain coherent.
- Every faction landmark has faction identity metadata and does not masquerade as a town.
- Density validation catches cluttered 16x16 regions, sparse empty stretches, blocked approach tiles, and stacked visitables.
- Save/load preserves object state: collected, owned, damaged, depleted, visited, guarded, captured, and route-open states.
- AI can value object categories for capture, defense, bypass, scouting, and raiding.
- UI snapshots expose object class, owner, risk, reward category, route effect, and state in compact hover/selection payloads.

Manual play gates:

- A player can tell decoration from interactable objects without clicking every tile.
- A player can identify guard risk before committing.
- A player can understand why a persistent site matters.
- A player can read route objects as route decisions.
- A player sees faction and region identity through object placement rather than lore panels.
- Dense areas still leave clear paths, hero focus, town presence, and negative space.

## Migration Sequence

1. Freeze this document as the taxonomy and density target.
2. Add schema design notes for primary class, secondary roles, footprint body, approach tiles, passability, ownership states, and guard links.
3. Extend validators before adding broad content so bad placement fails early.
4. Define a small object registry with class metadata while keeping existing content behavior stable.
5. Migrate current `map_objects.json` entries into the new taxonomy without changing gameplay balance.
6. Convert existing neutral dwellings into explicit dwelling subfamilies with approach, guard, state, and art-gate metadata.
7. Add a first decoration/blocker set per major region as non-interactable map vocabulary.
8. Add pickup families that support the economy plan, including future resources while preserving `wood` compatibility until the resource decision is made.
9. Add persistent resource-front families from the economy plan.
10. Add transit/route objects and validation around route effects.
11. Add neutral encounter object models separate from dwellings and resource sites.
12. Add guarded reward families with explicit risk/reward tiers.
13. Add faction landmark families after concept-art review for each faction.
14. Upgrade map-editor placement previews and density diagnostics.
15. Place object mixes in a test scenario region by region, then manually play for readability, pathing, risk comprehension, and clutter.
16. Only after this proves stable, use the taxonomy for campaign/skirmish map production.

## Deep-Enough Gate For Maps

Overworld object foundations are deep enough for broader campaign/skirmish map production only when:

- Each major Aurelion region has decoration, pickups, economy fronts, transit, shrine/support, neutral encounter, guarded reward, and landmark vocabulary.
- At least two factions have concept-art-reviewed landmark and economy-site variants.
- Neutral encounters are visibly distinct from dwellings and guarded sites.
- Footprints and approach rules are validated and visible in the editor.
- Density checks prevent maps from becoming empty grids or cluttered object carpets.
- Manual play proves that players can read class, risk, reward, route, ownership, and faction identity without large panels covering the map.

Until then, current object content remains useful scaffolding, not production-depth object design.
