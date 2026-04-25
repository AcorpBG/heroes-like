# Artifact System Expansion Foundation

Status: design source, not implementation proof.
Date: 2026-04-25.
Slice: artifact-system-expansion-foundation-10184.

## Purpose

This document defines the target artifact-system foundation for Aurelion Reach before broad artifact JSON migration, campaign/skirmish maps, final battle polish, town polish, or balance claims. The goal is to turn artifacts from a few passive stat items into a production system that supports hero builds, faction identity, magic schools, economy pressure, map rewards, unique sets, AI valuation, readable UI, save/load stability, concept-art gates, and content validation.

Heroes 2, Heroes 3, and Oden Era may inform expectations for artifact breadth, reward excitement, map readability, and strategic density only. They are not source material for artifact names, art, lore, icons, set identities, item effects, maps, or text.

## Current Baseline And Gap

The current `content/artifacts.json` is useful scaffolding, not a deep artifact system.

Reality check as of this slice:

- The live artifact catalog contains four artifacts: Trailsinger Boots, Quarry Tally Rod, Warcrest Pennon, and Bastion Gorget.
- Current artifact data supports stable ids, names, slots, descriptions, and simple bonuses such as movement, scouting, income, attack, initiative, and defense.
- Current artifact content does not yet define rarity, artifact class, accord school, faction affinity, set membership, curse/tradeoff rules, spell modifications, unit keyword interactions, economy catalysts, map-source rules, AI valuation hints, UI icon metadata, concept-art readiness, or migration/version rules.
- Slots are present as strings, but there is no production equipment contract for hands, armor layers, banners, relics, trinkets, consumables, set limits, duplicate rules, or campaign carryover.
- Artifact rewards are not yet deep enough to shape build decisions, map routes, town investment, battle tactics, or faction strategy.

The missing work is not simply adding many item records. The project needs a stable artifact grammar that content, UI, combat rules, overworld rewards, AI systems, save/load, validators, and concept art can all share.

## Design Contract

Artifacts are physical remnants, tools, contracts, relics, instruments, maps, charms, and machines from Aurelion Reach. They should be materially grounded and tied to world systems: roads, ferries, lenses, roots, furnaces, bells, charts, mines, shrines, mirror fragments, and battlefield practices.

Artifact principles:

- Every artifact has a primary gameplay purpose: movement, scouting, economy, combat, magic, command, recovery, logistics, resistance, route control, set progression, or scenario objective.
- Every artifact has a source expectation: pickup, guarded reward, neutral dwelling reward, faction landmark, town service, campaign grant, set chain, Old Measure site, market/trade, or battle salvage.
- Most artifacts should be useful without requiring hidden combo knowledge, but high-rarity artifacts and sets can reward planning.
- Faction artifacts should express faction strategy without becoming unusable for other factions unless deliberately locked by campaign or scenario rules.
- Old Measure artifacts should be rare, powerful, and scenario-aware. They must not become ordinary stat sticks.
- Artifacts must stay readable in compact UI. Long lore belongs in secondary detail, not on the main map or battle surface.

## Taxonomy

Every artifact should have structured taxonomy metadata.

Required future fields:

- `artifact_class`: common, crafted, faction, accord, relic, cursed, set_piece, old_measure, scenario.
- `rarity`: common, uncommon, rare, epic, legendary, scenario.
- `slot`: equipment slot or non-equipped class.
- `roles`: economy, movement, scouting, combat, defense, morale, magic, resistance, recruitment, town_support, route, reward_modifier, progression, objective.
- `accord_affinity`: Beacon, Mire, Lens, Root, Furnace, Veil, Old Measure, neutral, or none.
- `faction_affinity`: optional faction id or cross-faction tag.
- `source_tags`: pickup, guarded_site, shrine, dwelling, artifact_cache, town, battle_salvage, campaign, set_chain, market, objective.
- `ai_hints`: value drivers, risk, preferred factions, preferred hero archetypes, and combo tags.
- `ui_tags`: short summary, icon id, effect category icons, comparison priority, warning tags.
- `validation_tags`: set id, mutual exclusions, stack rules, save behavior, schema version.

Artifact classes:

| Class | Purpose | Example forms |
| --- | --- | --- |
| Common utility | Early readable rewards and pacing | boots, gloves, lanterns, ration charms, small tools |
| Crafted equipment | Midgame build shaping | armor plates, banners, weapons, survey tools, saddles |
| Faction artifact | Strong faction identity and strategy hooks | tollstone rings, reed masks, choir forks, graft knots, gauges, fog charts |
| Accord artifact | Magic-school modifiers and counters | lenses, bells, drums, roots, furnace seals, mirror fragments |
| Relic | High-value non-set reward with broad strategic effect | ancient keys, crownless circlets, colossus cores, archive stones |
| Cursed artifact | Power with visible tradeoff | rot crowns, debt seals, cracked charts, overbright mirrors |
| Set piece | Partial and complete set progression | families of 3 to 6 items with staged bonuses |
| Old Measure artifact | Rare mirror-era artifact, often charged or scenario-gated | measure shards, anchor stones, time bells, weather plates |
| Scenario artifact | Objective or campaign-specific item | charter proofs, bridge writs, named fragments, evacuation bells |

## Slots And Equipment Model

The final slot model should allow meaningful hero builds without turning equipment into inventory clutter.

Target equipment slots:

| Slot | Role | Notes |
| --- | --- | --- |
| Head | vision, command, resistance, spell focus | masks, circlets, survey crowns, signal helms |
| Armor | defense, survival, repair, tradeoff protection | gorgets, coats, harnesses, scale layers |
| Hand primary | attack, spell anchor, command verb | rods, hooks, gavels, gauges, lanterns, tuning tools |
| Hand off | defense, utility, spell storage | shields, ledgers, charts, chains, bells |
| Boots | movement, terrain, scouting, retreat | road boots, marsh gaiters, rail cleats, fog slippers |
| Banner | morale, initiative, army command, faction identity | pennons, bells, standards, signal flags |
| Trinket 1-2 | economy, magic modifiers, resistance, small combos | rings, beads, keys, contracts, charms |
| Relic | rare high-impact slot, usually one equipped | mirror shard, old anchor, sacred tool, engine heart |
| Mount or conveyance | later optional movement/logistics slot | barge pass, ferry tack, rail harness, fog skiff token |
| Backpack | unequipped carried artifacts and scenario items | no active effect unless marked passive/carry |

Slot rules:

- One relic slot prevents multiple high-impact world artifacts from stacking invisibly.
- Two trinket slots preserve build variety without letting small economy artifacts stack without limit.
- Set pieces occupy normal slots; full sets should require meaningful opportunity cost.
- Scenario artifacts may be carried without occupying a combat slot if they are objective keys.
- Consumable or charged artifacts may exist later, but they need explicit UI, save, and AI rules before broad use.

## Rarity And Power Bands

Rarity should communicate expected impact, guard level, and map timing.

| Rarity | Expected timing | Power shape | Source expectation |
| --- | --- | --- | --- |
| Common | Opening route, low guard | One clear small bonus | pickups, light guarded caches, shops |
| Uncommon | Early/midgame | Two related bonuses or one build hook | guarded sites, minor shrines, dwellings |
| Rare | Midgame objective | Strong role bonus, school hook, or faction hook | standard/heavy guarded rewards, town services, set chains |
| Epic | Late map power | Build-defining effect with counter or opportunity cost | heavy/elite guarded sites, faction landmarks, major ruins |
| Legendary | Scenario/campaign spike | Unique rule, set capstone, or Old Measure power | elite guarded sites, campaign rewards, Old Measure anchors |
| Scenario | Authored objective | Progress, unlock, route, or story rule | campaign and scenario scripting only |

Power rules:

- Common and uncommon artifacts should be easy to compare at a glance.
- Rare artifacts can introduce school, faction, unit, town, or economy hooks.
- Epic artifacts can reshape a hero build but should not erase faction weaknesses alone.
- Legendary and Old Measure artifacts need source, guard, save, AI, and scenario safety rules before implementation.
- Cursed artifacts can appear at rare or higher tiers, but the tradeoff must be visible before pickup/equip.

## World And Faction Artifact Families

Artifact families should come from Aurelion Reach materials and infrastructure. They are production families, not one-off names.

### Cross-Region Utility Families

| Family | Roles | Notes |
| --- | --- | --- |
| Roadfinder Gear | movement, scouting, route | Boots, compasses, lanterns, mile rods, bridge passes. |
| Surveyor Instruments | scouting, economy, magic clue | Sextants, tally rods, lens sticks, map weights. |
| Ration And Recovery Charms | recovery, morale, readiness | Embergrain tins, field cups, healer seals, graft salves. |
| Battle Command Pieces | combat, morale, initiative | Pennons, horns, order chains, guard tablets. |
| Mine And Site Tools | economy, site capture, town support | Tally rods, quarry keys, pump seals, claim knives. |
| Shrine Tokens | magic, resistance, spell access | Accord-specific offerings and small anchors. |
| Salvage And Clue Artifacts | scouting, artifact discovery, memory | Charts, bells, ink flasks, wreck keys. |

### Embercourt League Families

| Family | Roles | Production intent |
| --- | --- | --- |
| Ash-Sealed Writs | morale, road, town_support | Improve bracing, public record, route reveal, or road-linked income. |
| Tollstone Rings | economy, route, Beacon | Strengthen owned crossings, tollhouses, and Beacon route spells. |
| Lockmaster Chains | defense, movement, town_support | Improve defensive posture near roads, towns, bridges, and lock sites. |
| Granary Keys | recovery, embergrain, recruitment | Improve readiness, recovery, and low-tier replenishment. |
| River Judge Gavels | command, morale, retaliation | Punish enemies that attack marked or braced allied stacks. |
| Beacon Lenses | scouting, Beacon, counter-Veil | Reveal hidden route state, fog, or ambush cues. |

### Mireclaw Covenant Families

| Family | Roles | Production intent |
| --- | --- | --- |
| Reed-Script Masks | scouting, Mire, resistance | Improve ambush reads, blind resistance, and marsh-route effects. |
| Chainboom Hooks | movement control, combat | Improve pull, pin, and route-block interactions. |
| Peatwax Votives | magic catalyst, recovery_denial | Store or reduce costs for Mire rites and den growth effects. |
| Mudglass Beads | debuff, wounded_prey | Improve blind, harry, and wounded-prey follow-up. |
| Drowned Antlers | morale, finish, curse | Strong attack/fear hooks with recovery or diplomacy tradeoffs. |
| Drum-Hide Ledgers | raid economy, den growth | Reward counter-capture, site denial, and cheap replacement loops. |

### Sunvault Compact Families

| Family | Roles | Production intent |
| --- | --- | --- |
| Choir Tuning Forks | Lens, spell cycling | Improve calibration, dispel, cooldown, or marked-target chaining. |
| Prism Circlets | scouting, resistance, spell focus | Boost sightline spells, shield effects, and anti-fog play. |
| Relay Keys | route, magic, town_support | Strengthen relays, observatories, and Lens adventure spells. |
| Aetherglass Cores | catalyst, high-tier magic | Store or discount aetherglass costs under strict limits. |
| Sun-Scribed Harnesses | defense, ranged support | Improve protection for compact formations and ranged lanes. |
| Observatory Sextants | scouting, artifact clue | Reveal guarded reward class, hidden ruins, or spell-site hints. |

### Thornwake Concord Families

| Family | Roles | Production intent |
| --- | --- | --- |
| Living Bridge Knots | route, Root, renewal | Renew damaged living sites or improve Root Gate effects. |
| Graft-Bound Mantles | recovery, resistance | Improve regeneration, cleanse, and living-unit sustain. |
| Thorn Toll Brooches | movement tax, control | Strengthen bramble zones and route-tax effects. |
| Seedmask Charms | recruitment, growth, town_support | Support weekly growth, recovery, or rooted-site links. |
| Orchard Oath Blades | combat, terrain | Reward fighting on rooted or renewed ground. |
| Pilgrim Root Sandals | movement, scouting | Improve forest/root route movement without universal speed creep. |

### Brasshollow Combine Families

| Family | Roles | Production intent |
| --- | --- | --- |
| Pressure Gauge Reliquaries | Furnace, risk | Improve overpressure effects while adding cooldown or heat risk. |
| Debt-Seal Plates | defense, economy, curse | Trade debt/resource obligations for armor or construction acceleration. |
| Furnace Clause Hammers | combat, breach | Improve armor breach, repair windows, and machine support. |
| Brass Scrip Ledgers | economy, town_support | Improve scrip income, markets, or capital projects. |
| Railmaster Cleats | route, movement | Improve rail/road movement and mine logistics. |
| Boiler Saint Icons | repair, resistance | Improve repair and heat resistance for machine-heavy armies. |

### Veilmourn Armada Families

| Family | Roles | Production intent |
| --- | --- | --- |
| Black-Sail Compasses | scouting, route, Veil | Reveal fog slips, salvage sites, and hidden route risk. |
| Obituary Ink Vials | morale, memory_salt | Fuel memory magic and morale-drain effects. |
| Bell-Buoy Charms | warning, counter-ambush | Improve fog reveal, retreat, or route safety. |
| Mirror Charts | displacement, Old Measure clue | Modify Veil route spells and reveal mirror rewards. |
| Salvage Claim Knives | economy, battle_salvage | Convert battle cleanup or guarded wrecks into extra rewards. |
| Salt-Lacquer Cloaks | concealment, resistance | Improve fogged state, morale resistance, or ambush survival. |

### Neutral And Old Measure Families

| Family | Roles | Production intent |
| --- | --- | --- |
| First Measure Stones | Old Measure, scouting | Rare world-memory and mirror-site clue artifacts. |
| Anchor Shards | route, scenario | Prepared recall, route opening, or objective lock under strict constraints. |
| Timekeeping Bells | tempo, counterplay | Once-per-battle or charged duration/initiative manipulation. |
| Weather Plates | terrain, scenario | Local weather or battle-zone effects with scenario gates. |
| Broken Mirror Keys | magic access, risk | Unlock rare spells or ruins with curse/memory tradeoffs. |
| Charter War Relics | objective, morale | Neutral artifacts from the current war, not faction-owned by default. |

## Unique Sets

Sets should create strategic identity and map goals without forcing every hero into one obvious full-set path.

Set rules:

- Most sets should contain 3 to 5 pieces.
- Two-piece bonuses should be useful but not mandatory.
- Full-set bonuses can be build-defining but should cost important slots.
- Sets should have clear source logic: faction landmark chain, region reward chain, Old Measure ruin chain, campaign chapter, or major guarded pocket.
- Set pieces must still be individually useful.
- Set bonuses should be computed from equipped pieces, not permanently written into hero state.
- UI must show current pieces, missing pieces, active set bonuses, and set source hints compactly.

Target set catalog:

| Set | Pieces | Identity | Partial bonus | Full bonus direction |
| --- | --- | --- | --- | --- |
| Charter of Open Roads | 4 | Embercourt road law | road movement, morale, public record reveal | owned road/crossing network improves readiness and retaliation |
| Drowned Sovereign Regalia | 4 | Mireclaw wetland rule | blind/harry strength and marsh movement | wounded-prey finishers trigger limited route or morale pressure |
| Harmonic Relay Array | 5 | Sunvault calibration | mark accuracy, dispel, scouting | Lens spells chain or discount through owned relays with caps |
| Thornwake Pilgrim Bond | 4 | living route law | regeneration, root-route movement | rooted sites renew faster and bramble zones strengthen |
| Furnace Contract Panoply | 5 | Brasshollow capital war | armor, repair, scrip value | overpressure and repair windows become stronger but heat risk rises |
| Black-Sail Salvage Kit | 4 | Veilmourn fog salvage | hidden-site reveal, memory salt, concealment | battle salvage and fog routes feed limited spell or movement spikes |
| Ninefold Measure Fragments | 6 | Old Measure mirror infrastructure | scouting, resistance, spell clue | scenario-gated mirror alignment effect, never unrestricted global power |
| Wayfarer Compact | 3 | neutral exploration | movement, scouting, encounter preview | first guarded site each week reveals reward category and risk tier |
| Artificer's Field Chest | 3 | economy and crafting | resource-site value, market caps | limited weekly artifact repair/charge/catalyst service in town |
| Banner Of The Last Treaty | 3 | morale and diplomacy | neutral recruitment, surrender/retreat clarity | neutral dwellings and guarded armies offer clearer parley/reward choices |

## Spell And Magic Interactions

Artifacts should connect deeply to the magic foundation without making spells unreadable.

Hook categories:

- School focus: improve one school's duration, range, resistance penetration, mana cost, catalyst cost, adventure range, or unlock chance.
- Spell unlock: grant a spell, spell family, or charged off-school cast without permanently teaching it unless specified.
- Hybridization: alter a spell when two accord families meet, such as Beacon plus Lens reveal marks or Mire plus Veil fear fog.
- Catalyst handling: store school residue, reduce resource costs, convert battle cleanup into catalysts, or protect rare resources from waste.
- Counterplay: grant resistance, reveal, cleanse, dispel, anti-root, anti-fog, cooling, anti-rot, or anti-overpressure effects.
- Risk amplifier: improve strong spells while adding miscast chance, cooldown, self-debuff, residue, resource drain, or enemy clue.
- Adventure safety: allow site or route interactions only through explicit target constraints.

Rules:

- Artifact-granted spell access must be visibly marked as artifact-granted.
- If an artifact modifies a spell, the cast preview must show the modified effect and tradeoff.
- Adventure-map spell artifacts must obey route, site, ownership, cooldown, and scenario-lock constraints.
- Old Measure spell artifacts should usually use charges, site attunement, or scenario restrictions.
- Artifact modifiers should reference spell families and role tags where possible, not only individual spell ids.

## Economy And Resource Interactions

Artifacts should make the expanded economy more meaningful without replacing resource-site control.

Economy hooks:

- Daily or weekly income bonuses tied to resource type, site class, town ownership, or route control.
- Claim reward bonuses for specific object classes such as quarries, wreck fields, observatories, groves, tollhouses, or shrines.
- Catalyst storage or discounts for school resources: aetherglass, peatwax, verdant grafts, brass scrip, memory salt, and embergrain.
- Market cap adjustments that are limited by town, week, faction, or artifact rarity.
- Construction or recruitment discounts that apply only to specific building classes, unit tags, or town states.
- Salvage, raid, or battle-cleanup conversion into small resource rewards.
- Cursed debt or upkeep artifacts that demand weekly resources in exchange for strong effects.

Rules:

- Artifacts must not create infinite resource loops.
- Economy artifacts should be weaker than holding the correct persistent sites.
- Rare-resource discounts need caps and UI explanation.
- If an artifact consumes resources automatically, the player needs clear opt-in or a visible priority setting.
- AI valuation must understand short-term cash, long-term income, catalyst scarcity, and faction resource preference.

## Unit, Hero, Build, And Town Interactions

Artifacts should shape builds across three layers: hero, army, and town.

Hero build hooks:

- Might heroes value attack, defense, retaliation, movement, scouting, recruitment, morale, and army-specific triggers.
- Magic heroes value school mastery, spell unlocks, mana economy, resistance, catalyst handling, adventure spells, and spell-family modifiers.
- Scout heroes value movement, reveal, route risk, hidden-site clues, retreat, and artifact discovery.
- Economy governors value site output, town support, recruitment cost, market caps, and recovery.

Unit hooks:

- Artifacts can improve or react to shared status keywords: marked, harried, rooted, fogged, overpressured, braced, calibrated, renewing, wounded_prey, repaired.
- Faction unit synergies should be readable from the artifact summary.
- Neutral-unit support should be local and limited so neutral stacks do not erase faction identity.
- Unit-tag artifacts should avoid global "all units are better" effects unless rare and expensive.

Town hooks:

- Town support artifacts can improve build discounts, recruitment availability, spell research, recovery, market caps, or defense while the hero is garrisoned or assigned.
- Captured-town behavior must be explicit: does the artifact help any town, only home faction towns, or only compatible building families?
- Artifact services can exist later: identify cursed items, repair charges, combine set clues, attune Old Measure relics, or trade low-tier items.
- Town UI must show artifact-driven changes in compact deltas, not buried text.

Progression hooks:

- Artifact rewards should scale map route decisions without replacing hero leveling.
- Campaign carryover needs caps so a completed map does not break the next scenario.
- Set completion can become a campaign objective, but missing pieces must not block normal scenario completion unless the scenario is explicitly built around it.

## Map Sources, Drops, And Rewards

Artifact sources should be authored by object class and risk tier.

Source families:

| Source | Artifact expectation |
| --- | --- |
| Small pickups | common utility, clues, low-value trinkets |
| Guarded reward sites | uncommon to epic artifacts based on guard tier and region |
| Persistent economy sites | site-themed artifacts as claim rewards or rare weekly events |
| Shrines and accord sites | school artifacts, spell unlocks, resistance tools |
| Neutral dwellings | local neutral artifacts or recruitment-support items |
| Overworld neutral encounters | chance of equipment tied to army family and difficulty |
| Faction landmarks | faction artifacts and set pieces |
| Town buildings | crafted artifacts, attunement, repair, market/trade services |
| Battle salvage | small chance of salvage artifacts, capped and visible by source |
| Campaign objectives | scenario artifacts, named relics, set chains |
| Old Measure ruins | rare relics, charged artifacts, cursed mirror items |

Drop rules:

- Major artifacts should be placed or sourced intentionally, not random noise.
- Random drops must use weighted tables by region, object class, guard tier, faction affinity, and rarity.
- A map should expose enough artifact source variety to support builds without flooding inventory.
- Duplicate handling must be clear: disallow unique duplicates, convert low-tier duplicates, or allow separate copies only where balance supports it.
- Artifacts that unlock spells, routes, or objectives must not be generated where they can break scenario structure.

## Faction-Specific Hooks

Faction hooks should create preference, not hard lock, unless the artifact is campaign-specific.

| Faction | Artifact preference | Avoid |
| --- | --- | --- |
| Embercourt | road law, bracing, morale, retaliation, toll income, Beacon reveal | generic knightly crowns or universal human nobility |
| Mireclaw | ambush, blind, drag, wounded-prey finish, peatwax, raid reward | generic swamp monster trophies or pure poison stats |
| Sunvault | marking, shields, dispel, relay scouting, aetherglass, Lens focus | angelic or holy-light relic language |
| Thornwake | regeneration, root routes, movement tax, renewal, verdant grafts | generic druid/elf forest jewelry |
| Brasshollow | armor, repair, overpressure, scrip, mine logistics, Furnace risk | generic dwarf/steampunk gadgets without contract logic |
| Veilmourn | fog, memory, salvage, displacement, morale drain, scouting | pirate, undead, assassin, or dark-elemental stock items |

Off-faction use:

- Off-faction heroes can use most artifacts, but may pay higher catalyst costs, receive narrower effects, or miss faction-building bonuses.
- Faction artifacts should still show their full potential in tooltips so players understand why a different hero values them less.
- AI should prefer faction-aligned artifacts but can choose off-faction power if it solves a current shortage.

## Curses And Tradeoffs

Cursed and tradeoff artifacts are useful if they add strategic tension rather than hidden punishment.

Accepted tradeoff types:

- Economy debt: weekly cost, resource lock, reduced market cap, or repair obligation.
- Magic residue: stronger school effect with cooldown, miscast, resistance penalty, or residue exposure.
- Morale risk: increased attack or fear pressure but lower recovery, surrender, or morale stability.
- Route risk: faster movement through a terrain but higher ambush, fatigue, or reveal risk.
- Faction tension: strong off-school access but reduced faction building synergy.
- Old Measure instability: charges, scenario attunement, route constraints, or memory loss effects.

Rules:

- The tradeoff must be visible before equipping and in comparison UI.
- Curses should not silently destroy resources, units, saves, or scenario progress.
- Removing a curse should require a clear service, cost, cooldown, or objective.
- AI can use cursed artifacts only if valuation understands the downside.

## AI Valuation

AI must value artifacts by current game state, not by flat rarity.

Required AI valuation inputs:

- Base rarity and slot conflict.
- Hero archetype: might, magic, scout, governor, raider, defender, carrier.
- Faction affinity and accord school access.
- Current army composition and unit keywords.
- Current spellbook and known school mastery.
- Resource shortages, catalyst availability, and economy goals.
- Map phase: early expansion, midgame site contest, town defense, final assault, campaign objective.
- Route value: movement, scouting, fog/marsh/rail/root/road access.
- Set completion potential and opportunity cost.
- Curse/tradeoff risk and removal availability.
- Scenario locks and carryover limits.

AI behavior requirements:

- Equip better artifacts when slot conflicts are obvious.
- Keep or transfer artifacts to heroes that can use them best.
- Prefer faction and school artifacts when they support current strategy.
- Avoid consuming scarce resources through artifact effects without benefit.
- Pursue guarded artifacts only when reward value justifies army risk and route delay.
- Defend set-chain and Old Measure objectives when the strategic value is high.
- Emit debug summaries explaining artifact pickup, equip, skip, transfer, and target decisions.

## UI And Readability

Artifact UI must obey the scenic/play-surface composition rules.

Required UI stance:

- Inventory uses compact slot layout, rarity frame, role icons, accord/faction tags, and set markers.
- Comparison view shows current item, candidate item, changed stats/effects, slot conflict, curse warning, and set delta.
- Tooltips show short effect summary first, then source/faction/school/set details.
- Artifact-granted spells or modified spells appear in the spellbook/cast preview with a small artifact marker.
- Economy effects show expected daily/weekly/resource impact in compact deltas.
- Cursed/tradeoff artifacts use explicit warning icons and one-line effect risk.
- Set UI shows active pieces and missing pieces without large panels covering the map or battle.
- Reward screens should identify artifact rarity, role, slot, and whether it is unique or set-related.

Screen rule: if the player needs a report panel to know whether an artifact helps movement, combat, magic, economy, or set progress, the design is wrong.

## Concept-Art Stage Gates

This artifact foundation depends on `docs/concept-art-pipeline.md`.

Before broad artifact JSON migration, icon production, runtime art, final reward screens, or set implementation:

- Generate artifact visual-language sheets for Beacon, Mire, Lens, Root, Furnace, Veil, Old Measure, and neutral utility families.
- Generate faction artifact sheets for all six factions using material anchors from `docs/factions-content-bible.md`.
- Generate set-piece sheets for at least the first two faction sets and one neutral exploration set before implementing set bonuses.
- Generate icon-readability sheets at inventory scale and reward-popup scale.
- Generate cursed/tradeoff artifact studies that make risk visible without text.
- Generate source-context sheets: pickup cache, guarded ruin, shrine, faction landmark, town service, battle salvage, Old Measure site.
- Annotate each accepted study with slot, rarity, family, role icons, material palette, silhouette read, animation/VFX hook, and rejection constraints.
- Keep generated studies in `art/concept/`; do not place generated output directly into runtime art folders.

Artifact art is not approved for implementation until the object reads as an artifact at inventory scale and as a map/reward object without copying generic fantasy item tropes.

## Save And Schema Implications

The future artifact system affects authored schemas, runtime saves, campaign carryover, and migration.

Authored artifact schema should eventually support:

- Stable id, display name, description, artifact class, rarity, slot, uniqueness, stack policy, roles, accord affinity, faction affinity, set id, source tags, and icon/VFX/audio ids.
- Typed effects rather than ad hoc bonus keys: stats, statuses, spell modifiers, resource modifiers, site modifiers, town modifiers, unit-tag modifiers, adventure effects, charges, cooldowns, tradeoffs, and curses.
- Unlock and restriction metadata: hero level, school mastery, town building, faction, campaign grant, scenario lock, Old Measure attunement.
- AI hints, UI summaries, validation tags, and concept-art readiness.

Save considerations:

- Save version should record artifact schema version when migration begins.
- Hero state stores equipped artifact ids by slot and carried artifact ids in inventory.
- Artifact instance state stores charges, cooldowns, curse state, attunement, temporary effects, and generated source only where needed.
- Unique artifacts should serialize ownership globally to prevent duplicates after save/load.
- Set bonuses should be derived from equipped item ids on load, not saved as permanent stat changes.
- Artifact-granted spell access should serialize as artifact-granted access, not as permanently learned spells unless explicitly learned.
- Campaign carryover must cap or filter artifacts by scenario rules and show what was retained, converted, or sealed.
- Old Measure and scenario artifacts need explicit objective-state serialization.

Migration rule: existing artifact ids should remain loadable until a deliberate migration slice remaps or retires them with compatibility handling.

## Validation And Testing Gates

Before the artifact system can be called production-deep, validation must prove:

- Every artifact has class, rarity, slot, roles, source tags, UI summary, AI hints, and valid effect payloads.
- Every artifact references registered resources, spells, statuses, schools, factions, unit tags, buildings, object classes, icons, VFX/audio ids, and set ids where applicable.
- Every slot follows equipment limits and duplicate rules.
- Every set has valid pieces, partial/full bonuses, source hints, and no impossible slot conflicts unless intentional.
- Every curse/tradeoff has visible UI warning, removal rules, save state, and AI downside valuation.
- Every artifact source table respects rarity, guard tier, object class, scenario locks, and unique ownership.
- Every economy artifact has capped income, cost, or conversion rules that cannot loop infinitely.
- Every spell-modifying artifact updates spellbook/cast-preview metadata.
- Save/resume preserves equipped artifacts, inventory, charges, cooldowns, curses, set bonuses, granted spells, unique ownership, and campaign carryover.
- AI can pick up, equip, transfer, pursue, ignore, and value artifacts in smoke scenarios.
- UI snapshots expose slot, rarity, role, faction/school affinity, set progress, comparison deltas, and curse warnings compactly.

Manual play gates:

- A player can understand what an artifact does before equipping it.
- A player can compare two artifacts without reading hidden rules.
- A player can see why a faction, hero, spell school, or unit army values an artifact.
- A player can pursue set pieces or guarded artifacts as a route decision.
- A player can identify and manage curses/tradeoffs without surprise loss.
- A player can save/resume after artifact pickup, equip, transfer, spell use, set completion, and curse removal.

## Concrete Target Artifact Family Catalog

This catalog is a production target, not an instruction to edit `content/artifacts.json` in this slice.

Minimum breadth before campaign/skirmish production:

- 30 to 40 common/uncommon utility artifacts.
- 12 to 18 artifacts per playable faction family.
- 10 to 14 artifacts per accord school family, including counters and catalysts.
- 8 to 12 Old Measure artifacts, mostly rare, charged, or scenario-gated.
- 8 to 12 cursed/tradeoff artifacts.
- 8 to 10 unique sets, with at least one set per faction plus neutral and Old Measure sets.
- 12 to 18 scenario/campaign artifacts for objectives and progression.

Representative catalog targets:

| Family | Target count | Example names |
| --- | --- | --- |
| Roadfinder Gear | 10 | Trailsinger Boots, Milepost Lantern, Causeway Spurs, Waymark Compass |
| Surveyor Instruments | 8 | Quarry Tally Rod, Shard Sextant Case, Prism Survey Pin, Flood Gauge Rule |
| Battle Command Pieces | 12 | Warcrest Pennon, Reserve Bell, Oathline Chain, Redoubt Order Tablet |
| Recovery Charms | 8 | Embergrain Cup, Field Infirmary Seal, Graft Salve Case, Pilgrim Ration Cord |
| Embercourt Relics | 14 | Tollstone Ring, Lockmaster Chain, River Judge Gavel, Ash Ledger Seal |
| Mireclaw Relics | 14 | Mudglass Beads, Chainboom Hook, Reed-Script Mask, Drowned Antler Crown |
| Sunvault Relics | 14 | Choir Tuning Fork, Relay Key, Prism Circlet, Aetherglass Heart |
| Thornwake Relics | 14 | Living Bridge Knot, Graft-Bound Mantle, Thorn Toll Brooch, Seedmask Charm |
| Brasshollow Relics | 14 | Pressure Gauge Reliquary, Debt-Seal Plate, Clause Hammer, Railmaster Cleats |
| Veilmourn Relics | 14 | Black-Sail Compass, Bell-Buoy Charm, Mirror Chart, Obituary Ink Vial |
| Old Measure Relics | 12 | Cracked Measure Shard, Timekeeping Bell, Weather Plate, Anchor Stone |
| Cursed Artifacts | 10 | Overbright Mirror, Rot-Crowned Antler, Unpaid Debt Seal, Drowned Route Chart |
| Set Pieces | 40+ | Charter Road pieces, Harmonic Relay pieces, Ninefold Measure fragments |
| Scenario Artifacts | 18 | Bridge Charter Proof, Evacuation Bell, Basin Claim Writ, Mirror Custody Key |

## Migration Sequence

1. Freeze this document as the artifact design target.
2. Add artifact schema design notes for class, rarity, slots, roles, affinities, source tags, typed effects, sets, curses, AI hints, UI metadata, and concept-art readiness.
3. Extend validators before adding broad artifact content.
4. Preserve existing artifact ids and map them into provisional rarity, class, role, and slot metadata without changing gameplay balance.
5. Define equipment slot limits, duplicate rules, unique ownership, and inventory/carry behavior.
6. Add typed artifact effect payloads while keeping compatibility for current simple bonus keys.
7. Add compact artifact UI metadata and comparison payloads with placeholder icons.
8. Add artifact source tables by object class, guard tier, region, faction, rarity, and scenario lock.
9. Add set schema and one small neutral set in a test branch of content after validation exists.
10. Add school/faction modifier hooks only after spell schema and faction vertical slices can consume them.
11. Add economy hooks only after resource migration decisions and caps exist.
12. Add curse/tradeoff support with UI warnings, removal services, save state, and AI downside valuation.
13. Add AI pickup/equip/transfer/pursuit heuristics and debug summaries.
14. Save/load migrate artifact inventory, equipped slots, charges, set derivation, curses, unique ownership, and artifact-granted spells.
15. Use concept-art-reviewed artifact sheets before final icon/runtime art or reward-screen polish.
16. Manually test artifact reward, equip, comparison, transfer, set progress, spell modification, economy effect, curse removal, and save/resume in one small map and one larger multi-faction map.

## Deep-Enough Gate For Campaign, Skirmish, Battle, And Town Polish

Artifacts are deep enough to support campaign/skirmish map production and battle/town polish only when:

- The artifact taxonomy, slot model, rarity bands, source rules, set rules, curse/tradeoff rules, and migration policy are locked or deliberately reduced.
- Existing artifact ids are migrated safely into the new metadata model without breaking saves.
- At least two factions have complete artifact vertical slices: family catalog, faction hooks, spell interactions, economy hooks, reward sources, UI reads, AI valuation, concept-art review, and manual play notes.
- Every major accord school has artifact support for focus, counterplay, catalyst handling, and at least one adventure-map role.
- Persistent economy and reward objects can source artifacts without invalid duplicates, impossible set chains, or scenario-breaking route/spell unlocks.
- Artifact UI remains compact and readable: slot, rarity, role, comparison, set progress, curse warnings, and granted spells are visible without covering scenic or play surfaces.
- AI can value artifacts for heroes, factions, armies, resource shortages, spellbooks, set progress, and guarded-route risk.
- Save/resume preserves artifact inventory, equipment, charges, cooldowns, curses, unique ownership, artifact-granted spells, set derivation, and campaign carryover.
- Concept-art stage gates for faction families, accord families, sets, cursed items, and source contexts have accepted review notes or documented placeholder exceptions.
- Manual play proves that players understand artifact purpose, build implications, reward sources, tradeoffs, set progress, spell interactions, and save behavior.

Until then, current artifacts remain useful scaffolding and flavor seeds, not production-depth artifact design.
