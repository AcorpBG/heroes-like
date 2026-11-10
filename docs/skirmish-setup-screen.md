# Skirmish setup and save menu

Date: 2026-11-10. Slice `ui-skirmish-setup-rework-20261110`.

Owner: the skirmish and save menus looked terrible, the random map setup most of
all, and hero selection told nothing about a hero's looks, stats, troops or
masteries. Of three imggen mockups (two cards side by side, one column at the
left, the hero as an unframed showpiece) the owner picked the left column; the
maps built earlier go behind a small button.

## The setup column

`scenes/menus/SkirmishSetupColumn.gd` is the view: one tall column at the left
under the game's title, in the information card's frame
(`docs/overworld-info-card.md`), so the painted scene stays in view. Top to
bottom:

- **Faction**: the six crests and a question mark for a random faction; the
  chosen one has a gold ring and its name beside the heading.
- **Hero**: the faction's eleven heroes as portrait thumbnails.
- **Hero card**: the portrait, name, calling and might or magic path, the
  one-line identity, the four command stats, each starting specialty with its
  insignia and what it gives at rank one, the starting spells, and the starting
  troops.
- **The map**: each setting is a row of pills with the chosen one in gold: size,
  players, layout, water, levels, monsters, difficulty; then the seed field (empty
  means a fresh seed) with a Roll button that writes a random one. A row with one
  option is hidden, as its picker was.
- **Build & Play**, **Built maps**, **Back**.

Starting troops come from the rule itself: `HeroCommandRules.starting_army_pool`
(native, `hero_rules_turn.cpp`) says which units `starting_army_for_hero` draws the
first company from, which more a second company can be, and how often the second
comes. The exact army is rolled with the map's seed, so the card shows the pool
and says so.

The main menu keeps the state it had. The pickers of the old board stay, hidden,
as the lists of what can be chosen (the launch tests and `validation_*` calls use
them); `MainMenu._sync_skirmish_setup_column` hands the column their options and
the chosen ids, and a pressed pill goes back through the picker's own handler. The
dock panel is the column for the skirmish tab: its header row, rail slot and inner
board frame are hidden there.

## Built maps

`scenes/menus/BuiltMapsDialog.gd`: the maps built earlier, in the card's frame,
with Play and Close. It plays the chosen map at the difficulty the column shows.

## Save menu

`scenes/menus/SaveListColumn.gd`: the same column. Each save is a card with the
hero's portrait, the slot or its name, the day, faction and difficulty, the hero,
mode and time; the newest is marked. Under the list: the name field of a manual
save, then Load, Delete and Back. The actions are the old board's (`SaveService`
labels, the delete confirmation, the load path); only the view is new.

## Not in this slice

- The campaign, settings and guide boards keep the cartography board.
- Stats have no icons; the four numbers are labelled in words.
- `tests/menu_outcome_visual_smoke.gd` and other layout tests of the old boards
  were not run or updated; they assert the old dock's coordinates.

## Validation

In the game at 1920 by 1080: the column for Embercourt, Veilmourn (might and magic
heroes), Mireclaw and the random faction; every row driven through its pills; a
map built and started through Build & Play; the built maps window; the save menu
with an autosave and two manual saves, a save renamed and one loaded. Content
check and core suite.
