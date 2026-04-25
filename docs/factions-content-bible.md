# Factions Content Bible

Status: design source, not implemented JSON.
Date: 2026-04-25.
Slice: faction-identity-foundation-10184.

This document defines the six target factions as original, world-grounded identity packages for Aurelion Reach. It supersedes the 2026-04-18 scaffold-first faction bible while preserving useful stable IDs, production naming direction, unit ladder intent, hero concepts, and building seeds.

Heroes 2, Heroes 3, and Oden Era may inspire expectations for breadth, readability, and strategic density only. They are not source material for creative substance, names, maps, faction identities, unit art, music, or text.

## Design Contract

- Target faction count: 6.
- Target unit depth per faction: 7 tiers.
- Target hero depth per faction: at least 10 hero concepts, split across might and magic identities.
- Existing faction ids to preserve where compatible: `faction_embercourt`, `faction_mireclaw`, `faction_sunvault`.
- Planned faction ids: `faction_thornwake`, `faction_brasshollow`, `faction_veilmourn`.
- JSON migration must happen later as vertical bundles: faction metadata, heroes, units, buildings, towns, spells or abilities, encounters, scenario placements, AI tuning, validation, and manual play notes.
- This bible is design direction only. It does not claim that the live client currently contains six playable factions.

## Shared World Grounding

The six factions are competing powers in the Charter War over Aurelion Reach, a broken basin where sky mirrors once regulated seasons, tides, memory, weather, and ore growth. The factions are not good-versus-evil skins. Each is partly right about how to survive the shattered world and dangerous when its local answer becomes basin-wide rule.

Faction identity must stay tied to:

- **Geography**: rivers, marshes, uplands, walking forests, furnace valleys, and fog coasts create political behavior.
- **Infrastructure**: locks, ferries, lenses, root gates, pressure rails, and bell harbors are strategic tools, not background flavor.
- **Accordance magic**: each faction makes reality obey through a distinct anchor language.
- **Economy pressure**: resources are political. Gold, timber, ore, aetherglass, embergrain, peatwax, verdant grafts, brass scrip, and memory salt should matter differently by faction.
- **Readable asymmetry**: no faction should be a swapped template with cheap melee, archer, cavalry, caster, flyer, and ultimate.

## Cross-Faction Contrast Matrix

| Faction | World role | Political motive | Moral tension | Accord identity | Economy pressure | Map pressure | Battle fingerprint |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Embercourt League | Civic river-law power of the Emberflow Basin | Restore enforceable roads, tolls, records, and granaries | Public order can become coercive occupation | Beacon Accord through writs, signal fires, court bells | Gold, timber, embergrain, road-linked income | Hold crossings, retake roads, punish overextension | Braced lines, counterfire, reserves, retaliation value |
| Mireclaw Covenant | Marsh sovereignty and predatory ferry clans of the Drowned Marches | Keep lowlands outside courthouse maps and mine contracts | Freedom from empire can shelter raids, extortion, and blood debts | Mire Accord through drums, reeds, peat, rot rites | Peatwax, raid spoils, den growth, replacement loops | Multi-lane raids, site denial, wounded-prey pressure | Harry, blind, drag, isolate, finish wounded targets |
| Sunvault Compact | Solar calibrators of the Glass Uplands | Rebuild mirror order under disciplined relay control | Truth and restoration can become technocratic rule | Lens Accord through crystals, choirs, prisms, relays | Ore, aetherglass, costly quality upgrades | Extend relay nodes, sightlines, and prepared fronts | Ranged lanes, shields, resonance timing, focused marks |
| Thornwake Concord | Living orchard law and migratory root infrastructure | Give land itself veto power over settlement and extraction | Renewal can become strangling exclusion and forced obedience | Root Accord through grafts, knots, orchards, root gates | Timber, verdant grafts, rooted sites, recovery loops | Root roads, tax movement, turn lanes into hostile ground | Binds, regeneration, brambles, attrition zones |
| Brasshollow Combine | Industrial contract power of the Brass Deeps | Make extraction, debt, and furnace capacity predictable | Fair contract can become debt rule and strip-mined necessity | Furnace Accord through clauses, gauges, heat seals | Ore, brass scrip, capital projects, repair windows | Mine camps, railheads, siege staging | Armor, heat bursts, artillery, repair, cooldown risk |
| Veilmourn Armada | Fog maritime network and memory salvage houses | Preserve mobility, salvage rights, and uncharted routes | Autonomy and grief trade can become theft of memory and certainty | Veil Accord through bells, charts, fog, obituary ink | Memory salt, salvage spikes, scouting rewards | Fog lanes, bypasses, backline threats | Displacement, blinds, morale drain, isolation spikes |

## No-Generic Constraints

These rules apply to every future JSON, art, spell, artifact, and scenario migration.

1. No common fantasy identity carriers.
   - Avoid faction-defining units such as generic militia, archer, pikeman, goblin, skeleton, zombie, elf, dwarf, angel, or dragon.
   - Familiar creature scale is allowed only when silhouette, recruitment source, name, battlefield role, and rule hooks are specific to Aurelion Reach.
2. No shared ladder skeleton.
   - Each faction needs a different distribution of blockers, ranged pressure, mobility, supports, siege, summons, elites, and finishers.
   - Shared code abilities may exist, but final content must wrap them in faction-specific rules, names, triggers, and counters.
3. No town badge thinking.
   - Towns are large world objects with silhouettes, infrastructure, local economy, and strategic approach sides.
4. No universal economy.
   - Markets may smooth scarcity later, but faction costs and map priorities must not flatten into perfect exchange rates.
5. No lore by text panel.
   - Campaign and map identity should come from object placement, town silhouettes, rewards, guards, route pressure, and concise names.

## Embercourt League

### World Role

The Embercourt League is the civic river-law power of the Emberflow Basin: lock cities, mill islands, oath courts, granary barges, and beacon towers that kept the Salvage Peace moving when the sky mirrors failed.

### Founding And Backstory

During the Long Shattering, flood seasons stopped obeying old calendars. River towns survived by chaining locks, posting beacon courts at crossings, and creating ash-sealed toll charters that guaranteed grain, ferries, and road repair. Those emergency charters became a league. By the Charter War, Embercourt leaders see the basin as a broken public work that must be governed before hunger and raiding finish what the mirrors started.

### Political Motive

Embercourt wants enforceable roads, audited tolls, public records, and protected granaries across Aurelion Reach. It claims the new mirror fragments in the Ninefold Confluence must be placed under civic law, not faction privilege.

### Moral Tension

The League really can prevent famine, reopen roads, and protect small settlements. It also turns emergency administration into occupation: toll seizures, forced levies, road courts, ration priority, and punishment for communities that choose hidden routes over public order.

### Home Region And Town Feel

Home region: Emberflow Basin.

Town feel: horizontal river fortresses with stone weirs, water wheels, lock gates, barge cranes, ash-ledger halls, red beacon towers, warm civic fire, and soot on pale masonry. The main approach should read as a guarded river crossing or lock court, not a castle gate.

### Visual Language

- Shapes: rectangles, lock steps, bridge spans, low walls, square towers, court bells.
- Materials: pale stone, river timber, iron chains, red ceramic signal braziers, ash-stamped parchment.
- Palette: warm fire red, river blue-green, cream masonry, dark wet wood, granary gold.
- Unit silhouettes: disciplined crews, hook tools, barge frames, signal lanterns, court-bell machinery.

### Hero Archetypes

Might heroes are bridge marshals, lockmasters, toll-road hunters, barge captains, and castellan quartermasters.

Magic heroes are beacon scribes, ash-writ lectors, rain-ledger economists, route revealers, and signal court jurists.

Hero seed IDs:

| Role | Hero ids |
| --- | --- |
| Might | `hero_embercourt_mira_flintmere`, `hero_embercourt_caelen_ashgrove`, `hero_embercourt_torren_pikeward`, `hero_embercourt_helva_tollbrand`, `hero_embercourt_saren_lockmaster` |
| Magic | `hero_embercourt_lyra_emberwell`, `hero_embercourt_seren_valechant`, `hero_embercourt_orra_cinderquill`, `hero_embercourt_belis_rainledger`, `hero_embercourt_jorun_beaconscribe` |

### Unit Ladder Intent And Roles

Embercourt should not become a generic human castle. Its ladder is a prepared civic war machine: line holders, lane preparation, protected ranged crews, court authority, signal support, lock-bred shock, and a walking charter engine.

| Tier | Unit id | Unit name | Intent |
| --- | --- | --- | --- |
| 1 | `unit_embercourt_fordhook_cadets` | Fordhook Cadets | Cheap crossing holders with reach, bracing, and objective-adjacent retaliation. |
| 2 | `unit_embercourt_lantern_sappers` | Lantern Sappers | Lane preparation, reveal utility, ember pots, and anti-ambush control. |
| 3 | `unit_embercourt_bargebow_crews` | Bargebow Crews | Limited-shot heavy ranged pressure that needs protection and lanes. |
| 4 | `unit_embercourt_ash_oath_bailiffs` | Ash-Oath Bailiffs | Bodyguard and morale-stable line enforcers that punish attacks into formation. |
| 5 | `unit_embercourt_beacon_lectors` | Beacon Lectors | Support casters that refresh readiness, mark lanes, and steady compact formations. |
| 6 | `unit_embercourt_sluicefire_lindworms` | Sluicefire Lindworms | Narrow-lane fire shock that hits hard when supported and collapses when isolated. |
| 7 | `unit_embercourt_charter_colossus` | Charter Colossus | Zone anchor that raises retaliation value and forces full commitment or withdrawal. |

### Economy Preferences And Resources

Embercourt prefers gold, timber, embergrain, and road-linked income. Its town development should reward civic chains: granaries, tollhouses, beacon courts, and support buildings that lower recruitment friction, improve recovery, and protect holdings. It should have reliable income, average raw growth, strong affordability after investment, and high value from crossroads, bridges, mills, and granary sites.

### Magic And Accord Identity

Beacon Accord: signal fires, ash writs, court bells, route marks, morale steadiness, and oath-bound retaliation. Embercourt magic should reveal lanes, stabilize allied morale, punish broken oaths, improve road scouting, and convert defense orders into tactical tempo.

### Artifacts And Object Hooks

- Artifacts: ash-sealed writs, tollstone rings, beacon lenses, river judge gavels, granary keys, lockmaster chains.
- Object hooks: tollhouses, ferry courts, burned ledgers, beacon relays, granary islands, old road courts, lockworks, public ration depots.

### Town Building Identity

Signature building seeds:

| Building id | Name | Identity |
| --- | --- | --- |
| `building_embercourt_charter_bastion` | Charter Bastion | Capital court and defensive readiness hub. |
| `building_embercourt_beacon_court` | Beacon Court | Magic, scouting, and lane-mark infrastructure. |
| `building_embercourt_granary_lock_exchange` | Granary Lock Exchange | Steady income, embergrain logic, and recovery. |
| `building_embercourt_oath_pikehall` | Oath Pikehall | Civic line discipline and bodyguard upgrades. |
| `building_embercourt_bargebow_slip` | Bargebow Slip | River weapon crews and town defense pressure. |
| `building_embercourt_drake_sluice` | Drake Sluice | High-tier lock-beast infrastructure. |
| `building_embercourt_tollstone_weir` | Tollstone Weir | Road and crossing economy support. |

### Strategic Playstyle

Embercourt is reliable, positional, and hard to uproot from mapped infrastructure. It wants to secure crossings, build support chains, keep formations compact, and punish enemies who overextend past prepared roads. Weaknesses: less explosive economy than salvage/raid factions, less flexible mobility than fog/marsh powers, and vulnerable if forced to fight away from roads and lanes.

### Campaign And Map Hooks

- Reopen a broken beacon chain before winter flood.
- Decide whether to seize a neutral ferry town for public rationing.
- Defend granary barges from Mireclaw raids while Sunvault demands mirror custody.
- Capture toll courts around the Ninefold Confluence to legalize a basin-wide road charter.

### Anti-Generic Constraints

- Do not call it the human kingdom, noble castle, or holy order faction.
- Avoid palace, knightly, and generic archer imagery as identity carriers.
- Every unit and building should show river law, locks, barges, tolls, ash writs, or beacon infrastructure.

## Mireclaw Covenant

### World Role

The Mireclaw Covenant is the sovereignty network of the Drowned Marches: ferry raiders, reed-script shrine keepers, bogplate handlers, chainboom toll breakers, and clans that treat marsh routes as living law.

### Founding And Backstory

When old roads drowned during the Long Shattering, outside courts wrote the lowlands off as lost. Marsh families survived by mapping reed lanes, breeding ferry beasts, raising shrine drums on old bridge piles, and learning which routes the bog would accept. The Covenant formed when Basin toll collectors tried to reclaim drowned causeways and found every bridge chain cut before dawn.

### Political Motive

Mireclaw wants the lowlands free from fixed maps, mine contracts, and river-court seizure. It claims any charter that ignores peat, flood, and clan oath is an invasion document.

### Moral Tension

Mireclaw protects local autonomy and understands unstable terrain better than any outside power. It also normalizes ambush tolls, hostage routes, blood-feud justice, and predatory raids against settlements that cannot tell a clan border from a safe ferry lane.

### Home Region And Town Feel

Home region: Drowned Marches.

Town feel: low, wet, mobile, and threatening. Drowned pilings, chain ferries, reed dens, drum platforms, blackwater shrines, smoked hides, mudglass glints, and hidden boat slips should matter more than walls.

### Visual Language

- Shapes: low profiles, chain curves, reed clusters, hanging hides, broken causeways.
- Materials: wet timber, peat, bone tokens, green-black water, mudglass, rope, rusted ferry chain.
- Palette: green-black, yellow reed, cold mud, muted bone, toxic glints.
- Unit silhouettes: crouched packs, hooks, lashes, shell or bogplate armor, drum carriers, antlered apex forms.

### Hero Archetypes

Might heroes are raid captains, packlords, ferrychain breakers, bogplate handlers, and marsh trackers.

Magic heroes are reed-script hexcallers, sporewake mystics, den augurs, drum oracles, and shrine-blood negotiators.

Hero seed IDs:

| Role | Hero ids |
| --- | --- |
| Might | `hero_mireclaw_vaska_reedmaw`, `hero_mireclaw_tarn_fenhook`, `hero_mireclaw_orrik_tollreaver`, `hero_mireclaw_kessa_chainboom`, `hero_mireclaw_brakka_mudkeel` |
| Magic | `hero_mireclaw_sable_muckscribe`, `hero_mireclaw_nix_votivejaw`, `hero_mireclaw_edda_rotlamp`, `hero_mireclaw_pell_reedscript`, `hero_mireclaw_zhorra_fenwake` |

### Unit Ladder Intent And Roles

Mireclaw is not a green monster horde. Its ladder is predatory wetland logistics: snares, blinds, bog armor, pulls, rot chants, wounded-target finishers, and a marsh apex that turns fear into route control.

| Tier | Unit id | Unit name | Intent |
| --- | --- | --- | --- |
| 1 | `unit_mireclaw_reedsnare_kin` | Reedsnare Kin | Cheap snarers that slow and mark, weak alone and strong while surrounding. |
| 2 | `unit_mireclaw_mudglass_slingers` | Mudglass Slingers | Ranged harriers that spread blindness and set up pack attacks. |
| 3 | `unit_mireclaw_bogplate_maulers` | Bogplate Maulers | Slow bruisers with resistance and bonus damage against harried enemies. |
| 4 | `unit_mireclaw_ferrychain_lashers` | Ferrychain Lashers | Pulls, pins, and movement punishment across lanes or objectives. |
| 5 | `unit_mireclaw_sporewake_chanters` | Sporewake Chanters | Rot support, recovery denial, and wounded-prey amplifier. |
| 6 | `unit_mireclaw_gorefen_rippers` | Gorefen Rippers | Fragile elite finishers for wounded or isolated targets. |
| 7 | `unit_mireclaw_drowned_antler_sovereign` | Drowned Antler Sovereign | Apex pressure piece with fear, trample lanes, and wounded-stack dominance. |

### Economy Preferences And Resources

Mireclaw prefers peatwax, raid spoils, den growth, ferry income, and cheap replacement loops. It should have lower safe income than Embercourt, stronger early growth, and value from denying or retaking resource sites. It should care about peat cuts, ferry chains, hidden caches, beast dens, and shrine drums more than formal mines.

### Magic And Accord Identity

Mire Accord: rot, drag, blind, wounded-prey marks, den growth, drum acceleration, and recovery denial. Mireclaw magic should make enemies less certain, less healed, and easier to finish rather than simply dealing clean damage.

### Artifacts And Object Hooks

- Artifacts: reed-script masks, chainboom hooks, peatwax votives, mudglass beads, drowned antlers, drum-hide ledgers.
- Object hooks: reed caches, ferry toll chains, peat cuts, bog dens, spore shrines, drowned causeways, blackwater ambush posts.

### Town Building Identity

| Building id | Name | Identity |
| --- | --- | --- |
| `building_mireclaw_blackbranch_den` | Blackbranch Den | Low-tier growth and den pressure. |
| `building_mireclaw_chainboom_ferry` | Chainboom Ferry | Crossing control, raiding support, retreat routes. |
| `building_mireclaw_war_drum_circle` | War Drum Circle | Pack initiative and wounded-target pressure. |
| `building_mireclaw_sporewake_shrine` | Sporewake Shrine | Rot, blind, and recovery-denial magic. |
| `building_mireclaw_floodtide_forge` | Floodtide Forge | Bogplate armor and rough ore use. |
| `building_mireclaw_nightglass_dominion` | Nightglass Dominion | Deep raid sustain and elite pack growth. |
| `building_mireclaw_antler_pit` | Antler Pit | Apex beast dwelling. |

### Strategic Playstyle

Mireclaw is tempo pressure and asymmetric map danger. It wants multiple small threats, exposed site attacks, cheap replacements, debuffs, and finishing windows. Weaknesses: weaker safe economy, fragile elite attackers, poor clean sieges, and trouble against factions that keep compact guarded routes.

### Campaign And Map Hooks

- Break an Embercourt survey line before it turns drowned roads into taxable causeways.
- Choose whether to ransom a mill town or preserve it as a neutral ferry market.
- Hunt a Sunvault relay crew that is mapping marsh paths with aetherglass.
- Defend shrine drums from Thornwake root law that would make bog routes conditional.

### Anti-Generic Constraints

- Do not make them generic orcs, goblins, swamp monsters, or raiders with green paint.
- Avoid clean tribal cliches. The culture is route law, ferry sovereignty, wetland logistics, drums, and shrines.
- Low-tier units must still show snares, reeds, mudglass, ferry craft, or den culture.

## Sunvault Compact

### World Role

The Sunvault Compact is the disciplined solar-calibration power of the Glass Uplands: lens keepers, crystal engineers, choir mathematicians, mirror duelists, and relay governors who believe the sky mirror network can be rebuilt.

### Founding And Backstory

When shards fell into the uplands, many settlements died from glare fields and broken weather. The survivors learned to bury observatories, tune crystal orchards, and use choirs to regulate dangerous resonance. The Compact began as a safety discipline. It became a political power when its relay maps proved it could forecast storms, reveal raiders, and make crystal fields productive.

### Political Motive

Sunvault wants mirror fragments gathered, measured, and rebuilt into a disciplined network. It argues that only calibrated truth can stop the Reach from dissolving into local superstition and resource war.

### Moral Tension

Sunvault can restore weather order, protect routes with sightlines, and prevent misuse of mirror fragments. It also treats disagreement as noise, local memory as unverified, and uncalibrated communities as problems to be corrected.

### Home Region And Town Feel

Home region: Glass Uplands.

Town feel: bright, vertical, angular, and deliberately aligned. Crystal buttresses, mirrored terraces, lens tracks, resonant cloisters, prism yards, buried observatories, and solar relay crowns should define the skyline.

### Visual Language

- Shapes: facets, triangles, thin towers, stepped terraces, beam paths, circular lens frames.
- Materials: pale stone, blue-violet crystal, polished mirror, gold inlay, white ceramic.
- Palette: sun gold, hard white, pale stone, blue-violet crystal, long cool shadows.
- Unit silhouettes: shields with facets, array frames, mirror blades, choir standards, walking batteries.

### Hero Archetypes

Might heroes are array marshals, battery captains, relay surveyors, mirror-step duel commanders, and target-focus tacticians.

Magic heroes are sunlance seers, harmonic scholars, cloister keepers, solar physicians, and calibration mages.

Hero seed IDs:

| Role | Hero ids |
| --- | --- |
| Might | `hero_sunvault_solera_prismarch`, `hero_sunvault_varis_mirrorstep`, `hero_sunvault_ilyr_glassmarshal`, `hero_sunvault_dovan_lenscaptain`, `hero_sunvault_renn_facetlane` |
| Magic | `hero_sunvault_neral_glasswind`, `hero_sunvault_thalen_choirward`, `hero_sunvault_essa_daynote`, `hero_sunvault_calis_sunvein`, `hero_sunvault_mirro_halometer` |

### Unit Ladder Intent And Roles

Sunvault is not a holy light faction. Its ladder is calibration warfare: shield line, marked-target ranged pressure, reposition duelists, resonance support, array constructs, heavy batteries, and a top-tier relay titan.

| Tier | Unit id | Unit name | Intent |
| --- | --- | --- | --- |
| 1 | `unit_sunvault_shard_wardens` | Shard Wardens | Durable shield line that protects arrays and reflects minor damage. |
| 2 | `unit_sunvault_prism_adepts` | Prism Adepts | Accurate ranged pressure against marked or staggered targets. |
| 3 | `unit_sunvault_mirror_duelists` | Mirror Duelists | Reposition melee that exploits broken timing and reflected lanes. |
| 4 | `unit_sunvault_resonant_choristers` | Resonant Choristers | Support for spell cycling, cohesion, and focused marks. |
| 5 | `unit_sunvault_solar_array_striders` | Solar Array Striders | Construct walkers that project small firing lanes and resist disruption. |
| 6 | `unit_sunvault_aurora_ballistae` | Aurora Ballistae | Heavy battery, excellent when protected and weak when rushed. |
| 7 | `unit_sunvault_daybreak_colossus` | Daybreak Colossus | Prepared-front amplifier and resonance capstone. |

### Economy Preferences And Resources

Sunvault prefers ore, aetherglass, relay-linked spell infrastructure, and quality upgrades. It should be costly to build, modest in raw growth, strong after support buildings, and highly sensitive to crystal orchards, observatories, watch sites, and high-ground relays.

### Magic And Accord Identity

Lens Accord: light, resonance, shields, long sight, target calibration, dispels, and spell cycling. Sunvault magic should reward planned turns, marked targets, formation cohesion, and relay control.

### Artifacts And Object Hooks

- Artifacts: prism sextants, choir tuning forks, shard mantles, halometers, broken mirror crowns, sun-vein lenses.
- Object hooks: lens fields, buried observatories, crystal orchards, relay towers, glare scars, prism road markers, calibration shrines.

### Town Building Identity

| Building id | Name | Identity |
| --- | --- | --- |
| `building_sunvault_shard_yard` | Shard Yard | Shield-line root and crystal labor yard. |
| `building_sunvault_lens_gallery` | Lens Gallery | Ranged support and sightline infrastructure. |
| `building_sunvault_harmonic_cloister` | Harmonic Cloister | Spell cycling and cohesion recovery. |
| `building_sunvault_aurora_spire` | Aurora Spire | Heavy battery dwelling. |
| `building_sunvault_daybreak_matrix` | Daybreak Matrix | Capital relay pressure and top-tier support. |
| `building_sunvault_mirror_forge` | Mirror Forge | Duelist and reposition technology. |
| `building_sunvault_zenith_observatory` | Zenith Observatory | Scouting, relay sight, and sunlance access. |

### Strategic Playstyle

Sunvault is expensive, deliberate, and high-quality. It wants to extend relay networks, control sightlines, protect batteries, mark priority targets, and win by executing prepared turns. Weaknesses: costly replacement, vulnerability to scattered brawls, dependence on setup, and pressure when rushed before relay support exists.

### Campaign And Map Hooks

- Secure a cracked observatory before its glare field destroys nearby farms.
- Escort a calibration choir through contested bridge and marsh territory.
- Decide whether to reveal a Veilmourn route at the cost of exposing civilian memory records.
- Compete with Brasshollow for aetherglass-bearing ore seams under the Glass Uplands.

### Anti-Generic Constraints

- Do not frame Sunvault as angels, clerics, high elves, or generic good light.
- Avoid divine halos and palace sanctity. Use engineering, resonance, lenses, towers, and disciplined calibration.
- Ranged power must depend on marks, lanes, and support, not generic archery.

## Thornwake Concord

### World Role

The Thornwake Concord is the living law of the Walking Green: root pilgrims, graftwrights, seed judges, thorn toll keepers, and orchard caravans that carry settlement rules through migrating forest.

### Founding And Backstory

The Long Shattering made old forests move. Logging roads vanished, nurseries appeared in former fields, and root systems began rejecting towns that ignored water and soil debts. Pilgrims who learned graft law survived by negotiating with living routes. The Concord formed when several orchard caravans bound their seed vaults together and declared that no charter was legitimate unless the land itself had a voice.

### Political Motive

Thornwake wants settlement, extraction, and travel made conditional on renewal. It opposes permanent roads, unchecked mines, and mirror restoration that treats terrain as inert infrastructure.

### Moral Tension

Thornwake protects exhausted land and forces long-term thinking. It also uses living tolls, forced regrowth, hostage roads, and exclusionary root law that can starve towns if they refuse Concord terms.

### Home Region And Town Feel

Home region: Walking Green.

Town feel: alive and semi-mobile. Root wheels, suspended seed vaults, graft halls, living bridges, moss-lit courts, thorn toll arches, orchard engines, and woven pilgrim markers should make the town feel like settlement and caravan at once.

### Visual Language

- Shapes: branching silhouettes, root arches, graft bands, thorn braids, hanging seed lanterns.
- Materials: pale bark, dark leaves, living rope, amber fruit glass, moss stone, red thorn.
- Palette: deep green, pale bark, thorn red, amber fruit, damp soil, pilgrimage cloth.
- Unit silhouettes: carriers with seed packs, whip-thorn reach, living shields, grafted support frames, rooted bastions.

### Hero Archetypes

Might heroes are briar marshals, rootwright siege growers, pilgrim captains, recovery wardens, and bramble hunt leaders.

Magic heroes are seed seers, sporeglass doctors, loam singers, moss-memory mages, and graft sibyls.

Hero seed IDs:

| Role | Hero ids |
| --- | --- |
| Might | `hero_thornwake_ardren_briarmarshal`, `hero_thornwake_tova_rootwright`, `hero_thornwake_halen_thorncart`, `hero_thornwake_merek_greenbarrow`, `hero_thornwake_silsa_bramblehound` |
| Magic | `hero_thornwake_veyra_seedseer`, `hero_thornwake_osmund_pollenglass`, `hero_thornwake_elian_loamchant`, `hero_thornwake_ralka_mossvein`, `hero_thornwake_nara_graftsibyl` |

### Unit Ladder Intent And Roles

Thornwake is not elves, druids, or tree people. Its ladder is living infrastructure: bramble carriers, reach binders, menders, siege growth, mobility through rooted ground, regeneration leaders, and a battlefield-rooting bastion.

| Tier | Unit id | Unit name | Intent |
| --- | --- | --- | --- |
| 1 | `unit_thornwake_seedcutters` | Seedcutters | Low-tier carriers that plant brambles and improve on rooted ground. |
| 2 | `unit_thornwake_thornwhip_carriers` | Thornwhip Carriers | Reach binders and disengage punishers. |
| 3 | `unit_thornwake_sporeglass_menders` | Sporeglass Menders | Healing, cleanse, and rooted-status support. |
| 4 | `unit_thornwake_barkmantle_rams` | Barkmantle Rams | Durable living siege and fortified-line breakers. |
| 5 | `unit_thornwake_stagknot_runners` | Stag-Knot Runners | Mobile flankers through allied bramble lanes and anti-ranged pins. |
| 6 | `unit_thornwake_graft_matriarchs` | Graft Matriarchs | Regeneration leaders and stronger bramble creators. |
| 7 | `unit_thornwake_worldroot_bastion` | Worldroot Bastion | Living fortress that roots battlefield zones and enables attrition walls. |

### Economy Preferences And Resources

Thornwake prefers timber, verdant grafts, rooted neutral sites, nursery control, and long-term recovery. It should have slower direct gold but compounding value from site links and growth buildings. Some town upgrades should only reach full value while linked sites remain controlled.

### Magic And Accord Identity

Root Accord: growth, bind, regeneration, terrain denial, road taxation, site renewal, and recovery. Thornwake magic should convert space into obligation: move slower here, heal here, pay a toll here, lose tempo for breaking root law.

### Artifacts And Object Hooks

- Artifacts: graft knives, seed-judge masks, pilgrim root maps, thorn toll rings, amber fruit lanterns, living bridge knots.
- Object hooks: root gates, graft nurseries, thorn tolls, forbidden logging roads, orchard graves, pilgrim clearings, moss courts.

### Town Building Identity

| Building id | Name | Identity |
| --- | --- | --- |
| `building_thornwake_seed_vault` | Seed Vault | Core growth store and site-link root. |
| `building_thornwake_graftworks` | Graftworks | Recovery, menders, and graft upgrades. |
| `building_thornwake_bramble_toll` | Bramble Toll | Movement taxation and map pressure. |
| `building_thornwake_sporeglass_hothouse` | Sporeglass Hothouse | Healing, cleanse, and support magic. |
| `building_thornwake_barkmantle_run` | Barkmantle Run | Living siege dwelling. |
| `building_thornwake_pilgrim_orchard` | Pilgrim Orchard | Growth/economy that scales with rooted sites. |
| `building_thornwake_worldroot_gate` | Worldroot Gate | Top-tier dwelling and regional recovery. |

### Strategic Playstyle

Thornwake is slow-starting, territorial, and exhausting to fight on prepared ground. It wants to seed regions, tax roads, recover losses, bind enemies, and win through denial and compounding growth. Weaknesses: limited burst damage, limited clean ranged pressure, slower expansion before root networks, and vulnerability to fast disruption before nurseries mature.

### Campaign And Map Hooks

- Root a burned mill valley before Embercourt reopens it as a permanent toll road.
- Negotiate with a neutral nursery that refuses all faction banners.
- Stop Brasshollow rails from crossing a migratory root corridor.
- Decide whether to choke a Veilmourn fog slip that locals need for evacuation.

### Anti-Generic Constraints

- Do not make Thornwake an elf, druid, forest guardian, or treant faction.
- Avoid pure nature-good framing. It is law, tolls, renewal debt, and living infrastructure.
- Root and growth mechanics must create strategic obligations, not just healing flavor.

## Brasshollow Combine

### World Role

The Brasshollow Combine is the industrial contract power of the Brass Deeps: quarry syndicates, furnace chapels, pressure rail offices, debt foundries, worker courts, and machine yards.

### Founding And Backstory

The shattered mirrors exposed deep metals and unstable heat seams. Early mine houses survived cave-ins, slag storms, and famine by writing binding furnace contracts: every shaft owed heat, every crew owed repair labor, every machine owed recorded service. The Combine formed when those contracts outgrew individual mines and became a political system with armies attached.

### Political Motive

Brasshollow wants extraction made predictable and enforceable. It supports restoration only if mirror work, rail routes, and resource rights can be contracted, metered, insured, and paid.

### Moral Tension

Brasshollow can build the machines, rails, armor, and pumps that keep the Reach alive. It also converts survival into debt, treats labor as collateral, and sees exhausted land as a solvable throughput problem.

### Home Region And Town Feel

Home region: Brass Deeps.

Town feel: heavy, angular, hot, and audited. Furnace pits, brass lifts, ore elevators, gantry cranes, pressure rail terminals, boiler chapels, contract halls, slag canals, and warning banners define the town.

### Visual Language

- Shapes: plates, braces, rails, pipes, gantries, pressure gauges, blocky machinery.
- Materials: brass, black iron, hot ceramic, slag glass, quarry chalk, stamped contract metal.
- Palette: brass, charcoal, iron blue, heated orange, ash gray, chalk dust.
- Unit silhouettes: shield teams, haulers, rivet machines, boilers, crawler engines, walking furnace icons.

### Hero Archetypes

Might heroes are contract marshals, siege captains, railhead enforcers, mine-field commanders, and pavis foremen.

Magic heroes are heat rite engineers, furnace chaplains, gauge savants, clause mages, and slag alchemists.

Hero seed IDs:

| Role | Hero ids |
| --- | --- |
| Might | `hero_brasshollow_marka_ironclause`, `hero_brasshollow_oren_bellfounder`, `hero_brasshollow_kuld_varn`, `hero_brasshollow_selka_pitmarshal`, `hero_brasshollow_daxis_chaincaptain` |
| Magic | `hero_brasshollow_vellum_quench`, `hero_brasshollow_odrik_heatpriest`, `hero_brasshollow_lina_gaugesavant`, `hero_brasshollow_harro_debtrune`, `hero_brasshollow_pava_ashmeter` |

### Unit Ladder Intent And Roles

Brasshollow is not dwarves, generic golems, or steampunk soldiers. Its ladder is contract industry: armored labor, machine skirmish, pavis protection, pressure artillery, debt engines, siege crawlers, and a furnace saint.

| Tier | Unit id | Unit name | Intent |
| --- | --- | --- | --- |
| 1 | `unit_brasshollow_scrip_haulers` | Scrip Haulers | Armored labor levy with bracing and minor repair utility. |
| 2 | `unit_brasshollow_rivet_hounds` | Rivet Hounds | Fast machine skirmishers for anti-raider work and armor weakness reveal. |
| 3 | `unit_brasshollow_furnace_pavis_teams` | Furnace Pavis Teams | Heavy shield teams that protect engines and punish frontal attacks. |
| 4 | `unit_brasshollow_boiler_rivetcasters` | Boiler Rivetcasters | Short-range pressure artillery with heat buildup and splash risk. |
| 5 | `unit_brasshollow_debt_engine_exactors` | Debt-Engine Exactors | Burst melee engines that overheat and then need protection. |
| 6 | `unit_brasshollow_crucible_crawlers` | Crucible Crawlers | Setup siege engines that burn terrain and punish clustered enemies. |
| 7 | `unit_brasshollow_foundry_saint` | Foundry Saint | Walking furnace idol that repairs machines, hardens allies, and projects heat. |

### Economy Preferences And Resources

Brasshollow prefers ore, brass scrip, furnace throughput, mine control, and capital projects. It should have expensive recruitment, low growth, strong durability, repair/recovery rules for machines, and major late strength when it controls ore and rail-linked production.

### Magic And Accord Identity

Furnace Accord: heat, pressure, armor, repair, binding clauses, overpressure release, and extraction acceleration. Brasshollow magic should create power with cooldowns, repair windows, area heat, and contractual punishment.

### Artifacts And Object Hooks

- Artifacts: debt-seal hammers, pressure gauges, furnace relic plates, rail keys, slag saint fragments, clause tablets.
- Object hooks: ore tithe offices, pump houses, rail switches, slag vents, worker chapels, survey stakes, debt foundries.

### Town Building Identity

| Building id | Name | Identity |
| --- | --- | --- |
| `building_brasshollow_ore_tithe_office` | Ore Tithe Office | Ore income and build affordability. |
| `building_brasshollow_boiler_cathedral` | Boiler Cathedral | Heat rites and machine recovery. |
| `building_brasshollow_rivet_kennels` | Rivet Kennels | Anti-raider machine dwelling. |
| `building_brasshollow_pavis_foundry` | Pavis Foundry | Armored line and shield-team upgrades. |
| `building_brasshollow_pressure_rail` | Pressure Rail | Mine-to-town movement and staging. |
| `building_brasshollow_crucible_dock` | Crucible Dock | Siege crawler dwelling. |
| `building_brasshollow_titan_charter_hall` | Titan Charter Hall | Top-tier contract and siege capstone. |

### Strategic Playstyle

Brasshollow is slow, costly, and hard to dislodge. It wants mines, railheads, repair windows, siege staging, and decisive objective pushes. Weaknesses: poor chase, expensive losses, ore dependence, and vulnerability to route bypass or early site denial.

### Campaign And Map Hooks

- Reopen a collapsed pressure rail through territory claimed by Thornwake root law.
- Decide whether to enforce old debt contracts on a starving neutral quarry town.
- Fortify a mine line while Veilmourn steals memory-salt ledgers from wrecked rail barges.
- Race Sunvault for aetherglass seams needed to calibrate furnace gauges safely.

### Anti-Generic Constraints

- Do not make Brasshollow dwarves, generic constructs, or decorative steampunk.
- Industrial identity must include law, debt, furnace religion, repair, and resource politics.
- Machines should have clear positioning limits and maintenance logic, not just high stats.

## Veilmourn Armada

### World Role

The Veilmourn Armada is the fog-maritime and memory-salvage power of the Veil Coast: black-sail houses, bell crews, obituary mages, mirror navigators, wreck claimants, and harpoon captains who move where maps fail.

### Founding And Backstory

Some broken mirrors reflected memory into the coast instead of weather. Harbors disappeared for days, wrecks returned with impossible cargo, and sailors forgot routes that had saved them. Funeral crews learned to mark fog lanes with bells and memory salt. The Armada formed from houses that promised to remember the dead, salvage the lost, and keep routes open without submitting them to inland maps.

### Political Motive

Veilmourn wants mobility, salvage rights, and control over uncharted routes. It rejects fixed empire because fixed records make fog lanes taxable, predictable, and exploitable by powers that do not understand them.

### Moral Tension

Veilmourn preserves lost routes, recovers the dead, and opens evacuation paths no road power can reach. It also trades in memory, conceals crimes behind fog law, steals charts, and can make communities forget the cost of its help.

### Home Region And Town Feel

Home region: Veil Coast.

Town feel: harbor inside fog. Bell towers, mirror drydocks, black mooring posts, obituary vaults, lantern reefs, harpoon gantries, half-visible hulls, and negative space between masts should define the silhouette.

### Visual Language

- Shapes: masts, hull curves, bells, lantern dots, mirror plates, trailing cloth, narrow gangways.
- Materials: black lacquered wood, tarnished silver, salt stone, wet rope, mirror shards, funeral cloth.
- Palette: gray-green fog, black lacquer, tarnished silver, salt white, lamp amber.
- Unit silhouettes: oar crews, lantern bearers, maskglass corsairs, harpoon lines, scribes, phase keels, fog leviathan mass.

### Hero Archetypes

Might heroes are black-sail admirals, harpoon captains, phase raiders, signal thieves, and fleet wardens.

Magic heroes are fog prophets, obituary scribes, mirror navigators, funeral hexers, and route diviners.

Hero seed IDs:

| Role | Hero ids |
| --- | --- |
| Might | `hero_veilmourn_ivara_blacktide`, `hero_veilmourn_ruln_vanehook`, `hero_veilmourn_cela_mistcorsair`, `hero_veilmourn_damar_oriflag`, `hero_veilmourn_jessa_keelwarden` |
| Magic | `hero_veilmourn_morwen_wakeoracle`, `hero_veilmourn_thir_obituaryink`, `hero_veilmourn_sael_mirrorbell`, `hero_veilmourn_nacre_vowless`, `hero_veilmourn_orso_nightchart` |

### Unit Ladder Intent And Roles

Veilmourn is not pirates, undead, or generic shadow assassins. Its ladder is fog-route warfare: evasive crews, lantern marks, maskglass skirmish, harpoon displacement, obituary debuffs, phase raiders, and a fog control leviathan.

| Tier | Unit id | Unit name | Intent |
| --- | --- | --- | --- |
| 1 | `unit_veilmourn_bellwake_oars` | Bellwake Oars | Evasive screens and scouts that survive better while fogged. |
| 2 | `unit_veilmourn_mourning_lanterns` | Mourning Lanterns | Reveal, blind, and isolation-mark support. |
| 3 | `unit_veilmourn_maskglass_corsairs` | Maskglass Corsairs | Mobile skirmishers that punish blinded or isolated enemies. |
| 4 | `unit_veilmourn_undertow_harpooners` | Undertow Harpooners | Ranged pulls, formation breaks, and kill-lane setup. |
| 5 | `unit_veilmourn_obituary_scribes` | Obituary Scribes | Morale drain, retaliation weakening, and salvage storage. |
| 6 | `unit_veilmourn_mirrorkeel_reavers` | Mirror-Keel Reavers | Phase raiders that strike backlines through fog lanes. |
| 7 | `unit_veilmourn_fogbound_leviathan` | Fogbound Leviathan | Battlefield fog control and isolated-victim punishment. |

### Economy Preferences And Resources

Veilmourn prefers memory salt, salvage, scouting rewards, artifact recovery, and uneven income spikes. It should have weaker steady income than Embercourt and Brasshollow, but strong reward bursts from wreck fields, marked routes, battle cleanup, and hidden-object discovery.

### Magic And Accord Identity

Veil Accord: fog, displacement, memory theft, salvage sense, morale drain, decoys, and route bypass. Veilmourn magic should manipulate information and position while keeping player-facing states explicit and readable.

### Artifacts And Object Hooks

- Artifacts: mirror charts, bell-buoy clappers, obituary inks, memory-salt reliquaries, black-sail compasses, harpoon vows.
- Object hooks: fog docks, wreck caches, bell buoys, mirror shoals, obituary vaults, lantern reefs, hidden slips, ransom exchanges.

### Town Building Identity

| Building id | Name | Identity |
| --- | --- | --- |
| `building_veilmourn_bell_harbor` | Bell Harbor | Core fog defense and scouting support. |
| `building_veilmourn_mirror_drydock` | Mirror Drydock | Phase and route-bypass infrastructure. |
| `building_veilmourn_obituary_vault` | Obituary Vault | Magic, memory salt, and salvage conversion. |
| `building_veilmourn_harpoon_gantry` | Harpoon Gantry | Displacement and formation-break dwelling. |
| `building_veilmourn_mistgate_slip` | Mistgate Slip | Fog-lane movement and map pressure. |
| `building_veilmourn_ransom_exchange` | Ransom Exchange | Scouting, cleanup, and artifact recovery economy. |
| `building_veilmourn_leviathan_sounding` | Leviathan Sounding | Top-tier fog control dwelling. |

### Strategic Playstyle

Veilmourn is information, bypass, and selective violence. It wants to scout more, threaten weak backs, isolate targets, create route uncertainty, and cash out salvage spikes. Weaknesses: fragile honest trades, uneven income, reliance on fog and marks, and risk when pinned by compact formations or strong reveal tools.

### Campaign And Map Hooks

- Recover a wrecked mirror shard before Sunvault records its memory reflections.
- Smuggle civilians through a fog lane that Embercourt calls illegal.
- Raid a Brasshollow debt convoy for ledgers that contain stolen crew memories.
- Decide whether to erase a route from public memory to keep it safe from the Charter War.

### Anti-Generic Constraints

- Do not make Veilmourn undead, pirate, assassin, or dark-elemental stock fantasy.
- Funeral, memory, salvage, bells, charts, and fog logistics are the core.
- Fog mechanics must communicate explicit readable states; confusion is for enemies, not the player.

## Cross-Faction Production Notes

### Asymmetry Checks For Future Implementation

- Embercourt should be the most reliable at holding public infrastructure, not the most mobile or explosive.
- Mireclaw should be the best at making exposed map play unsafe, not the best at formal sieges.
- Sunvault should have the clearest setup turns and relay dependency, not generic ranged superiority.
- Thornwake should transform routes over time, not simply heal more than other factions.
- Brasshollow should be the most capital-intensive and hardest to uproot, not a fast machine swarm.
- Veilmourn should win through information and route distortion, not raw stat efficiency.

### Economy Differentiation Targets

| Resource pressure | Embercourt | Mireclaw | Sunvault | Thornwake | Brasshollow | Veilmourn |
| --- | --- | --- | --- | --- | --- | --- |
| Gold | steady civic base | lower safe income | moderate | weaker direct | contract-heavy | spike-based |
| Timber | roads, barges | ferries, dens | supports | core growth | secondary supports | docks |
| Ore | defenses, heavy engines | bogplate only | core quality | limited | core requirement | harpoons |
| Aetherglass | beacon/lens hybrids | low priority | core magic | rare graft focus | gauge safety | mirror charts |
| Embergrain | readiness and recovery | raid target | supplies relays | growth support | worker rations | trade cargo |
| Peatwax | low priority | core fuel/rites | low priority | soil medium | furnace fuel supplement | sealant |
| Verdant grafts | treaty resource | contested | study material | core resource | obstruction | rare cargo |
| Brass scrip | road contracts | stolen value | equipment trade | suspicious | core credit | ransom exchange |
| Memory salt | records | oral oath hazard | verification | moss memory | contract proof | core resource |

### Implementation Sequencing

1. Do not migrate all six factions to JSON at once.
2. Choose alpha factions only after concept-art, economy, object, magic, artifact, animation, and AI foundation plans identify which pair best proves the game.
3. For each faction vertical slice, implement faction data, units, heroes, buildings, town lists, spell hooks, artifacts, economy costs, AI weights, map placements, validators, and manual play notes together.
4. Preserve stable ids only where references are safe. Rename generic legacy content during a focused migration slice, not casually.

### Current JSON Migration Notes

- `faction_embercourt` remains valid, but current generic civic levies and archers should migrate toward lockworks, beacon courts, ash writs, and river-control units.
- `faction_mireclaw` remains valid. Current cutthroat, slinger, brute, and ripper concepts can survive only if renamed and mechanically grounded in snares, mudglass, bogplate, ferries, or wounded-prey loops.
- `faction_sunvault` remains valid. Current shard/prism/mirror/aurora concepts are compatible but need stronger relay, support, and construct context.
- New ids should be introduced only when their vertical slice is ready: `faction_thornwake`, `faction_brasshollow`, and `faction_veilmourn`.
- Hero ids in this bible are future targets. Existing scenario references should be migrated with compatibility in mind.

### Future Implementation Checklist

For each faction implementation slice:

1. Confirm it still passes the no-generic and no-shared-ladder rules.
2. Add or migrate `content/factions.json`.
3. Add 7 unit tiers in `content/units.json` with unique names, roles, ability wrappers, growth, and costs.
4. Add at least 10 heroes in `content/heroes.json`, split across might and magic identities.
5. Add faction buildings in `content/buildings.json` and town build lists in `content/towns.json`.
6. Add or map spells, artifacts, resource sites, and encounters needed for the faction identity.
7. Add AI strategy weights that express faction map pressure.
8. Add validator coverage for content references, roster depth, and faction-specific required hooks.
9. Place the faction in at least one scenario or skirmish test map before calling it playable.
10. Capture manual play notes for town, overworld, battle, save/load, and outcome routing.
