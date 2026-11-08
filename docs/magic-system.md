# Magic system

The owner reworked magic on 2026-11-06 and 2026-11-07, settling it draft by draft on a local plan page (`.artifacts/magic_atlas/magic_plan.html`, built by `.artifacts/magic_atlas/build/plan.py`; magic pages stay local views, never published). This doc holds the rules and the build order. The 139 spells and 138 mechanics are in `docs/magic-system-spells.md`. Slices 1 to 3 of the build order are in the game, on today's spells, and the new spells enter content unreleased slice by slice. Today's spells stay the live ones, described in `docs/magic-system-expansion-foundation.md` and `docs/battle-spell-effects.md`, which this doc replaces at the switch (`magic-switch-20261107`).

## Why

The owner found seven schools too many and today's spells bad: their review of 2026-10-09 said buffs were confusing and most spells "do the same thing". None of today's 119 spells is reused, by name, id or effect.

## The shape

- **Tiers.** Tier 1 holds 15 basic spells with no school and no mastery; every hero can learn them, and they grow with spell power only. The four schools start at tier 2 with 9 guild spells each, then 9 at tier 3, 6 at tier 4 and 3 at tier 5, so the top tier has the fewest. Each school also has one scroll-only spell at each of tiers 2 to 5. In all: 15 basic, 108 school guild spells and 16 scroll-only spells, 139.
- **Schools.** Four schools are shared by all factions. Each has a method that shows in every kind of spell it has:

| School | Words | Method | Best at | Weak |
|---|---|---|---|---|
| Furnace | fire, forge, pressure | Power now, paid for later: Heat that builds until it bursts, forged plates and brass constructs, strength with a price. | damage, boost, ward | Heals badly (its heals carry a cost) and controls only by force. |
| Root | growth, soil, grafts | Patience: what it binds holds tighter every turn, what it plants grows, what it grafts shares one life. | control, healing, field | Slow: little speed or turn order; its damage leans on stacks it has already bound. |
| Beacon | light, signal, crystal | Coordination: it decides who acts when, marks targets, bends beams through crystal, reflects and purifies. | boost, healing, ward | No summons and little lasting damage; it wins by timing, not attrition. |
| Veil | fog, mire, the dead | Attrition and deceit: it drains, curses and frightens, hides stacks in murk, sinks them in mire and raises the fallen. | damage, control, field | Protects by hiding and dodging, never by armour; heals only by taking. |

- **Kinds.** Seven: damage, control, boost, ward, healing, field (walls, hazards, fog, crystals, summoned and moved stacks) and map. Every school has spells of each. Each kind but map is the flavour of two schools; a flavour spell does about a third more for the same mana, and a school has 5 or 6 spells of each flavour kind and 2 or 3 of the others.
- **One job low, more at the top.** A basic spell does one plain thing. From tier 2 a spell does its one thing in its school's way; from tier 3 most spells add a second effect; the top tier reaches every stack or the whole battle.
- **The hero casts.** A spell is the hero's, not the acting stack's: a helpful spell can pick any of the hero's stacks and a harmful one any enemy stack; some pick hexes, a destroyed stack or the whole battle. Area spells can still hit the caster's own stacks (Cinder Spray and Fog Mind keep that price).

## Spell power and resistance

- Every spell grows with its caster's spell power: damage or healing, turns, hexes, shares or counts. The notation (`{a+bP}`, `{a+bE}`, `{a+P/d}`) is explained at the top of `docs/magic-system-spells.md`; damage and healing follow the bands there.
- A lasting effect gets one more turn per 4 spell power, with no limit (today's limit of 3 more turns goes). A summoned stack stays a number of rounds set the same way.
- The enemy hero's Knowledge is the resistance: against an enemy hero's stacks a spell's harmful numbers and turns work at the caster's spell power less all of that hero's Knowledge, never below 0. At power 8 against Knowledge 6 it works at power 2; against Knowledge as high as the power, only the flat part and the base turns are left. A neutral army's leader and a heroless town's captain are not heroes, so there only the creatures resist. Knowledge no longer gives a percentage of spell or control resistance; items and specialties keep theirs.
- Creatures keep their own resistances on top of Knowledge. General spell and control resistance stay; resistance to Furnace, Root, Beacon and Veil stays as it is; Lens resistance becomes Beacon (30 creatures), Mire becomes Veil (30) and the one Old Measure resistance (Galehorn Striders) becomes Beacon. No creature has both of a merged pair. Basic spells meet only general spell resistance.

## Masteries

Four school masteries replace the seven; basic spells have none. A mastery strengthens its school's spells as today: rank 1 +8% damage and healing; rank 2 +16% and 1 mana less; rank 3 +24%, 1 mana less and one more turn; rank 4 +32%, 2 mana less and one more turn. From mastery 2 or 3, 29 spells also reach the stacks next to the target or every stack, as their Mastery column says.

## Guilds and learning

When the map is made, every town draws its own guild: at each level, a third of that tier's guild spells. Two towns of one faction get different draws, and a captured town keeps its draw. It is a plain weighted draw, with no guarantee at any level.

| Guild level | Tier | Guild spells | Scroll-only, never drawn | Drawn per town |
|---|---|---|---|---|
| 1 | 1 | 15 basic | 0 | 5 |
| 2 | 2 | 36, 9 per school | 4 | 12 |
| 3 | 3 | 36, 9 per school | 4 | 12 |
| 4 | 4 | 24, 6 per school | 4 | 8 |
| 5 | 5 | 12, 3 per school | 4 | 4 |

A full guild offers 41 of the 123 guild spells. Each spell of the town faction's preferred school (`preferred_spell_school_id` in `factions.json`) is twice as likely to be drawn as any other. A town keeps its draw (`guild_spell_ids` in its state) through captures and saves; a save from before the draws draws on load, from the game's seed and the town's placement like a new game. Until the switch the draw runs on today's 119 spells and each faction's school today (Lens for Sunvault, Mire for Mireclaw), with the third rounded to the nearest spell: 12, 7, 9, 6 and 5 of 36, 22, 26, 19 and 16. The exact odds of a draw without replacement, as spells of one school per town:

| Weight | Level 2 (12 drawn) | Level 3 (12) | Level 4 (8) | Level 5 (4) | Levels 2 to 5 (36) | Level 5 has none of it |
|---|---|---|---|---|---|---|
| ×1, no preference | 3.0 | 3.0 | 2.0 | 1.0 | 9.0 | 25% |
| ×2, the owner's answer | 4.4 | 4.4 | 2.9 | 1.5 | 13.2 | 9% |

Learning stays free: a hero in an own town learns everything its guild offers up to the hero's level, and shrines and other map sites teach guild spells of their tier.

## Scrolls

- The 16 scroll-only spells never appear in a guild. About 1 scroll in 3 found on the map holds one.
- A scroll teaches nothing. A hero casts a scroll's spell, for mana as usual, only while the scroll is worn in one of its two trinket slots, like a charm, so a hero wears at most two, in place of charms. The scroll is not used up and can be handed to another hero like any item.
- Generated maps keep placing scrolls by tier as they do today.
- Each spell has one scroll item, which the content store adds to `artifacts.json` as it reads the file: `artifact_scroll_<spell id without spell_>`, a trinket of class `spell_scroll` naming its `spell_id`, with no bonus. Rarity follows the tier: 1 common, 2 uncommon, 3 rare, 4 and 5 epic. It shows the spell's icon.
- A scroll site (`site_spell_scroll`, `gives_spell_scrolls`) hands its scroll to the hero, worn at once when a trinket slot is free, else carried. A hero holds one copy of each scroll; a second copy of one it holds is lost. Shrines and Pandora-style sites still teach, and only guild spells.
- A spell marked `scroll_only` in `spells.json` never enters a guild draw, a shrine or a Pandora's lesson. Where a tier has both kinds, a map scroll holds a scroll-only spell 1 time in 3.
- Scrolls are found only as scroll sites: placed artifacts, merchants, the field market and the collection count leave scroll items out, so generated maps place the same artifacts as before.
- The spellbook lists a worn scroll's spell after the learned ones, in battle, on the map and on the hero sheet. Two heroes meeting teach each other only learned spells.
- Computer players walk to scrolls whose spell they lack, as they valued scroll sites before, and wear a scroll when it beats a charm: `loadout_scroll_spell_tier_value` (8 per tier of a spell they have not learned) in `content/ai_hero_weights.json`. Their battle and strength estimates count lent spells.

## Mana and casting limits

- One hero spell per side per round in battle, as a free action; one map spell per hero per day.
- The maximum stays 8 + 4 × Knowledge. A hero gets back a fifth of its maximum each day (rounded up) instead of all of it, and all of it on a day that starts in an own town with a guild. The Ley Well, the Moonspring and the Calibration Court work as today.

## The new spells in content

`magic-basic-tier-20261107` put the 12 basic battle spells in `spells.json` with school `basic` and `"unreleased": true`. Far Sight, Stride and Read Tracks come with the map spells.

- **Unreleased.** The content check, `battle_sim_cli` and focused checks cast them. Guild draws, hero and commander starts, rewards, Pandoras, shrines, scroll items and the battle arena's guild pool leave them out (`spell_rules::spell_is_released`).
- **Any stack.** A helpful spell picks any of the hero's stacks (`ally_selected`) and a harmful one any enemy stack, as today's support spells already could. The computer weighs every stack.
- **Shift** (`move_ally`). The player picks the stack, then one of the lit empty hexes it can walk to in {2+P/3} steps, around walls and stacks like a move. The stack keeps its turn. A Rooted stack cannot be shifted, and a cast without a hex in reach costs nothing. Esc puts the spell away.
- **Daze** (`status_dazed`). The stack acts after every other stack, waiting ones included, for {1+E/4} rounds. **Hobble** puts Slowed (`status_slowed`, −2 speed) and **Snare** today's Rooted.
- **Unweave** (`dispel_enemy`) takes {1+E/3} of the target's helpful spell effects, the newest first; a stack with none cannot be chosen. **Cleanse** (`cleanse_ally` with a count) takes {1+P/3}, the newest first, of these: the statuses Harried, Staggered, Rooted, Slowed and Dazed, effects that harmful spells put there, and other effects that only lower stats.
- **Texts.** The spellbook shows each number at the caster's spell power; a cast's summary on a chosen enemy shows it at E, the power less that hero's Knowledge.
- **Art and sound.** The icons are stand-ins borrowed from today's spells. Slowed and Dazed have no badge, and the spells no battle effects or sounds, until `magic-art-audio-20261107`.
- **Computer players.** Shift moves an engaged shooter away from the enemy, or the acting melee stack into reach of a strike. Unweave scores 3 per effect it removes, and Slowed and Dazed count as control: Slowed 1.5 on a melee stack and 0.3 on a shooter, Dazed 1.0. These values are first choices, not measured.

`magic-tier2-spells-20261107` has put the 36 tier-2 battle spells in `spells.json`, unreleased the same way, with the mechanics `docs/magic-system-spells.md` gives them. Forge Road, Green Path, Flare and Mire Stride come with the map spells.

- **Effects that work.** A helpful effect can carry a mechanic beside its stat changes (`ally_effect`), and a harmful one a status or a mechanic; the numbers are fixed at the cast. The stack's details list each one, a harmful one as harmful.
- **Mastery** (`mastery_reach`). From the rank the spell names, it also reaches the stacks of the target's side next to it, or every stack of that side. Each stack it reaches resists a harmful spell on its own draw. Stacks deploy apart, so "next to it" counts once they close up.
- **Shapes.** Cinder Spray also burns every stack next to the target, own stacks too, at the target's E. Dawn Lance hits the stacks of the target's side on its row. Spark Swarm's first spark hits the chosen stack and the others land at random on its side. Morning Light heals every stack of the side. Leech's drinker is the stack the second pick names, or else the caster's most wounded stack.
- **Two stacks.** After the first stack the battle screen lights the stacks that can be the second; a cast without one asks for it and spends nothing. Graft joins two of your stacks and Blood Tithe takes health from the second into the first. Signal Swap trades two of yours; Changeling Swap trades the enemy stack with one of yours. Graft's partner takes the smaller half, a new graft on either stack ends its old one, and a fallen partner ends it. Blood Tithe leaves the giver at least 1 health and cannot reach a sealed wound. A swap needs both bodies to fit in the other's place and no Rooted stack; Changeling Swap draws no resistance.
- **Hexes.** Flame Furrow, Bramble Patch, Crystal Pillar, Murk and Thorn Seed take a hex. The battle screen lights the hexes that can take the spell and outlines the ones a pick covers; a cast without a hex asks for one and spends nothing. "In a row" is the picked hex and the hexes above and below it. The ground keeps the numbers of its cast, its damage at E against the other side's hero, and a newer ground of the same kind takes the older one's hexes. Ground draws no resistance; immunity to Rooted still holds.
  - Fire burns a stack once a turn, after its action: when its walk crossed burning ground or ended in it, or when it ends its turn standing in it. A walk takes the way with the fewest burning hexes its steps allow. The caster's own stacks burn too.
  - A walk that enters brambles ends there and pays at the end of the turn.
  - A pillar blocks like an obstacle and gives its side's stacks next to it its defense once, however many pillars stand there.
  - Murk refuses shots into and out of it, on any hexes.
  - A seed goes off under the first stack of the other side that ends a walk next to it, and both sides see it. Shift, knockback and swaps are not walks.
  - The board draws ground in plain tints until `magic-art-audio-20261107`.
- **Prism Ward** turns the next damage or control spell cast at its stack onto a random stack of the caster's side, then breaks. Unweave can take it off.
- **Heat** (Ember Lash). At 3 Heat the stack burns for {25+12E} and its Heat starts over.
- **Rules read one way where the list leaves room.** Strike-backs count as blows for lifesteal and momentum. A sealed wound (Hot Iron) also keeps town wards from healing the stack. A confused stack's blows land on a stack next to it, its shots on the target or a stack next to the target. A blinded stack cannot shoot and its blows do 30% less.
- **Computer players.** First values, not measured. A stack already under one of the hero's effects is not given it again. Prism Ward is worth a cast only against a hero who knows a spell, and the computer does not aim damage or control at a warded stack. Asleep counts as control worth 2.5, Blinded 2.5 on a shooter and 1.0 otherwise, Afraid 1.5 on a melee stack and 0.3 on a shooter, Confused 1.5, Marked and Cursed 1.0; each further stack a mastery reaches adds 1.5. It does not hold back from striking a sleeping stack. Graft joins a stack in a fight to a bigger free one; Blood Tithe moves health from a lower tier into a higher one; Signal Swap frees an engaged shooter or pulls a badly wounded stack out for a fresh one; Changeling Swap brings a free enemy shooter among its own stacks. A hex spell goes on the hex worth most: fire and brambles by the stacks that walk through them or fight beside them, murk by the shooters it silences, a pillar by the stacks in a fight beside it, a seed beside a stack an enemy walks to. Its own stacks do not yet steer around ground, so the hexes on their way count as walked through.

`magic-tier3-spells-20261107` puts the 36 tier-3 battle spells in `spells.json`, unreleased the same way. All 36 are in: Molten Edge, Cinderfall, Flashpoint, Annealing, Heavy Plating, Tempering, Smelter's Bargain, Budding, Earthsplit, Bloomburst, Seed of Return, Bark Ring, Blight, Volley Signal, Prism Bolt, Rekindle, Watchful Light, Glass Aegis, Steadfast Halo, Hollowing, Tolling Doom, Last Breath, Goad, Uproot, Living Wall, Boundary Line, Prism Array, Fogwalk, Night Terror, Bog Pool, Brass Sentinel, Wake the Grove, Raise the Fallen, Decoy, Hour Ledger and Puppet Strings. Firebreak, Rootway, Relay and Ferry Call come with the map spells.

- **Burning** (`status_burning`). The stack takes its damage at the end of each of its turns, and a newer Burning replaces the older one. Molten Edge's blows, strike-backs and shots set any stack they hit Burning for 2 turns at {8+4E}. Cinderfall leaves Burning at {10+5E} on the target and on the stacks of its side next to it, each on its own resistance draw.
- **Flashpoint** deals its damage times the target's Heat and spends the Heat; a stack without Heat takes it once and gains 1. Its mastery bursts only the other enemy stacks that carry Heat.
- **Stats.** Heavy Plating's defense grows with power but its speed cost does not, and it lasts a fixed 3 turns. Tempering caps every kind of hit at a quarter of the stack's health when hit. Bark Ring and Steadfast Halo also reach the caster's stacks next to the target, and Bloomburst heals them for half.
- **Smelter's Bargain** takes the enemy stack first and the payer second. The payer loses 15% of its health, never its last point. The cost is not damage, so no cap, plate or graft touches it. The enemy takes {150+10E}% of the cost, after its resistance.
- **Budding** adds budded creatures for this battle. Budded health is lost first and withers when the battle ends, so survivors are counted without it. Blight and a sealed wound do not stop it.
- **Earthsplit** knocks the target one hex toward its own edge, in its row, when its body fits there. A Rooted stack is not moved, and a knockback is not a walk.
- **Seed of Return** brings a fallen stack back once with {15+2P}% of its starting count, at least 1. **Last Breath** holds the stack at 1 health while it lasts, then heals {20+4P} at the end of its last turn. Last Breath goes before a seed.
- **Blight** (`status_blighted`) lasts the battle. Healing aimed at the stack harms it by {100+10E}% of the healing asked, and so does raising the fallen. A sealed wound keeps both healing and harm out. Blood Tithe moves nothing into it, Watchful Light passes it by, and Cleanse takes it off.
- **Volley Signal.** Every stack of the caster's that can shoot the target fires at once, for {40+4P}% of the middle of its damage roll, with no draw. Each shot uses a shot and brings its blow's effects, but takes no shooter's turn. A cast with no shooter able to fire is refused.
- **Prism Bolt** jumps from the target to the nearest enemy stack it has not struck, for 70% and then 50%, and from mastery 3 once more for 30%. Jumps pass over Glass Aegis stacks.
- **Rekindle** raises the fallen, up to the starting count.
- **Watchful Light** (target mode `battle`, cast at once) heals the caster's most wounded stack by {24+5P} at the start of each of the next {2+P/4} rounds, within its surviving creatures like any heal. A newer cast replaces the side's older one.
- **Glass Aegis** keeps enemy spells from being aimed at the stack. Splash, beams and mastery reach still land; jumps and Prism Ward pass it by.
- **Steadfast Halo** keeps off Harried, Staggered and Rooted and stops cohesion from dropping. A status's own cohesion change, such as Afraid's, still applies.
- **Hollowing** needs an enemy stack next to the caster's stack. Each enemy stack next to it takes the damage at its own E, after resistance, and the stack heals the total dealt; the battle log shows the heal before the hits.
- **Tolling Doom** (`status_doomed`) fixes its damage at the cast, after resistance and with no draw, and lands it at the end of the stack's second turn. Prism Ward can turn it, and Cleanse takes it off.
- **Goad** (`status_goaded`) takes the enemy stack first and a stack of the caster's second. While the goaded stack can reach the named one (shoot it, strike it where it stands, or walk beside it), its only orders are a strike or shot at it: waiting, defending, advancing and other targets are refused, and a computer's stack attacks it. Out of reach it is free. Hero casts, retreat and surrender stay open.
- **Uproot** drags the stack up to {2+E/3} hexes of its own walk, Rooted or not, to a hex the caster picks. The caster's Boundary Line closes that way like a walk, but the drag is not a walk: no ground or seed goes off. The drag always lands; only its Staggered can be resisted or kept off.
- **Living Wall** (`wall`) blocks its hexes for both sides like an obstacle. A shot whose straight line from the shooter's hex to the target's crosses it does half damage, either side's.
- **Boundary Line** (`barrier`) closes its hexes to the other side's walks only; the caster's stacks walk over it, and Fogwalk does not pass it.
- **Prism Array** (`prism`) blocks its hex. After each spell of its side with the damage role, Prism Array itself left out, each of the side's crystals fires {15+5E} at the nearest enemy stack not under Glass Aegis, by distance and then stack order. Murk does not stop it.
- **Fogwalk.** While it lasts the stack walks through stacks and obstacles and ends where its body fits. Its next melee blow is not struck back, and that blow spends it.
- **Night Terror** (`status_fleeing`). At the start of its next turn the stack walks to the hex farthest from the other side's stacks, and that takes its turn; with no farther hex it cowers and loses the turn. A Fleeing stack does not strike back.
- **Bog Pool** (`mire`) turns up to {2+P/4} hexes, under stacks too but not obstacles, to mire for the battle. A stack in mire has half its movement points, at least 1; a defend order still ends its turn but braces nothing.
- **Lines and pools.** A line runs down the picked hex's column; a pool grows from the picked hex to the nearest hexes.
- **Conjured stacks.** Brass Sentinel, Wake the Grove, Raise the Fallen and Decoy put a stack on the field for some rounds. A conjured stack holds the field for neither side: a side whose own stacks have all fallen has lost. When the battle ends conjured stacks leave no losses, survivors, recovery or corpse.
- **Summons.** Brass Sentinel and Wake the Grove take an empty hex next to one of the caster's stacks where the body fits. They act from the next round for their rounds, with their unit's attack, defense and damage. Brass Sentinel has Mossglass Sentinels' numbers, cannot move and counts as Rooted; on its turn it strikes what stands next to it, and it strikes back. Treants have Rootvault Barkhulks' numbers and walk 2.
- **Raise the Fallen** takes the hex of a stack destroyed in this battle, either side's, once per stack; a conjured stack is never raised. The Risen are that stack's unit, at most its starting creatures, and act from the next round.
- **Decoy** copies the stack's unit, creatures, health and name onto the empty hex next to it nearest the closest enemy, from the cast to the end of its last round. It takes no turn. A hit, or a harmful spell the other side aims at it, makes it vanish, and that spell is spent. Its own side's spells cannot be aimed at it, and it is never a second stack.
- **Hour Ledger.** While a commander in the battle knows it, each stack's creatures, health and hex are written down at the start of every round. The cast picks the hex the stack stood on at the start of a round within reach; this round counts as none back, and on a hex two rounds share the one with more health wins. Budded creatures come back too. It is not a heal, so Blight and a sealed wound do not touch it.
- **Puppet Strings** takes the enemy stack first and a stack of its own side second, one it can shoot (with a shot left and none of the caster's stacks next to it), strike where it stands, or walk beside by its own walk. A walker takes the fewest steps; the approach is not a walk, so no ground or seed goes off. The blow is the middle of its damage roll at {50+10E}%, it is not struck back, and the puppet keeps its turn.
- **Texts and art.** Each new kind has its spellbook line and battle-screen sentence. The icons are stand-ins until `magic-art-audio-20261107`.
- **Computer players.** First values, not measured.
  - Tolling Doom scores as the same damage now, less 1. A doomed stack is not doomed again, and a blighted one is not healed.
  - Volley Signal scores by the shots' share of the target plus a shooter's attack. Budding scores by the creatures it adds and the stack's blows. Hollowing scores by each enemy's share and the useful heal.
  - Watchful Light scores by its rounds and the wounded or fighting stacks, and not while the side already keeps watch.
  - Smelter's Bargain weighs the share taken against 0.6 times the share paid, plus 0.5 when the enemy's tier is at least the payer's.
  - Molten Edge suits a stack that strikes. Tempering, Seed of Return and Last Breath suit a stack under attack, more as it weakens. Glass Aegis is worth a cast only against a hero who knows a spell. Steadfast Halo suits a stack in a fight. Burning and Blighted count 1.0 as statuses.
  - Goad draws an enemy stack that can reach it onto a melee stack that strikes back, more when that stack is the sturdier; the +2 attack counts against. Uproot drags a free shooter in beside a melee stack of the computer's, or a melee stack out of reach or off a shooter it holds.
  - A summon scores its blows on the nearest enemy over up to three rounds, at three quarters for each later round, less for a sentinel no enemy can reach soon, and up to 2 for how much of that enemy's health it stands for. The Risen score the same way.
  - Decoy suits a stack an enemy can strike this turn, by the biggest blow it would take; a stack with a decoy standing gets no second one.
  - Hour Ledger scores by the health it brings back and how wounded the stack is. Puppet Strings scores the puppet's blow like an attack, by the share of the victim it deals.
  - Living Wall scores 1.5 for each shooter's line it crosses, half a shooter silenced by murk, and loses as much for its own side's lines. It and Boundary Line score 2.5 for each walk they stop from striking this turn and less for a longer way round; the wall counts both sides' walks.
  - Prism Array is worth its cast when the firings in its later rounds, as far as the hero's mana pays for damage spells, out-damage the best damage spell it puts off, on that spell's own score. At spell power 8 Ember Lash still wins; from about 12 the crystal does.
  - Fogwalk suits a melee stack out of the fight or with a strike to make. Fleeing counts 2.5 as control. Bog Pool scores the enemy stacks it slows, most a melee stack that must still walk.

`magic-tier45-spells-20261107` puts the 39 tier-4 and tier-5 battle spells in `spells.json`, unreleased the same way: Molten Brand, Kiln Burst, Crucible Ward, Spore Cloud, Thicket Snare, Sapflood, Ironbark, Censure, Searing Ray, Sanctuary, Grave Edge, Stupor, Death's Door, Full Steam, Molten Deluge, Iron Oath, Second Sun, Grasp of the Deep, Spring Eternal, Lantern Vigil, Daybreak Charge, Dawn of Return, Eternal Noon, Fever Wind, Long Night, Black Tide, Redline, Clarion Call, Echo, Shadow Ranks, Elder Grove, Glass Dome, Green Return, Foundry Golem, Clockwork Twin, Waking Forest, Wraith Host, Drowned Host and Hollow Crown. Scorched Earth, Harvest Bloom, Wardwood, Watchtower Lens and Mist Jump come with the map spells.

- **A hurt** is any damage a stack takes: a blow, shot, spell or end-of-turn damage, as for Tempering and Decoy. Each hurt meets, in order, a decoy, a graft, Sanctuary or Crucible Ward, a plate, the town's absorb, then the caps and Last Breath.
- **Molten Brand** (`status_branded`) lasts the battle. Each hurt that takes health and leaves the stack standing melts 1 more point of its defense, down to −{4+E/2}.
- **Kiln Burst** strikes the target, which gains 1 Heat; every other stack of the target's side within 2 hexes takes {28+15E}, each after its own resistance and without Heat.
- **Crucible Ward** takes the next hurt within its turns whole, then gives the stack +4 attack for its next turn.
- **Poison** (`status_poisoned`, Spore Cloud) hurts at the end of each of the stack's turns, a skipped one too, and halves healing on it (rounded down) after Blight's check. Spore Cloud also lands on each enemy stack next to the target, each on its own draw.
- **Thicket Snare** takes any hex; its area is that hex and the six around it. Each enemy stack with a hex in the area is Rooted on its own draw, and no ground stays. A cast that would catch no enemy stack is refused before the mana is spent.
- **Sapflood** heals, raises the fallen with what is left up to the starting count, then gives Regrowth {15+3P} for {1+P/4} turns.
- **Ironbark** halves shots, and halves what a spell's damage keeps after resistance.
- **Censure** (`status_censured`) turns off all the stack's abilities, and its own hero's spells cannot help it: helpful spells, their reach, Watchful Light and the two-stack spells pass it by. The other side's spells still land.
- **Searing Ray** does double damage to a Blinded stack.
- **Sanctuary** lasts {1+P/6} turns. Nothing hurts the stack, and it makes no strike, shot or strike-back; a computer's stack in Sanctuary defends.
- **Grave Edge** gives {1+P/4} blows that ignore the target's defense, its hero's and the defend bonus included. Each attack the stack makes spends one (strikes, strike-backs, shots, volleys and puppet blows), and it lasts until spent.
- **Stupor** (`status_stunned`): the stack loses its next turn, before it could flee; then it is Harried for {1+E/4} turns.
- **Death's Door** (`status_deaths_door`) fixes its share at the cast, {30+4E}% after spell resistance. At the end of the stack's third turn it loses that share of its living creatures, at least 1, as damage, so caps, plates, wards and Sanctuary still count. Cleanse takes it off.
- **Every stack.** The spells on every stack of a side take one stack, and their reach carries them to every other stack of its side, as for Morning Light. Each stack meets the spell at its own resistance and on its own draw; Censured stacks are passed by.
- **Full Steam**: only the first blow each stack lands sets Burning; the +4 attack and +2 speed stay for the turns.
- **Molten Deluge** adds Heat up to 2 on each stack and never more, so it never bursts.
- **Iron Oath**: a spell can now keep off any harmful status, Stunned too, not only the four the units name.
- **Second Sun** lasts the rest of the battle. Its {12+6E} is fixed at the cast, against the other side's Knowledge then; each stack's resistance applies at each burn. It burns as each later round starts, which is the end of the round before.
- **Grasp of the Deep**: a stack already Rooted is Stunned for 1 turn instead, unless it is immune to stuns.
- **Spring Eternal**'s regrowth raises the fallen up to the starting count, as Sapflood's heal does.
- **Daybreak Charge**: every reached stack acts before any enemy stack next round, in initiative order among them.
- **Eternal Noon** keeps its four statuses off from the cast, and puts its side first in each of the {3+P/3} rounds after the cast, in initiative order among its stacks. Dazed stacks still go last, and waiting ones after the rest.
- **Fever** (`status_fevered`, Fever Wind): the {14+7E} now goes through each stack's resistance; the {14+7E} at the end of each of its turns does not, like Burning.
- **Long Night**: Afraid carries −3 cohesion, as Dread's does. The smallest enemy stack (fewest creatures, then least health; decoys aside) is also Fleeing for 1 turn, on its own draw.
- **Black Tide** takes min(creatures − 1, max(1, round(creatures × (10+E)%))) creatures as damage. Resistance and the hero's potency then count, but never past the last creature, and a stack of one is untouched.
- **Redline** counts melee only. The first melee attack its stack makes while the boost holds strikes twice; the second blow comes only while both stacks stand and the target is still in reach, it is not re-aimed by Confusion, and each blow may draw a strike-back as the retaliations allow. After the double blow, or at the end of the boost's turn when it never struck, the boost goes and the stack is Staggered for 2 turns; a stack immune to Stagger is spared that. Cast on the stack whose turn it is, it works this turn and, unused, the next.
- **Clarion Call**'s extra turn comes as its stack's turn ends: right after this one when cast on the stack whose turn it is, else after its next turn. The +attack holds through both turns. The extra turn cannot wait and starts like any turn (a grove heals, regrowth raises); a Stunned turn passes, then the extra turn comes.
- **Shadow Ranks** counts the creatures its stack loses to hurts while warded. That share, rounded half up, comes back as the next round starts, after the battle-wide spells, up to the starting count. It is not a heal, so Poison and heal blocks do not touch it, and a stack destroyed loses its shadows.
- **Green Return** works once a battle for each side and may be cast before anything has fallen. As the next round starts, each fallen stack of its side that was not conjured comes back with max(1, floor(starting creatures × (30+4P)%)) creatures, on its own hex or the nearest one its body fits (none, no return): its effects cleared, its strike-backs reset, its shots as they were.
- **Echo** casts again the side's last spell of the battle that was not an Echo; the hero pays only Echo's 8 mana. The spell resolves with +{1+P/2} power on the stack it named, or, for a spell over the battle or on hexes, with the stack whose turn it is and the same hexes. Echo is refused when nothing has been cast, when the named stack is gone or the spell needed a second pick, and when the spell's own check now refuses. Prisms fire for the echoed spell.
- **Elder Grove**: the best grove under a stack counts; groves do not add up. Its heal is a true heal at the start of each turn of its side's stacks in it: it raises no fallen, and Poison, Blight and heal blocks apply.
- **Glass Dome** shelters the stacks of both sides under it, for {1+P/4} rounds counted as a boost's are, the cast round included. No shot from outside reaches them; damage, doom, sacrifice and volley spells on them are refused, a spell's reach passes them by, and Second Sun and prisms skip them. Melee and control spells are unchanged, statuses keep ticking, and shooters under it shoot out.
- **Conjured stacks of tiers 4 and 5** stand, act and fade as tier 3's do: they act from the next round, Hollow Crown's Risen in the round they rise; they last their rounds, hold the field for neither side and leave nothing behind. The units are stand-ins until their art: Deepforge Vaultwyrms as the Brass Golems, Tidepool Cutters as the Wraiths, Rootcrown Knotstags as the Elder Treant.
- **Foundry Golem** builds its two-hex summon on an empty hex beside one of the caster's stacks, as Wake the Grove's treants stand.
- **Wraith Host** takes any empty hex the side picks. A second stack stands on the empty hex nearest the first, nearest the closest enemy stack among those, and the health is shared out, the first stack the larger half; with no such hex, or health for fewer than two wraiths, the host is one stack. The wraiths walk 8 and fly: their walk passes over stacks and obstacles as Fogwalk's does, never through the other side's Boundary Line.
- **Clockwork Twin** copies a stack of the caster's that was not conjured: a new stack of its unit, without its effects, with {30+4P}% of its living creatures (whole, at least 1), on the hex beside it that Decoy would take.
- **Waking Forest** names no hex. Its treant (walk 3) stands on the empty hex beside one of the caster's stacks nearest the closest enemy stack, the first in board order among equals; with none the cast is refused. Up to 4 trees then grow on the empty hexes beside the treant, nearest the closest enemy stack first, each only where the field still lets a two-hex body cross from side to side. The trees are obstacles for the rest of the battle, drawn with the deadwood art for now.
- **Drowned Host** raises every stack destroyed so far, either side's, that was never conjured or raised: max(1, floor(starting creatures × (25+2P)%)) of its unit, on its own hex or the nearest one its body fits (none, no rise). With nothing to raise the cast is refused.
- **Hollow Crown** lasts the rest of the battle, one to a side; a second cast is refused. Each enemy stack destroyed after the cast, not conjured or raised, rises for the caster as the next round starts with max(1, floor(starting creatures × (20+2P)%)) creatures, placed as Drowned Host's are, for {2+P/4} rounds counted from that round. Enemy stacks fallen before the cast and the caster's own stacks do not rise.
- **Texts and art.** A helpful spell with a mechanic reads like a status under the spell's name, tier-2 and tier-3 ones too: "Ironbark (shots and spells do half damage to it) on Bog Brute for its next 4 turns". A raising heal no longer also says the fallen are not restored. The icons are stand-ins until `magic-art-audio-20261107`.
- **Computer players.** First values, not measured.
  - As control, Molten Brand and Poison count 1, Censure 1.5 on a stack with abilities (else 0.5), and Stun 3.
  - Crucible Ward suits a stack in the fight (2 plus half its health share). Sanctuary suits one in the fight more as it weakens (1 plus 3.5 times its lost share). Ironbark scores 1 plus the enemy's shooters; Grave Edge 1 plus the stack's offense when it strikes.
  - Kiln Burst's blast counts in its reach value. Thicket Snare scores each enemy stack its area catches as the one-stack Rooted spell would, the mana counted once.
  - Death's Door scores as the creatures it takes, dealt now, less 1.5; a stack already at Death's Door is not marked again.
  - A raising heal (Rekindle, Sapflood, Spring Eternal, Dawn of Return) counts the fallen up to the starting count as room to heal.
  - Fever counts 1 as control, as Poison does. Grasp of the Deep scores a Rooted stack as a stun. Full Steam's burn counts half, for its one blow.
  - Daybreak Charge's first place counts 1.5 for a melee stack that must still close in, 1 for one in the fight and 0.8 otherwise. Eternal Noon counts as much for each of its side's stacks, times half its rounds, at most 2.
  - Second Sun counts each enemy stack's burn as a share of its health, for two rounds. The computer does not cast Second Sun again while its own burns, nor Eternal Noon before its last round.
  - Redline counts 1.5 plus 1.5 times the stack's offense for a melee stack that can strike (−1 otherwise), less 0.3 a turn of Stagger when the enemy has melee stacks. Clarion Call counts 1.5 plus the stack's offense. Shadow Ranks counts 2 for a stack in a fight, 1 for one an enemy can reach and −1 otherwise, times its share over 50%.
  - Green Return counts 1.5 and 0.8 a creature for each fallen stack it brings back; with nothing fallen, or once used, it is not cast. Echo scores as the spell it repeats, at the echo's power on what that spell named, plus that spell's mana and less Echo's; a spell that needs a hex or a second pick is not weighed again.
  - Elder Grove counts, for each of the computer's stacks in it without as good a grove, 1.5 in a fight (0.5 otherwise), 0.5 (0.2) a point of defense, and 0.6 for each creature's worth its heal mends now and, in a fight, over two later turns. Glass Dome counts each stack under it 0.5 plus, for each free shooter of the other side, the share of the stack its volley takes, at a quarter of a damage spell's worth for each round up to two; the other side's stacks under it count against.
  - The tier-4 and tier-5 summons score as tier 3's: Foundry Golem's golems, Clockwork Twin's copy, Waking Forest's treant (plus 0.3 a tree) and each of Drowned Host's Risen. Wraith Host adds 1 for its second stack and, landing anywhere, 2 for each enemy shooter it lands beside, less 0.1 a hex to the nearest enemy stack.
  - Hollow Crown counts each enemy stack as the Risen it would become, fighting the other enemy stacks, at the odds it falls: 0.6 times the computer's share of both sides' health (0.1 to 0.9) plus 0.3 times the share of the stack already lost.

## Faction preference

No faction owns a school. Each prefers the school its spells, town library and creatures belong to today, moved to the four:

| Faction | Prefers | Today |
|---|---|---|
| Embercourt | Beacon | 24 of its heroes' 35 starting spells, 5 of 8 library spells; 25 of 27 creatures resist Beacon. Next best: Furnace. |
| Sunvault | Beacon | Its school, Lens, joins Beacon: 32 of 34 starting spells are Lens or Beacon. |
| Mireclaw | Veil | Its school, Mire, joins Veil: 23 of 35 starting spells. |
| Veilmourn | Veil | 19 of 33 starting spells are Veil or Mire. |
| Brasshollow | Furnace | 23 of 33 starting spells. |
| Thornwake | Root | 18 of 33 starting spells. |

The bonus, by the owner's answers:

- In the faction's towns each spell of that school is twice as likely to be drawn (the table above).
- The faction's heroes cast every spell of it, guild or scroll, in battle and on the map, at 1 more spell power.
- They start with mastery 1 in it, which takes one of the hero's 6 specialty slots like any mastery. Today all 66 heroes start with one specialty and none with a mastery, so a faction hero starts with two and chooses the other 4.
- A hero's faction is the one it belongs to, whoever hires it.

Together, a faction hero's preferred-school spell does about a fifth to a quarter more than another hero's at spell power 5. It does more against an enemy hero whose Knowledge is close to the caster's power, because the extra point is not resisted: about 37% more damage at power 8 against Knowledge 6.

## What changes

Counted from the content at d6d472702.

- **Content.**
  - `spells.json`: today's 119 spells go and the 139 come in, each with a new id.
  - `heroes.json`: 203 starting spells on 66 heroes get new picks, and each hero gains its faction's mastery. `encounters.json`: 250 starting spells on 116 neutral commanders get new picks.
  - `towns.json`: the 45 fixed library spells go; guild draws replace them. `factions.json`: each faction names its preferred school.
  - `resource_sites.json`: 72 taught spells on 36 sites move to tier picks. `random_map_generator_data_model.json` names 38 spell ids and `homm3_re_reward_object_proxy_catalog.json` names 1.
  - `hero_specialties.json`: seven school masteries become four. `units.json`: 61 creatures' school resistances move. `artifacts.json`: Trailsinger Boots and Choir Tuning Fork name a school.
  - `spell_icons.json` (119 icons; 51 entries on Lens, Mire or Old Measure), `battle_vfx_manifest.json` (97 spell cues), `audio_production_banks.json` (119 entries) and `animation_event_cues.json` follow the new spells.
  - Spell scrolls on the map and in rewards become worn items.
- **Native rules** (`src/gdextension/rules/core/port/`): `spell_rules*.cpp`, `spell_battle.cpp`, `spell_events.cpp`, `battle_ai_spell_choice.cpp`, `battle_ai_spell_scores.cpp`, `commander_payload.cpp`, `content_validate.cpp`, the day's mana in `day_economy.cpp`, guilds in the town rules, scrolls in `artifact_rules.cpp`, `generated_reward_rules.cpp` and `overworld_rules_site_rewards.cpp`, and the screens' data in `human_registry.cpp`. The 112 new battle mechanics include 25 new statuses; there are 14 new map mechanics. `SpellRules.gd` stays a thin wrapper.
- **Screens.** The spellbook (`SpellbookView.gd`), battle casting and target picking (`BattleShell.gd`, `BattleBoardView.gd`), the town guild (`TownShell.gd`, `TownBuildingPanelView.gd`), map casting (`OverworldShell.gd`), the hero sheet and exchange (worn scrolls, masteries). Spell texts show their numbers at the caster's power.
- **Computer players.** A battle value for every new mechanic and target choice among all stacks; map values for the map spells; wearing and fetching scrolls.
- **Art and sound.** An icon for each of the 139 spells (none of today's reused), battle effects and sounds for each, badges for the 25 new statuses; the four school sigils stay.
- **Saves.** Each learned spell in an old save becomes a new spell of the same tier and kind, from the school its school moves to; towns get their guild draws on load; heroes get their faction's mastery on load.
- **Tests and docs.** The core case `magic_spell_schema_report` and the content check's spell domains follow the new spells. At the switch this doc replaces `docs/magic-system-expansion-foundation.md` and `docs/battle-spell-effects.md`; `docs/shared-spellbook-and-town-learning.md`, `docs/spell-effect-variety.md`, `docs/spell-system-player-balance-audit.md` and `docs/magic-school-availability-strategic-influence-report.md` describe today's magic and are updated or archived with it.

## Build order

Each slice is in `PLAN.md` and `ops/progress.json`. Rule changes go into the native rules core, with one six-seed native check against main for battle and day changes and `battle_sim_cli` rebuilt after battle changes (`AGENTS.md`).

1. `magic-power-mana-20261107`: spell power against Knowledge, turns per 4 power and the slower mana, on today's spells first.
2. `magic-guild-draws-20261107`: each town draws its guild, weighted to the faction's preferred school; it runs on today's spells and home schools until the switch.
3. `magic-worn-scrolls-20261107`: scrolls become worn trinket items that lend their spell; scroll-only spells never enter guilds.
4. `magic-basic-tier-20261107`: the hero casts on any stack; the 12 basic battle spells and their mechanics.
5. `magic-tier2-spells-20261107`: the 36 tier-2 battle spells and the 36 new mechanics they need, and mastery shapes.
6. `magic-tier3-spells-20261107`: the 36 tier-3 battle spells and their 36 new mechanics.
7. `magic-tier45-spells-20261107`: the 39 tier-4 and tier-5 battle spells and their 36 new mechanics.
8. `magic-map-spells-20261107`: the 16 map spells of every tier and the 16 map mechanics.
9. `magic-art-audio-20261107`: icons, battle effects, sounds and status badges, before or with the switch.
10. `magic-switch-20261107`: today's spells go and the new ones go live, with the four schools, masteries, the preference's hero bonuses, moved resistances, new picks in content, save conversion, tests and docs.

Slices 1 to 3 change today's game and stay. Slices 4 to 8 add the new spells to `spells.json` marked unreleased: the content check, the battle simulator and the focused checks use them, while guilds, hero and commander starts, rewards and sites leave them out. The switch removes today's spells and that mark together. A spell enters content in the slice that brings the last mechanic it needs; the Mechanics column of the spells doc says which.

## Owner decisions

- 2026-11-06: four schools shared by all factions instead of seven; each faction prefers one, with a small bonus decided after the system; every kind of effect in every school, with each school's flavour kinds stronger.
- 2026-11-07, first draft: tier 1 is basic spells with no school; the top tier is smallest; the hero casts on any stack; each town draws a third of each tier for its guild, weighted to the faction's preferred school; none of today's spells is reused; higher tiers combine effects; some spells come only from scrolls.
- 2026-11-07, marks on the second draft: 139 spells as drafted, with field as a seventh kind and the flavours as they are; every spell grows with spell power, and the enemy hero's Knowledge is the resistance; mastery can widen a spell; summons last rounds set by spell power; scrolls are worn, never learned, and about 1 in 3 is scroll-only; much slower mana; Molten Deluge toned down; vision spells reveal more than a hero or town already does; a plain weighted guild draw; friendly fire stays.
- 2026-11-07, answers on the third draft: all of the enemy hero's Knowledge counts; one more turn per 4 spell power, no limit; creatures keep their school resistances on top of Knowledge; a fifth of the maximum mana back each day, all of it on a day that starts in an own town with a guild; scrolls are worn in a trinket slot.
- 2026-11-07, faction preference: the schools above; guild odds ×2; its heroes cast it at 1 more spell power and start with mastery 1 in it, in a specialty slot like any mastery.
