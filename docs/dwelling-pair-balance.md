# Dwelling pair balance

Slice: `balance-dwelling-pairs-20261006` (owner-directed, 2026-10-06).

## Rule

Every faction town offers two exclusive dwelling lines at tiers I–V, and each line has a base unit and an upgrade. The two lines of one tier must be a real trade-off, never one line that is a little better at everything:

- Two melee lines (or two ranged lines) at the same tier split into a **tank** (more defense and health, less attack and top damage) and a **striker** (more attack and top damage, less defense), and trade evenly per gold.
- When one line shoots and the other fights in melee, the melee line is always the bulkier one (health weighted by defense). The shooter keeps a head-on edge per gold, because a duel cannot credit the melee line for screening, blocking and closing on shooters in a real army.
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
