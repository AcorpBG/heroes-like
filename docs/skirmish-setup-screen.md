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
  troops. The portrait and the card keep one size for every hero (the height of
  the longest text, a magic hero's two specialties), so nothing moves when the
  hero changes; the hero thumbnails and the save cards' portraits are fixed too.
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

Between the title and the launch buttons the setup scrolls when the screen is too
low for it: at the 115% and 130% interface scales, or in a small window. Build &
Play, Built maps and Back stay in view.

## Built maps

`scenes/menus/BuiltMapsDialog.gd`: the maps built earlier, in the card's frame,
newest first. Owner, 2026-11-10: less text, a picture of what the map is.

- At the left a card for each map: a small picture of its surface with your
  start town, its name, the crests of the seats and its size.
- At the right the chosen map: a picture of each level (ground in the minimap's
  colours, obstacles darker, roads, towns: your start town in your seat's colour,
  the neutral towns grey), the commander it was built for, each seat's crest in a ring
  of the seat's colour, and the settings as chips (size, players, levels, water,
  monsters, towns) with the seed under them.
- Play and Close; a double click plays. It plays the chosen map at the difficulty
  the column shows.

`scripts/ui/MapPackagePreview.gd` reads the pictures from the map package (the
terrain and road layers and the objects) and keeps them for the session. A large
package takes a third of a second to load, so the window opens at once and reads
one map each frame, the chosen one first. The seats, hero and settings come from
the entry the rules already list.

The pictures show the whole map's ground, but not where the rivals start: their
start towns are left off (owner, 2026-11-10).

## Save menu

`scenes/menus/SaveListColumn.gd`: the same column. Each save is a card with the
hero's portrait, the slot or its name, the day, faction and difficulty, the hero,
mode and time; the newest is marked. Under the list: the name field of a manual
save, then Load, Delete and Back. The actions are the old board's (`SaveService`
labels, the delete confirmation, the load path); only the view is new.

## Settings

`scenes/menus/SettingsColumn.gd`: the same column (owner, 2026-11-10: the settings
menu in the same style). Four sections of rows:

- **Display**: window, resolution, quality, frame limit, VSync.
- **Sound**: master, music and effects as sliders with their percentage.
- **Game**: battle speed, navigation keys, hero movement keys (opens the keys
  window).
- **Readability**: interface scale, battle shake, colour cues, high contrast,
  reduce motion, reduce flashes, fewer repeat sounds.

A setting with a few values is a row of pills with the chosen one in gold; an
on or off setting is the two pills On and Off. Under the rows a status line (what
was saved, or why not), then Restore defaults, Support bundle and Back. The rows
scroll when the screen is too low for them.

The view is generic: `show_settings` takes sections of rows (choice, switch,
volume, button) and the column emits what was pressed. `MainMenu` builds the rows
from the old board's pickers, toggles and sliders, which stay, hidden, as the
model (`_sync_settings_column`), and a pressed pill goes back through the old
control's own handler, so the rules of the settings are unchanged: display changes
are previewed and kept or reverted, a held volume slider previews and saves once
when let go, Restore defaults asks first. After a confirmation the focus returns
to the column's control that stands for the old one (`_settings_column_control`).

The theme pass of the menu (`_apply_visual_theme`, run when high contrast or the
colour cues change) dressed the dock as the old board again; it now ends by giving
an open column its card frame back, and the settings column rebuilds its rows in
the new colours.

## The windows

Owner, 2026-11-10: the settings window inside a game and the confirmation windows
in the same look.

- **Settings inside a game** (`scenes/shared/ActivePlaySettingsDialog.gd`, opened
  from the map and from a battle): the settings column in the card's frame, with
  the settings that window had (Sound; battle speed; Readability) and Close. Its
  sliders, pickers and toggles stay, hidden, as the model, as in the main menu.
  The window is 620 by 650, less where the screen is smaller; then its rows scroll.
- **Confirmation windows** (`FrontierVisualKit.apply_confirmation_dialog`, every
  window that asks before an action: end turn, restore defaults, keep display
  settings, delete a save, overwrite a save, withdraw, recruit, level up and the
  rest): one card frames the window and its title strip, the title in gold; the
  window's own picture is clear so the card shows through, the content keeps off
  the frame, the buttons have a least size, and the close cross is gone (the
  second button closes). In high contrast the plain panel stays.
- **Hero movement keys**: the card's frame.

In the settings column the arrow keys move along a row and to the chosen value of
the row above or below, Tab goes through every control, and the focus stays in
the column (`SettingsColumn._wire_focus`).

## Not in this slice

- The campaign and guide boards keep the cartography board.
- In high contrast the logo's panel shows behind the top of a column.
- Stats have no icons; the four numbers are labelled in words.
- `tests/menu_outcome_visual_smoke.gd` and other layout tests of the old boards
  were not run or updated; they assert the old dock's coordinates.

## Validation

In the game at 1920 by 1080: the column for Embercourt, Veilmourn (might and magic
heroes), Mireclaw and the random faction; every row driven through its pills; a
map built and started through Build & Play; the built maps window; the save menu
with an autosave and two manual saves, a save renamed and one loaded. Content
check and core suite. For the fixed portrait and the pictured built maps: five
heroes of four factions measured at one portrait size, the window with six maps
of two sizes, one and two levels, and one of them started from it. For the
settings column: every kind of row driven (battle speed, interface scale, colour
cues, high contrast, reduce motion, music volume), the saved values read back from
the settings service, Restore defaults confirmed, a window mode change made by
keyboard and reverted with the focus back on its row, the keys window opened; the
three columns at the 130% interface scale. For the windows: restore defaults,
keep display settings, the keys window, end turn on the map, and the settings
inside a game with a pill, a switch and a volume set and read back, in the normal
look and in high contrast. The battle's windows, the recruit, save and level-up
windows share the function and were not opened.
