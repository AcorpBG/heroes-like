# Economy Overhaul Foundation

Status: design source, not implementation proof.
Date: 2026-04-25.
Slice: economy-overhaul-foundation-10184.

## Purpose

This document defines the target economy foundation for Aurelion Reach before content JSON migration, broad campaign/skirmish maps, final town polish, or balance claims. The goal is not to add more colored costs. The goal is to make resources express geography, faction identity, route control, town development, recruitment choices, AI pressure, and readable map conflict.

Heroes 2, Heroes 3, and Oden Era may inform expectations for strategic density, map readability, and resource pressure only. They are not source material for names, art, maps, factions, object layouts, or text.

## Current Baseline And Gap

Current authored content uses a narrow economy:

- `gold` is the dominant cost, reward, hero-hire cost, recruitment cost, site reward, and service cost.
- `wood` and `ore` exist as construction and reward resources, with some unit and site costs.
- Resource sites in `content/resource_sites.json` already support useful production concepts: one-shot rewards, persistent control, `control_income`, guarded sites, repeatable services, response profiles, transit profiles, town support, and scouting structures.
- Scenario starts, campaign caps, scripted rewards, raid pillage, encounters, units, towns, factions, heroes, and artifacts are currently balanced around the three-resource baseline.

The gap is strategic depth:

- Faction economy differences are mostly numeric, not world-defining.
- Mines are not yet a full family of contested resource fronts.
- Site control does not yet create enough counter-capture, escort, route, or logistics pressure.
- Town building and recruitment costs cannot yet force distinct faction priorities.
- Market behavior is too shallow to preserve scarcity once more resources exist.
- AI cannot plan around faction-specific shortages until resources, sites, costs, and exchange limits are explicit.
- UI has no proof that a larger economy remains readable without covering the map or town with panels.

## Target Resource Set

The target economy uses nine resources at full foundation depth. Migration should stage these in carefully; the final set can still be reduced if testing proves it is too wide.

| Resource | Target id | Category | World meaning | Strategic use |
| --- | --- | --- | --- | --- |
| Gold | `gold` | Liquidity | Wages, contracts, tolls, bribes, market smoothing | Universal spending, hero hire, services, low-tier recruitment |
| Timber | `timber` | Construction | Roads, boats, halls, siege frames, root rites | Buildings, road/ferry repair, wooden units, Thornwake/Embercourt pressure |
| Ore | `ore` | Construction | Armor, tools, fortifications, machines, lens mounts | Defenses, heavy units, Sunvault/Brasshollow pressure |
| Aetherglass | `aetherglass` | Arcane material | Mirror and lens fragments | Magic buildings, relays, artifacts, high-tier Sunvault costs |
| Embergrain | `embergrain` | Supply | Preserved food and lamp fuel | Readiness, recovery, town growth, long-route operations |
| Peatwax | `peatwax` | Local fuel/medium | Marsh fuel, sealant, rot rite medium | Mireclaw growth, ferries, recovery denial, mire services |
| Verdant grafts | `verdant_grafts` | Living material | Cuttings, root bonds, nursery stock | Thornwake buildings, renewal, regeneration, rooted sites |
| Brass scrip | `brass_scrip` | Industrial credit | Furnace contracts and machine debt | Brasshollow capital projects, repair windows, acceleration |
| Memory salt | `memory_salt` | Salvage/memory medium | Fog charts, obituary ledgers, salvage claims | Veilmourn routes, morale magic, artifacts, hidden-object rewards |

Compatibility note: existing JSON uses `wood`. A future migration should either alias `wood` to display as Timber or migrate authored ids to `timber` through a save-aware compatibility layer. Do not casually rename the resource id until content validation, save migration, UI, and tests are ready.

## Resource Categories

Resources should behave differently by category instead of sharing one generic stockpile feel.

- Liquidity: Gold is frequent, flexible, and smooths mistakes. It should rarely be the only blocker for high-tier power.
- Construction staples: Timber and ore are stable map-control resources. They should come from mines/fronts and drive town shape.
- Arcane material: Aetherglass is scarce, guarded, and often tied to spell infrastructure, artifacts, relays, and high-quality upgrades.
- Supply resources: Embergrain supports readiness, recovery, growth, and expedition tempo. It should be consumed by long campaigns and recovery loops.
- Local fuel/rite resources: Peatwax and verdant grafts should matter most where their faction, region, or site network makes them productive.
- Contract/salvage resources: Brass scrip and memory salt are not normal mined goods. They should come from contracts, salvage, rail/fog sites, battle cleanup, and special services.

## Faction Economy Behavior

### Embercourt League

Embercourt should feel reliable and civic. It prefers gold, timber, embergrain, and road-linked income.

- Strengths: steady town income, efficient low/mid recruitment near controlled roads, strong recovery when granary and beacon chains are held.
- Shortages: aetherglass and memory salt should remain awkward without trade or conquest; ore should be adequate but not effortless.
- Sites it values: tollhouses, timber yards, embergrain granaries, bridge bastions, beacon courts, mills, river locks.
- Cost profile: broad but fair costs, with support buildings reducing gold friction and embergrain supporting readiness/recovery.
- Strategic behavior: holds crossings, retakes road economy quickly, benefits from contiguous public infrastructure more than scattered mines.

### Mireclaw Covenant

Mireclaw should feel unsafe to ignore and difficult to starve in the marsh. It prefers peatwax, raid spoils, den growth, ferry control, and cheap replacement.

- Strengths: low-cost replacement loops, early growth, value from counter-capture and raiding exposed sites.
- Shortages: formal ore, aetherglass, and brass scrip should be inefficient; safe gold income should be weaker than Embercourt.
- Sites it values: peat cuts, ferry chains, reed caches, beast dens, shrine drums, drowned causeways, ambush posts.
- Cost profile: low-tier units and den upgrades lean on gold/peatwax; elite finishers require scarce inputs so losses hurt.
- Strategic behavior: raids mines and routes instead of only rushing towns; makes opponents pay to keep distant sites.

### Sunvault Compact

Sunvault should feel precise, costly, and quality-driven. It prefers ore, aetherglass, relay-linked spell infrastructure, and prepared fronts.

- Strengths: efficient use of aetherglass, strong magic building value, high-quality units when relay sites and ore lines are secure.
- Shortages: timber and embergrain should constrain expansion tempo; peatwax and memory salt are peripheral.
- Sites it values: crystal orchards, lens galleries, prism roads, relay crowns, observatories, aetherglass quarries.
- Cost profile: fewer cheap shortcuts; buildings and high-tier units need ore/aetherglass and should reward planning.
- Strategic behavior: secures sightlines and relay nodes before committing to expensive upgrades.

### Thornwake Concord

Thornwake should feel slow-starting and compounding. It prefers timber, verdant grafts, renewal sites, nurseries, and long-term recovery.

- Strengths: site-link bonuses, regrowth, recovery, and route taxation once root networks mature.
- Shortages: direct gold should be weaker; ore, brass scrip, and aetherglass are specialized rather than core.
- Sites it values: graft nurseries, rooted groves, living orchards, root gates, pilgrim clearings, renewal shrines.
- Cost profile: buildings use timber and verdant grafts; some upgrades reach full value only while linked sites remain controlled.
- Strategic behavior: seeds territory, defends networks, counter-captures to restore links, and wins by making routes costly.

### Brasshollow Combine

Brasshollow should feel capital-intensive and hard to uproot. It prefers ore, brass scrip, furnace throughput, mine control, railheads, and repair windows.

- Strengths: durable infrastructure, strong late projects, repair economies, excellent use of ore and scrip.
- Shortages: timber and embergrain should constrain early expansion; memory salt and verdant grafts are awkward.
- Sites it values: ore quarries, pressure rails, debt foundries, pump houses, furnace chapels, slag roads, machine yards.
- Cost profile: expensive buildings and units, lower growth, heavy ore/scrip needs, high penalty for losing production chains.
- Strategic behavior: protects mines, builds rail-linked staging, commits to objectives after capital setup.

### Veilmourn Armada

Veilmourn should feel opportunistic and information-led. It prefers memory salt, salvage, scouting rewards, fog routes, and uneven income spikes.

- Strengths: burst income from wrecks and hidden sites, good rewards from scouting and battle cleanup, flexible route bypass.
- Shortages: steady gold, ore, and timber should be less reliable; brass scrip is mostly ransom/exchange value.
- Sites it values: memory-salt wreck fields, bell docks, fog slips, mirror shoals, obituary vaults, salvage camps, lighthouses.
- Cost profile: mid/high units and magic need memory salt; some recruitment discounts come from recent salvage or scouted route marks.
- Strategic behavior: scouts aggressively, avoids honest static races, raids weak backline resources, cashes out spikes before being pinned.

## Mine And Resource-Site Classes

The word mine should become a gameplay family, not one visual. Every persistent economy site needs a resource identity, guard expectation, approach side, capture state, and concept-art classification.

Core classes:

- Civic production: mills, tollhouses, granaries, timber yards. Mostly gold/timber/embergrain and road-linked bonuses.
- Extraction fronts: ore quarries, aetherglass seams, peat cuts, crystal orchards, slag pits. Guarded or exposed based on value.
- Living production: graft nurseries, rooted orchards, renewal groves. Often linked and vulnerable to counter-capture.
- Industrial finance: debt foundries, scrip offices, pressure rail depots. Produce brass scrip or acceleration value.
- Salvage fronts: wreck fields, obituary vaults, mirror shoals, fog salvage camps. Produce memory salt and burst rewards.
- Transit economy: ferry stages, rail switches, root gates, fog slips, bridge bastions, prism road markers. Often pay less directly but modify route value.
- Support sites: watchtowers, relays, shrines, infirmaries, caravanserais. These improve scouting, recovery, market access, or local costs.

Each class should define:

- `site_class`
- `resource_outputs`
- `claim_reward`
- `daily_income`
- `weekly_yield`
- `guard_profile`
- `capture_profile`
- `counter_capture_value`
- `route_affinity`
- `faction_preference_weights`
- `art_direction_family`

This is a future schema direction, not an instruction to edit JSON in this slice.

## Pickups

Pickups should remain small pacing objects and should not replace persistent control sites.

Pickup types:

- Simple cache: one or two resource types, low guard or none.
- Route cache: appears near roads, ferries, rail lines, root gates, or fog lanes; supports movement/recovery decisions.
- Faction-flavored cache: writ bundles, peatwax votives, crystal lots, seed packets, gauge cases, salvage crates.
- Scouting pickup: reveals a nearby site or fog pocket and may grant memory salt, aetherglass, or map information.
- Recovery pickup: embergrain, infirmary supplies, graft bundles, peat remedies, morale objects.
- Guarded small reward: should be visually distinct from major guarded sites and carry low-to-medium risk.

Pickups must read as world objects, not UI tokens. Concept-art object-family sheets should cover cache silhouettes before broad production placement.

## Daily And Weekly Income Model

The economy should use both daily and weekly rhythm.

Daily income:

- Town base income, faction modifiers, and controlled site income tick at day advance.
- Gold should be the most common daily resource.
- Timber, ore, peatwax, and embergrain can be daily when tied to stable production.
- Aetherglass, verdant grafts, brass scrip, and memory salt should usually be slower, conditional, guarded, or burst-based.
- Route-linked bonuses can add small daily income only when paths remain controlled.

Weekly rhythm:

- Unit growth and recruit pool refresh happen weekly.
- Some sites produce weekly yields instead of daily trickles: crystal orchards, graft nurseries, scrip offices, wreck fields.
- Repeatable services refresh weekly.
- Markets refresh exchange caps weekly.
- AI planning should re-evaluate shortages at weekly boundaries.

No resource should require tedious manual pickup every day. The player should care about capturing, defending, and routing, not collecting a chore list.

## Town Development Costs

Town development should expose faction identity through costs.

Cost rules:

- Low-tier recruitment buildings use gold plus one faction-appropriate staple.
- Economy buildings use the resource they improve, plus gold, to create early tradeoffs.
- Magic buildings require the faction accord resource or aetherglass.
- Defensive upgrades use ore/timber/gold with faction bias.
- High-tier dwellings require two or three resources and should create map-control pressure.
- Capstone buildings require a rare faction resource and should not be reachable through market exchange alone.

Examples:

- Embercourt beacon and granary buildings: gold, timber, embergrain, small aetherglass for advanced beacon logic.
- Mireclaw dens and shrine drums: gold, peatwax, timber, occasional ore for bogplate infrastructure.
- Sunvault relays and batteries: gold, ore, aetherglass, small embergrain for supply.
- Thornwake nurseries and root gates: timber, verdant grafts, gold, rare aetherglass for Old Measure graft studies.
- Brasshollow furnaces and rail terminals: gold, ore, brass scrip, small embergrain for worker rations.
- Veilmourn harbors and obituary vaults: gold, timber, memory salt, occasional aetherglass for mirror charts.

## Recruitment Costs

Recruitment should force roster choices without making low-tier recovery impossible.

- Tier 1 and 2 units should mostly cost gold and one common staple only when faction identity demands it.
- Tier 3 and 4 introduce faction resources in light amounts.
- Tier 5 and 6 require a meaningful faction resource or construction material.
- Tier 7 requires rare resource pressure and should make site control matter.
- Neutral dwellings should use gold plus local resource flavor, but should not undercut faction identity.
- Some factions can have non-cost recruitment constraints: route link, recent salvage, den control, root network maturity, relay readiness, repair window.

Recruitment scarcity should shape play but not create unwinnable starts. Campaign and skirmish starts need minimum viable opening paths for each faction.

## Market And Exchange Limits

Markets should smooth bad luck without flattening faction differences.

Rules:

- Global perfect exchange is not allowed.
- Exchange rates are asymmetric and unfavorable.
- Weekly exchange caps prevent buying a capstone from gold alone.
- Markets should distinguish common construction resources from rare faction resources.
- Town markets can have faction flavor: Embercourt public exchanges, Mireclaw ferry barter, Sunvault calibrated lots, Thornwake renewal pacts, Brasshollow contracts, Veilmourn salvage brokers.
- Some resources are restricted until the player discovers or controls a matching site class.
- Scenario markets can be disabled, capped, or scripted when scarcity is the point.

Suggested exchange stance:

- Gold can buy limited timber/ore at poor rates.
- Timber and ore can trade into each other at worse rates through market sites.
- Aetherglass, verdant grafts, brass scrip, and memory salt require special markets or site control.
- Faction resources should have sell value but limited buy availability.

## Capture And Counter-Capture Loops

Persistent economy sites need active map contest.

Baseline loop:

1. Scout a site and understand its reward class.
2. Clear guards or pay/solve a route requirement.
3. Capture the site and receive claim reward.
4. Site begins daily or weekly output.
5. Opponent pressure evaluates the site as a target based on faction needs and route exposure.
6. Counter-capture interrupts income, may pillage stock, and may weaken linked routes or town bonuses.
7. Player decides whether to retake, defend, reroute, trade, or race another objective.

Counter-capture should not be pure frustration:

- The UI must show why a site matters and what was lost.
- Important sites should offer defense investments, patrol response, garrison hooks, or route fortification.
- Some factions should counter-capture differently: Mireclaw raids, Thornwake roots, Brasshollow audits, Veilmourn salvage theft, Sunvault relay interdiction, Embercourt legal retaking.
- Recovery after retake can include damaged-state timers rather than all-or-nothing permanent loss.

## Route And Logistics Model

Routes should matter because Aurelion Reach is about infrastructure conflict.

Roads:

- Embercourt and general civic routes improve reliable income, scouting, and defense response.
- Road-linked income should require contiguous or locally controlled route objects, not arbitrary map-wide ownership.

Ferries:

- Ferries support shortcut economy, marsh/coast control, and vulnerable crossings.
- Mireclaw and Veilmourn can gain extra value from ferry or water-adjacent economy.

Rails:

- Brasshollow pressure rails should support heavy logistics, repair, and mine chains.
- Rails are high value and high target priority.

Fog lanes:

- Veilmourn fog routes enable scouting, salvage, bypass, and hidden-object discovery.
- Player-facing states must be explicit; fog should hide enemy intent, not confuse the owning player.

Root networks:

- Thornwake roots link nurseries, gates, recovery, and road taxation.
- Root links should grow over time and become important counter-capture targets.

Prism roads and relays:

- Sunvault routes amplify vision, aetherglass use, and spell access.
- Relay breaks should create visible strategic consequences.

Route logistics should not require a full supply-line simulation before alpha, but the first implementation must support local route bonuses, route site dependencies, and readable interruption.

## Scarcity Pressure

Scarcity must create choices, not random dead ends.

Pressure types:

- Opening scarcity: early town/recruitment choices force priorities but allow recovery.
- Regional scarcity: map regions favor certain factions or resource classes.
- Conflict scarcity: opponents target resources that block player growth.
- Temporal scarcity: weekly growth, service refresh, and rare-site yields create timing windows.
- Opportunity scarcity: using a resource for recruitment delays town development or market smoothing.

Avoid:

- Starting positions with no reachable path to a required early resource.
- Too many rare resources required at once.
- Market exchange that erases map identity.
- Hidden dependencies where the player cannot tell why they are blocked.

## AI Economy Requirements

Strategic AI cannot treat all resources as generic score.

Required AI concepts:

- Resource need model by faction, town, current build plan, recruitment plan, and enemy pressure.
- Site valuation that understands daily income, weekly yield, rare resource bottlenecks, route bonuses, and counter-capture value.
- Build/recruit planning that can choose between economy, military, magic, defense, market trade, and hero hiring.
- Shortage response: capture target, defend target, trade, delay build, recruit cheaper stacks, raid opponent resource, or pivot objective.
- Route awareness: roads, ferries, rails, fog lanes, roots, and relays alter travel and target priority.
- Pillage/counter-capture behavior tuned per faction.
- Difficulty hooks that can adjust income, starting stock, exchange caps, and AI risk tolerance without changing core rules.
- Explainable debug summaries for AI decisions so validation can catch bad planning.

The first AI implementation does not need perfect strategy, but it must avoid starving itself, ignoring required resources, or targeting sites that do not support its faction.

## Save And Schema Implications

The overhaul affects saves and schema boundaries.

Required save considerations:

- Resource stockpile must accept new resource ids while preserving old saves.
- Save version should record resource schema version.
- Legacy `wood` must either persist as an alias or migrate to `timber` deterministically.
- Site ownership state must store capture owner, damaged/raided state, cooldowns, weekly-yield timers, route-link state, and optional garrison/patrol state.
- Market state must store weekly caps, discovered exchanges, and scenario restrictions.
- AI economy state may need cached plans, but caches must be rebuildable from authoritative save data.
- Scenario scripts that add resources must validate unknown resource ids and migration aliases.

Authored content schema implications:

- Resource definitions should become explicit content or a core registry, with display name, category, icon, color/material cue, market tier, and faction affinity.
- Unit, building, hero, artifact, site, encounter, campaign, scenario, and script rewards must all validate against that registry.
- Content validation should report resources that are unused, unproducible, unaffordable, or unavailable before required costs.

## UI Readability Requirements

The economy must remain readable under the screen composition rules.

Required UI stance:

- The top or footer resource display may show core resources compactly, but must not become a full-width spreadsheet.
- Common resources can be always visible; rare/faction resources can be grouped behind compact icons, tabs, or contextual popouts.
- Town build/recruit views must show missing resources at the point of decision.
- Overworld site hover/selection must show output, owner, risk, route effect, and capture state in compact form.
- Market UI must show exchange caps and poor rates clearly.
- Route bonuses and interruptions need concise map cues and tooltips.
- AI/opponent raids should explain which site/resource was targeted without dumping a report panel over the map.
- Resource icons must be concept-art reviewed for icon readability and material identity before final UI polish.

Screen rule: if showing all resources requires a large panel over the map, the design is wrong. Use compact rails, command spine entries, footer pockets, tabs, and contextual popouts.

## Concept-Art And Visual Stage Gates

This economy plan depends on `docs/concept-art-pipeline.md`.

Before broad resource-site JSON migration or final object art:

- Generate and review overworld object-family sheets for resource fronts: ore quarry, crystal orchard, peat cut, graft nursery, salvage foundry, embergrain yard, memory-salt wreck field, scrip office, and timber yard.
- Generate route-law and transit sheets for tollhouse, ferry chain, root gate, rail switch, fog slip, bridge bastion, and prism road marker.
- Generate pickup sheets for caches, cairns, carts, writ bundles, salvage crates, seed packets, gauge cases, peatwax votives, and crystal lots.
- Require object classification notes: decoration, pickup, persistent economy site, transit economy, support site, guarded reward site, or faction landmark.
- Require approach side, footprint, visit/capture read, material palette, damaged/captured state, and animation hooks.
- Keep generated studies in `art/concept/`; do not place generated output directly into runtime art folders.

Economy visuals must make resource type legible at map scale without text labels: quarry does not equal crystal orchard, peat cut does not equal timber yard, salvage wreck field does not equal memory vault.

## Validation And Testing Gates

Before the economy can be called production-deep, validation must prove:

- Every resource id is registered and has display metadata.
- Every cost resource can be produced, granted, traded, or deliberately scenario-blocked.
- Every faction has reachable opening costs in at least one test scenario.
- Every high-tier unit and capstone building has a plausible resource path.
- Market caps prevent rare-resource flattening.
- Daily and weekly income ticks are deterministic and save/resume safe.
- Site capture, counter-capture, damaged state, and recovery serialize correctly.
- AI can build, recruit, trade, capture, defend, and recover from shortages in smoke scenarios.
- UI validation snapshots expose enough labels/icons/counts to prove readability without relying on manual screenshots only.
- Concept-art stage gates are satisfied before final economy object art or broad placement.

Manual play gates:

- A player can understand why a resource matters.
- A player can identify where to get a missing resource.
- A player can recover from losing a key site.
- A player sees faction economy differences without reading a lore panel.
- Scarcity creates route and build choices instead of confusion.

## Migration Sequence

1. Freeze this document as the economy design target.
2. Add an explicit resource registry design and decide whether `wood` remains the internal id or migrates to `timber`.
3. Extend validators to understand resource metadata, aliases, and availability graphs.
4. Add schema support for new resources without changing gameplay balance yet.
5. Add UI icon placeholders and compact resource display rules behind validation snapshots.
6. Migrate site schemas first: outputs, categories, capture profiles, route affinity, and faction weights.
7. Add concept-art-reviewed resource-site and pickup families before broad map placement.
8. Migrate one or two factions vertically with town costs, recruitment costs, sites, AI weights, market access, and manual play notes.
9. Add market/exchange limits and save migration.
10. Expand to remaining factions only after the first vertical pair proves readable, affordable, and strategically distinct.
11. Retune campaigns/skirmishes after the economy model is stable, not before.

## Deep-Enough Gate For Campaign And Skirmish Maps

Economy gameplay is deep enough for campaign/skirmish map production only when all of the following are true:

- The target resource set or a deliberately reduced final set is locked.
- At least two factions have complete economy vertical slices: resources, town costs, recruitment costs, site preferences, market rules, AI weights, and manual play notes.
- Every resource has at least one persistent site class, one pickup or reward source, one UI icon/read, and one validation path.
- Mines/resource fronts have distinct visuals, capture behavior, income cadence, and counter-capture value.
- Daily and weekly income, recruitment growth, market caps, and save/resume are deterministic.
- AI can pursue and defend faction-relevant resources.
- Route logistics have at least local bonuses and interruptions for roads, ferries, rails, fog lanes, roots, or relays as applicable.
- Scarcity and exchange have been manually tested in at least one small map and one larger multi-faction map.
- Concept-art stage gates for resource sites, pickups, route objects, and economy UI have accepted review notes or documented placeholder exceptions.

Until then, broad maps may use economy placeholders, but they must not be called production-ready campaign or skirmish economy.
