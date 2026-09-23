# Shared town development

Implemented owner direction, 2026-09-21. All six factions use one town template, common upgrade lines and exclusive creature choices. The former 26 town IDs remain compatibility aliases. Runtime rules live in `TownDevelopmentRules.gd`, construction/economy adapters in `OverworldRules.gd`, and player services in `TownRules.gd`.

## Common buildings

| Line | Stages and benefits |
| --- | --- |
| Town Hall | 500 / 1,000 / 2,000 / 4,000 gold daily. One active stage; per-town Capital Hall, no player-wide capital restriction. |
| Fortifications | Three stages: +10 / +20 / +30 town readiness and +2 / +4 / +6 defense to defending creatures in town battles. Higher stages replace earlier benefits. |
| Magic Guild | Five stages, enabling faction spells through tiers 1–5. |
| Marketplace | Basic wood/ore exchange; Trade Exchange improves rates and enables bulk orders, plus paid imports of the town faction's two rare resources: 1,200 gold each, five of each per week. No daily gold income. |
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
- Each of the 72 base creature choices now has an individually named upgrade with authored combat distinctions. Faction design records live in `content/unit_upgrade_designs/`; the live rows are in `content/units.json`. Existing `*_veteran` IDs and `upgrade_from` links remain stable for saves. Recruitment prices and weekly growth retain the shared foundation economy; ability effects are covered by actual battle scenarios, including trigger and non-trigger cases. Linked-creature abilities recognize the upgraded identity.
- Upgrading a dwelling replaces the base recruitment line. Existing reserve count converts to the selected upgraded identity with no extra weekly grant. Subsequent growth produces that upgrade only.
- Existing field and garrison troops are upgraded through **Muster Hall**, for the undiscounted difference between base and upgraded costs. Each order trains all troops of that type in the selected stationed army; it does not consume town reserve or a construction day.
- All 72 upgrades have original portraits, battle/map sprites and 285 articulated idle poses integrated locally, with no base-art alias. Battle and overworld idle rendering, reduced-motion behavior, recruitment and save persistence passed 1,233 focused checks. All 72 upgrades also have two original attack poses, a hit reaction and a fallen body: 288 action paintings, 573 authored poses including idle. Dedicated attack/ranged/retaliation, recoil, death and corpse clips now use upgraded art. Expanded transparent action canvases retain the original body scale and anatomical ground anchor. Final action/simulation/save/GPU validation passed 2,291 focused checks, in addition to the 1,233 idle/recruitment/save checks and 424 faction combat checks. Ability statuses now respect innate and active-effect immunity without consuming an unused readiness ward. Original sources, exact prompts, references and recipes are retained.
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

### Limited rare imports

Trade Exchange provides an expensive fallback when the map lacks a renewable source of a faction resource. Each town can import up to five of its main resource and five of its secondary resource per week, at 1,200 gold per unit. Imports are buy-only, have no bulk discount and do not carry unused allowance forward. The town's authored faction determines the pair even when another faction captures it. Ownership changes, visiting heroes, rebuilding and save/load preserve consumed allowance; the next normal week resets it. Older saves begin with unused allowance and receive no free resources.

Town Market shows the price, remaining allowance and reset day. Players place actual exchange orders before constructing or recruiting. AI uses the same prices and allowance, banking only the shortage for a legal T6/T7 construction target while reserving the project's complete cost and at least 2,000 gold. It can accumulate shipments across weeks for a ten-unit requirement. Mines, Storehouse II and faction producers remain the cheaper sustained supply.

`tests/town_rare_import_regression.py` passes 198 focused Windows checks: all six resource pairs, prices, caps, capture/rebuild/save persistence, legacy migration, rejected sales/off-pair orders, real construction/recruitment transactions and AI banking. Full-match continuations also exercise the recovery on their existing maps and earned treasuries. Native generation is unchanged.

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

AI town visitors and stationed defenders use the same paid services and persistent limits. AI saves gold for construction/recruitment, uses supply convoys when gold is low, keeps common-material reserves, requests growth only when matching recruitment stock is running low, restores mana when at least half is missing, and makes fuel only when the faction's tier-6 resource is low. The full-match pass below retained these values; this does not establish final competitive balance.

## Artifact trading

Artifact Exchange requires Marketplace. A visiting active hero can buy up to three distinct stocked artifacts per town per week; claimed offers remain exhausted through saves and ownership changes until the next weekly refresh. Offers use stable town identity/week, not simulation RNG. Common/uncommon/rare items cost 1,500 / 2,500 / 4,000 gold. Epic/legendary sale valuations are 6,500 / 10,000. Selling pays half valuation and requires the artifact in inventory, not equipped; quest items are excluded. Buying places the item in inventory. Duplicate ownership, sold-out stock, insufficient funds, remote visits, unowned towns and stale action callbacks are rejected before mutation.

Artifact commerce is in **Town Market**; training is in **Town Log & Logistics**. Hover descriptions explain effects before use. Owned towns can upgrade their garrison even without a visiting hero; hero training/artifact commerce require a visitor.

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
