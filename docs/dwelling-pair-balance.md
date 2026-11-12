# Dwelling pair balance

Slice: `balance-dwelling-pairs-20261006` (owner-directed, 2026-10-06).

## Single-type tiers (owner decision, 2026-11-12)

Slice `single-type-dwelling-tiers-20261112`. Armies had become all shooters: 24 of the 30 tier I–V choices set a melee line against a ranged one, and a ranged army wins its fights without losses while a melee army's losses add up over a game. Since this slice every tier I–V choice is between two lines of one attack type, so a town fields shooters only from its ranged tiers.

The owner chose to regroup the lines that exist, not to redesign units. 24 lines moved one tier up or down. Four units changed attack type, because their towns had an odd number of melee and ranged lines: Reedsnare Kin and Solar Array Striders became ranged, Pollenhook Whistlers and Quenchspool Slingers melee (each with its upgrade).

| Town | I | II | III | IV | V |
| --- | --- | --- | --- | --- | --- |
| Embercourt | melee: River Guard / Fordhook Cadets | ranged: Ember Archer / Bargebow Crews (from III) | melee: Citadel Pikeward / Lantern Sappers (from II) | ranged: Beacon Lectors (from V) / Lockglass Writcasters | melee: Ash-Oath Bailiffs (from IV) / Beaconline Writguard |
| Mireclaw | melee: Blackbranch Cutthroat / Bog Brute (from II) | ranged: Reedsnare Kin (from I) (now ranged) / Mudglass Slingers | melee: Gorefen Ripper / Bogplate Maulers | melee: Ferrychain Lashers / Fenbell Chainstalkers (from V) | ranged: Sporewake Chanters / Mireglass Reedcasters (from IV) |
| Sunvault | melee: Shard Pavise Guard / Shard Wardens | ranged: Prism Harrier / Prism Adepts | ranged: Aurora Ballista / Resonant Choristers (from IV) | melee: Mirror Duelists (from III) / Noonfacet Sentinels | ranged: Solar Array Striders (now ranged) / Zenith Lensbearers |
| Thornwake | melee: Seedcutters / Pollenhook Whistlers (now melee) | ranged: Sporeglass Menders (from III) / Bramblekite Needlers | melee: Thornwhip Carriers (from II) / Seedshield Wardens | ranged: Seedglass Cantors (from V) / Dawnseed Bolters | melee: Stag-Knot Runners / Barkmantle Rams (from IV) |
| Brasshollow | melee: Scrip Haulers / Rivet Hounds (from II) | ranged: Tallyspring Throwers (from I) / Gaugefire Arbalists (from III) | melee: Furnace Pavis Teams / Quenchspool Slingers (from II) (now melee) | ranged: Boiler Rivetcasters / Quenchbell Mortars (from V) | melee: Debt-Engine Exactors / Gaugeplate Bailiffs (from IV) |
| Veilmourn | melee: Bellwake Oars / Tidehook Deckhands (from II) | ranged: Mourning Lanterns / Saltbell Casters (from I) | melee: Maskglass Corsairs / Wakechain Boarders | ranged: Undertow Harpooners / Obituary Scribes (from V) | melee: Gloamkeel Bulwarks (from IV) / Wakeglass Navigators |

- **A moved line** keeps its unit ids, names, art, abilities, speed and initiative, and its two dwelling buildings with their ids, art and plots (`building_dev_embercourt_t3_2` is now a tier II dwelling). Its buildings take the new tier's cost, requirements, `dwelling_tier`, `choice_group` and `choice_branch`.
- **Numbers.** Health and damage scale by the ratio of today's medians of the new and old tier for that attack type; attack and defense shift by the difference of the medians. The price starts at the tier's median gold per strength (`army_power` terms without a commander). Weekly growth makes a week of the line cost what a week of its tier and attack type costs.
- **Balance.** Each pair was duelled on `battle_sim_cli` through the battle arena's setup (`tools/battle_ai_arena`): one stack against one at seven budget ratios, from both sides, three dice, level 1 heroes with no mana, 2,520 fights a round. The ratio at which the lines tie is one line's strength per gold against the other's. Over six rounds the moved lines' prices were corrected (within 0.75–1.35 of the rule price, the rest from health and damage, an upgrade costing 1.2–1.75 times its base). Of the 50 changed pair stages, 40 tie within 10% and all but 4 within 15% (embercourt:t3:upgrade 0.82, embercourt:t5:base 0.81, mireclaw:t2:base 0.78, veilmourn:t1:base 0.80); the ten untouched same-type stages read 0.93 to 1.29 on the same measure, so this is the harness's resolution.
- **Converted abilities.** Bloomchime Echo and Quenchspool Redline became melee blows against rooted or staggered targets (`backstab`); Heliostat Pathfinders' reach became Survey Beam (`volley`). The two new shooters and their upgrades have their own shooting clips since `single-type-tier-shooting-art-20261112`: Reedsnare Kin and Knotroot Trappers cast the snare from the pole, Solar Array Striders unfold their lens train, hold the aim, kick back and fold it again (painted aim and recoil poses guide the video), Heliostat Pathfinders level the forearm and hold the aim. The battle draws one shared projectile for every shooter, so none was painted.
- **Derived content.** `content/generated_neutral_companies.json` was rebuilt, map dwellings hire the new weekly growth, and each faction's `unit_ladder_ids` holds a unit of the slot's tier again.
- **Saves.** A town keeps what it built. Where it had built two lines that now share a tier, the one built first stays active (the standing rule for exclusive branches); the other line's stored recruits stay hireable and its troops stay in the armies.
- `tests/unit_pair_duel_report.tscn` below no longer runs: it sets its duels up in an archived authored scenario.

## Moved lines against the field (owner decision, 2026-11-12)

Slice `moved-lines-field-balance-20261112`. The regroup above made each moved line even with its tier partner. Where the partner was weak against other factions, the moved line was tuned down with it: an Embercourt army fell from 35% to 24% of even fights, Beacon Lectors cost 410 gold for nearly the Writcasters' numbers, and the Ash-Oath Bailiffs' upgrade added one point of health for 145 gold. The owner asked for the 26 changed lines (52 units) to be balanced against the whole field.

- **Worth.** A line's worth is the gold of field troops one gold of it ties with. It is read from single-stack duels at five gold ratios against twelve units the regroup did not touch, one melee and one ranged of each faction (the line's own faction left out), half of them from each seat, level 1 heroes without mana: 50 fights a unit.
- **Par.** The median worth of the untouched lines of the tier, for the base unit and for the upgrade: 1.27 and 1.23 at tier I, 1.37 and 1.39 at II, 1.31 and 1.26 at III, 1.07 and 0.89 at IV, 1.00 and 0.98 at V.
- **Correction.** A changed unit more than 8% off par moves to par through its price. The price stays within 0.8 to 1.25 of the tier's usual price for its attack type, and an upgrade within 1.2 to 1.75 of its base; what the price cannot cover comes from health and damage. Weekly growth again makes a week of the line cost what a week of its tier costs. Attack, defense, speed and abilities are unchanged. Two rounds: 8 of the 52 units were within 10% of par before, all 52 after. 49 units changed; map dwellings hire the new growth.
- **Town armies** (equal gold spent top tier first at weeks 2, 4 and 6, every faction's two choices against every other's, 1,584 fights before and after): Embercourt 29% → 44% of even fights, Brasshollow 26% → 41%, Thornwake 46% → 52%, Sunvault 51% → 46%, Mireclaw 98% → 85%, Veilmourn 50% → 32%. Veilmourn's three strongest moved lines came down to par, and its untouched low tiers field less gold a week than the other towns'.
- **Pairs.** Only the changed lines moved in this slice, so a pair with an untouched partner that was itself off par came out uneven: 23 of the 50 pair stages were more than 20% apart on this measure (17 before). The next section evens them.
- **Running it.** A custom arena job holds every battle of a call in memory, about 20 MB each: 3,168 battles took 29 GB and a 6,000-battle call froze the machine. The duels ran in calls of 150 battles with twelve threads (3.5 GB, about 40 battles a second) under a watchdog (`tools/battle_ai_arena/README.md`).

## Every line against the field (owner decision, 2026-11-12)

Slice `all-lines-field-balance-20261112`. The owner asked for the 34 untouched tier I–V lines to come to the same par, so that the two lines of a tier are even again and every line is worth its gold against the other factions.

- **Yardstick.** The same twelve units, as frozen copies at the numbers they had before this slice (extra `unit_ref_…` rows in the simulator's content only), so the measure stays put while those units are tuned themselves. Par is the median worth of the 34 untouched lines, measured before any change: 1.30 and 1.22 at tier I, 1.46 and 1.36 at II, 1.32 and 1.30 at III, 1.03 and 0.86 at IV, 1.03 and 1.01 at V.
- **Correction.** The rule of the section above, applied to all 60 lines (120 units): price inside the tier's band, the rest from health and damage, growth so a week of the line costs what a week of its tier and attack type costs. Five rounds: 59 units were more than 10% off par at the start, none at the end. 77 units changed. No upgrade breaks the rule below (at least its base on every stat, more health and one more of attack, defense or damage, at least 20% more gold).
- **Pairs.** 59 of the 60 pair stages are within 15% of each other on this measure (Veilmourn tier I base 1.18).
- **What moved most.** Mireclaw's untouched lines cost 25 to 60% more or lost about a fifth of their health and damage (Blackbranch Cutthroat, Gorefen Ripper, Mudglass Slingers, Bogplate Maulers, Sporewake Chanters); Veilmourn's Mourning Lanterns and Undertow Harpooners likewise. Citadel Pikeward, Furnace Pavis Teams, Debt-Engine Exactors and Seedshield Wardens gained a fifth to a third in health and cost a fifth to a third less. Veilmourn's and Thornwake's cheap low tiers grow in larger numbers (Bellwake Oars 8 → 14 a week, Seedcutters 11 → 16).
- **Town armies** (1,584 fights on each set of numbers; the regroup, the moved lines, every line): Embercourt 29% → 44% → 52% of even fights, Thornwake 46% → 52% → 58%, Sunvault 51% → 46% → 49%, Brasshollow 26% → 41% → 73%, Mireclaw 98% → 85% → 43%, Veilmourn 50% → 32% → 26%. The spread of the six (standard deviation) went 0.235 → 0.170 → 0.143.
- **What this does not level.** A win rate magnifies small differences in strength, and three things outside this slice still differ by town: the tier VI and VII units, how many of the first tiers are shooters (a ranged tier brings more gold a week than a melee one, so Mireclaw's week-2 army is about a tenth smaller than Embercourt's and wins 15% of its week-2 fights), and how single-stack duels read slow, sturdy lines (Brasshollow's read weak alone and are strong in an army). The same line moved by 10% between two measurements (Bargebow Crews went 80 → 90 → 80 gold over the two slices), which is this harness's resolution. The next section levels the towns' whole armies.

## Town armies levelled (owner decision, 2026-11-12)

Slice `faction-army-level-20261112`. With every line at one par the six towns' armies still won 27% to 69% of their even fights. The owner asked for the whole armies to be levelled.

- **Two factors a town.** One for its tier I–V lines: every price is divided by it and weekly growth rises to match, so a week of a line still costs the same gold and the two lines of a tier stay even (price rounding moves no pair by more than 4%). One for its tier VI and VII units: health and damage are multiplied, prices and growth stay.
- **The factors.** Tiers I–V: Embercourt 0.90, Thornwake 0.94, Brasshollow 0.94, Sunvault 1.03, Veilmourn 1.09, Mireclaw 1.11 (above 1 is cheaper and more numerous). Tiers VI–VII: Mireclaw 0.81, Sunvault 0.90, Brasshollow 0.96, Veilmourn 1.02, Embercourt 1.16, Thornwake 1.21. Each set averages 1, so the game as a whole is no richer or stronger.
- **How they were found.** Town armies as in the sections above (equal gold spent top tier first at weeks 2, 4 and 6, both dwelling choices, every other town's both choices, both seats), now with the level 1 heroes rotated through each town's eleven. After each round of 1,080 even fights a town's tier I–V factor moved by 0.35 of its shortfall from half at weeks 2 and 4, its tier VI–VII factor by 0.35 of its shortfall at week 6, within ±30% and ±22%. Six rounds; the factors are the mean of the last four.
- **Check on dice the search never used** (1,440 fights each): before, Embercourt 69%, Brasshollow 64%, Thornwake 53%, Sunvault 47%, Mireclaw 40%, Veilmourn 27% of even fights (standard deviation 0.142). After: Mireclaw 57%, Sunvault 56%, Embercourt 50%, Thornwake 46%, Veilmourn 46%, Brasshollow 45% (0.048). By week the towns range 41–59% at week 2, 41–68% at week 4 and 35–65% at week 6; Mireclaw's week 4 (68%) and Thornwake's week 6 (35%) are the widest. With twice the gold the attacker wins 95% and loses 21% of its army, as before.
- **Limits.** This levels one model of a town army: troops only, no spells, skills or artifacts, gold spent top tier first. Whole games are not measured. Mireclaw's and Thornwake's tier VI–VII factors sit near the ±22% limit, so their late armies are not fully level.

## Rule (2026-10-06)

Every faction town offers two exclusive dwelling lines at tiers I–V, and each line has a base unit and an upgrade. The two lines of one tier must be a real trade-off, never one line that is a little better at everything:

- Two melee lines (or two ranged lines) at the same tier split into a **tank** (more defense and health, less attack and top damage) and a **striker** (more attack and top damage, less defense), and trade evenly per gold.
- (No pair is mixed since 2026-11-12; kept for the record.) When one line shoots and the other fights in melee, the melee line is always the bulkier one (health weighted by defense). The shooter keeps a head-on edge per gold, because a duel cannot credit the melee line for screening, blocking and closing on shooters in a real army.
- An upgrade stays at least as strong as its base on every stat and costs at least 20% more gold. It always gains health and at least one of attack, defense or damage; tank upgrades such as Ledgerwall Porters and Kilnwall Wardens gain defense instead of attack by design. `tests/town_development_regression.py` checks this for all 72 upgrades.

Tiers VI and VII are single dwellings and neutral units are not part of this pass.

## Method

`tests/unit_pair_duel_report.tscn` fights every tier I–V pair (60 pairs: base and upgrade stage for five tiers in six towns) with the live battle rules:

- equal gold budgets (24 units at the pair's average price), commanders neutralised, no spells, no battlefield tags or objectives;
- each pairing is fought from both sides with seeds 101 and 202; the player side uses battle autoplay and the enemy side the battle AI;
- the report bisects the size of line B's army until the two lines tie; `value_ratio` is line A's strength per gold relative to line B (1.0 = even).

Pass bands, enforced by the report's exit code:

| Pair kind | Target | Pass band |
| --- | --- | --- |
| Same role | 1.0 | ±10% |
| Ranged vs melee (ranged edge) | 1.6 | 1.3–2.0 |

The original mixed pairs spread from a 1.12 to a 2.86 ranged edge (median 1.92). The 1.6 target sits mid-band: shooters keep a clear head-on edge, but no shooter is worth almost three of its melee partner per gold.

Run it on Windows with an isolated profile (see `AGENTS.md` and the town reports); set `DUEL_FACTION=faction_<id>` to measure one town. Each pair prints a `UNIT_PAIR_DUEL_ROW` line and the run ends with `UNIT_PAIR_DUEL_REPORT`.

## Changes

Only `hp`, `attack`, `defense`, `min_damage`, `max_damage` and gold cost changed; growth, abilities, roles, shots, speed, initiative and art are untouched. 107 of 232 units changed.

- **Tank/striker splits** where one line was at least as good on every stat: Embercourt T1 (River Guard tank, Fordhook Cadets striker), Mireclaw T1 (Reedsnare Kin tank, Blackbranch Cutthroat striker), Sunvault T1 (Shard Pavise Guard tank, Shard Wardens striker), Veilmourn T3 (Wakechain Boarders tank, Maskglass Corsairs striker), with their upgrades.
- **Bulk swaps** where the shooter was also the bulkier line: Mireclaw T5, Thornwake T2, Brasshollow T2, T3 and T5, Veilmourn T5. The melee line now has the health; the shooter has the range.
- **Price and stat corrections** for pairs outside the bands: gold moves first (at most 15% per pass on each side), then health and damage for the rest of the gap.

Before the pass 36 of 60 pairs were outside the bands. The worst were Mireclaw T3 upgrade (Bogplate Gatebreakers worth 2.9 Gorefen Redhooks per gold), ranged edges of 2.7–2.9 at Embercourt T4–T5, Thornwake T2, Veilmourn T1 upgrade and T4, and Brasshollow T1 upgrade, Sunvault T2 (Prism Harriers 1.6 times the Adepts' value) and Sunvault T1 (Shard Pavise Guard 1.27 times the Wardens'). After it all 60 pass:

| Faction | Same-role ratios | Ranged edges |
| --- | --- | --- |
| Embercourt | 0.93, 1.01 | 1.46–1.78 |
| Mireclaw | 0.93–1.06 | 1.49–1.66 |
| Sunvault | 0.93–1.06 | 1.56–1.70 |
| Thornwake | — | 1.43–1.81 |
| Brasshollow | — | 1.37–1.89 |
| Veilmourn | 1.01, 1.01 | 1.37–1.63 |

## Test fixtures that followed the new stats

- `tests/validate_repo.py` and `tests/unit_ability_runtime_report.gd` pin Undertow Harpooners at the new 4–7 damage band.
- The Obituary Scribes AI proof now offers Dawnseed Bolters as the competing shooter. The bulkier Thornwhip Carriers no longer outscored Sporeglass Menders, so the proof also checks that plain Scribes shoot the Bolters and Final Notice makes them pick the braced Carriers.
- The magic AI scouting proof delays opportunistic hero intercepts for its raid. The stronger Blackbranch Cutthroats otherwise hunt the nearby exposed hero, which the hero-hunt reports already prove, instead of the scouted shrine.

## Limits

- The duel measures head-on value per gold. It does not measure flying, screening, siege roles or spell support, so the ranged edge is a shared assumption, not a per-faction proof.
- Unit abilities count only as far as battle autoplay uses them.
- The report borrows the `river-pass` skirmish and its Ford Reavers encounter only as a session and battlefield shell. Authored scenarios are obsolete, so it needs another shell when they are removed.
- Upgrade jumps differ between lines of one tier (for example Gorefen Redhook gains more over its base than Bogplate Gatebreakers do); both lines stay even per gold, so this is a pacing question for a later pass, not a dominance problem.
