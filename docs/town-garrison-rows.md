# Town garrison and visiting rows

Slice: `ux-town-garrison-rows-20261008` (owner request and approved mockup, 2026-10-08).

The Town screen works like HoMM2/HoMM3: two permanent army rows instead of the Town Log & Logistics window, the overworld resource bar in every town view, a list of your towns for switching without the overworld, and a hero sheet one click away. A hero can hold a town's garrison, and the overworld shows it.

## Rules (`HeroCommandRules`)

- Both town heroes stand on the town entrance tile. `town[garrison_hero_id]` names the garrison hero; any other hero of yours on the entrance is the visiting hero (the active one first).
- **Entering an unheld garrison** (`set_town_garrison_hero(session, town, hero_id)`): the town's own garrison troops join the hero's army, same units merging and new units taking free slots. If they do not fit in seven slots the order is refused and nothing changes.
- **Entering a held garrison** swaps the heroes: the old garrison hero steps out to the gate with its own army.
- **Stepping out** (`hero_id` = ""): only when nobody waits at the gate; the hero leaves with its army and the town's garrison row is empty.
- **Walking away** from the entrance ends garrison duty (normalization clears the field).
- **Defense**: the garrison hero defends the town (`town_defending_hero` prefers it unless a caller names a hero), so its army is the town's defense, and recruits go to it.
- **Saves**: `garrison_hero_id` is kept with the town. Old saves migrate once (`overworld.town_garrison_heroes_version`): a town holding two of your heroes gives the garrison to the one not in active use, when the garrison's troops fit.
- `TownRules.set_garrison_hero_in_active_town` is the Town screen's order.

## Town screen (`TownShell`, `TownArmyRows`)

- **Army panel**, bottom left: a 2x2 block of rounded command squares (Build, Muster, Market, Mage Guild; unbuilt ones are dimmed), then the garrison row (garrison hero portrait or an empty "Garrison" square, seven slots) above the visiting row (the hero at the gate or an empty "Gate" square, seven slots). Squares are 70 px.
  - Troops: click a stack, then a slot, to move, merge or swap; Shift opens a split slider; drag and drop works too. Orders go through `TownRules.manage_army_slots_in_active_town`, so a hero is never left without creatures.
  - Heroes: click a portrait to select it, click it again (or double-click) for the hero sheet, click the other portrait (or drag onto it) to move the hero into or out of the garrison or swap them.
  - Escape cancels the split, then a selection, before it returns to the field.
- **Resource bar**: the overworld's stockpile bar along the bottom edge of every town view, above building popouts and the construction screen. The construction board has no resource strip of its own and ends above the bar.
- **Town list**, top right: one thumbnail per owned town with its name overlaid; the current town is outlined. Clicking another town opens it directly (`OverworldRules.set_active_town_visit`).
- **Banner**: Return to Field replaces the old Stores chip.
- **Retired**: the Town Log & Logistics window and its command, the Command card, the footer (Save, Guide, Settings, Main Menu; Escape returns to the field and those stay on the overworld, as in HoMM3), and the stage's "Defending troops" and "Garrison troops" chips (the rows show them).

## Overworld

- A garrison hero is drawn as a round portrait medallion on its town with a "G" badge (`OverworldMapView._draw_garrison_medallion`); the visiting hero still stands at the gate.
- The hero list marks the garrison hero with the same "G" badge.

## Validation

`tests/town_garrison_rows_report.tscn` (58 checks, generated small map): the garrison rules (enter with troop merge, defense, swap, blocked step-out, step-out, refused overflow, walking away), the save round trip and one-time migration, the Town screen (panel, command squares, rows, resource bar above popouts, retired surfaces, banner, town list, stage chips, click-click and split orders, portrait swap, hero sheet, Escape), the construction board (no header resource strip, Close beside Build, board above the resource bar, V town view clear of the rows, Esc and Close), and the overworld medallion index and hero-list badge.

## Follow-ups

- The retired Town Log catalog code is still in `TownShell` behind validation hooks; remove it with the tests that drive it.
- AI towns do not use the garrison row. An idle computer hero parks in its town's doorway instead (one per town) and the town's troops stay in its garrison (`docs/ai-plays-by-player-rules.md`).
