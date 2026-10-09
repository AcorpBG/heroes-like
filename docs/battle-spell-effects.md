# Battle spell effects

Slice: `battle-spell-effect-identity-20261009` (owner review, 2026-10-09: buffs and debuffs were "omega confusing" and "it feels like most of the spells do the same thing").

## What was wrong

- Every buff was a mixed bundle of the same five stats (attack, defense, initiative, cohesion, momentum), so most buffs read and played alike.
- Effects lasted rounds: a 1-round effect ended with the current round, so it was nearly worthless on a stack that had already acted, and a 1-round initiative bonus never counted (turn order is set when a round starts, after the effect had expired).
- The three debuff statuses hid behind 13 names, and Rooted did not stop movement; no status did anything beyond its numbers except Harried and Staggered's hidden cohesion drain.

## One job per family

| Family | Effect | Spells |
|---|---|---|
| Attack buff | attack (main) and momentum | 17 |
| Defense buff | defense (main) and cohesion | 16 |
| Haste (initiative buff) | initiative (main) and speed: extra hexes of movement | 14 |
| Recovery | heals the wounded top creature, plus defense and cohesion | 6 |
| Cleanse | removes Harried, Staggered and Rooted, grants immunity to them, plus defense and cohesion | 8 |
| Damage | damage, most with a status rider | 22 |

Amounts follow the existing tier bands (`tests/validate_repo.py`): the main stat +2 / +2 / +3 / +4 / +5 by tier, the second +1 / +1 / +2 / +2 / +3.

## Three statuses, one name each

| Status | Numbers | Rule | Spells |
|---|---|---|---|
| **Harried** | -cohesion | loses 1 cohesion each round and each time it is hit; attackers gain momentum against it | 14 |
| **Staggered** | -initiative | cannot strike back (no retaliation) | 12 |
| **Rooted** | -defense | cannot move: no advance and no walking up to strike; it can still attack what is next to it and shoot | 10 |

Every spell shows the status by its real name. By their flavour, the Snares, Boundaries and the Moonfen Dragnet now root, and the Fogbinds and the Drowned-Bell Verdict stagger. The rules apply wherever the status comes from, including creature abilities (Thornwake's Bramble Ground roots attackers in place).

## Durations count the stack's own turns

- A spell effect lasts for the next N turns of the stack it is on ("its next 2 turns"), however the rounds fall. Content keeps the field name `duration_rounds`; for spells it is that turn count (plus the power and specialty bonuses).
- A spell cast on the stack whose turn it is does not spend that turn (casting ends the turn), so a 1-turn buff on it covers its next turn.
- `turns_left` ticks down when the affected stack's turn ends (`BattleRules.spend_effect_turns`, called from `advance_turn`); round starts no longer end spell effects. Effects from other sources (abilities, towns) still last rounds.
- When an effect changes initiative, the stacks still to act this round are put back in initiative order at once (`_resort_remaining_turn_order`), so haste and Staggered count the same round.

## Wording

Spell previews and the stack effect list say what an effect does and for how long, for example "Leave Ogres Rooted (-1 defense, cannot move) for its next turn." and "Grant +2 attack, +1 momentum to Pikemen for its next 2 turns."; a stack's list reads "Rooted (cannot move), 2 turns".

## AI and benchmark

The battle AI's damage estimate knows Staggered stops retaliation; a rooted computer stack does not try to advance; spell scoring values Rooted on melee stacks and Staggered on stacks that can still strike back, and haste's speed on a melee stack that still has to close in. `tests/battle_faction_fast_balance_benchmark.py` mirrors turn-counted durations, the reordering, Rooted and Staggered (its distance model has no movement points, so haste speed is not modelled there).

## Wounded targets

Nine damage spells (Cinder Burst, Sunlance Arc and others) add `wounded_bonus_damage` to a stack at or below `wounded_threshold_ratio` of its starting health. `SpellRules` measures a stack the way `BattleRules` does: living creatures are `ceil(total_health / unit_hp)` and full health is `base_count * unit_hp`. Until 2026-10-09 it read an army `count` that battle stacks do not have, so a stack with one whole creature left counted as unhurt, the bonus almost never applied, and the living stacks behind spell hints were always none; the benchmark already applied the bonus. The battle screen's Active and Target labels, initiative cue and target-cycle fallback had the same fault and showed "x0" or no next stack.

## Validation

`tests/battle_spell_effects_report.tscn` (105 checks): each family's stats and each status's name and numbers in content; turn counting (the casting turn, round changes, the stack's own turns); reordering; haste speed; Staggered without retaliation (rules and AI); Rooted without movement or approach and its advance; plain-language previews and effect lists; on a battle from a generated small map. The battle stat scaling, specialty catalog, magic behaviour, resistance, prism bastion, AI spell valuation (one fixture now uses the defense spell Bulwark Litany for a Linekeeper) and deterministic RNG reports pass.

`tests/battle_spell_wounded_target_report.tscn` (18 checks, generated small map): spell and battle rules agree on a wounded stack's health; Cinder Burst adds its bonus at 40% health and not above its threshold, in damage and summary; a side's living stacks and abilities are found. The old rules failed 8.

Faction benchmark before/after (curated lead heroes, 100 seeds, weeks 1-4): balance stays outside the 45-55% band as before (outliers 52 to 54; mean distance of a pair from 50% 26.1 to 25.1 points); battles are 0.2 rounds shorter early and 0.3 longer in week 4; casts moved from buffs to damage and control (attack buffs 14,309 to 9,242, control 682 to 1,280, damage 9,400 to 12,126; haste 7,801 to 514, since that model has no movement for speed to help). Largest faction shifts: week 1 Brasshollow 75% to 92%, Mireclaw 39% to 61%, Sunvault 66% to 41%; week 4 Thornwake 79% to 54%, Mireclaw 36% to 53%. Faction tuning remains its own open work.
