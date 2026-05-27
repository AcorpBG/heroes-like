# Spell System Player-Balance Audit

Date: 2026-05-27
Task: #10184
Status: baseline audit findings; catalog counts were updated by `magic-school-availability-strategic-influence-10184`

## Scope

This audit reviews the current full-game spell surface from a player-balance perspective:

- `content/spells.json` catalog shape and spell identity.
- Hero spellbook exposure in `content/heroes.json`.
- Runtime support in `SpellRules.gd`, `BattleRules.gd`, `BattleAiRules.gd`, and overworld spell rules.
- Fast benchmark parity in `tests/battle_faction_fast_balance_benchmark.py`.
- Current benchmark evidence around the visible Sunvault week-2/week-3 imbalance.

This is not a new validation gate and does not claim final spell balance.

## Catalog Reality

Baseline spell catalog before `magic-school-availability-strategic-influence-10184`:

- 20 total spells.
- 17 battle spells.
- 3 overworld spells.
- Battle effect families:
  - 5 `damage_enemy`
  - 4 `initiative_buff`
  - 3 `attack_buff`
  - 2 `defense_buff`
  - 1 `control_enemy`
  - 1 `recover_ally`
  - 1 `cleanse_ally`
- Overworld effect families:
  - 3 `restore_movement`

This is still a narrow early catalog. It has basic damage, buffs, one control spell, one recovery spell, one cleanse spell, and movement restoration. It does not yet have enough breadth for production magic balance: no mass spells, terrain spells, summons, displacement, anti-ranged wards, spell resistance, dispel variants, school counters, economy/map tradeoffs beyond movement, or high-tier spell identity.

Post-slice update:

- 112 total spells.
- 90 battle spells.
- 22 overworld spells.
- 16 spells in each live school: Beacon, Mire, Lens, Root, Furnace, Veil, and Old Measure.
- Old Measure now has a broad live study catalog plus Survey Chain as the first validated field-survey spell.
- Overworld effects now include movement restoration and `reveal_radius` scouting spells.
- Town study now supplements explicit town spell-library entries with faction school access plus Old Measure access by town magic tier.

## Main Findings

### 1. Sunvault Is Not Simply Weak

The current matrix shows Sunvault is polarized, not globally weak.

From the current 100-seed artifact:

- Week 2 Sunvault vs Veilmourn: Veilmourn wins 71.0%.
- Week 2 Sunvault vs Thornwake: Thornwake wins 56.5%.
- Week 2 Sunvault beats Mireclaw 62.0% and Brasshollow 57.5%.
- Week 3 Sunvault vs Thornwake: Thornwake wins 71.5%.
- Week 3 Sunvault beats Brasshollow 67.0%, Embercourt 64.0%, Veilmourn 60.0%, and Mireclaw 55.0%.

So a broad Sunvault buff is the wrong tool. The real problem is specific counterplay and spell-use behavior against Veilmourn tempo and Thornwake root/control.

### 2. Benchmark Spell Valuation Is Not Live-AI Parity

The Python benchmark and live `BattleAiRules.gd` do not value spell candidates the same way.

Damage spells:

- Live AI scores damage spells using tactical attack context, target pressure, status payoff, cohesion pressure, objective modifiers, and mana cost.
- The Python benchmark scores damage mostly as damage divided by unit HP, plus wounded pressure and mana cost.
- This undervalues some damage/status spells in the benchmark, especially against larger stacks where the status and tactical pressure matter more than raw unit-HP math.

Buff spells:

- Live AI has context-sensitive buff scoring: distance, hostile ranged pressure, terrain tags, faction hooks, cohesion state, momentum value, and alive stack count.
- The benchmark mostly scores buffs from positive modifier sums and mana cost.

Cleanse/recovery:

- Live AI checks matching cleanse ids, missing health, cohesion pressure, combat distance, and faction/terrain context.
- The benchmark uses much simpler active-effect and missing-health scoring.

Candidate selection:

- Live AI considers spell, attack, advance, defend, and withdrawal candidates in one scored action pool.
- The benchmark requires the best spell to beat a minimum threshold and the best attack by 0.8 before casting.

This means the benchmark can suppress spells that live AI would cast, then balance tuning may chase the wrong unit stats.

### 3. Generic Spell-Scoring Fixes Overcorrect

Focused in-memory experiments were run against week 2 and week 3 Sunvault matchups.

Results:

- Current scoring: Sunvault loses W2 vs Veilmourn 68.3% and W3 vs Thornwake 70.0% in the 30-seed focused smoke.
- Live-like damage-spell scoring: W2 Veilmourn improves to 56.7%, but W3 Thornwake worsens to 75.0% and other Sunvault rows become unstable.
- Conservative damage/status scoring: W2 Veilmourn improves to 53.3% and W3 Thornwake improves to 63.3%, but Sunvault overpowers other rows, including W3 vs Brasshollow 81.7% and W3 vs Embercourt 70.0%.
- Stronger damage/status scoring creates catastrophic Sunvault overperformance, with several 80-93% rows.

Conclusion: the benchmark does misuse spells, but a generic damage-spell valuation buff is too blunt. Fixing parity must be paired with content retuning and better target/counterplay logic.

### 4. Ally Spell Targeting Is Too Narrow

Current ally battle spell target mode is effectively `ally_active`.

That means:

- Cleanse and recovery are tied to the currently acting stack.
- The AI cannot choose the most threatened allied stack for Prism Bastion or Graft Mend.
- A faction can have a theoretical counter spell that does not fire at the tactically relevant time.

This is a major reason Prism Bastion does not solve Thornwake control pressure. It is a ward on the active stack first, not a reliable answer to the stack that is actually rooted or collapsing.

### 5. Prism Bastion Is Not A Thornwake Counter

Prism Bastion currently cleanses:

- `status_harried`
- `status_staggered`

It does not cleanse:

- `status_rooted`

Thornwake root pressure comes from `Briar Bind`, Barkmantle brace-root, and faction damage payoff against rooted targets. Sunvault's only countermagic spell does not answer that main pressure channel.

Adding root to the cleanse list alone did not move the focused benchmark because the current active-stack targeting/scoring model still does not make the AI use Prism as a tactical root answer. The real fix is target/scoring behavior plus content counter identity, not just adding one id to JSON.

### 6. Tempo Buffs Are High Leverage

Several low-tier buffs carry large modifier packages:

- Relay Drum: initiative +3, attack +2, momentum +1.
- Bloodwake Drum: attack +3, initiative +2, momentum +2.
- Resonant Chorus: initiative +3, attack +1, cohesion +1, momentum +1.
- Fogwake Step: initiative +3, defense +1, momentum +1.

These are not inherently wrong, but they are very high-leverage in a stack game. If spell AI starts casting more aggressively, these buffs can reshape matchups as much as unit-stat changes. Spell balance cannot be evaluated separately from AI casting frequency.

### 7. Hero Spellbook Selection Affects The Benchmark Surface

The benchmark selects one representative live hero per faction. For Sunvault it selects Neral Glasswind, who has:

- Sunlance Arc
- Prism Bastion
- Trailglyph

That is a specific faction doctrine, not necessarily the average or intended Sunvault battle identity. A full-game spell balance pass should decide whether the benchmark should use:

- one canonical faction commander;
- multiple spellbook archetypes per faction;
- or a faction doctrine profile independent of authored hero ordering.

Until then, some "faction balance" rows are actually hero-spellbook balance rows.

## Current Risk

The current combat tuning commit reduced the number and severity of 65%+ rows but increased total 55%+ outliers. That result should not be treated as final improvement. It is acceptable evidence that severe blowouts can be moved, but the next balance work should prioritize spell-system correctness before more unit-stat nudges.

## Recommended Next Slice

Next implementation should be a spell parity and counterplay slice, not another stat-only balance slice.

Recommended order:

1. Add a spell decision trace to the fast benchmark:
   - spell id cast counts;
   - spell target tier/role;
   - spell skipped because below attack threshold;
   - spell score family breakdown for damage/control/buff/cleanse/recovery.

2. Bring benchmark spell valuation into deliberate parity with live AI:
   - either port live scoring faithfully, then retune content around that reality;
   - or define a shared scoring policy and apply it to both live AI and benchmark.

3. Fix ally spell target semantics:
   - introduce `ally_selected` or "best affected ally" behavior for cleanse/recovery/ward spells;
   - make AI choose the ally that actually needs the spell, not always the active stack.

4. Rework Sunvault counterplay around actual threats:
   - Prism Bastion should be able to answer root/control if Sunvault is meant to be the clarity/countermagic faction;
   - Sunlance Arc should be a tactical pressure spell without becoming a universal nuke that makes Sunvault dominate all week-2/week-3 rows.

5. Re-run the 100-seed battle matrix after spell parity changes.
   - Required outcome for acceptance: total 55%+ outliers must not increase, and severe 65%+ outliers should decline or stay lower with a better matchup distribution.

## Non-Goals

- Do not claim final spell balance from this audit.
- Do not add broad new report gates just to make a matrix green.
- Do not broadly buff Sunvault unit stats; the evidence points to polarized spell/counterplay behavior.
- Do not tune only the Python benchmark if live `BattleAiRules.gd` will behave differently.
- Do not start campaign production from this work.
