# Battle AI arena

Plays two versions of the battle AI (`scripts/core/BattleAiRules.gd`) against each other and
says which one is better. Use it to judge a strategy change before it lands, and later as the
evaluator for weight tuning.

It is evaluation tooling, run on demand. It is not part of `tools/core_suite.py`, the game or
the export. The `.gdignore` here keeps Godot's import and the script compile check out of the
folder. It never writes the repo's files.

## Running it

```
python tools/battle_ai_arena/arena.py                       # HEAD's AI (A) vs the working tree's (B)
python tools/battle_ai_arena/arena.py --suite holdout       # the battles a tuning run never sees
python tools/battle_ai_arena/arena.py --a git:main~5 --b path/to/BattleAiRules.gd --suite quick
python tools/battle_ai_arena/arena.py --roles                # also says where B gains: as player or as enemy
python tools/battle_ai_arena/arena.py --plain --suite standard  # the game's own AI on both sides, no router
```

A variant is `current` (the working tree), `git:<rev>`, or a path to a copy of
`BattleAiRules.gd`. A `git:<rev>` variant plays with that revision's weights file; `current`
and a file read the working tree's `content/battle_ai_weights.json` unless given a weights
file. Godot comes from `--godot`, `$GODOT_BIN`, `godot4`/`godot` on PATH, or
the owner's Windows install, as for the core suite. Every worker gets a throwaway user
profile. Results go to `.artifacts/battle_ai_arena/<time>-<suite>/` (`summary.json`,
`games.jsonl`). Worker logs are kept only when something went wrong, or with `--keep-logs`.

The usual loop for a strategy change: edit `BattleAiRules.gd`, run the `standard` suite
against HEAD, then confirm on `holdout` before committing.

A variant can also take a weights file (`--a-weights`, `--b-weights`): the battle AI's tunable
numbers live in `content/battle_ai_weights.json` (`BattleAiRules._w`), and the variant is
the same script with those weights built in.

## Tuning the weights

```
python tools/battle_ai_arena/tune.py                     # 30 generations, a few hours
python tools/battle_ai_arena/tune.py --resume .artifacts/battle_ai_arena/tune-<time>
python tools/battle_ai_arena/tune.py --base-weights <earlier run>/weights.json --seed 2   # search on from a run
python tools/battle_ai_arena/arena.py --b-weights .artifacts/battle_ai_arena/tune-<time>/weights.json --suite holdout
```

`tune.py` searches the weights with separable CMA-ES. Each generation samples a population of
weight sets around the current mean, and plays each of them and the mean itself against the
game's current weights, on the same battles and both sides each. The battles are realistic
and contested ones (below): 48 maps of 3 battles generated a generation by default
(`--maps`, `--battles`), the contested ones played (`--odds`, about 100). Every generation
plays fresh maps, armies and heroes (never the `standard` or `holdout` battles), so the
result cannot fit one set of battles. A weight is searched as a power-of-two multiple of its
current value (1/8 to 8 times), so it keeps its sign. `weights.json` in the run directory is the current
mean, the run's recommendation; `history.jsonl` has one line per generation. Copy the weights
into `content/battle_ai_weights.json` only after `arena.py` confirms them on `standard` and
`holdout`. When weights reach the 1/8 or 8 times limit, search on from that run's weights
with `--base-weights` (and another `--seed`, which also picks other training maps): they
become the centre and the opponent.

On a 32-thread machine with 24 workers the 480 games of `standard` take about 75 seconds.

## What it plays

Realistic battles, built by `scenarios.py`. Suites (`SUITES` in `arena.py`):

- `standard`: 48 generated maps with 5 battles each, 240 battles.
- `holdout`: the same mix on other maps, armies and heroes. Keep it out of any tuning loop.
- `quick`: 12 maps with 3 battles each, a smoke run.

Each map is generated as the skirmish menu makes it: small or medium, 2 to 4 players, weak,
normal or strong monsters, every faction in turn as the player's. A battle is one of:

- a guard (55%): the player's hero against a neutral guard exactly as the generator placed it,
  the one whose strength (`AiHeroRules.army_power`) is nearest a sampled share of the hero's,
  0.3 (easy) to 1.3 (hard) times;
- an AI hero (30%): another faction's hero with an army of its own, a few weeks ahead or
  behind. It may withdraw, as on the map;
- a siege (15%): the player attacks an enemy town: the garrison, a defending hero half the
  time (else the town's captain), the fort level of the week and sometimes the faction's
  defence building.

Armies are built the way players build them, from the factions' town rosters: a build plan
picks one dwelling of each tier's two (balanced, ranged wherever a tier offers it, melee, top
tiers, or massed low tiers), dwellings open over the weeks, upgrades come with time, a
second town adds the other dwelling, a neutral stack joins now and then, and the gold of the
week buys top tier first. Heroes are any of the faction's, at the level, guild spells and
mana of the week (weeks 1 to 10, early weeks most often).

Nothing is evened out: a mismatched battle is part of a game. Both sides of every battle
play, so the armies cancel; a battle the armies decide still moves the score through the
losses. The report breaks the score down by battle type, monster strength, guard odds, build
plan, week and odds. With `--roles` each battle is also played A against A, and B's gain
splits into its play as the player side and as the enemy side: guards, defenders and AI
heroes. The battle AI plays both: the enemy side in the game, and the player side in Quick
Resolve and every computer player's own fights.

Contested battles (`--odds 0.6,1.7`): most realistic battles are mismatches whose winner is
fixed, which squeezes the score. With `--odds` the worker plays only the battles whose odds
(the player's strength over the enemy's) fall in the band, from twice as many generated, and
guards are sampled near even. No army is rescaled: they are the same realistic battles, only
the ones the AI can swing. On `standard` that keeps 333 of 480; switching off hero spells
scores 0.436 there against 0.465 on all battles, and 15% of battles change winner with the
AI instead of 5 to 7%. `tune.py` trains on contested battles by default.

## Fitting the strength estimate

```
python tools/battle_ai_arena/power_fit.py                 # 7,200 battles, about 25 minutes
python tools/battle_ai_arena/power_fit.py --ceiling 3     # also replays 720 battles with other dice
python tools/battle_ai_arena/power_fit.py --games <run>/games.jsonl
```

`AiHeroRules.army_power` is how the computer players weigh armies: which guards and heroes to
take on, threats, town defence, what to recruit and build. Generated guards are sized by it too.
`power_fit.py` plays realistic battles once each with the battle AI on both sides. It then fits
the estimate's terms to who won, with a logistic fit on the log strength ratio. It prints the
terms and how often the game's current estimate and the refitted one call the winner of the
battles left out of the fit. Copy the terms into `content/ai_hero_weights.json` (`army_power`),
then rebuild the company catalog with `tools/build_generated_neutral_companies.py`, which reads
them from there. The worker
records each side's hero (`player_commander`, `enemy_commander`), and a group's `dice`
replays its battles with other damage rolls.

The 2026-10-16 fit, tested on 2,400 battles the fit never saw:

| Estimate | Winner called | Near-even battles (within 1.5x) |
|---|---|---|
| sqrt(health x damage), shooters x1.15 (before) | 86.7% | 70.8% |
| the same, shooters x1.6 | 88.4% | 74.6% |
| health^0.3 x damage^0.6, defense, speed, initiative, shooters x1.65, hero x1.7 | 90.0% | 78.2% |
| a small neural network on 61 features a side (not used) | 90.7% | 79.9% |
| the true odds of each battle (replayed with 9 dice) | 97.4% | |

- Damage counts more than health. Each point of defense adds 7.5%, of speed 6% and of
  initiative 4.5%.
- Creature attack, strike-backs, shots and the unit abilities added nothing.
- The hero's attack, defense and damage spells count about 1.7 times as much as before.
- In guard battles the player does as well as 6% more strength would, and in sieges as 8% less.
  The AI's margins cover this: `GUARD_WIN_RATIO` 1.3, `TOWN_ATTACK_RATIO` 1.4.
- An abstract simulation of the battle (free shots while melee closes in, strikes and
  strike-backs) called 86% and added nothing to the estimate.
- Almost every miss is a near-even battle. With the new estimate, guards at 1.3 to 1.5x lose
  93% of the time, and no battle at 2x or more was lost.
- Before fighting a guard or another AI hero, the computer players already play the battle
  itself in Quick Resolve (`AiHeroRules._fight_looks_good`). The estimate only shortlists
  what they consider.

## How the variants are swapped

The game calls the AI through `BattleAiRules`' static functions. Inside the worker, and only
in its memory, that script is reloaded with a generated router (`router.py`). The router
has one stub per static function, with the same signature, forwarding to the variant that
plays the acting stack's side. Each variant is a full copy of the file, so its internal calls
stay inside it. A call is routed by:

1. a parameter naming the acting stack (`active_stack`, `stack`, ...);
2. otherwise a side parameter;
3. otherwise to the enemy's variant for functions named after the enemy;
4. otherwise to A.

Limits:

- Only `BattleAiRules.gd` changes per side. The battle AI's choices live there, the
  advance plan and the advance walk included (`advance_plan`, `best_advance_destination`).
  `BattleRules.gd` only carries out the orders (the enemy turn flow, a hero's cast before
  its stack's order), and that part is shared by both sides.
- Functions the rest of the game calls must keep their signatures; the router is built from
  the working tree's file.
- Battles run native by default (`HEROES_NATIVE_BATTLE`, `scripts/core/BattleEngine.gd`), and
  the native engine does not call the router. So runs with variants, and with them `tune.py`
  and `power_fit.py`, set the switch to `gdscript` for their workers: the GDScript copy of the
  battle rules plays, which the native engine matches. Tuned weights carry over, since both
  read `content/battle_ai_weights.json`. This lasts until the Phase 2 battle tool
  (docs/native-rules-engine-transition.md).
- `--plain` installs no router and no variants: the game's own `BattleAiRules` plays both
  sides, with the caller's battle switch (native by default). The native battle engine's
  parity checks use it.

## Scoring

For each game, from the player side's point of view:

```
score = 0.5 * result + 0.25 * kept_own + 0.25 * (1 - kept_enemy)
```

- `result` is 1 for a win (victory, enemy retreat or surrender), 0 for a loss and 0.5 for
  a stalemate.
- `kept_*` is the share of a side's starting value still standing at the end.
- A unit is worth its recruitment cost: gold, plus other resources at 250 gold each.
- A hero is worth 20% of its army's starting value. It is lost when its side is routed, and
  kept on a withdrawal or a win.

The enemy side scores 1 minus the player side, so any win beats any loss, a cheap win beats
a bloody one, and a loss that cost the enemy dearly beats a rout. B's score for a battle is
its mean over the two games. The report gives the mean over battles with a 95% interval and
the breakdowns above.

The report also counts the battles the AI decided: those where the winner changes when the
sides swap. The rest are decided by the armies and only move the score through losses.

## Checked

- Two identical variants score 0.5000 +/- 0 on every suite, in every breakdown and role.
- A copy with hero spellcasting switched off scores 0.37 +/- 0.03 on `standard`: clearly
  worse, weakest at week 1.

## Strategy changes tried

On the first, synthetic suites (hero against hero, every army a full tier ladder, strengths
evened out):

- Kills weighed by the damage each creature deals instead of counted (two dragons beat twenty
  peasants): 0.560 +/- 0.023 on `standard`, 0.562 +/- 0.022 on `holdout`. Landed.
- Focus fire, where the stacks still to act this round pile onto a target they can destroy
  together: 0.49 +/- 0.02 in two forms, and nothing added on top of the kill weighting. The
  scorer already favours wounded targets.
- A melee stack that reaches no enemy holds its ground while its side outshoots the other,
  until the battle clock presses: 0.529 +/- 0.019 on `standard`, 0.540 +/- 0.020 on
  `holdout`. Landed. Holding at half or one and a half times the enemy's shooting scored less.
- Strike-back estimated from the survivors, with our creatures lost weighed like kills:
  0.49-0.50. The scorer already counts the strike-back.
- Striking first the enemies that can reach our shooters next turn: 0.497, and nothing added
  on top of holding.

On the realistic suites (`standard`, `--roles`):

- Battles are mostly decided by the armies: only 5 to 7% change winner when the AIs swap
  sides, so most of the score comes from the losses. Weights drawn at random between a
  quarter and four times the current ones score 0.51 +/- 0.02 on `quick`.
- The three changes above together, against the AI before them: 0.517 +/- 0.012, as player
  +0.021 and as enemy +0.012. Without the kill weighting 0.488 +/- 0.011; without holding the
  line 0.501 +/- 0.005 (it seldom comes up); the tuned weights over the ones before them
  0.506 +/- 0.010. All kept.
- With the current AI on both sides, an army built ranged does about 0.10 better in the 67
  hero battles of `standard` than its strength (`AiHeroRules.army_power`) predicts, and one built melee 0.12
  worse: the battle AI's melee is the weak side against shooters. Since corrected: see
  "Fitting the strength estimate" below.
- A melee stack heading for the enemy's shooters instead of the nearest enemy, up to eight
  turns further: no change at all. The field is 11 by 9 hexes, so melee meets the enemy within
  a turn or two whatever it heads for.
- A melee stack whose side is outshot not waiting for contact: 0.490 +/- 0.009, worse.
  Waiting lets the shooters and the hero act first.
- Holding the line only while the enemy has melee strength to come: 0.502 +/- 0.003.

On contested battles (`--odds 0.6,1.7`), against the weights above:

- A one-move look-ahead: each order (shot, strike, defend, advance) played on a copy of the
  battle with the AI's own damage estimate, every enemy stack answering with its most costly
  blow, and the stack's next blow counted at half; the strength each side keeps (creatures
  worth the root of damage times health, shooters more) added to the order's score. At weight
  1 and 3: 0.499 to 0.502 +/- 0.008. It changes more than half the battles, by 0.03 on average,
  and its gains and losses cancel. Not landed. A look-ahead that plays the real rules costs
  about a second a candidate, too slow for Quick Resolve and the computer players' fights.
- Weights for being outshot (the share of ranged power the enemy has over ours): shooting
  enemy shooters first, control spells on shooters, melee not defending out of contact and
  advancing: 0.497 +/- 0.005. Not landed.

## Weight tuning runs

- First run, on the synthetic suites (40 generations of 16, 48 battles each, about two
  hours): training score from 0.50 to about 0.54. Against the previous weights 0.553 +/- 0.019 on `standard` and 0.532 +/- 0.023
  on `holdout`; against an older AI the tuner never played, 0.577 where the previous weights
  score 0.540. Landed. The largest moves: enemy shooters first (x4), damage and kills over the
  flat kill bonus (x0.15), melee closing in harder (x3), damage spells worth more but held to a
  higher bar, buffs cheaper, and holding the line from two thirds of the enemy's shooting.
- First realistic run (18 generations of 16, 72 battles each, about an hour): kills x8 and
  strike-back x8 reached the search limit. Its weights: 0.519 +/- 0.013 on `standard`, but
  0.505 +/- 0.010 on `holdout`.
- Second realistic run from those weights (`--base-weights`, `--seed 2`, 18 generations):
  training scores stayed near 0.50, and its mean against the weights before both runs scores
  0.517 +/- 0.012 on `standard` and 0.509 +/- 0.009 on `holdout`, as player +0.020 and as
  enemy +0.014 on `standard`, in guard, hero and siege battles alike. Landed. The largest
  moves against the weights before: our losses to the strike-back x10, kills x7, enemy
  shooters first x4.5 (and "has shots left" x0.1), wounded stacks defending x0.2, damage
  spells x2.9.
- Third run, on contested battles with the look-ahead and outshot weights added (16
  generations of 16, about 100 battles each, three hours): training scores 0.49 to 0.51 all
  run, and its mean scores 0.503 +/- 0.007 on contested `standard` and 0.500 +/- 0.008 on
  contested `holdout`; the look-ahead weight did not move (x0.93). Not landed: around the
  current weights the battle AI is at a flat optimum against itself. What decides most
  realistic battles is the armies, and against ranged armies the free shots during the two
  or three rounds melee needs to close in.
