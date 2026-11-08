# Magic system: spells and mechanics

The 139 spells and 138 mechanics of the magic system in `docs/magic-system.md`, as the owner settled them on 2026-11-07. The 12 basic battle spells, the 36 tier-2 battle spells, the 36 tier-3 battle spells and the 39 tier-4 and tier-5 battle spells are in `spells.json`, marked unreleased (`docs/magic-system.md`, "The new spells in content"); nothing else here is in the game yet. None of today's 119 spells, names or ids is reused; the ids below are `spell_` and the name.

## Reading the numbers

- `{a+bP}`: a + b × spell power. Helpful numbers. `{a+P}` means b = 1.
- `{a+bE}`: a + b × E, where E is spell power less all of the enemy hero's Knowledge, never below 0. Against a neutral army, which has no hero, E is the spell power. Harmful numbers and the turns of effects on enemy stacks.
- `{a+P/d}` and `{a+E/d}`: a + spell power (or E) ÷ d, rounded down: turns, rounds, tiles and counts. A lasting effect gets one more turn per 4 spell power, with no limit.
- A faction's heroes cast its preferred school at 1 more spell power, and start with mastery 1 in it.
- Mana is the cost per cast before mastery discounts. Mastery: from the mastery rank named, the spell also reaches the stacks the column says.
- Creatures keep their own school resistances on top of Knowledge; basic spells meet only general spell resistance.

## Number bands

Damage and healing per cast at tiers 1 to 5, as [flat part, per point of spell power]. A flavour spell (a kind its school is best at) does about a third more for the same mana.

| Kind | Tier 1 (basic) | Tier 2 | Tier 3 | Tier 4 | Tier 5 |
|---|---|---|---|---|---|
| Damage, ordinary | [15, 10] | [26, 15] | [37, 20] | [51, 28] | [74, 35] |
| Damage, flavour | – | [34, 20] | [48, 26] | [66, 36] | [96, 46] |
| Healing, ordinary | [20, 5] | [28, 6] | [40, 8] | [56, 11] | [78, 15] |
| Healing, flavour | – | [36, 8] | [52, 10] | [73, 14] | [100, 20] |

- Splash, beam, blast: the main target near the band; each other stack about half.
- Every enemy stack: about half the band on each.
- Damage over time: about a third of the band each turn, for 2 to 3 turns.
- Delayed (Doom): about one and a half times the band, landing 2 turns later.
- Plates: a little above the healing band.
- Stat boosts: +2 to +3 at tiers 1 to 3, up to +6 at the top; flavour one point more.
- Turns: the base turns plus one per 4 spell power, with no limit; against an enemy hero's stacks, per 4 of your power less its Knowledge.

## Spells

| School | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 | All |
|---|---|---|---|---|---|---|
| Basic | 15 | – | – | – | – | 15 |
| Furnace | – | 9 + 1 scroll-only | 9 + 1 scroll-only | 6 + 1 scroll-only | 3 + 1 scroll-only | 31 |
| Root | – | 9 + 1 scroll-only | 9 + 1 scroll-only | 6 + 1 scroll-only | 3 + 1 scroll-only | 31 |
| Beacon | – | 9 + 1 scroll-only | 9 + 1 scroll-only | 6 + 1 scroll-only | 3 + 1 scroll-only | 31 |
| Veil | – | 9 + 1 scroll-only | 9 + 1 scroll-only | 6 + 1 scroll-only | 3 + 1 scroll-only | 31 |

Battle and map spells by tier: tier 1: 12 battle, 3 map; tier 2: 36 battle, 4 map; tier 3: 36 battle, 4 map; tier 4: 23 battle, 5 map; tier 5: 16 battle, 0 map.

### Basic, tier 1

Plain spells every hero can learn: one job each, no school, no mastery. They grow with spell power only.

| Spell | Id | Kind | Target | Mana | Effect | Mechanics |
|---|---|---|---|---|---|---|
| Bolt | `spell_bolt` | damage | One enemy stack | 3 | Deals {15+10E} damage. | `damage` |
| Mend | `spell_mend` | healing | One of your stacks | 3 | Heals {20+5P}, the wounded creature first; no creature comes back. | `heal` |
| Sharpen | `spell_sharpen` | boost | One of your stacks | 3 | +3 attack for its next {2+P/4} turns. | `buff_attack` |
| Quicken | `spell_quicken` | boost | One of your stacks | 3 | +2 speed for its next {2+P/4} turns: it walks 2 hexes farther. | `buff_speed` |
| Shell | `spell_shell` | ward | One of your stacks | 3 | +3 defense for its next {2+P/4} turns. | `buff_defense` |
| Steady | `spell_steady` | ward | One of your stacks | 2 | +3 cohesion for its next {2+P/4} turns. | `buff_cohesion` |
| Hobble | `spell_hobble` | control | One enemy stack | 3 | −2 speed for its next {2+E/4} turns. | `slow` |
| Daze | `spell_daze` | control | One enemy stack | 3 | It acts last for {1+E/4} rounds, starting with this one if it has not acted yet. | `delay` |
| Snare | `spell_snare` | control | One enemy stack | 4 | Rooted for its next {1+E/4} turns: −1 defense, cannot move. | `rooted` |
| Unweave | `spell_unweave` | control | One enemy stack | 4 | Removes up to {1+E/3} spell effects that help it, the newest first. | `dispel` |
| Cleanse | `spell_cleanse` | healing | One of your stacks | 4 | Removes up to {1+P/3} harmful statuses and spell effects from it, the newest first. | `cleanse` |
| Shift | `spell_shift` | field | One of your stacks | 4 | Moves it to an empty hex up to {2+P/3} hexes away; it keeps its turn. | `move_ally` |
| Far Sight | `spell_far_sight` | map | On the map | 2 | The hero sees {3+P/2} tiles farther until the day ends; what it sees stays scouted. | `map_sight` |
| Stride | `spell_stride` | map | On the map | 3 | +{2+P/2} tiles of movement today. | `map_move` |
| Read Tracks | `spell_read_tracks` | map | On the map | 2 | Until the day ends, shows the garrisons of the towns that are not yours within {6+P} tiles of the hero; scouting shows a hero's army but no garrison. | `map_scout` |

### Furnace

Power now, paid for later: heat that builds until it bursts, forged plates and brass constructs, strength with a price. Best at damage, boost, ward. Weak: Heals badly (its heals carry a cost) and controls only by force.

Signature: Heat: up to 3 on a stack; the third bursts; Burning; Plates that soak damage; Boosts with a backlash; Brass constructs; Burning ground.

#### Furnace, tier 2

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Overdrive | `spell_overdrive` | boost | One of your stacks | 5 | +{4+P/3} attack for its next 2 turns; at the end of each of those turns it loses 8% of its health. | `buff_attack`, `backlash` | 2: also lands on your stacks next to it; 3: lands on every stack of yours |
| Stoke | `spell_stoke` | boost | One of your stacks | 5 | For its next {2+P/4} turns, every blow it lands gives it +1 momentum, up to +4 (each point of momentum adds 4% damage). | `momentum_ramp` | 3: also lands on your stacks next to it |
| Cooling Slag | `spell_cooling_slag` | control | One enemy stack | 5 | Rooted for its next turn; then the slag cools and it has −2 speed for its next {1+E/4} turns. | `rooted`, `slow` | 3: also lands on the enemy stacks next to the target |
| Cinder Spray | `spell_cinder_spray` | damage | One enemy stack | 6 | Deals {24+13E} to the target and to every stack next to it, yours included. | `splash_friendly` |  |
| Ember Lash | `spell_ember_lash` | damage | One enemy stack | 5 | Deals {30+18E} damage and adds 1 Heat. | `damage`, `heat` |  |
| Flame Furrow | `spell_flame_furrow` | field | Hexes you pick | 6 | Up to 3 empty hexes in a row burn for {2+P/4} rounds: a stack that walks through or stands in one takes {12+6E}. | `fire_ground` |  |
| Hot Iron | `spell_hot_iron` | healing | One of your stacks | 5 | Heals {36+8P} at once, but no other healing works on it for its next 2 turns. | `heal`, `heal_block` |  |
| Forge Road | `spell_forge_road` | map | On the map | 4 | Roads cost the hero's army half the movement for {1+P/5} days. | `map_road` |  |
| Rivet Plate | `spell_rivet_plate` | ward | One of your stacks | 5 | A plate of {36+10P} health takes damage before the stack does; it lasts until broken or for {2+P/4} turns. | `plate` | 3: also lands on your stacks next to it |
| Spark Swarm (scroll-only) | `spell_spark_swarm` | damage | Every enemy stack | 5 | {4+P/2} sparks each strike a random enemy stack for {8+4E}. | `random_hits` |  |

#### Furnace, tier 3

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Molten Edge | `spell_molten_edge` | boost | One of your stacks | 7 | For its next {2+P/4} turns every blow it lands leaves the target Burning: {8+4E} at the end of each of its next 2 turns. | `on_hit_burning` | 3: also lands on your stacks next to it |
| Goad | `spell_goad` | control | One enemy stack | 7 | It gets +2 attack, but for its next {1+E/4} turns it must attack the stack of yours you name, if it can reach it. | `taunt` |  |
| Cinderfall | `spell_cinderfall` | damage | One enemy stack | 8 | Deals {40+22E}; the target and every enemy stack next to it are left Burning: {10+5E} at the end of each of their next {1+E/4} turns. | `damage`, `burning` |  |
| Flashpoint | `spell_flashpoint` | damage | One enemy stack | 7 | Sets off its Heat now: {25+12E} for each Heat it carries. A stack with no Heat takes {25+12E} and gains 1 Heat. | `heat_burst` | 3: also sets off the Heat of every other enemy stack |
| Brass Sentinel | `spell_brass_sentinel` | field | Hexes you pick | 8 | Builds a brass sentinel worth {60+15P} health on an empty hex next to one of your stacks. It cannot move; it strikes whatever stands next to it. It lasts {2+P/4} rounds. | `summon_static` |  |
| Annealing | `spell_annealing` | healing | One of your stacks | 7 | Heals {40+8P} and gives +2 defense for its next {1+P/4} turns. | `heal`, `buff_defense` |  |
| Firebreak | `spell_firebreak` | map | On the map | 6 | A wall of fire closes a tile next to the hero; no army can pass it for {1+P/4} days. | `map_block` |  |
| Heavy Plating | `spell_heavy_plating` | ward | One of your stacks | 7 | +{5+P/4} defense but −2 speed, for its next 3 turns. | `buff_defense`, `tradeoff` | 2: also lands on your stacks next to it; 3: lands on every stack of yours |
| Tempering | `spell_tempering` | ward | One of your stacks | 8 | For its next {1+P/4} turns no single blow or spell can take more than a quarter of its health. | `damage_cap` |  |
| Smelter's Bargain (scroll-only) | `spell_smelters_bargain` | damage | One of yours and one enemy stack | 6 | Your stack loses 15% of its health; the enemy stack you name takes {150+10E}% of what your stack lost. | `sacrifice` |  |

#### Furnace, tier 4

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Redline | `spell_redline` | boost | One of your stacks | 10 | It strikes twice on its next turn, with +{2+P/3} attack. After that it is Staggered (cannot strike back) for its next 2 turns. | `double_strike`, `buff_attack`, `staggered_self` |  |
| Molten Brand | `spell_molten_brand` | control | One enemy stack | 9 | For the rest of the battle it loses 1 defense each time it is hit, up to −{4+E/2}. | `defense_melt` | 3: also lands on the enemy stacks next to the target |
| Kiln Burst | `spell_kiln_burst` | damage | One enemy stack | 10 | Deals {62+34E} to the target and adds 1 Heat; every other enemy stack within 2 hexes takes {28+15E}. | `damage`, `heat`, `radius2` |  |
| Foundry Golem | `spell_foundry_golem` | field | Hexes you pick | 11 | Builds brass golems worth {90+20P} health, a two-hex body, on your side; they fight for you for {3+P/4} rounds. | `summon` |  |
| Scorched Earth | `spell_scorched_earth` | map | On the map | 9 | For {2+P/4} days enemy armies pay double movement within 3 tiles of where the hero stands. | `map_slow_zone` |  |
| Crucible Ward | `spell_crucible_ward` | ward | One of your stacks | 10 | The next blow or spell that would hurt it within its next {2+P/4} turns does nothing; then it gets +4 attack for its next turn. | `absorb`, `buff_attack` |  |
| Clockwork Twin (scroll-only) | `spell_clockwork_twin` | field | One of your stacks | 11 | Builds a brass copy of one of your stacks with {30+4P}% of its creatures, on an empty hex next to it; the copy lasts {2+P/4} rounds. | `clone` |  |

#### Furnace, tier 5

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Full Steam | `spell_full_steam` | boost | Every stack of yours | 14 | Every stack of yours gets +4 attack and +2 speed for its next {1+P/4} turns, and the first blow each lands leaves the target Burning: {12+6E} at the end of each of its next 2 turns. | `buff_all`, `buff_attack`, `on_hit_burning` |  |
| Molten Deluge | `spell_molten_deluge` | damage | Every enemy stack | 15 | Deals {40+20E} to every enemy stack and adds 1 Heat to each, but never a third: Molten Deluge cannot make a stack burst. | `damage_all`, `heat` |  |
| Iron Oath | `spell_iron_oath` | ward | Every stack of yours | 15 | Every stack of yours gets a plate of {40+10P} health and cannot be Staggered, Rooted or Stunned for its next {1+P/4} turns. | `plate`, `status_immunity`, `buff_all` |  |
| Second Sun (scroll-only) | `spell_second_sun` | damage | The whole battle | 16 | For the rest of the battle every enemy stack takes {12+6E} at the end of each round. | `battle_aura` |  |

### Root

Patience: what it binds holds tighter every turn, what it plants grows, what it grafts shares one life. Best at control, healing, field. Weak: Slow: little speed or turn order, and its damage leans on stacks it has already bound.

Signature: Rooted that tightens; Regrowth; Grafts between stacks; Seeds that wait; Thorns; Living walls and treants; Poison.

#### Root, tier 2

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Heartwood Stance | `spell_heartwood_stance` | boost | One of your stacks | 5 | For its next {2+P/4} turns, +4 attack whenever it attacks without moving first. | `stationary_attack` | 3: lands on every stack of yours |
| Grasping Roots | `spell_grasping_roots` | control | One enemy stack | 6 | Rooted for its next {1+E/4} turns, and it loses 1 more defense for each turn it stays rooted. | `rooted`, `tightening` | 3: also lands on the enemy stacks next to the target |
| Pollen Drift | `spell_pollen_drift` | control | One enemy stack | 6 | Asleep: it skips its next {1+E/4} turns unless something hits it first. | `sleep` | 3: also lands on the enemy stacks next to the target |
| Thornshot | `spell_thornshot` | damage | One enemy stack | 5 | Deals {26+15E}; half as much again against a Rooted stack. | `damage`, `bonus_rooted` |  |
| Bramble Patch | `spell_bramble_patch` | field | Hexes you pick | 5 | Up to 3 empty hexes grow brambles for {2+P/4} rounds: a stack that enters one stops there and takes {10+5E}. | `bramble_ground` |  |
| Graft | `spell_graft` | healing | Two of your stacks | 6 | Joins two of your stacks for {2+P/4} rounds: damage either one takes is split evenly between them. | `graft` |  |
| Green Mending | `spell_green_mending` | healing | One of your stacks | 5 | Regrowth: heals {14+3P} at the start of each of its next {2+P/4} turns. | `regrowth` | 2: also lands on your stacks next to it; 3: lands on every stack of yours |
| Green Path | `spell_green_path` | map | On the map | 4 | Forest, rough and hills cost the hero's army no more than grass for {1+P/5} days. | `map_forest_ways` |  |
| Thornmail | `spell_thornmail` | ward | One of your stacks | 5 | For its next {2+P/4} turns any stack that strikes it in melee takes {8+3E}. | `thorns` | 3: also lands on your stacks next to it |
| Thorn Seed (scroll-only) | `spell_thorn_seed` | field | Hexes you pick | 5 | Plants a seed on an empty hex: the first enemy stack that ends a move next to it is Rooted for its next {1+E/4} turns and takes {20+10E}. | `trap` |  |

#### Root, tier 3

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Budding | `spell_budding` | boost | One of your stacks | 8 | New creatures worth {40+10P} health sprout in it; they wither when the battle ends. | `temp_creatures` |  |
| Uproot | `spell_uproot` | control | One enemy stack | 8 | Drags it up to {2+E/3} hexes toward a hex you pick; it is Staggered for its next turn. | `pull`, `staggered` |  |
| Earthsplit | `spell_earthsplit` | damage | One enemy stack | 7 | Deals {37+20E} and knocks it 1 hex back, if that hex is free. | `damage`, `push` |  |
| Living Wall | `spell_living_wall` | field | Hexes you pick | 7 | Trees grow on up to 3 empty hexes in a row for {2+P/4} rounds: they block movement, and shots across them do half damage. | `wall` |  |
| Wake the Grove | `spell_wake_the_grove` | field | Hexes you pick | 8 | Treants worth {70+16P} health rise next to one of your stacks; slow and sturdy, they fight for {3+P/4} rounds. | `summon_timed` |  |
| Bloomburst | `spell_bloomburst` | healing | One of your stacks | 8 | Heals {52+10P}; every stack of yours next to it heals half as much. | `heal`, `heal_splash` |  |
| Seed of Return | `spell_seed_of_return` | healing | One of your stacks | 8 | If it would be destroyed within its next {2+P/4} turns, it regrows instead with {15+2P}% of its starting creatures, once. | `death_save` |  |
| Rootway | `spell_rootway` | map | On the map | 7 | The hero's army steps to any forest tile within {4+P} tiles. | `map_jump_forest` |  |
| Bark Ring | `spell_bark_ring` | ward | One of your stacks | 7 | +3 defense for its next {1+P/4} turns, to it and to every stack of yours next to it. | `buff_defense`, `buff_splash` | 3: lands on every stack of yours |
| Blight (scroll-only) | `spell_blight` | control | One enemy stack | 8 | For the rest of the battle it cannot be healed or raised; anything that would heal it hurts it instead, by {100+10E}% of the healing. | `heal_inversion` |  |

#### Root, tier 4

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Thicket Snare | `spell_thicket_snare` | control | Hexes you pick | 10 | Every enemy stack on the target hex or next to it is Rooted for its next {1+E/4} turns. | `rooted_area` |  |
| Spore Cloud | `spell_spore_cloud` | damage | One enemy stack | 9 | The target and every enemy stack next to it are Poisoned: {12+6E} at the end of each of their next {2+E/4} turns, and healing on them is halved. | `poison` |  |
| Elder Grove | `spell_elder_grove` | field | Hexes you pick | 10 | A grove covers the target hex and the six around it for the rest of the battle: your stacks in it heal {10+2P} at the start of their turns and have +2 defense. | `zone` |  |
| Sapflood | `spell_sapflood` | healing | One of your stacks | 11 | Heals {73+14P} and brings back fallen creatures with what is left over; then Regrowth heals {15+3P} at the start of each of its next {1+P/4} turns. | `heal`, `raise`, `regrowth` |  |
| Harvest Bloom | `spell_harvest_bloom` | map | On the map | 9 | The mine next to the hero yields double for the next {3+P} days. | `map_mine` |  |
| Ironbark | `spell_ironbark` | ward | One of your stacks | 10 | Shots and spells do half damage to it for its next {2+P/4} turns. | `half_ranged` | 3: also lands on your stacks next to it |
| Wardwood (scroll-only) | `spell_wardwood` | map | On the map | 10 | Plants a wardwood on the hero's tile for {6+P} days: an enemy army that comes within 2 tiles of it stops there and starts its next day with half its movement. | `map_watch` |  |

#### Root, tier 5

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Grasp of the Deep | `spell_grasp_of_the_deep` | control | Every enemy stack | 15 | Every enemy stack is Rooted for its next {1+E/4} turns; a stack that was already Rooted is Stunned instead and skips its next turn. | `rooted_all`, `stun` |  |
| Waking Forest | `spell_waking_forest` | field | The whole battle | 16 | An elder treant worth {150+30P} health, a two-hex body, rises on your side for {4+P/4} rounds, and trees grow on 4 empty hexes for the rest of the battle. | `summon_big`, `obstacles` |  |
| Spring Eternal | `spell_spring_eternal` | healing | Every stack of yours | 15 | Every stack of yours heals {20+4P} at the start of each of its next {2+P/4} turns, and fallen creatures come back with what is left over. | `regrowth_all`, `raise` |  |
| Green Return (scroll-only) | `spell_green_return` | healing | The whole battle | 18 | Every stack of yours destroyed in this battle regrows with {30+4P}% of its starting creatures at the start of the next round, once per battle. | `mass_revive` |  |

### Beacon

Coordination: it decides who acts when, marks targets, bends beams through crystal, reflects and purifies. Best at boost, healing, ward. Weak: No summons and little lasting damage; it wins by timing, not attrition.

Signature: Turn order; Marks; Beams that pierce or jump; Blinded; Reflection and spell shields; Crystals on the field.

#### Beacon, tier 2

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Call to Arms | `spell_call_to_arms` | boost | One of your stacks | 5 | It acts next: it moves to the front of this round's order, or of the next round if it has already acted, with +{1+P/4} speed for that turn. | `act_next`, `buff_speed` |  |
| Sighting Mark | `spell_sighting_mark` | boost | One enemy stack | 5 | Marked for {1+E/4} rounds: your stacks deal 20% more damage to it. | `mark` | 3: also lands on the enemy stacks next to the target |
| Dazzle | `spell_dazzle` | control | One enemy stack | 5 | Blinded for its next {1+E/4} turns: it cannot shoot, and its blows do 30% less. | `blinded` | 3: also lands on the enemy stacks next to the target |
| Dawn Lance | `spell_dawn_lance` | damage | One enemy stack | 5 | A beam from your edge through the target: every enemy stack on the line takes {20+11E}. | `line` |  |
| Crystal Pillar | `spell_crystal_pillar` | field | Hexes you pick | 5 | A crystal pillar stands on an empty hex for {3+P/4} rounds: it blocks movement, and your stacks next to it have +2 defense. | `pillar` |  |
| Morning Light | `spell_morning_light` | healing | Every stack of yours | 6 | Every stack of yours heals {10+2P}. | `heal_all` |  |
| Radiant Mend | `spell_radiant_mend` | healing | One of your stacks | 5 | Heals {32+7P} and removes one harmful status. | `heal`, `cleanse_one` | 3: also lands on your stacks next to it |
| Flare | `spell_flare` | map | On the map | 4 | Scouts every tile within {5+P/2} tiles of any tile up to {10+2P} tiles away; it stays scouted. | `map_flare` |  |
| Prism Ward | `spell_prism_ward` | ward | One of your stacks | 5 | The next harmful spell cast on it within its next {2+P/4} turns bounces to a random enemy stack. | `reflect` | 3: also lands on your stacks next to it |
| Signal Swap (scroll-only) | `spell_signal_swap` | field | Two of your stacks | 5 | Two of your stacks up to {4+P} hexes apart swap places; neither spends its turn. | `swap` |  |

#### Beacon, tier 3

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Volley Signal | `spell_volley_signal` | boost | One enemy stack | 8 | Every stack of yours with shots left fires at the enemy stack you name, at {40+4P}% damage; each uses a shot and keeps its turn. | `free_volley` |  |
| Boundary Line | `spell_boundary_line` | control | Hexes you pick | 7 | Marks a line of up to 4 hexes: enemy stacks cannot cross it for {1+P/4} rounds. | `barrier` |  |
| Prism Bolt | `spell_prism_bolt` | damage | One enemy stack | 7 | Deals {37+20E}, then jumps to a second enemy stack for 70% and to a third for 50%. | `chain` | 3: jumps on to a fourth enemy stack for 30% |
| Prism Array | `spell_prism_array` | field | Hexes you pick | 8 | A crystal stands on an empty hex for {2+P/4} rounds; each time your hero casts a damage spell, it fires {15+5E} at the nearest enemy stack. | `spell_turret` |  |
| Rekindle | `spell_rekindle` | healing | One of your stacks | 8 | Brings back fallen creatures worth {52+10P} health. | `raise` |  |
| Watchful Light | `spell_watchful_light` | healing | The whole battle | 8 | For {2+P/4} rounds, at the start of each round your most wounded stack heals {24+5P}. | `triage` |  |
| Relay | `spell_relay` | map | On the map | 7 | The hero's army jumps to one of your towns within {8+2P} tiles, using all the movement left today. | `map_town` |  |
| Glass Aegis | `spell_glass_aegis` | ward | One of your stacks | 7 | Enemy spells cannot target it for its next {1+P/4} turns. | `spell_shield` | 3: also lands on your stacks next to it |
| Steadfast Halo | `spell_steadfast_halo` | ward | One of your stacks | 8 | It and every stack of yours next to it cannot be Harried, Staggered or Rooted, and lose no cohesion, for their next {1+P/4} turns. | `status_immunity`, `buff_splash` | 3: lands on every stack of yours |
| Hour Ledger (scroll-only) | `spell_hour_ledger` | healing | One of your stacks | 9 | It goes back to the creatures, health and hex it had at the start of a round you pick, up to {1+P/4} rounds back. | `rewind` |  |

#### Beacon, tier 4

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Clarion Call | `spell_clarion_call` | boost | One of your stacks | 11 | It takes another full turn right after this one, with +{2+P/4} attack. | `extra_turn`, `buff_attack` |  |
| Censure | `spell_censure` | control | One enemy stack | 9 | For its next {1+E/4} turns its abilities do not work and its hero's spells cannot help it. | `silence` |  |
| Searing Ray | `spell_searing_ray` | damage | One enemy stack | 9 | Deals {51+28E}; double against a Blinded stack. | `damage`, `bonus_blinded` |  |
| Lantern Vigil | `spell_lantern_vigil` | healing | Every stack of yours | 11 | Every stack of yours heals {30+6P} and loses one harmful status. | `heal_all`, `cleanse_one` |  |
| Watchtower Lens | `spell_watchtower_lens` | map | On the map | 9 | Scouts every tile within {8+2P} tiles of the hero at once, underground too when the map has two levels. | `map_lens` |  |
| Sanctuary | `spell_sanctuary` | ward | One of your stacks | 10 | Nothing can hurt it for its next {1+P/6} turns, but it cannot attack meanwhile. | `invulnerable` |  |
| Echo (scroll-only) | `spell_echo` | boost | The whole battle | 8 | Casts the last spell your hero cast in this battle again, at once, for no mana and with +{1+P/2} spell power. | `recast` |  |

#### Beacon, tier 5

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Daybreak Charge | `spell_daybreak_charge` | boost | Every stack of yours | 15 | Every stack of yours gets +3 attack and +3 initiative for its next {1+P/4} turns, and all of them act before any enemy stack next round. | `buff_all`, `buff_attack`, `act_first` |  |
| Dawn of Return | `spell_dawn_of_return` | healing | Every stack of yours | 16 | Every stack of yours heals {40+8P} and brings back fallen creatures with what is left over. | `heal_all`, `raise` |  |
| Glass Dome | `spell_glass_dome` | ward | Hexes you pick | 15 | A crystal dome covers the target hex and the six around it for {1+P/4} rounds: stacks inside cannot be hurt by shots or spells from outside it. | `dome` |  |
| Eternal Noon (scroll-only) | `spell_eternal_noon` | ward | The whole battle | 18 | For {3+P/3} rounds your stacks cannot be Blinded, Rooted, Staggered or Stunned, and they act first in every round. | `status_immunity`, `act_first` |  |

### Veil

Attrition and deceit: it drains, curses and frightens, hides stacks in murk, sinks them in mire and raises the fallen. Best at damage, control, field. Weak: Protects by hiding and dodging, never by armour; heals only by taking.

Signature: Drain; Curses that spread; Doom that lands later; Fear and flight; Murk and mire; The Risen.

#### Veil, tier 2

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Hungering | `spell_hungering` | boost | One of your stacks | 5 | For its next {2+P/4} turns it heals a quarter of the damage its blows deal. | `lifesteal` | 3: also lands on your stacks next to it |
| Dread | `spell_dread` | control | One enemy stack | 5 | −3 cohesion, and it is Afraid: for its next {1+E/4} turns it will not move toward your stacks. | `fear`, `cohesion_down` | 3: also lands on the enemy stacks next to the target |
| Fog Mind | `spell_fog_mind` | control | One enemy stack | 6 | Confused for its next {1+E/4} turns: its blows land on a random stack next to it, its own side included. | `confusion` | 3: also lands on the enemy stacks next to the target |
| Leech | `spell_leech` | damage | One enemy stack | 5 | Deals {30+17E}; a stack of yours you pick heals half the damage dealt. | `damage`, `drain` |  |
| Wasting Curse | `spell_wasting_curse` | damage | One enemy stack | 6 | Cursed: it takes {10+6E} at the end of each of its next {2+E/4} turns; if it is destroyed while cursed, the curse jumps to the nearest enemy stack. | `curse` | 3: also lands on the enemy stacks next to the target |
| Murk | `spell_murk` | field | Hexes you pick | 6 | Fog covers up to 3 hexes for {2+P/4} rounds: stacks inside cannot be shot and cannot shoot. | `murk` |  |
| Blood Tithe | `spell_blood_tithe` | healing | Two of your stacks | 4 | Moves up to {40+8P} health from one of your stacks to another; fallen creatures can come back this way. | `transfer` |  |
| Mire Stride | `spell_mire_stride` | map | On the map | 4 | Swamp, mire and coast cost the hero's army no more than grass for {1+P/5} days. | `map_mire_ways` |  |
| Mist Cloak | `spell_mist_cloak` | ward | One of your stacks | 5 | Shots cannot target it for its next {1+P/4} turns. | `shot_shield` | 2: also lands on your stacks next to it; 3: lands on every stack of yours |
| Changeling Swap (scroll-only) | `spell_changeling_swap` | field | One of yours and one enemy stack | 5 | One of your stacks and an enemy stack up to {4+E} hexes apart swap places. | `swap_enemy` |  |

#### Veil, tier 3

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Fogwalk | `spell_fogwalk` | boost | One of your stacks | 7 | For its next {1+P/4} turns it walks through stacks and obstacles, and its next blow cannot be struck back. | `phase`, `no_strike_back` |  |
| Night Terror | `spell_night_terror` | control | One enemy stack | 8 | Fleeing: on its next turn it runs as far from your stacks as it can, and it cannot strike back for its next {1+E/4} turns. | `flee` | 3: also lands on the enemy stacks next to the target |
| Hollowing | `spell_hollowing` | damage | One of your stacks | 8 | Every enemy stack next to one of your stacks takes {24+13E}; your stack heals the total. | `damage_around`, `drain` |  |
| Tolling Doom | `spell_tolling_doom` | damage | One enemy stack | 8 | Doomed: at the end of its second turn from now it takes {72+39E}. | `doom` |  |
| Bog Pool | `spell_bog_pool` | field | Hexes you pick | 7 | Up to {2+P/4} hexes turn to mire for the rest of the battle: a stack in mire has half speed and cannot defend. | `mire_ground` |  |
| Raise the Fallen | `spell_raise_the_fallen` | field | A destroyed stack | 9 | A stack destroyed in this battle, yours or the enemy's, rises as Risen worth {60+14P} health and fights for you for {2+P/4} rounds. | `risen` |  |
| Last Breath | `spell_last_breath` | healing | One of your stacks | 8 | For its next {1+P/4} turns it cannot lose its last creature; then it heals {20+4P}. | `deathless`, `heal` |  |
| Ferry Call | `spell_ferry_call` | map | On the map | 7 | The hero's army crosses up to {4+P} tiles of water to the far shore as if by boat. | `map_ferry` |  |
| Decoy | `spell_decoy` | ward | One of your stacks | 7 | A copy of it stands on an empty hex next to it for {1+P/4} rounds; the copy vanishes when anything hits it. | `decoy` |  |
| Puppet Strings (scroll-only) | `spell_puppet_strings` | control | One enemy stack | 9 | It makes one attack now, at {50+10E}% of its damage, against a stack you pick that it can reach. | `charm` |  |

#### Veil, tier 4

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Grave Edge | `spell_grave_edge` | boost | One of your stacks | 9 | For its next {1+P/4} blows, the target's defense does not count. | `pierce` | 3: also lands on your stacks next to it |
| Stupor | `spell_stupor` | control | One enemy stack | 11 | Stunned: it skips its next turn; then it is Harried for its next {1+E/4} turns. | `stun`, `harried` |  |
| Fever Wind | `spell_fever_wind` | damage | Every enemy stack | 11 | Every enemy stack takes {14+7E} now and at the end of each of its next {1+E/4} turns. | `dot_all` |  |
| Wraith Host | `spell_wraith_host` | field | Hexes you pick | 11 | Wraiths worth {90+20P} health in all, fast fliers, appear on two empty hexes and fight for you for {2+P/4} rounds. | `summon_fliers` |  |
| Mist Jump | `spell_mist_jump` | map | On the map | 10 | The hero's army jumps up to {4+P/2} tiles to any free tile, even past guards. | `map_jump` |  |
| Shadow Ranks | `spell_shadow_ranks` | ward | One of your stacks | 10 | For its next {1+P/4} turns, {40+2P}% of the creatures it loses come back at the end of the round. | `loss_return` |  |
| Death's Door (scroll-only) | `spell_deaths_door` | damage | One enemy stack | 11 | At the end of its third turn from now it loses {30+4E}% of its creatures, unless the effect is removed first. | `doom_half` |  |

#### Veil, tier 5

| Spell | Id | Kind | Target | Mana | Effect | Mechanics | Mastery |
|---|---|---|---|---|---|---|---|
| Long Night | `spell_long_night` | control | Every enemy stack | 15 | Every enemy stack loses 3 cohesion and is Afraid for its next {1+E/4} turns; the smallest enemy stack runs from your stacks. | `fear_all`, `cohesion_down`, `flee` |  |
| Black Tide | `spell_black_tide` | damage | Every enemy stack | 16 | Every enemy stack loses {10+E}% of its creatures, never its last one. | `percent_all` |  |
| Drowned Host | `spell_drowned_host` | field | The whole battle | 17 | Every stack destroyed in this battle, on either side, rises as Risen with {25+2P}% of its creatures and fights for you for {2+P/4} rounds. | `risen_all` |  |
| Hollow Crown (scroll-only) | `spell_hollow_crown` | field | The whole battle | 18 | For the rest of the battle every enemy stack that is destroyed rises on your side as Risen with {20+2P}% of its creatures and fights for {2+P/4} rounds. | `risen_aura`, `battle_aura` |  |

## Mechanics

138 mechanics, 126 of them new to the game. A spell names the mechanics it uses; a mechanic is built once and shared.

### Board

| Id | Name | What it does | New | Spells |
|---|---|---|---|---|
| `barrier` | Boundary | A line enemy stacks cannot cross. | yes | 1 |
| `bramble_ground` | Brambles | Hexes that stop a stack entering them and hurt it. | yes | 1 |
| `fire_ground` | Burning ground | Hexes that hurt stacks walking through or standing in them. | yes | 1 |
| `mire_ground` | Mire | Hexes that halve speed and stop defending. | yes | 1 |
| `move_ally` | Shift | Moves one of your stacks without spending its turn. | yes | 1 |
| `murk` | Murk | Fog hexes: stacks inside cannot be shot and cannot shoot. | yes | 1 |
| `obstacles` | New obstacles | Adds lasting obstacles to the field. | yes | 1 |
| `phase` | Walk through | Walks through stacks and obstacles. | yes | 1 |
| `pillar` | Crystal pillar | A blocking hex that gives cover to your stacks next to it. | yes | 1 |
| `pull` | Drag | Moves an enemy stack toward a hex you pick. | yes | 1 |
| `push` | Knock back | Moves the target a hex away from the hit. | yes | 1 |
| `spell_turret` | Prism | A crystal that fires whenever your hero casts a damage spell. | yes | 1 |
| `swap` | Swap | Two of your stacks trade places. | yes | 1 |
| `swap_enemy` | Changeling swap | One of yours and an enemy stack trade places. | yes | 1 |
| `trap` | Trap | Waits on a hex and goes off when an enemy stack comes next to it. | yes | 1 |
| `wall` | Living wall | Blocking hexes for a while; shots across them do half damage. | yes | 1 |
| `zone` | Grove | An area that helps your stacks standing in it each turn. | yes | 1 |

### Boosts

| Id | Name | What it does | New | Spells |
|---|---|---|---|---|
| `backlash` | Backlash | The boosted stack pays health each turn. | yes | 1 |
| `buff_all` | Every stack of yours | One cast reaches every stack of yours. | yes | 3 |
| `momentum_ramp` | Building momentum | Gains momentum with each blow it lands. | yes | 1 |
| `no_strike_back` | Unanswered | Its next blow cannot be struck back. | yes | 1 |
| `pierce` | Ignore defense | A blow that ignores the target's defense. | yes | 1 |
| `staggered_self` | Spent | The boosted stack is Staggered afterwards. | yes | 1 |
| `stationary_attack` | Stand fast | More attack when it attacks without moving first. | yes | 1 |

### Damage

| Id | Name | What it does | New | Spells |
|---|---|---|---|---|
| `battle_aura` | Battle-long effect | Works every round until the battle ends. | yes | 2 |
| `bonus_blinded` | Against the Blinded | Hits harder on a Blinded stack. | yes | 1 |
| `bonus_rooted` | Against the Rooted | Hits harder on a Rooted stack. | yes | 1 |
| `chain` | Jumping bolt | Jumps from the target to further enemy stacks, weaker each jump. | yes | 1 |
| `damage` | Damage | Takes health from one stack. | today | 8 |
| `damage_all` | Every enemy stack | One cast reaches every enemy stack. | yes | 1 |
| `damage_around` | Around your stack | Hits every enemy stack standing next to one of yours. | yes | 1 |
| `dot_all` | Sickness on all | Every enemy stack loses health now and for some turns after. | yes | 1 |
| `drain` | Drain | A stack of yours heals from the damage dealt. | yes | 2 |
| `heat` | Heat | Up to 3 Heat sit on a stack for the battle; when it reaches 3 it bursts: the stack takes {25+12E} at once and its Heat clears. A burst is damage, not a kill. | yes | 3 |
| `heat_burst` | Burst Heat | Sets off a stack's Heat now. | yes | 1 |
| `line` | Beam | Hits every enemy stack on a straight line through the target. | yes | 1 |
| `percent_all` | A share of each stack | Takes a share of the creatures of every enemy stack, whatever its size. | yes | 1 |
| `radius2` | Blast | Hits every enemy stack within 2 hexes of the target as well. | yes | 1 |
| `random_hits` | Random strikes | Several small hits on random enemy stacks. | yes | 1 |
| `sacrifice` | Sacrifice | Your stack pays health to hurt an enemy more. | yes | 1 |
| `splash_friendly` | Wild splash | Hits the stacks around the target too, your own included. | yes | 1 |

### Healing

| Id | Name | What it does | New | Spells |
|---|---|---|---|---|
| `cleanse` | Cleanse | Removes harmful statuses and spell effects. | today | 1 |
| `cleanse_one` | Remove one status | Removes one harmful status. | yes | 2 |
| `death_save` | Seed of return | Regrows instead of being destroyed, once. | yes | 1 |
| `deathless` | Last breath | Cannot lose its last creature for a while. | yes | 1 |
| `graft` | Graft | Two of your stacks split the damage either takes. | yes | 1 |
| `heal` | Healing | Restores health, wounded creature first; on its own it brings no creature back. | today | 7 |
| `heal_all` | Heal every stack | Every stack of yours heals at once. | yes | 3 |
| `heal_block` | Sealed wound | No other healing works on the stack for a while. | yes | 1 |
| `heal_splash` | Heal neighbours | Your stacks next to the target heal too. | yes | 1 |
| `lifesteal` | Lifesteal | Heals from the damage its own blows deal. | yes | 1 |
| `mass_revive` | Return of the destroyed | Destroyed stacks of yours come back. | yes | 1 |
| `raise` | Raise | Brings back creatures that fell in this battle. | yes | 4 |
| `regrowth` | Regrowth | Heals at the start of each of its turns for a while. | yes | 2 |
| `regrowth_all` | Regrowth, every stack | Every stack of yours regrows at once. | yes | 1 |
| `rewind` | Rewind | A stack goes back to how it stood at the start of an earlier round. | yes | 1 |
| `transfer` | Transfer | Moves health from one of your stacks to another. | yes | 1 |
| `triage` | Watchful heal | Each round the most wounded stack heals by itself. | yes | 1 |

### Map

| Id | Name | What it does | New | Spells |
|---|---|---|---|---|
| `map_block` | Firebreak | Closes a tile to every army for a while. | yes | 1 |
| `map_ferry` | Ferry | Crosses water without a boat. | yes | 1 |
| `map_flare` | Flare | Scouts a distant area at once. | yes | 1 |
| `map_forest_ways` | Forest ways | Forest, rough and hills cost like grass. | yes | 1 |
| `map_jump` | Mist jump | Jumps the army a few tiles, past guards. | yes | 1 |
| `map_jump_forest` | Rootway | Steps to a forest tile at a distance. | yes | 1 |
| `map_lens` | Lens | Scouts a wide area around the hero at once, underground too. | yes | 1 |
| `map_mine` | Harvest | A mine yields double for a while. | yes | 1 |
| `map_mire_ways` | Mire ways | Swamp, mire and coast cost like grass. | yes | 1 |
| `map_move` | More movement | Extra tiles of movement today. | today | 1 |
| `map_road` | Fast roads | Roads cost less movement. | yes | 1 |
| `map_scout` | Read garrisons | Shows the garrisons of the towns nearby that are not yours. | yes | 1 |
| `map_sight` | Farther sight | The hero sees farther today; what it sees stays scouted. | today | 1 |
| `map_slow_zone` | Scorched ground | Enemy armies pay double movement in an area. | yes | 1 |
| `map_town` | Relay | Jumps the army to one of your towns. | yes | 1 |
| `map_watch` | Wardwood | A lasting tree that stops enemy armies coming near it and slows their next day. | yes | 1 |

### Protection

| Id | Name | What it does | New | Spells |
|---|---|---|---|---|
| `absorb` | Absorb one | The next blow or spell that would hurt it does nothing. | yes | 1 |
| `buff_splash` | Neighbours too | The effect also lands on your stacks next to the target. | yes | 2 |
| `damage_cap` | Tempered | No single blow or spell takes more than a quarter of the stack's health. | yes | 1 |
| `decoy` | Decoy | A copy that draws attacks and vanishes when hit. | yes | 1 |
| `dome` | Dome | Stacks inside an area cannot be hurt by shots or spells from outside it. | yes | 1 |
| `half_ranged` | Ironbark | Shots and spells do half damage to it. | yes | 1 |
| `invulnerable` | Sanctuary | Cannot be hurt for a while, and cannot attack meanwhile. | yes | 1 |
| `loss_return` | Shadow ranks | Part of the creatures it loses come back at the end of the round. | yes | 1 |
| `plate` | Plate | Extra health that takes damage before the stack does, until broken. | yes | 2 |
| `reflect` | Reflect | The next harmful spell on it bounces to an enemy stack. | yes | 1 |
| `shot_shield` | Shrouded | Shots cannot target it. | yes | 1 |
| `spell_shield` | Spell shield | Enemy spells cannot target it. | yes | 1 |
| `status_immunity` | Status immunity | Cannot be given some statuses for a while. | yes | 3 |
| `thorns` | Thorns | Melee attackers take damage when they strike it. | yes | 1 |
| `tradeoff` | Heavy | Gives defense but costs speed. | yes | 1 |

### Stats

| Id | Name | What it does | New | Spells |
|---|---|---|---|---|
| `buff_attack` | Attack up | More attack for some turns. | today | 7 |
| `buff_cohesion` | Cohesion up | More cohesion: at 8 or more a stack hits 5% harder. | today | 1 |
| `buff_defense` | Defense up | More defense for some turns. | today | 4 |
| `buff_speed` | Speed up | Walks more hexes for some turns. | today | 2 |

### Statuses

| Id | Name | What it does | New | Spells |
|---|---|---|---|---|
| `blinded` | Blinded | Cannot shoot; its blows do 30% less. | yes | 1 |
| `burning` | Burning | Takes damage at the end of each of its turns for a while. | yes | 1 |
| `charm` | Puppet | An enemy stack makes one attack for you. | yes | 1 |
| `cohesion_down` | Cohesion down | Loses cohesion: at 3 or less a stack hits 10% softer and takes 8% more. | yes | 2 |
| `confusion` | Confused | Its next blow lands on a random stack next to it, its own side included. | yes | 1 |
| `curse` | Cursed | Takes damage at the end of its turns; if it dies cursed, the curse jumps to the nearest enemy stack. | yes | 1 |
| `defense_melt` | Branded | Loses defense each time it is hit. | yes | 1 |
| `dispel` | Unweave | Removes the helpful spell effects on an enemy stack. | yes | 1 |
| `doom` | Doomed | A large hit lands a set number of its turns later. | yes | 1 |
| `doom_half` | Death's mark | Loses a share of its creatures a set number of turns later unless the effect is removed. | yes | 1 |
| `fear` | Afraid | Will not move toward your stacks on its next turn. | yes | 1 |
| `fear_all` | Afraid, every stack | Every enemy stack is Afraid at once. | yes | 1 |
| `flee` | Fleeing | Runs from your stacks on its next turn and cannot strike back until then. | yes | 2 |
| `harried` | Harried | Loses cohesion each round and when hit; attackers gain momentum on it. | today | 1 |
| `heal_inversion` | Blighted | Cannot be healed or raised; healing hurts it instead. | yes | 1 |
| `mark` | Marked | Your stacks deal more damage to it. | yes | 1 |
| `on_hit_burning` | Burning blows | A stack's blows set what they hit Burning. | yes | 2 |
| `poison` | Poisoned | Takes damage at the end of its turns, and healing on it is halved. | yes | 1 |
| `rooted` | Rooted | Cannot move; −defense; can still strike what stands next to it and shoot. | today | 3 |
| `rooted_all` | Rooted, every stack | Roots every enemy stack. | yes | 1 |
| `rooted_area` | Rooted, an area | Roots every enemy stack in a small area. | yes | 1 |
| `silence` | Censured | Its abilities stop working and its hero's spells cannot help it. | yes | 1 |
| `sleep` | Asleep | Skips its next turn unless something hits it first. | yes | 1 |
| `slow` | Slowed | Walks fewer hexes. | yes | 2 |
| `staggered` | Staggered | Cannot strike back; −initiative. | today | 1 |
| `stun` | Stunned | Skips its next turn. | yes | 2 |
| `taunt` | Goaded | Must attack the stack you name on its next turn. | yes | 1 |
| `tightening` | Tightening roots | Rooted grows worse each turn it lasts. | yes | 1 |

### Summons

| Id | Name | What it does | New | Spells |
|---|---|---|---|---|
| `clone` | Copy | A copy of one of your stacks with part of its creatures. | yes | 1 |
| `risen` | The Risen | A destroyed stack, either side's, rises to fight for you for some rounds. | yes | 1 |
| `risen_all` | Risen host | Every destroyed stack rises at once. | yes | 1 |
| `risen_aura` | Hollow crown | Every enemy stack destroyed from now on rises for you. | yes | 1 |
| `summon` | Construct | A summoned stack built on your side; like every summon, it stays a number of rounds set by spell power. | yes | 1 |
| `summon_big` | Elder | A large two-hex summoned stack. | yes | 1 |
| `summon_fliers` | Wraiths | Fast flying summoned stacks. | yes | 1 |
| `summon_static` | Sentinel | A stack that cannot move but strikes what comes next to it. | yes | 1 |
| `summon_timed` | Treants | Slow, sturdy summoned stacks that rise next to yours. | yes | 1 |
| `temp_creatures` | Budding | Adds creatures to a stack for this battle only. | yes | 1 |

### Turn order

| Id | Name | What it does | New | Spells |
|---|---|---|---|---|
| `act_first` | All act first | Your stacks act before every enemy stack next round. | yes | 2 |
| `act_next` | Act next | Moves a stack to the front of the order. | yes | 1 |
| `delay` | Act last | Pushes a stack to the end of the round's order. | yes | 1 |
| `double_strike` | Strike twice | Two blows in one turn. | yes | 1 |
| `extra_turn` | Extra turn | A stack takes another full turn. | yes | 1 |
| `free_volley` | Volley | Your shooters fire now without spending their turns. | yes | 1 |
| `recast` | Echo | Casts the hero's last spell again, stronger. | yes | 1 |
