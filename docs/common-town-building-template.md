# Shared town development

Implemented owner direction, 2026-09-21. All six factions use one town template, common upgrade lines and exclusive creature choices. The former 26 town IDs remain compatibility aliases. Runtime rules live in `TownDevelopmentRules.gd`, construction/economy adapters in `OverworldRules.gd`, and player services in `TownRules.gd`.

## Common buildings

| Line | Stages and benefits |
| --- | --- |
| Town Hall | 500 / 1,000 / 2,000 / 4,000 gold daily. One active stage; per-town Capital Hall, no player-wide capital restriction. |
| Fortifications | Three stages: +10 / +20 / +30 town readiness and +2 / +4 / +6 defense to defending creatures in town battles. Higher stages replace earlier benefits. |
| Magic Guild | Five stages, enabling faction spells through tiers 1–5. |
| Marketplace | Basic exchange; Trade Exchange improves wood/ore buying and selling rates and enables bulk orders. No daily gold income. Rare resources remain mine/storehouse sourced. |
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

Hero training is once per hero per building type across all towns, preventing repeated capture/visit farming. A different hero can receive their own benefit. Growth buildings only improve an existing chosen dwelling; they never create an unbuilt troop line. Workshop is omitted until its equipment gameplay is defined.

## Dwelling choices and upgrades

- Tiers 1–5 each offer two distinct existing creatures. Building one branch removes the other branch and its upgrade from construction. Choice persists through saves and captures.
- Tiers 6 and 7 each have a single dwelling and upgrade. Tier 6 requires the faction secondary rare resource for both construction and each recruit; tier 7 requires the main rare resource.
- Every tier after 1 requires a dwelling of the preceding tier; either branch qualifies. Tiers 3–5 also require Council Hall; tiers 6–7 require City Hall and Palisade.
- Each of the 72 base creature choices has a Veteran upgrade: +20% HP and damage (rounded upward), +2 attack/defense, +35% gold recruitment cost (rounded upward). Other abilities, mobility, footprint and rare-resource costs remain those of the base creature. Existing linked-creature abilities recognize the upgraded identity too.
- Upgrading a dwelling replaces the base recruitment line. Existing reserve count converts to Veterans with no extra weekly grant. Subsequent growth produces Veterans only.
- Existing field and garrison troops are upgraded through **Muster Hall**, for the undiscounted difference between base and Veteran costs. Each order trains all troops of that type in the selected stationed army; it does not consume town reserve or a construction day.
- The initial foundation's Veteran units reuse their original portraits, sprites, footprints and eight-frame idle/action animation assets; the individual creature upgrade pass remains pending. Most town stages and exclusive branches still reuse older paintings. The building art pass is now replacing these with original faction-specific layers, starting with all four Embercourt hall stages.
- One construction per town per day. Prerequisites recognize higher stages while effects count only the active stage. Buildings show full descriptions, costs, exclusivity and requirements in Construction.

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

## Faction buildings

Each faction has three unique buildings in addition to the common lines. Their costs, prerequisites and effects are authored in `content/buildings.json`.

| Faction | Building | Benefit |
| --- | --- | --- |
| Embercourt League | Convoy Charter | Chartered river convoys produce 500 gold daily. |
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
| Embercourt / Convoy Charter | Trade 3 wood + 3 ore for 1,200 gold. | Town | Beacon Watch: defending ranged attacks deal +25% damage in round 1. |
| Mireclaw / Reedkin Gathering | Spend 1 peatwax to add one base week of tier-1 recruitment stock. | Town | Chainboom Defenses: attackers lose 1 movement point in rounds 1–2, minimum 1. |
| Sunvault / Calibration Court | Spend 1 aetherglass to restore the visitor's mana fully. Does not consume the separate once-only power lesson. | Hero | Prism Muster: defenders gain 30 percentage points of spell-damage resistance in rounds 1–2, subject to the normal 75% cap. |
| Thornwake / Renewal Nursery | Spend 1 verdant graft + 500 gold to add half a base week of tier-1–3 stock, rounded up per built dwelling. | Town | Rootbound Ward: at the start of rounds 2 and 3, each surviving defending stack heals up to 25% of one creature's health. No resurrection. |
| Brasshollow / Assembly Discipline | Convert 2 wood + 2 ore + 350 gold into 2 embergrain for tier-6 recruits. | Town | Pressure Bastion: a shield on each defending stack absorbs damage equal to 15% of starting health, rounded up. It never refills during battle. |
| Veilmourn / Chart of Lost Voyages | Spend 1 memory salt + 500 gold for 1,500 XP, using normal level progression. The separate once-only 750 XP visit remains. | Hero | Bellwake Muster: defenders take 35% less ranged damage in rounds 1–2; melee damage is unchanged. |

Services appear first in Town Log & Logistics with prices on the buttons and exact benefits/limits in tooltips. Battle creature inspection explains active town effects and remaining shield strength; healing and shield absorption appear in the battle log. Shield consumption and already-resolved round healing survive battle saves. Effects apply to the defender in both player defense and player assault contexts, and not to field battles. These are defensive building effects, not destructible walls, gates or towers.

AI town visitors and stationed defenders use the same paid services and persistent limits. AI saves gold for construction/recruitment, uses supply convoys when gold is low, keeps common-material reserves, requests growth only when matching recruitment stock is running low, restores mana when at least half is missing, and makes fuel only when the faction's tier-6 resource is low. Values remain initial balance choices until the goal's full-match balance pass.

## Artifact trading

Artifact Exchange requires Marketplace. A visiting active hero can buy up to three distinct stocked artifacts per town per week; claimed offers remain exhausted through saves and ownership changes until the next weekly refresh. Offers use stable town identity/week, not simulation RNG. Common/uncommon/rare items cost 1,500 / 2,500 / 4,000 gold. Epic/legendary sale valuations are 6,500 / 10,000. Selling pays half valuation and requires the artifact in inventory, not equipped; quest items are excluded. Buying places the item in inventory. Duplicate ownership, sold-out stock, insufficient funds, remote visits, unowned towns and stale action callbacks are rejected before mutation.

Artifact commerce is in **Town Market**; training is in **Town Log & Logistics**. Hover descriptions explain effects before use. Owned towns can upgrade their garrison even without a visiting hero; hero training/artifact commerce require a visitor.

## AI town services

Enemy garrisons pay to upgrade existing troops at completed upgraded dwellings. Field commanders use training and artifact services when at an owned town entrance or its cardinal approach, on the same map level; assigned town defenders can also use them. Services run in the economy/full enemy turn and on route arrivals, independently of whether the host needs reinforcements. Available reserve commanders receive no remote training.

Player and AI transactions share upgrade costs, once-per-building training claims, shop stock, prices and resale restrictions. AI service spending retains 2,000 gold for its economy and limits upgrades and artifact buying to half the current excess. It upgrades higher-tier troops first, equips beneficial owned gear, compares both trinket slots, buys at most one useful improvement per hero/day, and sells dominated unequipped non-quest/non-set surplus. Final balance remains pending the full-match pass.

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

Faction mechanics follow-up (2026-09-22): `tests/town_faction_mechanics_regression.py` passes 185 focused checks for all six paid services, exact resource/recruit/XP/mana effects, weekly scope and resets, save preservation, AI use, six actual town-battle effects in both defense orientations, shield spending and battle reloads, expiry and healing without resurrection. The live Town Log & Logistics service button and transaction were exercised; rendered dialog reviewed. Existing AI and shared-town regressions also pass (146 + 676; 1,007 total). No full repository suite or Linux execution. Full-match balance remains pending.

## Original building artwork

The art pass is in progress. Embercourt Town Hall, Council Hall, City Hall and Capital Hall each have a separate original painting and a matching construction icon. The village backdrop now has an empty civic courtyard, so only the active hall stage is drawn; its alpha-shaped hotspot opens construction and replaces the obsolete backdrop hotspot. Faction-specific icons are selected by the visiting town, with existing artwork retained for factions not yet converted.

`art/towns/source/generated/overhaul/production.json` records the built-in imagegen masters, exact prompts, source hashes and ground placement. `tools/prepare_town_overhaul_art.py` crops transparent outer margins, preserves aspect/alpha, produces 512px maximum scene layers and 256px icons, and merges only the authored entries. The original backdrop and all generated masters remain available. The wiki exposes each faction painting and icon.

The first hall line passed 43 focused runtime/art/input checks and 676 shared town checks on Windows Godot 4.6.2; all four stages and the developed town were visually inspected. Remaining building lines, alternate dwellings, the other factions and grounded placement of older developed-town layers still need the art pass. No full suite or Linux run was performed.
