# Battle stat scaling

Slice: `battle-stat-scaling-20261008` (owner review, 2026-10-08: "Spell Power feels underwhelming. Also attack/defense caps feel underwhelming too. Also address the big stack cohesion.").

## Attack against defense

Before: damage changed by 5% per point of the attacker's attack minus the target's defense, clamped to ±8 points (±40%). Past an 8-point gap no hero or creature stat counted, so a hero with 15 attack hit as hard as one with 10, and a tier-7 creature (attack 15-19) gained no more against tier-1 defense (2-8) than a tier-4 one.

Now (`scripts/core/BattleDamageRules.gd`, shared by `BattleRules._damage_modifier` and the battle AI's damage estimate):

- Each point of attack above the defense adds 5% damage, up to +300% (60 points).
- Each point of defense above the attack takes 2.5% off, down to -70% (28 points).

Examples: a 10-point lead is x1.5, 20 points x2.0, 30 points x2.5; a 10-point deficit is x0.75, 20 points x0.5. The caps sit beyond the gaps current content reaches, so every point of hero attack and defense (level-ups, artifacts, specialties), spell and cohesion/momentum bonuses and the +2 defend bonus counts.

## Spell power

Before, three things kept power from mattering:

1. Level-ups only alternated attack and defense; power and knowledge never grew.
2. Damage spells gained 4-15 damage per point of power (about a quarter of their base), so a starting caster's power 2 added little.
3. Buffs, debuffs and spell status riders did not scale with power at all.

Now:

- **Level-ups roll a stat weighted by the hero's command path** (`heroes.json` `command_path`, `HeroProgressionRules.COMMAND_GAIN_WEIGHTS`, owner choice 2026-10-08): might heroes roll attack 40%, defense 40%, power 10%, knowledge 10%; magic heroes attack 10%, defense 10%, power 40%, knowledge 40%. Each roll comes from the hero's growth seed and the level reached (`command_gain_stat`, SHA-256 of seed and level), so saving, loading or the level-up popup never re-roll it. A new hero draws its seed when created: from the session and hero when a session is known (`HeroCommandRules.new_growth_seed`, so the tavern card and the hire it shows roll alike), else at random; player heroes from older saves get a session seed on load, and other heroes without one roll from their id. Knowledge raises maximum mana (8 + 4 per point) and spell resistance as before. Gains already earned in old saves stay.
- **Damage spells gain 2.5x as much per point of power** (`content/spells.json` `power_scale`, tier bands in `tests/validate_repo.py`): tier 1 10-13, tier 2 15-18, tier 3 20-23, tier 4 25-30, tier 5 33-38 per point. Base damage is unchanged, so might heroes (power 0-2) cast about as before and magic heroes pull ahead as they level: Cinder Burst (tier 2) does 66 at power 2 and 138 at power 6; a tier-5 spell does about 280-310 at power 6.
- **Spell effects last longer with power**: every 4 points of the caster's power add a turn to a battle spell's buff, debuff or rider, up to 3 extra turns (`SpellRules.spell_duration_rounds`; since 2026-10-09 spell effects count the affected stack's own turns, see `docs/battle-spell-effects.md`). Spell summaries show the lengthened duration.

Healing spells still restore only the wounded top creature of a stack (no resurrection), so their power scaling stays small; that is a separate design question.

The battle AI's control lean for hexcaller-type commanders grew from 2.4 to 3.2 with the stronger damage spells, so those casters still prefer control in a close call.

## Big-stack cohesion

Before, a hit cost the target 2 cohesion if it killed two or more creatures and 1 if it killed one, whatever the stack's size, so a stack of 200 small creatures lost 2 cohesion to almost every hit.

Now the loss goes only by the share of the stack's health the hit took: -1 from 18%, -2 from 45%, -3 when the stack is destroyed (`BattleRules._casualty_cohesion_shift`). Small stacks are unaffected in practice (one of three creatures is a third of the stack).

## Validation

- `tests/battle_stat_scaling_report.tscn` (50 checks): the curve; hero attack scaling a real battle's damage past the old cap on a generated small map; cohesion loss by share; level-up rolls (same seed same growth, 11 points for 11 levels, different seeds diverge, session seeds, odds within 2.5 points of 40/40/10/10 over 8,000 rolls per path, old-save heroes, popup gains equal applied gains, a tavern preview equals its hire, AI commanders keep and roll from their seed); spell damage per power, buff and rider durations by power, and the spell summary.
- Existing synthetic battle and magic reports: magic battle spell behavior, resistance and counter-control, prism bastion, AI spell valuation (two fixture targets enlarged from 220 to 600 health so a power-8 tier-5 spell no longer ends the battle before the check).
- `tests/battle_faction_fast_balance_benchmark.py` mirrors the new curve, cohesion and durations. Before/after (curated lead heroes at level 1, so command growth is not modelled; 100 seeds, weeks 1-4): faction balance was already outside the 45-55% band (54 outliers, `needs_tuning`) and stays there (52); the mean distance of a pair's win rate from 50% moved from 25.4 to 26.1 points; battles are 0.2-0.4 rounds shorter; damage spell casts rose from 6,818 to 9,400. Largest shifts by faction win rate: week 1 Mireclaw 20% to 39%, Thornwake 62% to 46%, Veilmourn 21% to 14%; week 4 Thornwake 69% to 79%, Embercourt 38% to 45%, Veilmourn 42% to 35%. Faction tuning remains its own open work.
- `tests/validate_repo.py` output is identical to the unchanged code (the 112-spell mechanics hash was re-pinned for the new `power_scale`). `unit_ability_runtime_report` (76 errors) and `battle_intent_forecast_report` (1 error) fail identically on the unchanged code.
