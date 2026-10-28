# Hired heroes: starting army and level

Owner feedback, 2026-10-07: new heroes came without units and were always level 1. A hero must always lead at least one creature, and tavern recruits should sometimes be level 2 or 3.

## Rules

- **Starting army** (`HeroCommandRules.starting_army_for_hero`), HoMM3-like:
  - always a company of one of the faction's tier-1 creatures, sized 0.75–1.5× its weekly growth;
  - 75% of the time a second company: a tier-2 creature (70%) or the other tier-1 dwelling line (30%), sized 0.5–1× its growth;
  - creatures come from the faction's town development roster (`content/town_development.json` `rosters`), falling back to the faction unit ladder;
  - a hero template may author its own `starting_army` rows (`{unit_id, min, max}`); none do yet.
- **Tavern offer** (`HeroCommandRules.tavern_offer`). Each town tavern and Wayfarer Lodge draws its own two heroes a week from every faction, its own faction about four times in five (`docs/town-building-popouts.md`). A hero leads creatures of its own faction, wherever it is hired. Each weekly offer is `{hero_id, week, level, army}`:
  - level 1 most weeks, level 2 in about 10% of offers, level 3 in about 3%;
  - level and army are rolled from the session id, scenario, tavern week and hero id, so repeated reads, save/load, popout refreshes and a hire in the other tavern place never reroll an offer. Seeding by hero rather than slot index keeps the remaining hero's offer when the first place is hired.
- **One creation path** (`HeroCommandRules.build_recruited_hero`). Every hire builds its hero here; AI recruitment should call it too, with `tavern_offer` (or its own seed key) for the level and army:
  - an empty army is replaced by the starting army;
  - levels above 1 go through `HeroProgressionRules.advance_to_level`. It adds that level's experience through `add_experience`, so command gains, thresholds and specialty choices match earned levels. A recruit arrives trained: each queued choice is taken at once (focus specialty first) and no level-up popup waits;
  - movement and mana are full.
- **Start heroes**: `ScenarioFactory.create_session` and the native random-map bridge give the start hero its starting army when the scenario or faction start army has no troops.
- **One-creature floor**:
  - Transfers already refuse to move a hero's last company: town transfers, slot moves and field transfers, all through `_transfer_empties_hero_army`.
  - A town defense won by the garrison after the hero's own companies fell now moves one creature from the garrison's largest company to the hero (`HeroCommandRules.keep_hero_troop_from_garrison`, called from `BattleRules._sync_player_force_from_battle`).
  - The whirlpool and surrender losses already keep one creature. There is no stack dismissal.
- **Save migration** (`HeroCommandRules.restore_empty_hero_armies`, run by `SaveService._normalize_restore_result` on every restore). Any player hero leading no troops gets its starting army, and so does an AI raid commander whose host is empty. Mid-battle and finished sessions are skipped.

## Tavern card

The tavern popout card shows a level chip next to the hero's name and an **Army** row of creature portraits with counts, both taken from this week's offer. Attack, defense, power, knowledge, movement and specialties are those of the hero at the offered level. The hire action summary in the town logistics list names the level and army too.

## Validation

`tests/hero_hire_army_level_report.tscn` (`HERO_HIRE_ARMY_LEVEL_REPORT`):

- Sweeps 48 sessions × 26 weeks of offers. Every offer leads at least one creature, with a tier-1 company of the hero's faction first. Level shares stay within 80–93% / 5–16% / 1–6%, and two veterans in one week stay rare (the places roll independently). Offers are stable across re-reads and within the week. Every hero in `content/heroes.json` has a starting army.
- Hires both places for many weeks through `recruit_hero_at_town`. Each hero gets exactly the offered army and level, with experience, command gains, specialties, level-up state and full mana consistent with `HeroProgressionRules`. Hiring one place never rerolls the other.
- Checks save round trips (`SaveService` restore and `to_dict`/`from_dict`), old-save migration of empty-army player heroes (primary and reserve) and of an AI raid commander with an empty host, refused last-company transfers (town, slot, field) and the town-defense floor.
- Opens the tavern popout through the real Town hotspot route at 1280×720 and 1920×1080. The cards show the offer's level and army portraits without a scrollbar, stay the same on refresh and later in the week, and hiring from the card delivers that level and army. Set `HERO_HIRE_CAPTURE_DIR` and run windowed to save the popout.
