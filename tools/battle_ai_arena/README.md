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
```

A variant is `current` (the working tree), `git:<rev>`, or a path to a copy of
`BattleAiRules.gd`. Godot comes from `--godot`, `$GODOT_BIN`, `godot4`/`godot` on PATH, or
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
python tools/battle_ai_arena/tune.py                     # 40 generations, a few hours
python tools/battle_ai_arena/tune.py --resume .artifacts/battle_ai_arena/tune-<time>
python tools/battle_ai_arena/arena.py --b-weights .artifacts/battle_ai_arena/tune-<time>/weights.json --suite holdout
```

`tune.py` searches the weights with separable CMA-ES. Each generation samples a population of
weight sets around the current mean, and plays each of them and the mean itself against the
game's current weights, on the same battles and both sides each. Every generation plays fresh
maps, sites and heroes (never the `standard` or `holdout` battles), so the result cannot fit
one set of battles. A weight is searched as a power-of-two multiple of its current value
(1/8 to 8 times), so it keeps its sign. `weights.json` in the run directory is the current
mean, the run's recommendation; `history.jsonl` has one line per generation. Copy the weights
into `content/battle_ai_weights.json` only after `arena.py` confirms them on `standard` and
`holdout`.

On a 32-thread machine with 24 workers a 288-game suite takes about a minute.

## What it plays

Suites (`SUITES` in `arena.py`):

- `standard`: every faction at four army stages (`STAGES`: weeks 1, 3, 5 and 8 of
  growth, with the hero level, top tier and guild spells of that stage), each against all six
  factions. That is 144 battles.
- `holdout`: the same coverage on other maps, sites and heroes.
- `quick`: 18 battles at week 5, a smoke run.

Each battle is hero against hero on a generated small map. The enemy is set up as an AI
player's hero, so it may withdraw. The enemy's stack counts are scaled until both armies rate
equally on the game's own strength estimate (`AiHeroRules.army_power`, heroes included), so
more battles hinge on the AI. `--no-balance` turns that off.

Every battle is played twice from the identical start, A as the player side and then B. The
armies, the battlefield and the dice are the same, so only the AI differs. Two identical
variants score exactly 0.5; the arena checks itself that way.

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
its mean over the two games. The report gives the mean over battles with a 95% interval,
broken down by stage and by matchup.

The report also counts the battles the AI decided: those where the winner changes when the
sides swap. The rest are decided by the armies and only move the score through losses.

## Checked

- Two identical variants score 0.5000 +/- 0 on every suite.
- A copy with hero spellcasting switched off scores 0.37 +/- 0.03 on `standard`: clearly
  worse, weakest at week 1.

## Strategy changes tried

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
