# Town building popouts

Slice: `ux-town-building-popouts-20261006` (owner-directed UI, 2026-10-06).

Clicking a built building in the Town scene opens a popout made for that building instead of a generic information sheet. The main building still opens the full-screen construction board.

## What each building shows

Every popout starts with the building's painting, its description and short effect tags (income, defense, readiness, spell level, weekly growth, visit rewards, services). Below that come the building's own orders and its upgrade line.

| Building | Body |
| --- | --- |
| Creature dwelling | One recruit card per creature the dwelling offers now: portrait, tier and drawn melee/ranged badge, attack, defense, damage, health, speed, initiative, shots and abilities. An amount slider with **Max** sets how many to hire; the button shows the total cost. Stationed troops of the base creature can be upgraded here once the upgraded dwelling stands. |
| Magic guild | Spell shelves by guild level (tabs I–V). Each spell shows its icon, mana, adventure or battle use, school and effect. Built levels list what visiting heroes learn; unbuilt levels are dimmed and name the guild stage that teaches them. |
| Tavern | Every hero the player can hire: portrait, class, summary, attack, defense, power, knowledge, movement, specialty, battle traits, starting spells and cost, with **Hire**. A full command or short gold disables Hire with the reason. |
| Market | Exchange tags and an **Open market** hand-off to the full market. |
| Artifact exchange | The week's buy offers and sell orders for the visiting hero. |
| Hero training and faction services | The visit or service order for the visiting hero, disabled once claimed. |
| Every other building | Description, effects and the upgrade line. |

The upgrade line lists the building's stages (built, next, later), the next stage's description, for dwellings the creature change with stat gains, the cost with any shortfall, and an **Upgrade** button. When the market can cover the cost a **Trade for it** button opens the market; locked or already-built-today states explain why. Exclusive dwellings note the line they were chosen over. Buildings without stages say they have no upgrades.

## Rules and ownership

- `scripts/core/TownBuildingPanel.gd` builds a read-only model from the live rules: the construction board slot (stages, next order, status, cost), the muster catalog, the town spell library per guild level (`TownRules.spell_ids_through_tier`), recruitable heroes and the town's service orders. Opening a popout never changes the session.
- `scenes/town/TownBuildingPanelView.gd` renders the model and emits intents. `TownShell` runs every order through the existing paths: recruitment with a requested amount (`TownRules.recruit_active_town`), hiring, the construction commit and its scenic presentation, town services and the market hand-off. After recruiting or hiring the popout refreshes in place.
- Popouts may grow to 1280×900 on large screens and shrink to their content, so plain buildings do not cover the town with an empty sheet.

## Validation

`tests/town_building_panel_report.tscn` runs every faction town through the real hotspot route (1920×1080 and 1280×720 alternate): opening every popout leaves the session untouched; the dwelling recruits a chosen amount and refreshes; its upgrade is built from the popout and the upgraded dwelling reads complete; the guild shows five levels whose spells cover the town library once each, switches levels and waits for tomorrow after the day's build; the tavern hires a hero who then leaves the list; training, artifact and market services appear; the fort shows description, effects and its next stage inside the panel. Set `PANEL_TOWN=<town id>` to run one town.
