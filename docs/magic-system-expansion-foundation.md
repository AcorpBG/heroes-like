# Magic System Expansion Foundation

Status: design source, not implementation proof.
Date: 2026-04-25.
Slice: magic-system-expansion-foundation-10184.

## Purpose

This document defines the target magic-system foundation for Aurelion Reach before spell JSON migration, artifact expansion, faction vertical slices, final battle polish, town polish, broad campaign maps, or balance claims. The goal is to turn the current small spell list into a production magic model with schools, tiers, tactical roles, adventure-map roles, faction preferences, unit interactions, economy costs, artifact hooks, AI requirements, save/schema implications, and validation gates.

Heroes 2, Heroes 3, and Oden Era may inform expected spell breadth, readability, and strategic density only. They are not source material for names, factions, spell text, art, icons, effects, maps, or mechanics.

## Current Baseline And Gap

The current `content/spells.json` is useful scaffolding, not a deep magic system.

Reality check as of this slice:

- The live spell catalog is small and mostly built from a few effect shapes: movement restoration, single-target damage, defense buffs, attack buffs, and initiative buffs.
- Several spells already carry good Aurelion flavor, including Beacon, Mire, Lens, Root, Furnace, and Veil names.
- Current spell data does not yet define schools, spell tiers, hero-school aptitude, faction access rules, counter-spells, resistance categories, battlefield area rules, terrain interactions, adventure-map targeting, resource costs beyond mana, research/building unlocks, artifact modifiers, AI casting heuristics, or schema migration.
- Spells do not yet prove campaign/skirmish readiness because they do not create enough different tactical decisions, map-planning decisions, or faction identity.

The missing work is not simply adding many spell records. The project needs a stable magic grammar that content, UI, combat rules, AI, concept art, save/load, validators, and scenario design can all share.

## Accord Model

Magic in Aurelion Reach is **accordance**: making matter, place, memory, and intention agree strongly enough that reality follows. Accordance should remain visible and material. Spells are not generic colored beams. They are anchored through infrastructure, tools, formations, terrain memory, and faction practice.

Core rules:

- Every spell has an accord family, even if it is neutral or cross-school.
- Every spell has an anchor language: bells, writs, drums, peatwax, lenses, choirs, roots, grafts, gauges, furnaces, fog bells, charts, mirror fragments, or old measuring stones.
- Magic redirects existing force: heat, light, movement, fear, memory, growth, pressure, morale, stored potential, and route knowledge. It should rarely create unlimited matter from nothing.
- Strong magic should leave readable residue: ash marks, glare scars, rot blooms, graft knots, slag heat, fog gaps, or mirror echoes.
- Battle spells and adventure spells should feel related. A route-reveal spell can have a battle mark variant; a battlefield bramble can have an overworld route-tax variant.

## Schools And Categories

The full target model uses seven accord schools. Six map closely to playable faction identities; one is rare, neutral, and tied to old mirror infrastructure.

| School | Core verbs | Primary faction affinity | Typical anchor language |
| --- | --- | --- | --- |
| Beacon Accord | reveal, steady, mark, rally, retaliate, route | Embercourt League | ash writs, court bells, signal braziers, tollstones, road marks |
| Mire Accord | blind, rot, drag, harry, deny recovery, finish wounded | Mireclaw Covenant | peatwax, reed masks, mudglass, chain hooks, war drums |
| Lens Accord | shield, calibrate, focus, dispel, reflect, cycle | Sunvault Compact | lenses, prisms, choirs, tuning forks, relay stones |
| Root Accord | bind, regrow, tax movement, cleanse, renew, zone | Thornwake Concord | grafts, thorns, root knots, seed masks, living bridges |
| Furnace Accord | heat, armor, repair, overpressure, breach, accelerate | Brasshollow Combine | pressure gauges, furnace clauses, debt seals, slag plates |
| Veil Accord | fog, displace, conceal, drain morale, steal memory, salvage | Veilmourn Armada | bells, obituary ink, mirror charts, fog lanterns, memory salt |
| Old Measure Accord | weather, time, mirror, world-memory, rare transposition | Neutral/ancient | cracked mirrors, measuring stones, sky marks, anchor pits |

Each spell also needs a role category:

- Damage: direct stack harm, line harm, splash harm, delayed harm, terrain harm.
- Buff: attack, defense, initiative, morale/momentum, retaliation, range, repair, regeneration.
- Debuff: blind, slow, stagger, harry, exposed, overpressured, rooted, memory-drained.
- Control: push, pull, bind, displace, block, reveal, silence, deny retaliation.
- Recovery: heal, repair, cleanse, restore movement, restore readiness, reduce casualties.
- Summon or terrain state: temporary brambles, fog banks, glare fields, heat vents, beacon marks.
- Economy or map utility: scouting, route opening, site renewal, resource yield, market/research support.
- Countermagic: dispel, ward, resist, reflect, cleanse, reveal hidden state.

## Spell Tiers

Spell tiers should be production constraints, not only mana numbers.

| Tier | Purpose | Battle expectation | Adventure expectation | Unlock expectation |
| --- | --- | --- | --- | --- |
| 1 | Common utility | Single-stack buffs/debuffs, small damage, cleanse-lite | Minor movement, reveal adjacent risk, small readiness | Basic hero skill, starting spellbooks, low shrine |
| 2 | Reliable role spells | Stronger single-target pressure, simple area, basic counters | Route support, site clue, guarded shrine rewards | Faction magic building level 1 or hero school rank |
| 3 | Midgame identity | Strong control, area zones, stack synergies, faction combos | Local route manipulation, scouting, site interaction | Magic building level 2, school specialization |
| 4 | Strategic power | Wide area, major counters, terrain control, summon/repair | Economy/site effects, gate-like travel, guarded rewards | Advanced buildings, rare shrines, artifact support |
| 5 | Capstone/rare | Battle-defining but counterable effects | Scenario-scale utility with limits | Capstone magic building, Old Measure site, high hero mastery |

Tier rules:

- Tier 1 and 2 spells must be readable and useful without deep combo knowledge.
- Tier 3 spells are where faction playstyles should become obvious.
- Tier 4 and 5 spells must have clear counters, costs, cooldowns, or targeting limits.
- Old Measure spells should be rare, map-defining, and scenario-controlled rather than a normal faction school ladder.

## Tactical Combat Roles

The battle spell system needs more roles than "damage or buff active stack."

Required battle role coverage:

- Priority damage: finish a weakened stack or punish elite concentration.
- Formation pressure: mark lanes, punish clumps, expose protected ranged stacks.
- Tempo control: alter initiative, delay action, force movement, deny charge windows.
- Area denial: create brambles, heat, fog, glare, mire, or beacon zones that affect positions.
- Ally sustain: heal, repair, cleanse, stabilize morale/cohesion, preserve elite stacks.
- Unit synergy: trigger faction unit keywords such as braced, harried, marked, rooted, repaired, fogged, overpressured, or calibrated.
- Counterplay: dispel buffs, cleanse debuffs, reveal hidden/fog states, break roots, cool heat, disrupt relays.
- Risk magic: strong Furnace and Mire effects can overheat, exhaust, consume residue, or create self-exposure when misused.

Battle implementation must eventually support target shapes:

- Self hero or acting stack.
- Allied stack, enemy stack, any stack.
- Tile, line, cone, radius, lane, zone, battlefield edge, corpse/remnant, summon point.
- Conditional target: road-marked enemy, wounded enemy, mechanical ally, rooted tile, fogged tile, guarded stack, marked site.

## Adventure-Map Roles

Adventure spells should not be only movement refill. They should create route, scouting, economy, and object decisions.

Required adventure role coverage:

- Movement support: restore movement, discount a terrain type, safely cross a route object, or return to a marked town.
- Scouting: reveal nearby sites, expose guarded risk, identify resource class, detect hidden fog lanes, preview neutral army family.
- Route control: open root gates, repair ferries, activate prism roads, fog-slip a short path, tax enemy route use.
- Site interaction: renew a depleted grove, restart a damaged pump, reveal a buried cache, calm a shrine, unlock a mirror ruin.
- Economy support: temporary yield boost, market cap refresh, resource conversion through a relevant site, town readiness support.
- Defensive logistics: recall patrols, reinforce owned sites, lay warning beacons, hide route value, root a chokepoint.
- Scenario utility: objective-specific calibration, evacuation fog, bridge oath, mirror alignment, weather window.

Adventure spells need explicit map constraints so they do not break scenarios:

- Range limits, line-of-route requirements, ownership requirements, terrain requirements, cooldowns, and resource costs.
- No unrestricted teleport or map reveal before scenario design, AI, save/load, and UI can support it.
- AI must understand any spell that changes route value, scouting, income, or site state.

## Faction Access And Preferences

Factions should have preferred schools, tolerated schools, and awkward schools. A faction can learn outside its identity, but costs, unlocks, and AI preferences should preserve asymmetry.

| Faction | Primary school | Secondary access | Awkward access | Casting personality |
| --- | --- | --- | --- | --- |
| Embercourt League | Beacon | Lens, Furnace, Old Measure civic rites | Mire, Veil | Stabilize lines, reveal routes, punish overextension, protect roads |
| Mireclaw Covenant | Mire | Veil, Root | Lens, Beacon public law | Blind, drag, deny recovery, finish wounded stacks, threaten exposed sites |
| Sunvault Compact | Lens | Beacon, Old Measure, Furnace calibration | Mire, Veil | Mark, shield, focus fire, dispel, win prepared turns |
| Thornwake Concord | Root | Mire, Beacon treaty marks, Old Measure renewal | Furnace extraction, Veil memory theft | Bind routes, regenerate, cleanse, tax movement, deny terrain |
| Brasshollow Combine | Furnace | Beacon contracts, Lens calibration | Root, Veil | Armor, repair, heat zones, breach defenses, manage overpressure |
| Veilmourn Armada | Veil | Mire, Beacon stolen marks, Old Measure mirror routes | Furnace, public Lens discipline | Conceal, displace, isolate, drain morale, salvage knowledge |

Access rules to evaluate in implementation:

- Heroes have school aptitude and mastery ranks.
- Town buildings define the normal school inventory for a faction.
- Shrines and guarded reward sites can teach off-school spells but may require costs or conditions.
- Artifacts can grant off-school access, reduce awkward-school penalties, or unlock hybrid spells.
- Campaign scenarios can restrict or seed spell access for narrative and balance.

## Unit Interactions

Spells must interact with unit roles, not just stat numbers.

Shared status keywords to consider:

- `marked`: easier to target or focus; Lens and Beacon use this often.
- `harried`: reduced cohesion/defense; Mire and Veil exploit this.
- `rooted`: movement constrained; Root creates and some units benefit from it.
- `fogged`: concealed or harder to target; Veil creates, Beacon/Lens reveal.
- `overpressured`: vulnerable to heat/breach follow-up; Furnace creates.
- `braced`: defense/retaliation state; Embercourt and Brasshollow exploit.
- `calibrated`: improved accuracy, shield, or spell cycling; Sunvault uses.
- `renewing`: regeneration or recovery state; Thornwake uses.
- `wounded_prey`: low-health or damaged-stack marker; Mireclaw finishers exploit.
- `repaired`: machine/construct recovery state; Brasshollow uses.

Faction unit hooks:

- Embercourt units should gain value from Beacon marks, braced states, road/oath morale, and retaliation timing.
- Mireclaw units should exploit harried, blinded, dragged, wounded, and recovery-denied enemies.
- Sunvault units should exploit marked targets, calibrated shields, relay cohesion, and dispel windows.
- Thornwake units should benefit from rooted ground, bramble zones, regeneration, cleanse, and movement taxation.
- Brasshollow units should interact with armor, repair, heat buildup, overpressure, and machine tags.
- Veilmourn units should benefit from fogged tiles, isolated enemies, morale drain, displacement, and salvage marks.

Neutral units should have limited, local interactions. They can respond to terrain or status, but should not require faction-specific spell combos to remain useful.

## Resource And Economy Costs

Mana remains the common casting cost, but production-depth magic should also touch the economy without becoming bookkeeping.

Cost model:

- Tier 1 and 2 battle spells usually cost only mana.
- Tier 3 and higher spells can require school-specific catalysts when cast from towns, shrines, adventure-map sites, or repeated use.
- Adventure spells that change map economy, route state, or site state may require resource catalysts.
- Town research and spellbook expansion should require gold plus school resources.
- Faction resources should reinforce identity but not make basic spellcasting impossible.

School catalyst affinities:

| School | Resource hooks |
| --- | --- |
| Beacon | gold, wood, embergrain, small aetherglass for advanced route marks |
| Mire | peatwax, embergrain theft, occasional memory salt for fear/memory rites |
| Lens | aetherglass, ore, gold, relay ownership |
| Root | verdant grafts, wood, embergrain, rooted site control |
| Furnace | ore, brass scrip, embergrain for worker readiness |
| Veil | memory salt, wood for ships/docks, aetherglass for mirror charts |
| Old Measure | aetherglass, memory salt, scenario fragments, rare site ownership |

Economy rule: resource catalysts should support strategic choices, not spam prevention alone. If a spell consumes a rare resource, the UI must show why it is worth that cost and how to obtain more.

## Artifact Hooks

The artifact expansion should treat magic as a core interaction surface.

Artifact hook categories:

- School focus: +mastery, reduced mana, improved duration, increased resist penetration, or better adventure range for one school.
- Spell unlock: grants one spell, a spell family, or an off-school spell with restrictions.
- Hybridization: transforms a spell effect when two schools meet, such as Beacon plus Lens reveal marks or Mire plus Veil fear fog.
- Catalyst handling: reduces rare-resource cost, stores school residue, converts battle cleanup into catalysts.
- Counterplay: grants resistance, dispel trigger, reveal effect, anti-root, anti-fog, heat cooling, or rot cleanse.
- Risk amplifier: boosts strong spells but adds miscast, self-debuff, cooldown, residue, or resource drain.
- Set identity: artifact sets should reinforce faction and school identity without locking all magic to one faction.

Examples for future artifact planning:

- Tollstone Ring: Beacon route spells last longer near roads and owned tollhouses.
- Mudglass Beads: Mire blind and harry effects improve against wounded enemies.
- Choir Tuning Fork: Lens marks can chain once if a relay or prism site is owned.
- Living Bridge Knot: Root adventure spells can renew one damaged living site weekly.
- Pressure Gauge Reliquary: Furnace overpressure spells gain damage but add cooldown.
- Black-Sail Compass: Veil scouting spells can reveal one hidden route or salvage site.
- Cracked Measure Shard: Old Measure spell access with scenario-limited charges.

## Town And Building Hooks

Magic must be grounded in town development.

Town hooks:

- Each faction needs at least one magic building tied to its primary school.
- Higher building levels unlock higher tier spells, school mastery training, catalysts, and spell refresh services.
- Towns can offer school-biased spell inventories rather than a universal random pool.
- Some buildings should interact with adventure spells: beacon courts reveal routes, lens galleries extend scouting, root gates support movement, boiler chapels repair machines, obituary vaults store memory salt.
- Captured towns should preserve building identity but may limit off-faction spell access until a hero has the right school rank or pays higher catalyst costs.

Building examples:

- Embercourt Beacon Court: Beacon spell inventory, road reveal, morale/readiness service.
- Mireclaw Sporewake Shrine: Mire spell inventory, recovery denial, ambush warning manipulation.
- Sunvault Harmonic Cloister: Lens spell cycling, dispel training, relay-linked spell research.
- Thornwake Graftworks: Root spell inventory, cleanse/regrowth, living-site renewal.
- Brasshollow Boiler Cathedral: Furnace spell inventory, repair, heat/overpressure training.
- Veilmourn Obituary Vault: Veil spell inventory, memory-salt storage, fog/salvage scouting.

## Hero Progression Hooks

Hero progression should make magic decisions legible and persistent.

Required hero concepts:

- School mastery ranks: novice, adept, expert, master, with final names decided later.
- Hero spell power and knowledge equivalents can exist, but they should not be the only magic stats.
- Magic heroes should get earlier school access, better spell economy, and more reliable spellbook growth.
- Might heroes should still use low-tier and faction-support spells without feeling locked out.
- Hero specialties can target a school, a spell family, a role, or an adventure-map use.
- Campaign carryover needs spellbook compatibility rules and clear caps.

Progression should avoid universal optimal picks. A Sunvault Lens specialist, Embercourt Beacon route hero, and Veilmourn Veil scout should create different map and battle decisions.

## Resistance And Counterplay

Every deep magic system needs readable counters.

Resistance axes:

- School resistance: reduced effect from Beacon, Mire, Lens, Root, Furnace, Veil, or Old Measure.
- Role resistance: damage, debuff, movement control, morale drain, terrain zones, mind/memory, heat, rot, root.
- Unit trait resistance: machine, living, disciplined, feral, construct, spirit, amphibious, rooted, fog-trained.
- Terrain resistance: marsh improves Mire, relay ground improves Lens, roads improve Beacon, root zones improve Root, furnace ground improves Furnace, fog banks improve Veil.

Counterplay tools:

- Dispel or cleanse buff/debuff states.
- Reveal fog, hidden routes, and decoys.
- Break roots or burn brambles.
- Cool heat or vent overpressure.
- Stabilize morale against Veil and Mire.
- Harden armor against Furnace and damage.
- Interrupt anchors: relay, drum, bell, writ, root knot, gauge, or shrine.

Design rule: a player should understand whether a spell failed because of resistance, immunity, invalid target, line/range rule, resource cost, or counter-effect.

## AI Casting Requirements

AI must be able to use magic with intention before the system can be called production-deep.

Required tactical AI concepts:

- Spell value by role: damage, finish, buff, debuff, control, recover, dispel, terrain.
- Target scoring that considers stack value, health, statuses, turn order, retaliation, range threats, objective pressure, and friendly fire.
- Resource and mana budgeting across battle length.
- Combo awareness for faction keywords: harried, marked, rooted, fogged, overpressured, braced, calibrated, wounded prey.
- Counterspell awareness: cleanse a dangerous state, dispel high-value buff, reveal fogged attackers.
- Risk tolerance by difficulty and faction personality.
- Debug summaries that explain why a spell was cast or skipped.

Required adventure AI concepts:

- Scouting spell use for unknown site risk and hidden routes.
- Movement spell use when it reaches a clear objective, town, threat, or site.
- Economy/site spell use when yield or recovery outweighs resource cost.
- Route spell use for defense, raid, bypass, or objective pressure.
- Conservation logic so AI does not waste rare catalysts before a major battle.
- Scenario safety so AI does not break scripted gates with unrestricted travel.

AI cannot treat spells as generic stat score. Its spell choices must align with faction personality and current map needs.

## UI Readability

Magic UI must obey the screen composition rules. It cannot solve spell depth by covering battle or overworld scenery with large panels.

Required UI stance:

- Spellbook uses compact school tabs, tier filtering, and role icons.
- Battle casting uses small target previews, school color/material cue, cost, range/shape, and predicted main effect.
- Adventure casting uses contextual availability: target valid site, route, town, hero, or visible tile.
- Tooltips show school, tier, mana cost, catalyst cost, target mode, duration, resistance/counter tags, and key combo tags.
- Invalid casts explain the reason in one compact line.
- Status icons must distinguish buff, debuff, zone, reveal, conceal, and residue states.
- Spell effects should have readable icons and short names; long lore text belongs in a secondary detail view.
- Spell schools should use material language, not only hue. Beacon is signal/fire/writ, Mire is peat/reed/rot, Lens is prism/relay, Root is graft/thorn, Furnace is gauge/heat, Veil is fog/bell/chart, Old Measure is cracked mirror/stone.

Screen rule: if the player must open a large report box to understand a spell's cost, target, counter, or current status, the design is wrong.

## Animation, VFX, And Audio Needs

Magic needs production-readable feedback before battle/town polish.

Visual language requirements by school:

- Beacon: ash marks, signal lines, bell pulses, road glyphs, red ceramic flare, steady rectangular forms.
- Mire: reed shadows, peat smoke, mudglass glints, drag ripples, rot blooms, drum pulses.
- Lens: crisp refraction, narrow beams, prism facets, choir rings, calibrated shields, clean reveal cuts.
- Root: thorn growth, graft knots, bark splints, bramble lanes, amber seed light, living bridge motion.
- Furnace: heat shimmer, pressure vents, slag sparks, gauge needles, armor plates, overpressure pulses.
- Veil: fog sheets, bell ripples, chart folds, memory-salt specks, silhouette slips, lantern cuts.
- Old Measure: cracked mirror planes, weather marks, suspended dust, time ticks, stone alignment.

Audio requirements:

- Each school needs a compact audio palette that reads at battle speed and map speed.
- Cast, impact, resist, cleanse, dispel, and fizzle need distinct cues.
- Adventure-map spells should use shorter, less intrusive cues than battle capstones.
- UI hover should not spam audio for spellbook browsing.

Animation requirements:

- Status application and removal must be readable on stacked units.
- Area zones must remain legible without hiding units or hex/tile readability.
- Adventure spell effects must not obscure routes, towns, object class, or hero focus.
- VFX must support deterministic validation snapshots where possible through stable state markers.

## Concept-Art Pipeline For Magic

This magic foundation depends on `docs/concept-art-pipeline.md`.

Before broad spell JSON migration, icon production, final VFX, or artifact implementation:

- Generate one visual-language sheet per accord school.
- Generate icon-family sheets for spell roles: damage, buff, debuff, control, recovery, zone, scouting, route, economy, counter.
- Generate spell-anchor sheets that show faction materials: writs, drums, lenses, roots, gauges, bells, mirror stones.
- Generate VFX mood frames for battle-scale effects and adventure-map effects separately.
- Generate residue/state studies: ash writ, rot bloom, glare scar, graft knot, heat vent, fog gap, mirror echo.
- Generate UI icon frame studies that support compact school/tier/role reads without overwhelming scenic surfaces.
- Annotate each accepted study with school, role, target scale, icon readability, animation risk, palette/material notes, and rejection constraints.
- Keep generated studies in `art/concept/`; do not place generated output directly into runtime art folders.

Generated studies are direction evidence, not final assets. Implementation briefs must describe original icons, VFX, sprites, and audio behavior to build for the Godot 4 2D presentation.

## Save And Schema Implications

The future magic system affects authored schemas, runtime saves, and migration.

Authored spell schema should eventually support:

- Stable id, display name, school, tier, role tags, context, target mode, target shape, range, duration, cooldown, mana cost, catalyst costs.
- Effect payloads composed from typed operations instead of ad hoc fields.
- Status ids, resistance tags, counter tags, terrain tags, unit trait tags, school mastery scaling, AI hints, UI icon ids, VFX/audio ids.
- Adventure-map effect payloads that identify target object/site/route/town/hero/tile constraints.
- Unlock metadata: town building, hero school rank, shrine, artifact, campaign grant, scenario restriction.

Save considerations:

- Save version should record spell schema version when migration begins.
- Hero state stores known spell ids, school mastery ranks, mana, cooldowns if any, temporary adventure spell effects, and campaign carryover caps.
- Battle save state stores active statuses, zone effects, durations, residues, summons, spell cooldowns, and any once-per-battle spell flags.
- Overworld save state stores active route/site/town spell effects, cooldown timers, revealed hidden objects, temporary ownership modifiers, damaged/renewed site state, and spell-created blockers/openers.
- Artifact-granted spell access must serialize by artifact id plus computed active effects, not duplicated permanent spell ids unless explicitly learned.
- AI spell plans can be cached only if rebuildable from authoritative state.

Migration rule: existing spell ids should remain loadable until a deliberate migration slice remaps or retires them with compatibility handling.

## Validation And Testing Gates

Before the magic system can be called production-deep, validation must prove:

- Every spell has school, tier, role tags, context, target mode, valid cost metadata, and UI metadata.
- Every spell references registered statuses, resources, VFX/audio ids, icons, buildings, artifacts, and unit tags where applicable.
- Every spell has an AI role hint or is explicitly marked player-only/scenario-only.
- Every school has battle, adventure, counterplay, and UI icon coverage.
- Every faction has primary access, secondary access, awkward access, and town/building unlock expectations.
- Every catalyst resource can be produced, granted, traded, or deliberately scenario-blocked.
- Every status has duration, stacking rules, cleanse/dispel behavior, resistance tags, and save serialization.
- Adventure spells cannot target invalid, hidden, unreachable, or scenario-locked objects unless explicitly allowed.
- Save/resume preserves battle spells, overworld spell effects, hero spellbooks, artifact spell access, and cooldowns.
- AI can make non-trivial battle and adventure casting choices in smoke scenarios.
- UI snapshots expose spell school, tier, cost, target mode, invalid-cast reason, and active status summaries compactly.

Manual play gates:

- A player can tell what a spell does before casting.
- A player can identify why a spell is unavailable or resisted.
- A player sees faction magic differences in battle and on the adventure map.
- A player can use counterplay against strong magic.
- A player can recover from spell-driven map pressure without reading a design document.

## Target Spell Family Catalog

This catalog is a production target, not an instruction to edit `content/spells.json` in this slice.

### Beacon Accord

| Family | Tier range | Context | Role | Production intent |
| --- | --- | --- | --- | --- |
| Writ Mark | 1-3 | Battle | Mark/debuff | Mark an enemy for retaliation, focus fire, or morale pressure. |
| Rally Bell | 1-4 | Battle | Buff/recovery | Restore cohesion, improve bracing, protect against fear and morale drain. |
| Signal Lane | 2-4 | Battle | Zone/control | Create a lane where allies gain retaliation or movement clarity. |
| Oathfire Rebuke | 2-5 | Battle | Damage/counter | Punish enemies who attack braced or marked allies. |
| Beacon Path | 1-3 | Adventure | Movement/scouting | Restore movement or reveal route risk near roads and owned sites. |
| Tollstone Claim | 3-4 | Adventure | Economy/route | Improve road-linked income or reinforce a controlled crossing. |
| Public Record | 2-4 | Adventure | Reveal/counter | Reveal hidden route state, ownership changes, or Veil concealment. |

### Mire Accord

| Family | Tier range | Context | Role | Production intent |
| --- | --- | --- | --- | --- |
| Reed Blind | 1-3 | Battle | Debuff | Reduce accuracy/initiative and set up ambush or skirmish units. |
| Drag Chain | 2-4 | Battle | Control | Pull or pin an enemy stack into a kill lane. |
| Rot Bloom | 2-5 | Battle | Damage/recovery denial | Deal delayed pressure and weaken healing or repair. |
| Wounded-Prey Drum | 2-4 | Battle | Buff/finish | Improve attacks against damaged or harried stacks. |
| Mire Toll | 1-3 | Adventure | Movement/route | Slow enemy routes or discount marsh movement for the caster. |
| Peatwake Den | 3-4 | Adventure | Site/economy | Improve den growth or reveal marsh caches at a resource cost. |
| Blackwater Warning | 2-4 | Adventure | Scouting/ambush | Expose guarded risk, or create explicit ambush warning state. |

### Lens Accord

| Family | Tier range | Context | Role | Production intent |
| --- | --- | --- | --- | --- |
| Prism Ward | 1-4 | Battle | Shield/buff | Protect a stack and resist debuffs when formation is intact. |
| Calibration Mark | 1-3 | Battle | Mark/focus | Improve ranged or spell accuracy against a chosen enemy. |
| Resonant Chorus | 2-4 | Battle | Tempo/cycling | Improve initiative and reduce spell cooldown or mana strain. |
| Sunlance | 2-5 | Battle | Damage/line | Damage a target or line, stronger against marked enemies. |
| Dispersal Lens | 2-5 | Battle | Countermagic | Dispel, reveal fog, or reduce zone effects. |
| Relay Sight | 1-4 | Adventure | Scouting | Reveal terrain, sites, guards, or hidden object classes near relays. |
| Crystal Alignment | 3-5 | Adventure | Economy/site | Improve aetherglass yield, activate observatories, or unlock mirror ruins. |

### Root Accord

| Family | Tier range | Context | Role | Production intent |
| --- | --- | --- | --- | --- |
| Briar Bind | 1-4 | Battle | Control | Root or slow a stack, with stronger effect on reckless movement. |
| Graft Mend | 1-4 | Battle | Recovery | Heal living units, cleanse rot, or add defensive bark splints. |
| Bramble Toll | 2-5 | Battle | Zone | Create tiles that tax movement and protect Thornwake positions. |
| Seed Judgment | 3-5 | Battle | Counter/debuff | Punish enemies that exploit, burn, or break root zones. |
| Root Gate | 2-5 | Adventure | Route | Open, discount, tax, or block route objects with visible state. |
| Site Renewal | 3-5 | Adventure | Site/economy | Repair or renew living sites, groves, and damaged orchards. |
| Pilgrim Shelter | 1-3 | Adventure | Recovery | Improve readiness or attrition recovery near rooted networks. |

### Furnace Accord

| Family | Tier range | Context | Role | Production intent |
| --- | --- | --- | --- | --- |
| Heat Rite | 1-4 | Battle | Buff/risk | Increase attack or momentum, sometimes adding overheat cooldown. |
| Pressure Clause | 2-5 | Battle | Damage/debuff | Damage armor/cohesion and set overpressured state. |
| Slag Mantle | 1-4 | Battle | Shield/armor | Harden a stack, especially machines and braced units. |
| Vent Burst | 3-5 | Battle | Area/control | Heat zone or cone with risk to clustered allies if misused. |
| Repair Window | 2-4 | Battle | Recovery | Repair machine/construct units and remove overpressure. |
| Furnace Acceleration | 2-5 | Adventure | Economy/town | Temporarily improve production, building, repair, or mine output. |
| Rail Pressure | 3-4 | Adventure | Route | Improve rail-linked movement or reinforce mine logistics. |

### Veil Accord

| Family | Tier range | Context | Role | Production intent |
| --- | --- | --- | --- | --- |
| Fogwake Step | 1-4 | Battle | Tempo/conceal | Improve initiative or reposition through a fogged state. |
| Obituary Mark | 1-4 | Battle | Debuff/isolate | Mark a stack for morale drain, retaliation loss, or isolation damage. |
| Mirror Slip | 3-5 | Battle | Displacement | Move, swap, or phase a stack within strict targeting rules. |
| Bell Drown | 2-5 | Battle | Morale/counter | Suppress morale, reveal hidden fear, or silence a support effect. |
| Fog Bank | 2-5 | Battle | Zone/conceal | Create a readable concealment zone that has reveal counters. |
| Salvage Sense | 1-4 | Adventure | Scouting/economy | Reveal hidden caches, wreck rewards, or artifact clues. |
| Mistgate Passage | 3-5 | Adventure | Route | Short bypass through known fog slips, never unrestricted teleport. |
| Memory Ransom | 3-5 | Adventure | Economy/counter | Convert memory salt into reveal, rescue, or limited market access. |

### Old Measure Accord

| Family | Tier range | Context | Role | Production intent |
| --- | --- | --- | --- | --- |
| Mirror Weather | 4-5 | Battle/adventure | Zone/scenario | Change local battlefield or map weather with scenario limits. |
| Anchor Recall | 4-5 | Adventure | Route | Return to a prepared anchor, town, or mirror site with strict constraints. |
| Timekeeping Bell | 4-5 | Battle | Tempo/counter | Alter initiative order or extend/reduce durations once. |
| Shard Omen | 3-5 | Adventure | Scouting/objective | Reveal objective clues, mirror sites, or high-risk rewards. |
| Measure Seal | 4-5 | Battle/adventure | Counter/lock | Temporarily suppress a school effect, route object, or residue state. |

## Concrete Spell Catalog Target

The first production spell catalog should target breadth before final balance. A reasonable initial target is 70 to 90 spells:

- 8 to 10 battle spells per major school.
- 4 to 6 adventure spells per major school.
- 5 to 8 Old Measure spells, mostly rare or scenario-gated.
- At least 2 counterplay spells per school, including one self/ally answer and one enemy/zone answer.
- At least 2 spell families per school that directly interact with faction unit keywords.
- At least 1 route or site spell per major school.

Representative first-pass spell names:

| School | Battle spells | Adventure spells |
| --- | --- | --- |
| Beacon | Ash Writ, Rally Bell, Lantern Phalanx, Oathfire Rebuke, Signal Lane, Charter Ward, Countercall | Beacon Path, Public Record, Tollstone Claim, Road Court Seal |
| Mire | Reed Blind, Drag Chain, Rot Bloom, Bloodwake Drum, Mudglass Glare, Sporewake Hush, Fen Maw | Mire Toll, Blackwater Warning, Peatwake Den, Drowned Causeway Rite |
| Lens | Prism Ward, Calibration Mark, Sunlance Arc, Resonant Chorus, Dispersal Lens, Facet Mirror, Choir Shield | Relay Sight, Crystal Alignment, Observatory Wake, Prism Road Trace |
| Root | Briar Bind, Graft Mend, Bramble Toll, Seed Judgment, Thornwall, Loam Cleanse, Worldroot Pulse | Root Gate, Site Renewal, Pilgrim Shelter, Orchard Oath |
| Furnace | Heat Rite, Pressure Clause, Slag Mantle, Vent Burst, Repair Window, Clause Hammer, Crucible Wake | Furnace Acceleration, Rail Pressure, Pump Restart, Contract Seal |
| Veil | Fogwake Step, Obituary Mark, Mirror Slip, Bell Drown, Fog Bank, Undertow Vow, Memory Cut | Salvage Sense, Mistgate Passage, Memory Ransom, Bell Buoy Trace |
| Old Measure | Timekeeping Bell, Measure Seal, Mirror Weather, Shard Refrain | Anchor Recall, Shard Omen, Sky Mirror Alignment |

Names can change during content migration. The important production contract is the distribution of roles, schools, contexts, counters, and faction hooks.

## Migration Sequence

1. Freeze this document as the magic design target.
2. Add spell schema design notes for school, tier, role tags, target shapes, costs, statuses, counters, AI hints, UI metadata, VFX/audio ids, unlock metadata, and adventure constraints.
3. Extend validators before adding broad spell content.
4. Preserve existing spell ids and map them into provisional schools/tiers without changing balance.
5. Add a status registry and stacking/cleanse/dispel rules.
6. Add compact spellbook and cast-preview UI metadata with placeholder icons.
7. Implement target shapes and battle status rules in a narrow vertical slice.
8. Implement adventure-map spell targeting only after route/site/object schemas can express valid targets.
9. Add faction magic buildings and hero school progression for one or two vertical factions.
10. Add AI casting heuristics and debug summaries before broad spell expansion.
11. Add concept-art-reviewed icon/VFX/audio briefs for each school and role.
12. Expand the spell catalog by school families, not by one-off effects.
13. Wire artifacts after the artifact foundation plan defines set and spell-modifier rules.
14. Save/load migrate spellbooks, statuses, adventure effects, and artifact-granted spells.
15. Manually test one small map and one larger multi-faction map for spell readability, counterplay, AI use, and scenario safety.

## Deep-Enough Gate For Campaign, Skirmish, Battle, And Town Polish

Magic is deep enough to support campaign/skirmish map production and battle/town polish only when:

- The school model, spell tiers, role categories, status rules, and counterplay rules are locked or deliberately reduced.
- At least two factions have complete magic vertical slices: town buildings, hero progression, unit keyword interactions, spell access, artifact hooks, AI preferences, UI reads, and manual play notes.
- Every major school has battle spells, adventure spells, counterplay, spell icons, VFX direction, audio direction, and validation coverage.
- Adventure-map spells cannot break route gates, economy pacing, scenario objectives, save/load, or AI planning.
- The spellbook and casting UI remain compact and readable without covering the battle or map surface.
- AI can cast useful battle and adventure spells and explain choices in debug output.
- Save/resume preserves spellbooks, active statuses, zone effects, route/site effects, cooldowns, and artifact-granted access.
- Concept-art stage gates for school visual language, icons, VFX, and residues have accepted review notes or documented placeholder exceptions.
- Manual play proves that players understand spell purpose, cost, target validity, resistance, counterplay, and faction differences.

Until then, existing spells remain useful scaffolding and flavor seeds, not production-depth magic design.
