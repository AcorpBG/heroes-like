# Factions Content Bible

Status: design source, not implemented JSON.
Date: 2026-04-18.
Slice: faction-bible-design-10184.

This document starts the six-faction content-design workstream for heroes-like. It is implementation-ready direction for future JSON passes, but it does not claim that the live client currently contains six playable factions. Current authored JSON still only has partial Embercourt, Mireclaw, and Sunvault content.

## Design Contract

- Target faction count: 6.
- Target unit depth per faction: 7 tiers.
- Target hero depth per faction: at least 10 hero concepts, split across might and magic identities.
- Current surviving faction ids: `faction_embercourt`, `faction_mireclaw`, `faction_sunvault`.
- New planned faction ids: `faction_thornwake`, `faction_brasshollow`, `faction_veilmourn`.
- JSON implementation must happen later as vertical bundles: faction, heroes, units, buildings, towns, spells or abilities, encounters, scenario placements, AI tuning, validation, and manual play notes.
- Until the River Pass gate is proven, this document is a design bible only. Do not use this document to claim current faction breadth or playability.

## Cross-Faction Differentiation Rules

These rules exist to prevent the roster from collapsing into six reskins of the same faction.

1. No commons.
   - Avoid generic fantasy fillers such as "militia", "archer", "pikeman", "goblin", "ogre", "skeleton", "zombie", "elf", "dwarf", "angel", or "dragon" as a faction's identity carrier.
   - A familiar creature scale is allowed only when the name, silhouette, recruitment source, battlefield role, and mechanic are faction-specific enough that it cannot be moved to another faction unchanged.
   - Low tiers still need identity. Tier 1 cannot be a neutral-looking body with a common weapon.

2. No shared faction template skeletons.
   - Do not implement every ladder as cheap melee, archer, bruiser, cavalry, caster, flyer, ultimate.
   - Every faction needs a different distribution of blockers, ranged pressure, mobility, supports, siege, summons, and elite finishers.
   - Shared unit ability ids may exist in code, but final content should wrap them in faction-specific rules, triggers, names, and role pressure.

3. Each town must have a unique silhouette.
   - Embercourt reads as river fort, lockworks, beacon courts, and civic fire.
   - Mireclaw reads as drowned ferry chains, reed dens, drum circles, and predatory bog shrines.
   - Sunvault reads as crystal arrays, lens galleries, choirs, and solar relay crowns.
   - Thornwake reads as migratory living orchards, graft halls, root gates, and thorn tolls.
   - Brasshollow reads as contract foundries, pressure rails, furnace chapels, and brass gantries.
   - Veilmourn reads as fog harbors, bell docks, mirror drydocks, obituary vaults, and black-sail slips.

4. Each faction gets a distinct economy story.
   - Embercourt converts stable civic investment into readiness and reliable recruitment.
   - Mireclaw converts pressure, raiding, and den growth into cheap bodies and tempo.
   - Sunvault converts expensive infrastructure into quality, spell cycling, and prepared ranged lanes.
   - Thornwake converts rooted sites and growth buildings into regeneration, denial, and long campaigns.
   - Brasshollow converts ore and capital projects into machines, armor, and slow siege power.
   - Veilmourn converts scouting, salvage, and marked routes into ambush options and selective power spikes.

5. Each faction gets a distinct map-pressure pattern.
   - Embercourt fortifies crossings and forces the opponent to attack into prepared relief lines.
   - Mireclaw floods side lanes with raiders and punishes exposed sites.
   - Sunvault expands through relay nodes and projects threat along sightlines.
   - Thornwake roots roads and turns neutral lanes into recovery/denial zones.
   - Brasshollow advances through mining camps and siege staging, slow but hard to uproot.
   - Veilmourn manipulates fog, scouting, and route bypass to threaten weak backs.

6. Hero rosters cannot be generic class lists.
   - Might heroes should express how that faction commands armies, not just "better attack".
   - Magic heroes should express how that faction understands magic, not just "more spell power".
   - Each hero concept below includes an intended gameplay hook so future JSON specialties have a target.

7. Building ids must carry town identity.
   - Avoid shared upgrade names such as `building_barracks_2`.
   - If a building is structurally similar in code, give it a faction-specific id and mechanical wrapper.

8. Content migration must preserve stable ids only where they still fit.
   - Existing partial JSON can be migrated into these designs, but generic names should be renamed or replaced during the actual JSON pass.
   - Any migration that changes live content should update validators and manual scenario notes in the same slice.

## Faction Matrix

| Faction | Design id | Theme pillar | Economy style | Map pressure | Battle style | Ladder fingerprint |
| --- | --- | --- | --- | --- | --- | --- |
| Embercourt League | `faction_embercourt` | River charters, lockworks, beacon-fire civic war | Stable gold, readiness, discounted prepared levies | Secure crossings, signal relief, punish overextension | Braced lines, counterfire, late-order reserves | 3 line/control units, 2 support/fire units, 1 beast shock unit, 1 civic siege anchor |
| Mireclaw Covenant | `faction_mireclaw` | Predatory bog clans, ferry chains, drum oaths | Low base income, high growth, raid spoils | Multi-lane raids, site denial, wounded-prey pressure | Harried targets, finishers, attrition, ambush | 3 swarm/pack units, 2 control supports, 1 elite finisher, 1 bog apex |
| Sunvault Compact | `faction_sunvault` | Solar crystals, lens relays, harmonic command | Ore-heavy quality economy, support buildings, spell access | Relay nodes, battery sightlines, prepared fronts | Ranged lanes, shields, resonance timing | 2 ranged batteries, 2 line/duel pieces, 2 support/construct pieces, 1 array titan |
| Thornwake Concord | `faction_thornwake` | Migratory living orchards, grafted pilgrims, root law | Site-rooted growth, wood pressure, slow gold | Root roads, deny movement, recover through nurseries | Terrain growth, regeneration, binds, grind | 3 denial/regrowth units, 2 support/graft units, 1 mobile beast-knot, 1 rooted bastion |
| Brasshollow Combine | `faction_brasshollow` | Furnace contracts, pressure rails, brass debt engines | Ore and capital projects, expensive low growth | Mining camps, siege staging, resource exhaustion | Armor, heat bursts, artillery, repair windows | 2 machine skirmish/support units, 2 armored line units, 2 siege engines, 1 foundry saint |
| Veilmourn Armada | `faction_veilmourn` | Fog-bound funeral fleets, memory piracy, mirror charts | Salvage, scouting rewards, uneven income spikes | Fog lanes, bypass routes, ambush backs | Displacement, blinds, morale drain, isolation | 3 evasive/control units, 2 debuff/support units, 1 phase raider, 1 fog leviathan |

## Embercourt League

Implementation status: survives the uniqueness test only as a reworked river-charter faction. Current generic River Guard / Ember Archer style content should be replaced or renamed during the JSON pass.

### Fantasy And Theme Pillar

The Embercourt League is a confederation of river forts, mill cities, and oath courts that wages war through toll charters, beacon fires, lockworks, and disciplined relief columns. Their magic is not holy or noble-generic; it is civic fire, sworn signal law, and ash-sealed logistics.

### Mechanical Identity

Embercourt wins by preparing the board before the decisive fight. Their core loops should emphasize readiness, braced retaliations, crossing control, reserve timing, and reliable but not explosive recruitment. They are not the "human castle" faction; they are a river-state machine that turns roads, locks, granaries, and beacon courts into battlefield tempo.

### Town Visual And Building Identity

Towns should show stone river walls, water wheels, lock gates, beacon towers, red-lit court chambers, barge cranes, and ash-sealed ledgers. The skyline is horizontal and practical, broken by signal towers rather than palaces.

### Economy Style

Embercourt has steady gold and strong discounts once civic/support buildings are online. It should prefer investment chains that improve readiness, reduce recruitment friction, and protect towns. It should be average on raw growth, strong on recovery and affordability.

### Map Pressure Style

Embercourt projects control over bridges, roads, and crossings. It wants to hold towns and outposts, then punish opponents who raid too deep. AI pressure should value town defense, road chokepoints, and retaking linked support sites.

### Battle Style

Battle plans revolve around braced lanes, counterfire, and slow pressure. Embercourt wants the enemy to cross through controlled arcs, get marked or staggered, then be punished by sappers, barge weapons, and reserve elites.

### 7-Tier Unit Ladder

| Tier | Unit id | Unit name | Role notes |
| --- | --- | --- | --- |
| 1 | `unit_embercourt_fordhook_cadets` | Fordhook Cadets | Cheap crossing holders with hook reach, weak damage, and strong defensive retaliation when adjacent to an objective or braced ally. |
| 2 | `unit_embercourt_lantern_sappers` | Lantern Sappers | Control skirmishers who seed ember pots, reveal hidden threats, and punish enemies that end movement in prepared lanes. |
| 3 | `unit_embercourt_bargebow_crews` | Bargebow Crews | Heavy ranged crews with limited shots, bonus damage from protected lanes, and poor output when isolated. |
| 4 | `unit_embercourt_ash_oath_bailiffs` | Ash-Oath Bailiffs | Elite civic enforcers that bodyguard adjacent stacks, convert defense orders into retaliation pressure, and resist morale shocks. |
| 5 | `unit_embercourt_beacon_lectors` | Beacon Lectors | Support casters who refresh readiness, mark attack lanes, and let nearby units act with cleaner target priority. |
| 6 | `unit_embercourt_sluicefire_lindworms` | Sluicefire Lindworms | Lock-bred fire beasts that surge through narrow lanes, scorch clustered targets, and collapse if left unsupported. |
| 7 | `unit_embercourt_charter_colossus` | Charter Colossus | A walking court-bell engine that anchors a zone, increases allied retaliation value, and forces enemies to either disengage or commit fully. |

### Hero Concepts

Might identities:

| Hero id | Name | Identity hook |
| --- | --- | --- |
| `hero_embercourt_mira_flintmere` | Mira Flintmere | Bridgehead marshal; improves braced melee tempo and converts first retaliation each round into momentum. |
| `hero_embercourt_caelen_ashgrove` | Caelen Ashgrove | Mill-country castellan; improves town defense, garrison recovery, and crossing-site support radius. |
| `hero_embercourt_torren_pikeward` | Torren Pikeward | Quartermaster captain; reduces low and mid-tier recruitment costs after economy buildings. |
| `hero_embercourt_helva_tollbrand` | Helva Tollbrand | Toll-road hunter; gains map movement and combat bonuses near controlled roads or bridges. |
| `hero_embercourt_saren_lockmaster` | Saren Lockmaster | Siege-lock commander; improves sappers, bargebows, and town assault control effects. |

Magic identities:

| Hero id | Name | Identity hook |
| --- | --- | --- |
| `hero_embercourt_lyra_emberwell` | Lyra Emberwell | Beacon pathfinder; grants scouting and first-round lane marks on revealed enemies. |
| `hero_embercourt_seren_valechant` | Seren Valechant | Star-ledger mage; turns exploration and cache recovery into spell tempo. |
| `hero_embercourt_orra_cinderquill` | Orra Cinderquill | Ash writ specialist; strengthens fire-control spells and anti-ambush reveal effects. |
| `hero_embercourt_belis_rainledger` | Belis Rainledger | Granary economist; converts civic buildings into spell points, gold smoothing, or recovery. |
| `hero_embercourt_jorun_beaconscribe` | Jorun Beaconscribe | Signal court lector; improves ally initiative when formations remain compact. |

### Signature Buildings

| Building id | Name | Implementation note |
| --- | --- | --- |
| `building_embercourt_charter_bastion` | Charter Bastion | Capital project; raises readiness, defense, and reserve pressure from linked support sites. |
| `building_embercourt_beacon_court` | Beacon Court | Support/magic hybrid; unlocks beacon spells, scouting bonuses, and lane marks. |
| `building_embercourt_granary_lock_exchange` | Granary Lock Exchange | Economy; steady gold plus wood and small low-tier growth. |
| `building_embercourt_oath_pikehall` | Oath Pikehall | Dwelling; unlocks Ash-Oath Bailiffs or improves Fordhook Cadet line play. |
| `building_embercourt_bargebow_slip` | Bargebow Slip | Dwelling; unlocks Bargebow Crews and improves town defense ranged pressure. |
| `building_embercourt_drake_sluice` | Drake Sluice | Dwelling; unlocks Sluicefire Lindworms, high ore and support requirements. |
| `building_embercourt_tollstone_weir` | Tollstone Weir | Economy/support; improves road-site income and crossing control. |

## Mireclaw Covenant

Implementation status: survives the uniqueness test as the predatory bog-and-ferry faction. Current cutthroat, slinger, brute, and ripper ideas can remain as ancestors, but the full ladder needs stronger identity and tier separation.

### Fantasy And Theme Pillar

The Mireclaw Covenant is a marsh oath culture built from ferry raiders, beast handlers, reed-script shrine keepers, and clans that treat the bog as a living hunting ground. Their fantasy is not "green monster horde"; it is predatory wetland logistics, drum law, drowning traps, and wounded-prey rituals.

### Mechanical Identity

Mireclaw wins by making the map feel unsafe. It should create pressure through cheap bodies, quick raids, harried status effects, wounded-target finishers, and den growth. It accepts losses better than most factions and turns disrupted enemies into kill opportunities.

### Town Visual And Building Identity

Towns sit on drowned pilings, chain ferries, reed dens, bog forges, drum platforms, smoked hides, and black reedstone shrines. The skyline is low, wet, and threatening, with movement implied through ferry lanes rather than roads.

### Economy Style

Mireclaw has lower safe income and higher pressure income. It should gain value from raiding, dwellings, den upgrades, and sites that support ferries or drums. It should have strong early growth, uneven quality, and cheaper low-tier replacement.

### Map Pressure Style

Mireclaw should field multiple small threats, hunt resource sites, and punish isolated heroes. Its AI should prefer site denial, neutral dwelling capture, and hero hunting over slow town sieges until enough pressure has built.

### Battle Style

Mireclaw fights dirty: harry, stagger, isolate, then finish. Many units should get better against wounded, slowed, or statused enemies. Defensive staying power should come from mass, bog armor, and debuffs rather than clean shields.

### 7-Tier Unit Ladder

| Tier | Unit id | Unit name | Role notes |
| --- | --- | --- | --- |
| 1 | `unit_mireclaw_reedsnare_kin` | Reedsnare Kin | Cheap snare infantry that slows or marks targets, poor straight damage, strong when surrounding. |
| 2 | `unit_mireclaw_mudglass_slingers` | Mudglass Slingers | Ranged harriers that spread mudglass blindness and make later pack attacks more reliable. |
| 3 | `unit_mireclaw_bogplate_maulers` | Bogplate Maulers | Slow bruisers with ranged resistance and bonus damage while enemies are harried. |
| 4 | `unit_mireclaw_ferrychain_lashers` | Ferrychain Lashers | Control unit that pulls, pins, or punishes movement across lanes and objectives. |
| 5 | `unit_mireclaw_sporewake_chanters` | Sporewake Chanters | Debuff support that spreads rot chants, weakens recovery, and amplifies wounded-prey triggers. |
| 6 | `unit_mireclaw_gorefen_rippers` | Gorefen Rippers | Elite finishers that spike damage against wounded or isolated targets, fragile if forced to trade frontally. |
| 7 | `unit_mireclaw_drowned_antler_sovereign` | Drowned Antler Sovereign | Bog apex beast that creates fear, trample lanes, and heavy pressure around wounded stacks. |

### Hero Concepts

Might identities:

| Hero id | Name | Identity hook |
| --- | --- | --- |
| `hero_mireclaw_vaska_reedmaw` | Vaska Reedmaw | Raid captain; increases pressure from quick site captures and first-strike pack damage. |
| `hero_mireclaw_tarn_fenhook` | Tarn Fenhook | Fog-lane tracker; improves movement through marsh/fog and ambush setup. |
| `hero_mireclaw_orrik_tollreaver` | Orrik Tollreaver | Packlord; improves den growth and low-tier replacement after losses. |
| `hero_mireclaw_kessa_chainboom` | Kessa Chainboom | Ferrychain breaker; improves control units and bridge/crossing fights. |
| `hero_mireclaw_brakka_mudkeel` | Brakka Mudkeel | Bogplate handler; makes bruisers cheaper and harder to dislodge. |

Magic identities:

| Hero id | Name | Identity hook |
| --- | --- | --- |
| `hero_mireclaw_sable_muckscribe` | Sable Muckscribe | Reed-script hexcaller; improves debuffs and relic pressure. |
| `hero_mireclaw_nix_votivejaw` | Nix Votivejaw | Shrine-biter; converts battlefield kills into temporary spell power or pressure. |
| `hero_mireclaw_edda_rotlamp` | Edda Rotlamp | Sporewake mystic; strengthens rot, blind, and recovery-denial effects. |
| `hero_mireclaw_pell_reedscript` | Pell Reedscript | Den augur; improves dwelling growth when map sites are linked. |
| `hero_mireclaw_zhorra_fenwake` | Zhorra Fenwake | Drum oracle; accelerates units after enemies become harried or wounded. |

### Signature Buildings

| Building id | Name | Implementation note |
| --- | --- | --- |
| `building_mireclaw_blackbranch_den` | Blackbranch Den | Low-tier dwelling and den-growth root. |
| `building_mireclaw_chainboom_ferry` | Chainboom Ferry | Map pressure/economy; improves raiding, crossing control, and retreat routes. |
| `building_mireclaw_war_drum_circle` | War Drum Circle | Support; increases pressure and pack initiative around wounded targets. |
| `building_mireclaw_sporewake_shrine` | Sporewake Shrine | Magic; unlocks rot, blind, and recovery-denial spell families. |
| `building_mireclaw_floodtide_forge` | Floodtide Forge | Support/economy; strengthens Bogplate Maulers and grants ore trickle. |
| `building_mireclaw_nightglass_dominion` | Nightglass Dominion | Capital project; sustains deeper raids and elite pack growth. |
| `building_mireclaw_antler_pit` | Antler Pit | Top-tier dwelling; unlocks Drowned Antler Sovereign. |

## Sunvault Compact

Implementation status: survives the uniqueness test as the crystal-array and harmonic-command faction. Current shard/prism/mirror/aurora content can remain as a partial foundation if expanded away from a generic guard-archer-duelist shape.

### Fantasy And Theme Pillar

The Sunvault Compact is a disciplined crystal society that treats battle as calibration. Its towns are buried relay cities, lens crowns, choir galleries, and solar vaults. Their magic is geometric, harmonic, and blinding rather than celestial-good.

### Mechanical Identity

Sunvault wins by setting up resonance. It should reward formation, prepared lanes, spell timing, and target focus. The faction is expensive, quality-focused, and worse when forced into scattered brawls.

### Town Visual And Building Identity

Towns should show crystal buttresses, mirrored terraces, lens tracks, resonant cloisters, prism yards, and tower crowns that redirect sun into batteries. The silhouette is bright, angular, and vertical.

### Economy Style

Sunvault wants ore and support buildings. It has moderate gold, high build costs, and strong quality once relay chains are active. Growth is not swarmy; it should get better through upgraded dwellings and support/magic infrastructure.

### Map Pressure Style

Sunvault prefers linked relay nodes, watch sites, and prepared objectives. It should push by extending safe firing/sightline networks, not by flooding the map.

### Battle Style

Sunvault controls range and timing. Units gain value from marked targets, defending allies, resonance stacks, and support spells. They should have high clarity and strong turns, but can be flanked or rushed when unprepared.

### 7-Tier Unit Ladder

| Tier | Unit id | Unit name | Role notes |
| --- | --- | --- | --- |
| 1 | `unit_sunvault_shard_wardens` | Shard Wardens | Durable low-tier shield line that reflects minor damage and protects ranged arrays. |
| 2 | `unit_sunvault_prism_adepts` | Prism Adepts | Accurate ranged unit that improves against marked or staggered targets. |
| 3 | `unit_sunvault_mirror_duelists` | Mirror Duelists | Mobile melee unit that exploits broken timing and can reposition through reflected lanes. |
| 4 | `unit_sunvault_resonant_choristers` | Resonant Choristers | Support stack that improves spell cycles, ally cohesion, and marked-target focus. |
| 5 | `unit_sunvault_solar_array_striders` | Solar Array Striders | Construct walkers that project small firing lanes and resist disruption. |
| 6 | `unit_sunvault_aurora_ballistae` | Aurora Ballistae | Heavy battery unit, excellent behind protected lanes, weak to close pressure. |
| 7 | `unit_sunvault_daybreak_colossus` | Daybreak Colossus | Top-tier array titan that amplifies resonance and turns a prepared front into a killing field. |

### Hero Concepts

Might identities:

| Hero id | Name | Identity hook |
| --- | --- | --- |
| `hero_sunvault_solera_prismarch` | Solera Prismarch | Array marshal; improves line cohesion and resonance from defensive orders. |
| `hero_sunvault_varis_mirrorstep` | Varis Mirrorstep | Flank commander; improves Mirror Duelists and reposition attacks. |
| `hero_sunvault_ilyr_glassmarshal` | Ilyr Glassmarshal | Battery captain; improves Aurora Ballistae setup and protected-lane damage. |
| `hero_sunvault_dovan_lenscaptain` | Dovan Lens-Captain | Relay surveyor; improves map watch sites and ranged combat near relays. |
| `hero_sunvault_renn_facetlane` | Renn Facetlane | Duel-line tactician; improves target focus after enemy initiative drops. |

Magic identities:

| Hero id | Name | Identity hook |
| --- | --- | --- |
| `hero_sunvault_neral_glasswind` | Neral Glasswind | Sunlance seer; specializes in line damage and marked target spells. |
| `hero_sunvault_thalen_choirward` | Thalen Choirward | Cloister keeper; extends support spell duration and cohesion recovery. |
| `hero_sunvault_essa_daynote` | Essa Daynote | Harmonic scholar; improves resonance stack generation. |
| `hero_sunvault_calis_sunvein` | Calis Sunvein | Solar physician; turns light spells into shields and damage smoothing. |
| `hero_sunvault_mirro_halometer` | Mirro Halometer | Calibration mage; improves spell accuracy, dispel resistance, and relay building value. |

### Signature Buildings

| Building id | Name | Implementation note |
| --- | --- | --- |
| `building_sunvault_shard_yard` | Shard Yard | Low-tier dwelling and shield-line root. |
| `building_sunvault_lens_gallery` | Lens Gallery | Ranged dwelling/support; strengthens Prism Adepts and sightline play. |
| `building_sunvault_harmonic_cloister` | Harmonic Cloister | Support/magic; improves spell cycles and formation recovery. |
| `building_sunvault_aurora_spire` | Aurora Spire | Heavy battery dwelling; unlocks Aurora Ballistae. |
| `building_sunvault_daybreak_matrix` | Daybreak Matrix | Capital project; activates high-tier relay pressure. |
| `building_sunvault_mirror_forge` | Mirror Forge | Dwelling/support; upgrades duelists and line reposition tools. |
| `building_sunvault_zenith_observatory` | Zenith Observatory | Magic/scouting; improves relay sight and sunlance spell access. |

## Thornwake Concord

Implementation status: new planned faction. Do not reduce it to generic elves, druids, or treants. Its identity is migratory living infrastructure and graft law.

### Fantasy And Theme Pillar

The Thornwake Concord is a league of root pilgrims, graftwrights, seed judges, and living orchard-caravans that carries its homeland with it. It does not defend "nature" in the abstract; it spreads binding root law, toll briars, and living fortifications into contested roads.

### Mechanical Identity

Thornwake wins by making the battlefield and map less convenient for enemies every turn. It should grow value from rooted sites, recover in prepared zones, create terrain pressure, and win attrition. It is slow to start and dangerous when allowed to seed a region.

### Town Visual And Building Identity

Towns should look alive and mobile: root wheels, suspended seed vaults, graft halls, living bridges, moss-lit courts, thorn toll arches, and orchard engines. The silhouette is rounded, tangled, and vertical-horizontal at once.

### Economy Style

Thornwake is wood and growth hungry, with weaker direct gold but strong site-linked growth. It should care about neutral sites becoming rooted, support radius, and recovery. Some buildings should improve unit growth only when linked sites remain controlled.

### Map Pressure Style

Thornwake roots roads, slows enemy movement near controlled support sites, and uses nurseries to recover losses. Its pressure is not fast raiding; it is turning the map into hostile terrain for everyone else.

### Battle Style

Thornwake creates brambles, binds targets, regenerates while holding ground, and forces enemies to waste actions escaping control. It has limited burst and limited clean ranged damage.

### 7-Tier Unit Ladder

| Tier | Unit id | Unit name | Role notes |
| --- | --- | --- | --- |
| 1 | `unit_thornwake_seedcutters` | Seedcutters | Low-tier carriers that plant minor brambles, block lanes, and improve when fighting on rooted ground. |
| 2 | `unit_thornwake_thornwhip_carriers` | Thornwhip Carriers | Reach/control unit that binds enemies and punishes disengage attempts. |
| 3 | `unit_thornwake_sporeglass_menders` | Sporeglass Menders | Support unit that heals small amounts, clears some debuffs, and spreads rooted status. |
| 4 | `unit_thornwake_barkmantle_rams` | Barkmantle Rams | Durable living siege beasts that break fortified lines but move slowly. |
| 5 | `unit_thornwake_stagknot_runners` | Stag-Knot Runners | Mobile beast-knot flankers that leap through allied brambles and pin ranged units. |
| 6 | `unit_thornwake_graft_matriarchs` | Graft Matriarchs | Large support leaders that improve regeneration, create stronger brambles, and punish attackers who ignore them. |
| 7 | `unit_thornwake_worldroot_bastion` | Worldroot Bastion | Top-tier living fortress that roots a section of the battlefield and turns nearby allies into an attrition wall. |

### Hero Concepts

Might identities:

| Hero id | Name | Identity hook |
| --- | --- | --- |
| `hero_thornwake_ardren_briarmarshal` | Ardren Briar-Marshal | Front commander; improves binds and retaliation on rooted ground. |
| `hero_thornwake_tova_rootwright` | Tova Rootwright | Siege grower; improves Barkmantle Rams and town assault bramble creation. |
| `hero_thornwake_halen_thorncart` | Halen Thorncart | Pilgrim captain; improves map movement between rooted sites and low-tier growth. |
| `hero_thornwake_merek_greenbarrow` | Merek Greenbarrow | Recovery warden; improves post-battle wounded recovery in controlled regions. |
| `hero_thornwake_silsa_bramblehound` | Silsa Bramble-Hound | Hunt leader; improves Stag-Knot Runners and anti-ranged pinning. |

Magic identities:

| Hero id | Name | Identity hook |
| --- | --- | --- |
| `hero_thornwake_veyra_seedseer` | Veyra Seedseer | Root oracle; creates rooted terrain faster and improves rooted-site rewards. |
| `hero_thornwake_osmund_pollenglass` | Osmund Pollenglass | Sporeglass doctor; improves healing, cleanse, and debuff resistance. |
| `hero_thornwake_elian_loamchant` | Elian Loamchant | Loam singer; strengthens bind spells and battlefield bramble duration. |
| `hero_thornwake_ralka_mossvein` | Ralka Mossvein | Moss memory mage; converts long fights into spell power and recovery. |
| `hero_thornwake_nara_graftsibyl` | Nara Graft-Sibyl | Graft prophet; improves high-tier support units and growth chains. |

### Signature Buildings

| Building id | Name | Implementation note |
| --- | --- | --- |
| `building_thornwake_seed_vault` | Seed Vault | Core civic/economy; stores growth and links map sites. |
| `building_thornwake_graftworks` | Graftworks | Support; unlocks menders and improves recovery. |
| `building_thornwake_bramble_toll` | Bramble Toll | Map pressure; slows enemy movement near linked sites and adds gold trickle. |
| `building_thornwake_sporeglass_hothouse` | Sporeglass Hothouse | Magic/support; unlocks healing and cleanse spells. |
| `building_thornwake_barkmantle_run` | Barkmantle Run | Dwelling; unlocks Barkmantle Rams. |
| `building_thornwake_pilgrim_orchard` | Pilgrim Orchard | Economy/growth; stronger if neutral sites are rooted. |
| `building_thornwake_worldroot_gate` | Worldroot Gate | Capital/top-tier; unlocks Worldroot Bastion and regional recovery. |

## Brasshollow Combine

Implementation status: new planned faction. Do not reduce it to generic dwarves, golems, or steampunk soldiers. It is a furnace-contract society where debt, ore, pressure, and war engines are fused into law.

### Fantasy And Theme Pillar

The Brasshollow Combine is a network of foundry vaults, pressure rails, furnace chapels, contract courts, and brass debt engines. Its people treat war as an audited industrial obligation. Magic appears as heat rites, pressure seals, and binding clauses stamped into metal.

### Mechanical Identity

Brasshollow wins by building expensive, stubborn force. It should have low growth, high durability, repair windows, heat/overpressure bursts, and strong siege tools. It suffers if denied ore or forced to chase fast raiders across open maps.

### Town Visual And Building Identity

Towns should show furnace pits, brass lifts, ore elevators, gantry cranes, pressure rail terminals, boiler chapels, contract halls, and glowing slag canals. The silhouette is heavy, angular, smoky, and mechanical.

### Economy Style

Brasshollow is ore hungry and build-order sensitive. It has strong late economy from mines and capital projects, but expensive recruitment and slow replacement. Some machine units should be repairable or recoverable differently from living troops.

### Map Pressure Style

Brasshollow advances slowly through mining camps, railheads, and siege stages. It wants to exhaust resources, hold production sites, and bring overwhelming force to specific objectives rather than raid everywhere.

### Battle Style

Brasshollow fights with armor, heat, and artillery. Units should be hard to kill but positioning-limited. Heat bursts create dangerous turns followed by cooldown or vulnerability windows.

### 7-Tier Unit Ladder

| Tier | Unit id | Unit name | Role notes |
| --- | --- | --- | --- |
| 1 | `unit_brasshollow_scrip_haulers` | Scrip Haulers | Armored labor levy that can brace and perform minor repairs, low damage. |
| 2 | `unit_brasshollow_rivet_hounds` | Rivet Hounds | Fast clockwork skirmishers that harass ranged units and reveal weak armor. |
| 3 | `unit_brasshollow_furnace_pavis_teams` | Furnace Pavis Teams | Heavy shield teams that protect engines and punish frontal attacks. |
| 4 | `unit_brasshollow_boiler_rivetcasters` | Boiler Rivetcasters | Short-ranged pressure artillery with heat buildup and splash risk. |
| 5 | `unit_brasshollow_debt_engine_exactors` | Debt-Engine Exactors | Elite melee engines that overheat for burst damage and then need protection. |
| 6 | `unit_brasshollow_crucible_crawlers` | Crucible Crawlers | Siege engines that burn terrain, damage clustered enemies, and require setup. |
| 7 | `unit_brasshollow_foundry_saint` | Foundry Saint | Top-tier walking furnace idol that repairs machines, hardens allies, and turns heat into area pressure. |

### Hero Concepts

Might identities:

| Hero id | Name | Identity hook |
| --- | --- | --- |
| `hero_brasshollow_marka_ironclause` | Marka Ironclause | Contract marshal; improves armored units and morale under attrition. |
| `hero_brasshollow_oren_bellfounder` | Oren Bellfounder | Siege captain; improves artillery setup and town assault pressure. |
| `hero_brasshollow_kuld_varn` | Kuld Varn | Railhead enforcer; improves map movement between owned mines and towns. |
| `hero_brasshollow_selka_pitmarshal` | Selka Pitmarshal | Mine-field commander; improves ore-site defense and machine replacement. |
| `hero_brasshollow_daxis_chaincaptain` | Daxis Chain-Captain | Pavis foreman; improves bodyguard rules and frontline armor. |

Magic identities:

| Hero id | Name | Identity hook |
| --- | --- | --- |
| `hero_brasshollow_vellum_quench` | Vellum Quench | Heat rite engineer; improves overheat spells and cooldown smoothing. |
| `hero_brasshollow_odrik_heatpriest` | Odrik Heatpriest | Furnace chaplain; converts damage taken into temporary armor or spell power. |
| `hero_brasshollow_lina_gaugesavant` | Lina Gauge-Savant | Pressure mathematician; improves machine accuracy and heat thresholds. |
| `hero_brasshollow_harro_debtrune` | Harro Debt-Rune | Clause mage; specializes in binding, slowing, and punishing broken formations. |
| `hero_brasshollow_pava_ashmeter` | Pava Ashmeter | Slag alchemist; improves burn terrain and resource conversion. |

### Signature Buildings

| Building id | Name | Implementation note |
| --- | --- | --- |
| `building_brasshollow_ore_tithe_office` | Ore Tithe Office | Economy; boosts ore-site income and build affordability. |
| `building_brasshollow_boiler_cathedral` | Boiler Cathedral | Magic/support; unlocks heat rites and machine recovery. |
| `building_brasshollow_rivet_kennels` | Rivet Kennels | Dwelling; unlocks Rivet Hounds and anti-raider tools. |
| `building_brasshollow_pavis_foundry` | Pavis Foundry | Dwelling/support; improves armored line units. |
| `building_brasshollow_pressure_rail` | Pressure Rail | Map pressure; improves movement between owned production sites. |
| `building_brasshollow_crucible_dock` | Crucible Dock | Dwelling; unlocks Crucible Crawlers. |
| `building_brasshollow_titan_charter_hall` | Titan Charter Hall | Capital/top-tier; unlocks Foundry Saint and late siege pressure. |

## Veilmourn Armada

Implementation status: new planned faction. Do not reduce it to generic undead, pirates, or shadow assassins. It is a fog-bound funeral fleet that steals routes, memories, and certainty.

### Fantasy And Theme Pillar

The Veilmourn Armada is a chain of black-sail houses, obituary mages, mirror navigators, bell crews, and mist-bound captains who sail where maps say no water exists. Their power comes from funeral vows, stolen charts, and memory salvage rather than death-horde necromancy.

### Mechanical Identity

Veilmourn wins by information and disruption. It should scout unusually well, create fog-lane bypasses, isolate targets, displace positions, blind ranged enemies, and spike value from marked victims. Its armies should be fragile when pinned in honest trades.

### Town Visual And Building Identity

Towns should appear as harbors inside fog: bell towers, mirror drydocks, black mooring posts, obituary libraries, lantern reefs, harpoon gantries, and half-visible hulls. The silhouette is vertical masts and negative space rather than stone mass.

### Economy Style

Veilmourn income is uneven. It gains from scouting, salvage sites, artifacts, marked routes, and battle cleanup. It should not have the stable gold of Embercourt or the raw build economy of Brasshollow.

### Map Pressure Style

Veilmourn threatens by knowing more and moving strangely. It should bypass some normal route pressure through fog wakes, threaten backline sites, and force opponents to guard what they thought was safe.

### Battle Style

Veilmourn uses displacement, blinds, morale drain, and isolation. It should create confusing tactical states for enemies while keeping the player-facing UI readable: which stack is marked, which lane is fogged, and which unit can phase must be explicit.

### 7-Tier Unit Ladder

| Tier | Unit id | Unit name | Role notes |
| --- | --- | --- | --- |
| 1 | `unit_veilmourn_bellwake_oars` | Bellwake Oars | Evasive low-tier crew that scouts, screens, and gains defense while fogged. |
| 2 | `unit_veilmourn_mourning_lanterns` | Mourning Lanterns | Support lights that reveal, blind, or mark targets for isolation. |
| 3 | `unit_veilmourn_maskglass_corsairs` | Maskglass Corsairs | Mobile melee skirmishers that punish isolated or blinded enemies. |
| 4 | `unit_veilmourn_undertow_harpooners` | Undertow Harpooners | Ranged/control unit that pulls targets, breaks formation, and sets up kill lanes. |
| 5 | `unit_veilmourn_obituary_scribes` | Obituary Scribes | Debuff support that drains morale, weakens retaliation, and stores salvage value. |
| 6 | `unit_veilmourn_mirrorkeel_reavers` | Mirror-Keel Reavers | Phase raiders that reposition through fog lanes and strike backline stacks. |
| 7 | `unit_veilmourn_fogbound_leviathan` | Fogbound Leviathan | Top-tier control monster that floods sections of the battlefield with fog and punishes isolated victims. |

### Hero Concepts

Might identities:

| Hero id | Name | Identity hook |
| --- | --- | --- |
| `hero_veilmourn_ivara_blacktide` | Ivara Blacktide | Black-sail admiral; improves isolated-target damage and retreat control. |
| `hero_veilmourn_ruln_vanehook` | Ruln Vanehook | Harpoon captain; improves displacement, pulls, and anti-large tactics. |
| `hero_veilmourn_cela_mistcorsair` | Cela Mist-Corsair | Backline raider; improves phase movement and fog-lane attacks. |
| `hero_veilmourn_damar_oriflag` | Damar Oriflag | Signal thief; improves scouting raids and enemy movement disruption. |
| `hero_veilmourn_jessa_keelwarden` | Jessa Keelwarden | Fleet defender; improves fragile-stack survival and controlled withdrawals. |

Magic identities:

| Hero id | Name | Identity hook |
| --- | --- | --- |
| `hero_veilmourn_morwen_wakeoracle` | Morwen Wakeoracle | Fog prophet; creates fog lanes and improves vision manipulation. |
| `hero_veilmourn_thir_obituaryink` | Thir Obituary-Ink | Memory scribe; turns kills, artifacts, and salvage into spell tempo. |
| `hero_veilmourn_sael_mirrorbell` | Sael Mirrorbell | Mirror navigator; improves displacement spells and decoy effects. |
| `hero_veilmourn_nacre_vowless` | Nacre Vowless | Funeral hexer; weakens enemy retaliation and morale-style momentum. |
| `hero_veilmourn_orso_nightchart` | Orso Nightchart | Route diviner; improves scouting rewards and hidden-route map pressure. |

### Signature Buildings

| Building id | Name | Implementation note |
| --- | --- | --- |
| `building_veilmourn_bell_harbor` | Bell Harbor | Core dwelling/support; improves scouting and low-tier fog defense. |
| `building_veilmourn_mirror_drydock` | Mirror Drydock | Mobility/support; unlocks phase and route-bypass mechanics. |
| `building_veilmourn_obituary_vault` | Obituary Vault | Magic/economy; converts salvage into spell access or income spikes. |
| `building_veilmourn_harpoon_gantry` | Harpoon Gantry | Dwelling; unlocks Undertow Harpooners and formation-break tools. |
| `building_veilmourn_mistgate_slip` | Mistgate Slip | Map pressure; creates or improves fog-lane movement. |
| `building_veilmourn_ransom_exchange` | Ransom Exchange | Economy; rewards scouting, battle cleanup, and artifact recovery. |
| `building_veilmourn_leviathan_sounding` | Leviathan Sounding | Capital/top-tier; unlocks Fogbound Leviathan and stronger fog zones. |

## Current JSON Migration Notes

- `faction_embercourt` remains valid as a stable id, but its current identity should move away from generic civic levies and archers toward lockworks, beacon courts, ash writs, and river-control units.
- `faction_mireclaw` remains valid as a stable id. Current `unit_blackbranch_cutthroat`, `unit_mire_slinger`, `unit_bog_brute`, and `unit_gorefen_ripper` can either be renamed into the new ladder or kept as legacy prototypes until the vertical content migration.
- `faction_sunvault` remains valid as a stable id. Current shard/prism/mirror/aurora concepts are directionally compatible, but the full seven-tier ladder needs stronger support, construct, and top-tier identities.
- New ids should be introduced only when their vertical slice is ready: `faction_thornwake`, `faction_brasshollow`, and `faction_veilmourn`.
- Hero ids in this bible are future targets. The current small hero roster should not be deleted or renamed casually if River Pass or existing scenarios reference it; migrate with compatibility in mind.
- This bible intentionally does not add JSON content. The first implementation pass should choose the two alpha factions after River Pass is manually completable, then build those factions through complete units, towns, buildings, heroes, battle hooks, AI preferences, and scenario placements.

## Future Implementation Checklist

For each faction implementation slice:

1. Freeze the faction identity and confirm it still passes the no-commons and no-shared-skeleton rules.
2. Add or migrate `content/factions.json` data.
3. Add 7 tiers in `content/units.json` with unique names, roles, ability wrappers, growth, and costs.
4. Add at least 10 heroes in `content/heroes.json`, split across might and magic identities.
5. Add faction buildings in `content/buildings.json` and town build lists in `content/towns.json`.
6. Add or map spells, artifacts, resource sites, and encounters needed for the faction's mechanical identity.
7. Add AI strategy weights that express the faction's map pressure, not generic aggression.
8. Add validator coverage for content references, roster depth, and faction-specific required hooks.
9. Place the faction in at least one scenario or skirmish test map before calling it playable.
10. Capture manual play notes for town, overworld, battle, save/load, and outcome routing.
