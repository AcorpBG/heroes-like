# Town building popouts

Slices: `ux-town-building-popouts-20261006` (owner-directed UI, 2026-10-06) `ux-town-popouts-no-scroll-tavern-rotation-20261007` (owner follow-up, 2026-10-07: no scrolling, two-hero weekly tavern), `ux-muster-hall-recruit-cards-20261007` (owner follow-up, 2026-10-07: Muster Hall uses the dwelling recruit cards) and the 2026-10-07 market follow-up (one window for the market and magic guild, see `docs/town-market.md`).

Clicking a built building in the Town scene opens a popout made for that building instead of a generic information sheet. The main building still opens the full-screen construction board. The popout is the only window for the market and the magic guild: the Trade and Spells commands open the same popouts, and are disabled with a hint until the building stands.

## Layout

Popouts fit on screen without scrolling at 1280×720 and above:

- A compact header row: the building's painting, its kind and stage, the description and short effect tags (income, defense, readiness, spell level, weekly growth, visit rewards, services).
- Two columns below it. The main column holds the building's own orders; a 372-pixel side column holds its upgrade line. Buildings with no orders of their own use the full width for the upgrade line.
- The magic guild's spell grid reserves room for its largest level, so switching level tabs never resizes the popout.
- Popouts may grow to 1280×900 on large screens and shrink to their content, so plain buildings do not cover the town with an empty sheet. A scrollbar appears only if a window is smaller than the supported 1280×720.

## What each building shows

| Building | Main column |
| --- | --- |
| Creature dwelling | One recruit card per creature the dwelling offers now: portrait, tier and drawn melee/ranged badge, attack, defense, damage, health, speed, initiative, shots and abilities. An amount slider with **Max** sets how many to hire; the button shows the total cost. Stationed troops of the base creature can be upgraded here once the upgraded dwelling stands. |
| Magic guild | Spells by guild level (tabs I–V). Each spell shows its icon, mana, adventure or battle use, school and effect. Built levels list what visiting heroes learn; unbuilt levels are dimmed and name the guild stage that teaches them. |
| Tavern | This week's two heroes: portrait, class, summary, attack, defense, power, knowledge, movement, specialty, battle traits, starting spells and cost, with **Hire**. A full command or short gold disables Hire with the reason. |
| Market | The trading desk: buy and sell for gold, or convert one resource into another (`docs/town-market.md`). |
| Artifact exchange | The week's buy offers and sell orders for the visiting hero. |
| Hero training and faction services | The visit or service order for the visiting hero, disabled once claimed. |
| Every other building | Nothing extra; the upgrade line takes the full width. |

The upgrade line lists the building's stages (built, next, later), the next stage's description, for dwellings the creature's stat gains, the cost with any shortfall, and an **Upgrade** button. When the market can cover the cost a **Trade for it** button opens the market popout; locked or already-built-today states explain why. Exclusive dwellings note the line they were chosen over. Buildings without stages say they have no upgrades.

## Muster Hall

The Muster Hall (Muster command) lists every creature the town can muster with the same recruit card as the dwelling popouts (`scenes/town/TownRecruitCard.gd`): portrait, tier and melee/ranged badge, stats, abilities, reserve and weekly growth, cost each, the amount slider with **Max** and the total-cost **Recruit** button, plus **Trade for it** when the market can cover the price. Muster cards are the compact variant: a smaller portrait, short stat names (ATK, DEF, DMG, HP, SPD, INI) and the badges under the name, two cards per row. A town with a dwelling for every tier musters without scrolling. Stationed-troop upgrade orders stay above the cards. The dwelling popout and the Muster Hall build their cards from the same model row (`TownBuildingPanel.recruit_card`) and recruit through the same order with the chosen amount.

## Tavern rotation

- Every player tavern offers the same two heroes each week, drawn on days 1, 8, 15 and so on from the player faction's hireable heroes (`HeroCommandRules.tavern_offer_ids`).
- The draw shuffles the faction's whole hireable roster with a seed from the session, scenario and week, then takes the first two heroes not already in command. The same save always sees the same pair.
- Hiring a hero leaves that place empty until the next week; the popout shows the empty place and the day the next pair arrives. Only offered heroes can be hired.
- The pair is computed on read and stored only when a hire changes it (`overworld.tavern_rotation`), so looking at the tavern never changes the session.

## Rules and ownership

- `scripts/core/TownBuildingPanel.gd` builds a read-only model from the live rules: the construction board slot (stages, next order, status, cost), the muster catalog, the town spell library per guild level (`TownRules.spell_ids_through_tier`), the weekly tavern offer and the town's service orders. Opening a popout never changes the session.
- `scenes/town/TownPanelWidgets.gd` holds the shared labels, chips, melee/ranged badge, cost rows and stat grids; `scenes/town/TownRecruitCard.gd` is the recruit card used by dwellings and the Muster Hall.
- `scenes/town/TownBuildingPanelView.gd` renders the model and emits intents. `TownShell` runs every order through the existing paths: recruitment with a requested amount (`TownRules.recruit_active_town`), hiring, the construction commit and its scenic presentation, town services and market trades (`TownRules.perform_market_action`). After recruiting, hiring or trading the popout refreshes in place.

## Validation

`tests/town_building_panel_report.tscn` runs every faction town through the real hotspot route (1920×1080 and 1280×720 alternate):

- Opening every popout leaves the session untouched, and no popout needs a scrollbar, including after recruiting, hiring and switching guild levels.
- The dwelling recruits a chosen amount and refreshes; its upgrade is built from the popout, the upgraded dwelling reads complete and offers the stationed-troop upgrade.
- The guild shows five levels whose spells cover the town library once each, switches levels and waits for tomorrow after the day's build.
- The tavern shows exactly this week's two offered heroes, refuses a hero outside the offer, leaves an empty place after a hire, and draws a fresh pair next week.
- Training and artifact services appear and the market trades in its own popout; the fort shows description, effects and its next stage inside the panel.
- The Muster Hall shows one shared recruit card per muster row with the creature name visible, recruits a chosen amount from a card, and still fits without scrolling once every tier has a dwelling.

Set `PANEL_TOWN=<town id>` to run one town. Roster and hero-art reports that hire a specific hero place that hero in the week's offer first.
