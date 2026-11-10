# Shared town development

Implemented owner direction, 2026-09-21. All six factions use one town template, common upgrade lines and exclusive creature choices. The former 26 town IDs remain compatibility aliases. Runtime rules live in `TownDevelopmentRules.gd`, construction/economy adapters in `OverworldRules.gd`, and player services in `TownRules.gd`.

## Common buildings

| Line | Stages and benefits |
| --- | --- |
| Town Hall | 500 / 1,000 / 2,000 / 4,000 gold daily. One active stage; per-town Capital Hall, no player-wide capital restriction. |
| Fortifications | Three stages: +10 / +20 / +30 town readiness and +2 / +4 / +6 defense to defending creatures in town battles. Citadel adds 50% and Great Ramparts 100% to every dwelling's weekly growth (flat growth-building bonuses included, rounded up, so a Citadel already brings a second T7). Higher stages replace earlier benefits. |
| Magic Guild | Five stages, enabling faction spells through tiers 1–5. |
| Marketplace | Buys, sells and converts every resource, rare ones included, within weekly limits; Trade Exchange improves every rate, raises the limits and enables bulk wood/ore orders (`docs/town-market.md`). No daily gold income. |
| Tavern | Recruit additional heroes using the existing visiting-hero system. |
| Storehouse I | Exactly 1 wood and 1 ore per day. |
| Storehouse II | Retains 1 wood + 1 ore and adds 1 main faction resource per day. |
| Training Commons | +4 weekly recruits for the selected tier-1 dwelling. |
| Provisioners Lodge | +3 weekly recruits for the selected tier-2 dwelling. |
| Veterans Quarters | +2 weekly recruits for the selected tier-3 dwelling. |
| Sparring Grounds | Visiting hero gains +1 attack once. |
| Wardens School | Visiting hero gains +1 defense once. |
| Hall of Chronicles | Visiting hero gains 1,000 XP once, including normal level-up choices. |
| Artifact Exchange | Three weekly artifact offers; buy and sell unequipped artifacts. |
| Shipyard | Harbour towns only: open sea within 6 steps of the gate (`docs/water-travel.md`). 2,000 gold and 20 wood, needs the Town Hall. Launches a boat on the harbour for 1,000 gold and 10 wood, with or without a hero in town. |

Hero training is once per hero per building type across all towns, preventing repeated capture/visit farming. A different hero can receive their own benefit. Growth buildings only improve an existing chosen dwelling; they never create an unbuilt troop line. Workshop is omitted until its equipment gameplay is defined.

## Dwelling choices and upgrades

- Tiers 1–5 each offer two distinct existing creatures. Building one branch removes the other branch and its upgrade from construction. Choice persists through saves and captures.
- Tiers 6 and 7 each have a single dwelling and upgrade. Tier 6 requires the faction secondary rare resource for both construction and each recruit; tier 7 requires the main rare resource.
- Every tier after 1 requires a dwelling of the preceding tier; either branch qualifies. Tiers 3–5 also require Council Hall; tiers 6–7 require City Hall and Palisade.
- Each of the 72 base creature choices now has an individually named upgrade with authored combat distinctions. Faction design records live in `content/unit_upgrade_designs/`; the live rows are in `content/units.json`. Existing `*_veteran` IDs and `upgrade_from` links remain stable for saves. Recruitment prices retain the shared foundation economy. Weekly growth (2026-10-09) gives each T1-T6 line about 115 battle power (`AiHeroRules.army_power` of the upgrade) per week once the shared growth building for its tier stands, matching one T7; base and upgrade share the value and growth never fell below its earlier amount. Embercourt T1-T3 lines grow one more than that (owner, 2026-10-09): its T6/T7 are the weakest and its faction building discounts rather than grows, so its towns trailed the others by about 12%. Mireclaw T1 lines grow two more, T2 two more and T3-T4 one more (owner, 2026-10-17): in 180 AI-against-AI games it won 12 times against a fair 23 and its armies trailed from week 2, and by today's strength estimate its fully built town made the least power of the six (1,880 a week at Great Ramparts against 1,959-2,400; now 2,059). Embercourt's Convoy Charter pays 300 gold a day instead of 500 (same date): Embercourt won 31 against a fair 21. Embercourt's head start moved into its late game (owner, 2026-10-17, from 360 AI-against-AI games): its armies stood 1.44-1.47 times its rivals' from day 14 to day 28 and 1.31 on day 70, and fell behind only from about day 84, when most games were over. Its T2 Ember Archer line grows 12 instead of 14 and its T3 Bargebow Crews line 6 instead of 7 (with their map dwelling); its T6 Lindworm line, the weakest T6 of the six, grows 3 instead of 2 (with its map dwelling). Mireclaw's base creatures of tiers 1-4 were 57-72% as strong as their upgrades, the widest gap of the six, and its base T1-T3 lines the weakest per week; they gain a point or two of health, defense or damage (Blackbranch Cutthroat, Reedsnare Kin, Bog Brute, Mudglass Slingers, Gorefen Ripper, Ferrychain Lashers) to 71-79% of their upgrades, which stay as they were. Balance round 1 (owner, 2026-10-17, from 120 land AI-against-AI games on medium maps): Embercourt won most short games and almost none past day 100, so River Guard's brace answers at 1.15 instead of 1.3 and staggers one initiative instead of two, the Fordhook Cadets upgrade's hook pull strikes at 70%, and its T6 Sluicefire Lindworms and T7 Charter Colossus gain health and damage (the upgraded lines to about 138 and 134 power a week, from 129 and 122). Mireclaw fought 15% under its estimated power in every phase while every other faction's upgrades carry two or three abilities: its tier 1-4 upgrades with one ability gain a second (Blackbranch Knifeshade, Reedsnare, Bog Brute, Mudglass Slingers, Ferrychain Lashers and Mireglass Reedcasters upgrades), each paying off or setting up the pack's snares and roots. Thornwake's armies stood 0.78-0.80 of its rivals' in weeks 1-2: Seedcutters grow 12 (was 10), Pollenhook Whistlers 10 (was 9), Thornwhip Carriers 7 (was 6), Bramblekite Needlers 10 (was 9), with the Five-Bough veteran grove. Balance round 2 (owner, 2026-10-18, from round 1's 180 land AI-against-AI games): Thornwake overshot to 1.35 times its fair share of wins and Sunvault led the field, so Seedcutters grow 11 and the Daybreak Colossus loses about 9% of its strength (health 84, damage 14-23; upgrade 100 and 18-29). Balance round 3 (owner, 2026-10-18): Mireclaw lost about 1.5 times the others' share of its army in guard fights, most against shooters, so every Mireclaw melee line (both forms) gains 1 defense and about 10% health, and its T3, T6 and T7 melee lines, the tiers without a ranged choice, gain 1 speed. Balance round 4 (owner, 2026-10-18, from 50 land AI-against-AI games on medium maps): Embercourt led the middle game with the most towns, so its Sluicefire Lindworms return to their stats before round 1; Sunvault won most three-player games with the strongest T5 line, so the Zenith Lensbearers lose a point of damage; Veilmourn banked gold it had no creatures to spend on, so its T6 Mirrorkeel Reavers gain health, defense and damage (about 100 to 119 power a week); Mireclaw still lost the most on the way into melee, so every Mireclaw melee line carries Reed Cover (ranged damage x0.85, Bog Brute keeping x0.79). Balance round 5 (owner, 2026-10-19, from 120 large 3-4 player AI-against-AI games): Veilmourn won the fewest guard fights for its strength because its Mistwake Screen needed fog-bank ground most battles lack, so Veilmourn armies now bring their own fog bank to every battle, and their own shooters fire through it without the fog's ranged penalty; upgraded Mireclaw melee lines take ranged damage x0.75 from Reed Cover instead of x0.85 (Ironfen Bulwark x0.72). Balance round 6 (owner, 2026-10-19, after round 5's 30 large 4-player games): Mireclaw still traded worst against the shooter-heavy factions (0.54 of the power it lost against Sunvault, 0.84 against Brasshollow), so its base melee lines take ranged damage x0.80 from Reed Cover instead of x0.85 (Bog Brute x0.76 instead of x0.79). Balance round 7 (owner, 2026-10-20, from 180 large 4-player games and 2,000 arena battles): Sunvault fought above its estimated strength in field battles through its shooter lines' abilities, so the Volley bonuses of its Prism Harrier, Prism Adept, Aurora Ballista and Zenith Lensbearer lines are halved (Refraction Volley x1.06, Aurora Salvo x1.09, Zenith Crossline x1.05) and False Zenith, Calibration Cant and Counterpoint Censure are removed. Balance round 8 (owner, 2026-10-24, from 1,588 mid-game Sunvault field battles of the AI batches replayed in the battle arena): the Aurora Ballista and Sunline Repeater lose Aurora Relay, and the Prism Harriers and Glarewing Harriers lose their harries (Glare Splinters, Glarewing Pursuit); the Repeater keeps Rail-Pinning Salvo. Gold does not limit the early game: every faction buys its towns out weekly, so growth and creature strength decide it. Ability effects are covered by actual battle scenarios, including trigger and non-trigger cases. Linked-creature abilities recognize the upgraded identity.
- Upgrading a dwelling replaces the base recruitment line. Existing reserve count converts to the selected upgraded identity with no extra weekly grant. Subsequent growth produces that upgrade only.
- Existing field and garrison troops are upgraded through **Muster Hall**, for the undiscounted difference between base and upgraded costs. Each order trains all troops of that type in the selected stationed army; it does not consume town reserve or a construction day.
- All 72 upgrades have original portraits, battle/map sprites and 285 articulated idle poses integrated locally, with no base-art alias. Battle and overworld idle rendering, reduced-motion behavior, recruitment and save persistence passed 1,233 focused checks. All 72 upgrades also have two original attack poses, a hit reaction and a fallen body: 288 action paintings, 573 authored poses including idle. Dedicated attack/ranged/retaliation, recoil, death and corpse clips now use upgraded art. Expanded transparent action canvases retain the original body scale and anatomical ground anchor. Final action/simulation/save/GPU validation passed 2,291 focused checks, in addition to the 1,233 idle/recruitment/save checks and 424 faction combat checks. Ability statuses now respect innate and active-effect immunity without consuming an unused readiness ward. Original sources, exact prompts, references and recipes are retained.
- One construction per town per day. Prerequisites recognize higher stages while effects count only the active stage. Buildings show full descriptions, costs, exclusivity and requirements in Construction.

## Balance round 10: Mireclaw ranged cover

Owner request, 2026-10-25. Mudglass Slingers and Mireglass Reedcasters gain Reed Cover with ranged damage x0.80; their upgrades, Shattermire Slingers and Mireglass Dissonants, use x0.75. The protection belongs to each stack and uses the existing shielding rule. Their other abilities, combat stats, growth and costs are unchanged. The owner-requested evaluation repeats round 9's 300 large 4P two-level seeds, line-ups and rotated starts, with land/normal water and weak/strong guards.

## Balance round 9: Mireclaw choices and Sunvault recruitment

Owner request, 2026-10-24. Mireclaw's 8% faction damage bonus recognizes both generic Harried and its own Reedsnared status; native battle execution and battle-AI scoring use the same condition. Gorefen Rippers and Redhooks grow six per week and cost 145/205 gold. Bogplate Maulers and Gatebreakers retain eight per week, gain 18/22 health, and cost 105/145 gold; Gatebreakers deal 5–7 damage. Gorefen remains the fast, higher-damage branch and Bogplate the armored reach branch. Their base weekly estimated strength is 106/105, upgraded 151/144, before shared growth and fort bonuses, with about eight gold per estimated strength at both stages. Sunvault's recruitable ranged base and upgraded town lines cost about 10% more gold, rounded to the nearest five; their other recruitment resources, growth and combat stats are unchanged. The owner-requested evaluation uses the previous 300 large 4P two-level seeds, line-ups and rotations.

## Faction resource pairs

The main resource follows existing faction affinity; the new secondary assignments are the initial authored balance choices.

| Faction | Main / T7 / Storehouse II | Secondary / T6 |
| --- | --- | --- |
| Embercourt League | embergrain | aetherglass |
| Mireclaw Covenant | peatwax | memory salt |
| Sunvault Compact | aetherglass | brass scrip |
| Thornwake Concord | verdant grafts | peatwax |
| Brasshollow Combine | brass scrip | embergrain |
| Veilmourn Armada | memory salt | verdant grafts |

### Rare resources at the market

Owner decision, 2026-10-07: rare resources are fully tradeable, HoMM3 style. This replaces the earlier Trade Exchange import (the faction's two rares at 1,200 gold, five a week, buy only). Every market buys, sells and converts all six rare resources at twice the price of wood or ore, the economy's valuation:

- A Marketplace allows 2 bought and 3 sold of each rare per week.
- A Trade Exchange has better rates and allows 5 of each.
- Rates follow the town's local abundance.

The same weekly usage carries through ownership changes, visiting heroes, rebuilding and save/load, and the next normal week resets it. A saved import count stays in the buy bucket and counts against the rare buy limit. Players place actual orders in the market popout before constructing or recruiting.

The AI uses the same prices and limits. It banks only the shortage for a legal T6/T7 construction target while reserving the project's complete cost and at least 2,000 gold, and can accumulate purchases across weeks for a ten-unit requirement. Automatic cost coverage sells only wood and ore, never rares. Mines, Storehouse II and faction producers remain the cheaper sustained supply. Rules and validation: `docs/town-market.md`, `tests/town_rare_import_regression.py` and `tests/town_market_popout_report.tscn`.

## Faction buildings

Each faction has three unique buildings in addition to the common lines. Their costs, prerequisites and effects are authored in `content/buildings.json`.

| Faction | Building | Benefit |
| --- | --- | --- |
| Embercourt League | Convoy Charter | Chartered river convoys produce 300 gold daily. |
| Embercourt League | Beacon Watch | Signal beacons add 15 town battle readiness. Defending creatures also gain +2 defense during town battles. |
| Embercourt League | Quartermasters Seal | Organized supply reduces faction recruitment costs by 10%. |
| Mireclaw Covenant | Votive Waxworks | Marsh votives produce 1 peatwax daily. |
| Mireclaw Covenant | Chainboom Defenses | Flood chains add 20 town battle readiness. Defending creatures also gain +2 defense during town battles. |
| Mireclaw Covenant | Reedkin Gathering | Reedkin gatherings add 3 weekly tier-1 recruits. |
| Sunvault Compact | Lens Conservatory | Cultivated lenses produce 1 aetherglass daily. |
| Sunvault Compact | Calibration Court | Visiting heroes gain +1 power, once per hero across all Calibration Courts. |
| Sunvault Compact | Prism Muster | Calibrated musters add 2 weekly tier-2 recruits. |
| Thornwake Concord | Renewal Nursery | The living nursery produces 1 verdant graft daily. |
| Thornwake Concord | Rootbound Ward | Living roots add 15 town battle readiness. Defending creatures also gain +2 defense during town battles. |
| Thornwake Concord | Pollen Assembly | Seasonal pollen assemblies add 4 weekly tier-1 recruits. |
| Brasshollow Combine | Contract Mint | Stamped contracts produce 1 brass scrip daily. |
| Brasshollow Combine | Assembly Discipline | Standardized assembly reduces faction recruitment costs by 10%. |
| Brasshollow Combine | Pressure Bastion | Pressure defenses add 20 town battle readiness. Defending creatures also gain +2 defense during town battles. |
| Veilmourn Armada | Saltwake Vault | Preserved memories produce 1 memory salt daily. |
| Veilmourn Armada | Chart of Lost Voyages | Visiting heroes gain 750 experience, once per hero across all Charts. |
| Veilmourn Armada | Bellwake Muster | Harbor bells add 2 weekly tier-3 recruits. |

## Signature faction services and defenses

The following mechanics supplement the three faction buildings and their passive benefits above. Each service requires a physically visiting hero and its built faction building. A week begins on days 1, 8, 15 and so on. Town-scoped claims survive capture; hero-scoped claims apply across every town with that building. Neither loading a save nor revisiting resets them. Reserve rewards only affect constructed, chosen dwellings and use their active upgraded creature; they are additional recruitment stock, not free army units.

| Faction / service building | Weekly service | Scope | Town defense building and effect |
| --- | --- | --- | --- |
| Embercourt / Convoy Charter | Trade 3 wood + 3 ore for 2,700 gold (450 each, above the best market sell rate and below its buy rate). | Town | Beacon Watch: defending ranged attacks deal +25% damage in round 1. |
| Mireclaw / Reedkin Gathering | Spend 1 peatwax to add one base week of tier-1 recruitment stock. | Town | Chainboom Defenses: attackers lose 1 movement point in rounds 1–2, minimum 1. |
| Sunvault / Calibration Court | Spend 1 aetherglass to restore the visitor's mana fully. Does not consume the separate once-only power lesson. | Hero | Prism Muster: defenders gain 30 percentage points of spell-damage resistance in rounds 1–2, subject to the normal 75% cap. |
| Thornwake / Renewal Nursery | Spend 1 verdant graft + 500 gold to add half a base week of tier-1–3 stock, rounded up per built dwelling. | Town | Rootbound Ward: at the start of rounds 2 and 3, each surviving defending stack heals up to 25% of one creature's health. No resurrection. |
| Brasshollow / Assembly Discipline | Convert 2 wood + 2 ore + 350 gold into 2 embergrain for tier-6 recruits. | Town | Pressure Bastion: a shield on each defending stack absorbs damage equal to 15% of starting health, rounded up. It never refills during battle. |
| Veilmourn / Chart of Lost Voyages | Spend 1 memory salt + 500 gold for 1,500 XP, using normal level progression. The separate once-only 750 XP visit remains. | Hero | Bellwake Muster: defenders take 35% less ranged damage in rounds 1–2; melee damage is unchanged. |

Services appear first in Town Log & Logistics with prices on the buttons and exact benefits/limits in tooltips. Battle creature inspection explains active town effects and remaining shield strength; healing and shield absorption appear in the battle log. Shield consumption and already-resolved round healing survive battle saves. Effects apply to the defender in both player defense and player assault contexts, and not to field battles. These are defensive building effects, not destructible walls, gates or towers.

AI town visitors and stationed defenders use the same paid services and persistent limits. AI saves gold for construction/recruitment, uses supply convoys when gold is low, keeps common-material reserves, requests growth only when matching recruitment stock is running low, restores mana when at least half is missing, and makes fuel only when the faction's tier-6 resource is low. The full-match pass below retained these values; this does not establish final competitive balance.

## Artifact trading

Artifact Exchange requires Marketplace. A visiting active hero can buy up to three distinct stocked artifacts per town per week; claimed offers remain exhausted through saves and ownership changes until the next weekly refresh. Offers use stable town identity/week, not simulation RNG. Common/uncommon/rare items cost 1,500 / 2,500 / 4,000 gold. Epic/legendary sale valuations are 6,500 / 10,000. Selling pays half valuation and requires the artifact in inventory, not equipped; quest items are excluded. Buying places the item in inventory. Duplicate ownership, sold-out stock, insufficient funds, remote visits, unowned towns and stale action callbacks are rejected before mutation.

Artifact commerce is in the Artifact Exchange's building popout; training is in **Town Log & Logistics**. Hover descriptions explain effects before use. Owned towns can upgrade their garrison even without a visiting hero; hero training/artifact commerce require a visitor.

## AI town services

Enemy garrisons pay to upgrade existing troops at completed upgraded dwellings. Field commanders use training and artifact services when at an owned town entrance or its cardinal approach, on the same map level; assigned town defenders can also use them. Services run in the economy/full enemy turn and on route arrivals, independently of whether the host needs reinforcements. Available reserve commanders receive no remote training.

Player and AI transactions share upgrade costs, once-per-building training claims, shop stock, prices and resale restrictions. AI service spending retains 2,000 gold for its economy and limits upgrades and artifact buying to half the current excess. It upgrades higher-tier troops first, equips beneficial owned gear, compares both trinket slots, buys at most one useful improvement per hero/day, and sells dominated unequipped non-quest/non-set surplus. The full-match pass below verified these transactions; this does not establish final competitive balance.

Claims, the daily trading limit, army composition and equipment survive commander rebuilds and saves. Equipped purchased artifacts contribute daily income. Captured artifacts assigned to a hero are not counted twice, unequipped items do not pay, and sold items leave the empire income list. Unbound legacy empire relics retain their old income. Controller identity prevents same-faction rivals from using each other's services.

## Compatibility and economy replacement

`content/town_development.json` contains explicit per-faction legacy-building mappings, the selected rosters and upgrade pairs. Existing town placement/template IDs, source maps, source masks, owner, position, heroes and garrisons are not rewritten. Old built IDs are retained in `legacy_built_buildings` as migration history. Old economic/support buildings map to the new storehouse/fortification/guild lines; old unit-unlock buildings map to their matching choice, or the same-tier default if the old creature is not in the new town tree. Old dwelling upgrades map to the relevant Veteran lodge.

Where an old town had both exclusive branches, its first saved branch wins deterministically. Already stored recruits from an unselected/retired line remain recruitable until used, but receive no new growth. Garrison and field troops are preserved. Migration is idempotent, free and applies when old maps/saves load; it does not replay construction, refill stocks or overwrite source files. New towns begin with Town Hall and choose their first dwelling. Legacy per-category faction/town income and growth multipliers are retired from this replacement economy and retained as legacy content metadata. Existing occupation and other live strategic penalties still apply.

Retired building definitions remain for old script/content IDs and artwork provenance, but are not buildable or listed as active wiki buildings. Unit species outside the selected town roster remain available to their other authored encounters/sources. AI construction uses the same exclusivity, prerequisites, active-stage economy, converted reserves and Veteran recruitment rules.

## Creature roster

Each listed choice has an upgraded Veteran dwelling. Tier 6 uses secondary rare resource; tier 7 uses main rare resource.

### Embercourt League

| Tier | Choice A | Choice B |
| --- | --- | --- |
| 1 | River Guard | Fordhook Cadets |
| 2 | Ember Archer | Lantern Sappers |
| 3 | Citadel Pikeward | Bargebow Crews |
| 4 | Ash-Oath Bailiffs | Lockglass Writcasters |
| 5 | Beacon Lectors | Beaconline Writguard |
| 6 | Sluicefire Lindworms | — |
| 7 | Charter Colossus | — |

### Mireclaw Covenant

| Tier | Choice A | Choice B |
| --- | --- | --- |
| 1 | Blackbranch Cutthroat | Reedsnare Kin |
| 2 | Bog Brute | Mudglass Slingers |
| 3 | Gorefen Ripper | Bogplate Maulers |
| 4 | Ferrychain Lashers | Mireglass Reedcasters |
| 5 | Sporewake Chanters | Fenbell Chainstalkers |
| 6 | Gorefen Rippers | — |
| 7 | Drowned Antler Sovereign | — |

### Sunvault Compact

| Tier | Choice A | Choice B |
| --- | --- | --- |
| 1 | Shard Pavise Guard | Shard Wardens |
| 2 | Prism Harrier | Prism Adepts |
| 3 | Aurora Ballista | Mirror Duelists |
| 4 | Resonant Choristers | Noonfacet Sentinels |
| 5 | Solar Array Striders | Zenith Lensbearers |
| 6 | Aurora Bastions | — |
| 7 | Daybreak Colossus | — |

### Thornwake Concord

| Tier | Choice A | Choice B |
| --- | --- | --- |
| 1 | Seedcutters | Pollenhook Whistlers |
| 2 | Thornwhip Carriers | Bramblekite Needlers |
| 3 | Sporeglass Menders | Seedshield Wardens |
| 4 | Barkmantle Rams | Dawnseed Bolters |
| 5 | Stag-Knot Runners | Seedglass Cantors |
| 6 | Graft Matriarchs | — |
| 7 | Worldroot Bastion | — |

### Brasshollow Combine

| Tier | Choice A | Choice B |
| --- | --- | --- |
| 1 | Scrip Haulers | Tallyspring Throwers |
| 2 | Rivet Hounds | Quenchspool Slingers |
| 3 | Furnace Pavis Teams | Gaugefire Arbalists |
| 4 | Boiler Rivetcasters | Gaugeplate Bailiffs |
| 5 | Debt-Engine Exactors | Quenchbell Mortars |
| 6 | Crucible Crawlers | — |
| 7 | Foundry Saint | — |

### Veilmourn Armada

| Tier | Choice A | Choice B |
| --- | --- | --- |
| 1 | Bellwake Oars | Saltbell Casters |
| 2 | Mourning Lanterns | Tidehook Deckhands |
| 3 | Maskglass Corsairs | Wakechain Boarders |
| 4 | Undertow Harpooners | Gloamkeel Bulwarks |
| 5 | Obituary Scribes | Wakeglass Navigators |
| 6 | Mirror-Keel Reavers | — |
| 7 | Fogbound Leviathan | — |

## Validation

`tests/town_development_regression.py` checks all faction trees and both branch graphs, runtime construction/upgrade/resource/weekly-growth flows, training and trading transactions, persistent claims, migration, defending-side bonuses and actual town UI. Windows Godot 4.6.2 focused run passes 676 checks; town, muster, market and construction dialogs were rendered and reviewed, including an actual artifact purchase UI callback. JSON, artwork bindings, construction branch reachability, wiki counts and scoped diff checks pass. Known pre-existing certificate-store/MSAA startup messages remain. No full repository suite, native generation changes or Linux execution in this slice.

AI services follow-up (2026-09-22): `tests/town_ai_services_regression.py` passes 146 focused Windows runtime checks, including all six factions, public economy/full enemy turns, town defenders, route-arrival services, saved commander reconstruction, paid upgrades, equipment choice, treasury isolation and artifact income/sales. Shared player services retain all 676 existing focused checks. No full suite or Linux execution.

Faction mechanics follow-up (2026-09-22): `tests/town_faction_mechanics_regression.py` passes 185 focused checks for all six paid services, exact resource/recruit/XP/mana effects, weekly scope and resets, save preservation, AI use, six actual town-battle effects in both defense orientations, shield spending and battle reloads, expiry and healing without resurrection. The live Town Log & Logistics service button and transaction were exercised; rendered dialog reviewed. Existing AI and shared-town regressions also pass (146 + 676; 1,007 total). No full repository suite or Linux execution. The full-match balance results are recorded below.

## Full-match balance pass

The pass completed nine actual matches, then used three additional Medium continuations to exercise late-tier economics. Matches used normal gameplay actions and Quick Resolve, paid transactions, ordinary AI turns and exact save checkpoints. No resource grants, army edits, forced outcomes or native generation changes were used.

| Faction | Small match | Medium match |
| --- | --- | --- |
| Embercourt | Defeat, day 60 | Victory, day 67; upgraded T6 and constructed T7 |
| Mireclaw | Defeat, day 9 | Victory, day 63; constructed T6 after paid imports |
| Sunvault | Defeat, day 18 | Victory, day 57 |
| Thornwake | Defeat, day 11 | In progress at day 84; T6/T7 construction, upgrades and paid recruits |
| Brasshollow | Defeat, day 11 | In progress at day 88; T6 constructed with imported secondary resource |
| Veilmourn | Defeat, day 7 | In progress at day 73; AI constructed T6 during occupation, then player recaptured the town |

The concrete economy defect was Veilmourn Medium seed 10: no renewable verdant-graft supply, but T6 construction and recruitment require it and T7 requires T6. Trade Exchange's limited paid imports provide the fallback. In the actual match the occupying AI imported five grafts and constructed T6 on day 71. The player's day-72 recapture retained the dwelling and consumed allowance, confirming both progression and capture persistence. Earlier player-owned town loss was an ordinary strategic setback, not an import failure.

Across the six western terminal histories, 108 paid constructions, 109 recruit orders, 47 battles and 22 exact save checks completed with zero capacity violations. Actual Storehouse income, weekly growth, six hero-training transactions, four artifact purchases, two sales, equipment use and 13 paid rare imports were observed. Thornwake's eastern continuation additionally built, upgraded and recruited both T6 and T7 through earned resources; paid imports enabled Brasshollow's T6. These observations did not justify blanket construction-price or growth changes.

The three eastern Medium checkpoints are not claimed as victories or completed matches. The driver is a transaction/strategy probe, not an optimal player: deliberate artifact buying/selling verifies commerce and does not establish perfect AI or competitive balance. Terminal gameplay reports had no recorded gameplay failures, but strict wrappers still flag the Windows host's certificate-store and sampler messages. No full repository suite or Linux execution was performed. Sources remain in `tools/town_overhaul_match_east.py` and `tools/town_overhaul_match_west.py`; actual saves, backups and caches are preserved while disposable reports, logs and generated drivers are removed.

## Original building artwork

The art pass is complete across all six factions. All 51 active Embercourt building stages now have separate original paintings and matching construction icons: four halls, three fortifications, five magic guilds, two markets, two storehouses, a tavern, three growth buildings, three hero schools, an artifact exchange, three faction specials and 24 dwelling stages. The dwellings cover both exclusive T1-T5 branches and T6/T7, each with an architectural upgrade. Barracks, boarding schools, siege yards, court/archive buildings, sanctuaries, containment vaults and the colossus foundry have distinct structures and equipment. These are separate paintings, not scaled or recolored copies. The convoy office includes a barge on the river side of its dock. Authored terrace placements and the revised river-quay backdrop keep the lock open without obsolete painted buildings beneath active layers.

Mireclaw now has all 51 separate original building stages and matching icons. Blackbranch timber, reed and hide roofs, structural bone and chain braces establish its marsh-clan identity. The hall develops from a low council lodge to a broad covenant seat; support buildings include open drill courts, a communal kitchen, archive and relic bazaar. Faction specials have functional waxworks, chain capstans and a drum-led muster gathering. All 24 dwelling stages cover both exclusive T1-T5 branches and T6/T7, with distinct trapmaking, mudglass kilns, armored forges, chain boathouses, reed sound chambers, fungal sanctuaries and elite war-lodge/antler shrine designs. Each upgrade adds architecture and changes its silhouette. The cleared marsh backdrop and authored earthen terraces keep all 23 active plots grounded and selectable. Approved overworld town sprites are unchanged.

The active hall's alpha-shaped hotspot opens construction and replaces the obsolete backdrop hotspot. Other painted buildings open their information panels. Faction-specific icons are selected by the visiting town.

`art/towns/source/generated/overhaul/production.json` records the built-in imagegen masters, exact prompts, source hashes and ground placement. `tools/prepare_town_overhaul_art.py` crops transparent outer margins, preserves aspect/alpha, produces 512px maximum scene layers and 256px icons, and merges only the authored entries. Original backdrops and generated masters remain available. The wiki exposes each faction painting and icon.

Embercourt's art regression passed 460 focused Windows Godot checks across three bounded runs (210 civic/support, 125 per dwelling branch). It verifies construction and upgrade replacement, loaded faction art/icons, aligned input, information routing and exposed painted click areas for all 23 active buildings in both developed-town compositions. An initial combined render run exceeded the shared two-minute limit; splitting the same checks into three fresh processes resolved that timeout. The preceding hall slice passed 43 art/input checks and 676 shared-town checks. All 51 paintings and both developed-town compositions were visually inspected.

Mireclaw's complete art run passes 464 focused Windows Godot checks (212 civic/support and 126 per dwelling branch), covering all replacement stages, faction icons, actual backdrop selection, construction/information routes and exposed input for all 23 buildings in both developed branches. The preceding hall/foundation slice passed 182 checks. The original paintings, stage renders and both developed-town compositions were visually reviewed. The 72 creature upgrade identities and animations are complete; see Dwelling choices and upgrades above. No full suite or Linux execution was performed for these art slices.

Sunvault now has all 51 original building stages and matching icons. Ivory limestone, aged brass and blue-violet glazing distinguish its halls, lens-gate fortifications, prism guilds, markets and storehouses. The 11 support paintings include open drill courts, an archive tower, provisioner hall, lens greenhouse, calibration mirrors and a broad prism muster gate. Its 24 dwelling paintings cover both exclusive T1-T5 branches and T6/T7, with distinct barracks, firing schools, optical workshops, ballista gantries, dueling galleries, resonant pipe chambers, sentinel vaults, solar flight hangars, lens sanctuaries and colossus assembly towers. Upgrades add architecture and change the silhouette; the first barracks upgrade was revised to a tall command tower and raised sentry bridge after its initial version proved too similar at game scale. The original revision and its prompt remain preserved.

The cleared sandstone plateau and authored terrace placements retain all 23 selectable plots. The complete Sunvault art pass has 464 focused Windows checks (212 civic/support, 126 per dwelling branch); the preceding hall slice passed 47. Both final developed compositions and all individual building icons were visually reviewed. All 51 original hashes and 102 scene/icon bindings were verified. Source masters, exact built-in generation prompts and references are retained in the production packet; the wiki exposes all stages. Brasshollow and Veilmourn are now integrated too; the faction building art pass is complete. Creature upgrades and the full-match balance pass are complete, with validation limits recorded above. No full suite or Linux execution.

Thornwake has all 51 original orchard-caravan building stages and matching icons on a cleared orchard backdrop. Wheeled timber halls, living-root gates, amber greenhouses, archery decks and drumming platforms preserve its mobile grove identity. Upgrade stages expand platforms, rooflines, towers and enclosed chambers. All 23 developed plots remain selectable in both dwelling branches. The art pass passed 464 focused Windows checks (212 civic/support and 126 per dwelling branch), plus 47 preceding hall checks. All dwelling icons and both developed-town compositions were visually reviewed; source masters and exact prompts remain preserved. No full suite or Linux execution.

Brasshollow and Veilmourn complete the six-faction art pass: 306 original building stages, 306 matching icons and six cleared backdrops. Brasshollow uses riveted redbrick foundries, copper boilers, gantries and industrial training halls; Veilmourn uses reclaimed hull timber, pale structural ribs, mourning bells and memory mirrors across its harbor quays. Each has 51 stages with independently painted upgrades, both exclusive dwelling branches and all 23 active plots exposed for selection. Authored placements keep Brasshollow spires clear of the command rail and Veilmourn foundations on quay/wharf surfaces. Each faction passed 511 focused Windows checks (47 hall, 212 civic/support, 126 per dwelling branch); stage source reviews and final developed layouts were inspected. All 312 active source hashes are unique and verified, with exact prompts, references and portable runtime/icon bindings retained. No full repository suite or Linux execution.

Brasshollow was repainted on 2026-11-09 (owner's choice: the slag canyon). Its village backdrop is now an empty basalt canyon with a slag river. All 51 building stages are masked edits of that canyon at their own plots (gpt-image-2.6-sunburst through the imggen skill), so every building shares the backdrop's light, perspective and brushwork. Small plots were painted on close-up crops, because on the full frame the model paints buildings two to three times their plot. `tools/town_plot_mattes.py` marks each building with BiRefNet (general weights, MIT, run in the unit pipeline's matting environment), and `tools/package_town_plot_layers.py` cuts the building along that matte with a short soft skirt of its painted foundation. The first cut, from paint change against the empty canyon (GrabCut), lost dark walls in front of dark rock and kept chunks of the terrace the model painted under each building. The packet `art/towns/source/generated/overhaul/faction_brasshollow/slag_canyon.json` lists plots, paintings, mattes, prompts and references. The tool writes the layer, a building-only hit mask (`hit_mask_path`, for clicks and the hover outline) and the icon. It also writes the town fully built, as the town screen draws it (the last stage of each line, the first dwelling of each tier); `content/towns.json` gives that as the town's picture, which the town list, the town switcher and the build screen show. The faction layout's `layers_under_stage_light` draws these layers under the stage tint and slag glows. Its `stage_effects` turns on the stage's shader effects (`scenes/town/town_*_fx.gdshader`): slag that churns and drifts downstream, heat haze over it, flickering fire light in windows and furnaces, and a few rising embers. They touch only painted slag and fire light, hold still with reduced motion and stay off in high contrast. The Shipyard (owner's choice, 2026-11-10) is a boatworks on the cliff face under the market terrace, its iron hull on rails running down into the slag river, as the canyon has no water. Nothing of it stands on the terrace, so the T3 hall above stays clear; the first painting's gantry and winch house rose in front of the hall and hid up to half of it. The 2026-09 Brasshollow items in `production.json` are inactive.

Veilmourn was repainted the same way on 2026-11-09 (owner's choice: the planned bell fjord). Its 23 plots were drawn on a plan sketch before any painting and the concept was painted over it, so each plot has room for its largest stage. The village backdrop is that concept with its buildings painted out: a channel with moored ships, a sea stack for the bell hall and a rocky hillside around a waterfall. Each building's close-up crop is centred on its plot, with the fjord mirrored past the frame edge where the crop runs over it; in a crop pushed back inside the frame the model drifted the building toward the crop's middle. Words such as "long", "wide" or "a tower at its end" stretched buildings past their plot, while "compact" and "rising from the middle of its roof" kept them inside. The sea pens set `matte_passes`: BiRefNet marks the leviathan first, so it looks twice, the second time with what it found painted back to the empty cove. The packet is `art/towns/source/generated/overhaul/faction_veilmourn/bell_fjord.json`. The Shipyard (owner's choice, 2026-11-10) stands at the sea stack's foot, where a moored ship was painted out of the backdrop; the packet's `backdrop.revisions` records that edit. The stage glows sit on the sunset, the falls and the deck lanterns of the ship at the left edge. Its `stage_effects` (owner's picks, 2026-11-09) are:
- water that sways and glitters;
- the falls streaming down;
- streamers of fog drifting down the slopes, coloured and laid like the painted wisps;
- flickering lanterns and windows;
- a few pale wisps over the water.

Each acts only where the layout's `stage_effects_mask` puts it, with water in red, the falls in green, land in blue and fog thickness in alpha. `bell_fjord_fx_mask.py` beside the packet rebuilds that mask from:
- hand-drawn shapes;
- GrabCut for the shores;
- BiRefNet marks for the ships, the jetty and the sea stack, which GrabCut takes for water.

A repaint anywhere in a box's window shifts BiRefNet's marks for the whole box, so after the shipyard repaint only the removed ship's box was marked again; the marks file beside the script keeps the rest.

The 2026-09 Veilmourn items in `production.json` are inactive.

Embercourt was repainted the same way on 2026-11-10 (owner's choice: concept C, the lock gorge), the first town planned with its Shipyard from the start. Its 24 plots were drawn on a plan sketch first. The first plan looked straight up a river with every block the same size, and the owner rejected its concepts as flat, like the first Brasshollow drafts. The second plan is seen from high on the right wall of a deep gorge: the river winds in from the sunset, drops through a staircase of four locks on a rock step and opens into a harbour basin; far plots are small and near ones large. The army panel covers only basin water, and the Shipyard has its own plot on the basin's near shore. The village backdrop is the concept with the town painted out; that edit moved some ledges, so the plots were fitted to the emptied gorge, not to the concept. The Fort line is a river barrage in the far distance, the tier-6 drakes have a sluice pen in the basin (`matte_passes`, as the Veilmourn sea pens) and the tier-7 colossus has a tall plot on the right slope. The packet is `art/towns/source/generated/overhaul/faction_embercourt/lock_gorge.json`. The stage glows sit on the sunset on the far river and the locks' fire baskets. Its `stage_effects` are water that sways and glints on the basin and the river above the locks, the four lock falls streaming down, the fire baskets on the lock piers flickering (`beacons`: the backdrop's lamp flicker alone, where the mask's blue puts it) and fire light in the buildings at 0.6 (`windows`). At full strength the windows' fire test also caught lantern-lit awnings and the colossus' bronze in this sunset palette. `lock_gorge_fx_mask.py` beside the packet rebuilds the mask: hand-drawn zones, GrabCut for the basin's shores, the river picked by its light, the falls by their white paint and the fires by their flames. Measured beside the other two towns, those effects moved only in spots, so the gorge also has `mist`: pale gold haze bands that drift through the far gorge and across the locks, and spray around each fall, where the mask's alpha puts them. The layout's `stage_mist` gives the drifting fog its colour, wind and cover for this painting; without it a town gets the bell fjord's blue-grey fog. A first pass in the hills' own colour at 0.6 thickness could not be seen.

Mireclaw was repainted the same way on 2026-11-10 (owner's choice: concept D, the dusk fen). The first plan was a drowned gorge with a channel winding into the distance and the tier-7 antlered beast in a flooded pen; the owner rejected it: Mireclaw should feel more swampy and less like a river, and the elk should not be in the water. The accepted plan has no river: still pools, reed beds, mud and mossy hummocks under giant cypresses, an open mere at the lower left under the army panel, the drum hall on a root mound, and the beast on a dry mossy island. The Shipyard is a chain-ferry yard on the mere's near bank, right of the army panel. The great tree at the right edge is in the foreground, so no plot stands over it. The packet is `art/towns/source/generated/overhaul/faction_mireclaw/dusk_fen.json`. The stage glows sit on the horizon glow, its glints on the far pools and the drum hall's fire. Its `stage_effects` are water that sways and glints on the mere and the far pools, mist bands drifting across the whole swamp (`stage_mist`: a pale olive, a slow wind to the left; thickest far off, none on the sky or the foreground tree), a few wisps over the water and fire light in the buildings at 0.8. `dusk_fen_fx_mask.py` beside the packet rebuilds the mask. The first backdrop drew the swamp floor as thousands of thin upright reed strokes with upright reflections; the owner found it very streaky, with vertical lines all over (its vertical edges outweighed its horizontal ones, 1.12 against 0.73 to 0.83 in the other towns). The floor was repainted in one edit that keeps the layout (`dusk_fen_v2.png`, ratio 0.75): moss cushions, matted grass, mud, lily pads and calm water, with reeds only as a few tufts. The buildings were not repainted: the packet's `backdrop.painted_on` names the master they were painted on, both tools cut them against that one, and the game draws them over the new one. The great tree at the right edge is painted into the backdrop in front of the town, and the den's layer lay over its root. The packet's `backdrop.foreground` is a mask of that tree (`dusk_fen_foreground.py`, GrabCut from hand-drawn seeds); the packaging tool cuts every layer and hit mask away under it, so the tree stays in front. Icons keep the whole building.

Sunvault was repainted the same way on 2026-11-10 (owner's choice: concept A, the sun cirque, the steeper and more rugged of two). It is the one town in bright daylight: a mountain cirque on a cold clear morning, seen from high on its rim, with snow peaks and a glacier behind, bare golden rock dropping in broken shelves to a turquoise glacial lake at the lower left, and a meltwater fall down the middle of the wall. The army panel covers only lake water. The sun vault stands on a promontory above the lake, the prism spire on a crag at the upper left, the Fort line is a rampart across the far pass, the tier-7 colossus stands in a scaffold cradle on a terrace at the right edge, and the Shipyard is a boat hall with a gilded barge and a lens crane on the lake's near right shore, right of the army panel. The emptied backdrop was checked for streaks before any building went on it (vertical against horizontal edges 0.75) and no plot stands on the boulders of the lower right corner, so the packet needs no foreground mask. The concept's painted light beams were masked out with the buildings, and the building prompts ask for no beams, flares or glow, so the mattes stay clean. The Shipyard's matte keeps the barge, the crane and the hall, not the stone quay under them; two passes took the whole shore instead. The packet is `art/towns/source/generated/overhaul/faction_sunvault/sun_cirque.json`. The stage glows sit on the sun vault's gold front, the sun's glints on the lake and the spray at the foot of the fall. Its `stage_effects` are water that sways and glints on the lake (not on its ice floes), the fall streaming down, a pale vapour drifting to the right along the cirque wall and over the lake, thickest in the spray at the fall's foot (`stage_mist`: blue-white), and the buildings' light test at 0.25 (`windows`): in this daylight palette it catches gilded roofs, which at 0.5 flickered like fire and at 0.25 only glint. `sun_cirque_fx_mask.py` beside the packet rebuilds the mask.

Thornwake was repainted the same way on 2026-11-10, the last of the six (owner's choice: concept C, the root ravine, in a smoother repaint). The scene is a steep ravine in an ancient forest on a late-spring afternoon, seen from a high bough: a wall of giant roots and mossy ledges with small waterfalls, one colossal mother tree on a spur in the middle, pale trunks in a green-gold haze beyond, and a slow green river bending through the lower right. The water is a river bend at the lower right, not a lake under the army panel as in Mireclaw and Sunvault; the army panel covers only the crowns of blossoming trees, seen from above. Two first concepts had the ground as a gentle hillside, the flatness the owner had rejected for Embercourt, so two more were painted on the same plan with the valley turned into a ravine. The owner then asked why everything looked pixelated: the concept wording (loose painterly brushwork, visible brush texture, broad masses) had made the model build blossom, leaves and moss from blocky square dabs. One unmasked repaint that keeps the layout and asks for a finer, smoother hand removed it, at medium quality as well as at high, and the backdrop and all building prompts carry that wording; a full-size crop is checked before a concept is shown. The concord seat stands at the mother tree's foot, the pollen spire on a ledge at the upper left (kept below the status chips: its first painting rose under them and all five stages were repainted lower), the Fort line is a wall of coppiced bramble on the far saddle, and the tier-7 Worldroot Gate stands on the ledge under the mother tree. Its creatures follow the unit art: the base stage holds the squat, many-legged root bastion with a green seed-heart, the upgrade the root giant crowned with blossoming boughs. The Shipyard is a woven boat shed with a leaf-sailed barge on the river's near bank. BiRefNet marked only its barge, with one, two or three looks, so `root_ravine_shipyard_matte.py` cuts it from what the painting changed inside a hand-drawn outline and writes that matte into the packet. The blossoming crowns are in the foreground: `root_ravine_foreground.py` builds the packet's `backdrop.foreground` mask, as for Mireclaw's tree. The packet is `art/towns/source/generated/overhaul/faction_thornwake/root_ravine.json`; its `sources` note names the source art archive. The stage glows sit on the sunlit flank of the mother tree, the concord seat's lit arches and the sun's glints on the river. Its `stage_effects` are water that sways and glints on the river, four small waterfalls streaming, a pale green-gold pollen haze drifting to the left (`stage_mist`; thickest among the far trunks, none on the foreground blossom; thinned once because its bands read as smears at 0.85), a few wisps over the water and lantern light in the buildings at 0.8. `root_ravine_fx_mask.py` beside the packet rebuilds the mask.

A quality pass followed on 2026-11-10 (slice `town-art-quality-pass-20261110`), after a critical comparison of the six towns from in-game captures with the effects on and off (owner: fix all listed). Haze: the drifting mist was built as long thin streamers to match the bell fjord's painted wisps, and over the bright, detailed paint of Embercourt, Sunvault and Thornwake it read as straight parallel streaks. A layout's `stage_mist` now also takes `shape` (the streamers' length and thickness against the fjord's) and `soft` (0 keeps crisp wisps with fine strands, 1 blends them into haze); those three towns use short thick soft patches at a lower `gain`. Ground: Sunvault's rock was soft with long diagonal smears, Mireclaw's floor soft and featureless after its first repaint, and Veilmourn's slopes covered in fine diagonal hatching and thin fog wisps. Each was repainted in one edit of the whole backdrop without a mask, asking for the same picture in a crisper hand (`sun_cirque_v2.png`, `dusk_fen_v3.png`, `bell_fjord_v3.png`; forms moved by under 1 pixel), and the water, sky and foreground were blended back from the earlier backdrop through a keep mask, so effect and foreground masks still fit; the buildings stay cut against the backdrop they were painted on (`backdrop.painted_on`). A first try with a mask over the land failed: the model re-composed the cliffs and left part of the picture empty, so a ground repaint is never masked. Edges: a layer's soft skirt of painted ground showed as a pale halo once the ground under it had changed, worst in Sunvault, so the three repainted towns cut with a short skirt (`cut.skirt_radius` 4, `skirt_strength` 0.4, against 12 and 0.85). Lodges: ten building stages that blended into their ground were repainted in lighter materials on the backdrop they were first painted on: Thornwake's lash lodge and toll hut, ram run and den, artifact exchange and hall of chronicles (pale wood, bark shingles, bleached horns), and Mireclaw's two storehouses and two spore lodges (pale driftwood, bleached thatch). Measured in the game with the effects off, the share of fine detail a one-pixel blur removes rose from 0.49 to 0.58 in Sunvault, 0.54 to 0.67 in Mireclaw and 0.57 to 0.60 in Veilmourn; the soft edge round buildings fell to about half its area in all three; Sunvault's buildings that blend in fell from 4 to 1 of 29 and Thornwake's from 13 to 11. Mireclaw's dark buildings still read by their lights more than by colour (27 of 29 by the mean-colour measure). Not changed: Veilmourn's older overlaps (its tier-6 pen under the army panel, the shipyard a fifth hidden).
