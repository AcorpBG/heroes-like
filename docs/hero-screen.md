# Hero menu

Date: 2026-11-10. Slice `ui-hero-menu-rework-20261110`. It replaces the tabbed
sheet of `ui-owned-hero-screen-20260913`.

Owner: the hero menu on the map and in town was terrible. Of three imggen
mockups (one page with everything, a showpiece with a large portrait, a column at
the side) the owner picked the showpiece, with two changes: the artifacts are
laid out on a figure, as most games do, with more slots than the five in a row;
and a page shows only its own content, never a strip of the other pages.

## The menu

`scenes/shared/HeroSheet.gd`, one window in the information card's frame
(`docs/overworld-info-card.md`), opened from the map (double click or Enter on a
hero in the roster, a click on the hero's own tile, the level-up and spell
buttons) and from a hero in the town's army bar.

- **Left**: the portrait, large, with the name and the line "calling · might or
  magic hero · faction" on its lower edge; the level and the experience bar; the
  four command stats as tiles with an icon (attack and defense count what
  artifacts and specialties add).
- **Right, top**: four round buttons for the pages (Army, Artifacts, Specialties,
  Spells), the meters (movement, mana, scouting), the return button and a Meet
  button for each hero standing on the same tile.
- **Right, below**: the chosen page and nothing else.

Pages:

- **Army**: the seven stacks as large tiles with each unit's close-up and number;
  under them the chosen stack: its picture, tier and kind, the six numbers as
  chips, its abilities. On the map the tiles are the shared army bar
  (`ArmyStackBar`, large tiles): click a stack then a slot, or drag, to move,
  merge or split. Elsewhere they only show.
- **Artifacts**: the figure with a slot where each thing is worn (head, neck,
  cloak, chest, two hands, two rings, feet, a banner beside it), four trinket
  slots, the sets the hero has pieces of, and the backpack as a row along the
  foot. An empty slot shows the outline of what it takes. The card at the right
  reads whatever the mouse is over, at once: what it gives, its story, its
  family, and for a backpack item what wearing it would change; the tile's
  tooltip says the same. A click picks a slot or an item, and the card returns to
  it when the mouse leaves, with its Wear, Swap in or Stow button; a double click
  does the same. Picking an empty slot dims what in the backpack does not fit it.
  Artifacts are dragged: from the backpack onto a slot of their kind, from a slot
  to another slot of its kind (two worn there swap), and from a slot onto the
  backpack. While one is dragged the slots it fits stay lit and the others dim; a
  slot of another kind refuses it.
- **Specialties**: pending choices first, as buttons; then a card for each
  learned specialty with its insignia, rank and what it gives; then the hero's
  identity line, home ground and leanings.
- **Spells**: the known spells as icons, map spells and battle spells apart; the
  card at the right reads the spell under the mouse, else the chosen one (what it
  does, its cost, whether it can be cast now) and casts a map spell.

The menu never changes the session: it emits what was asked and its owning screen
runs the order and hands back a fresh snapshot (`refresh_hero`), which keeps the
page and what was picked. A drop onto a slot is the order
`wear_artifact:<slot>:<artifact id>` (`ArtifactRules.perform_management_action`,
native: into that slot from the backpack or from another slot); a drop onto the
backpack is the stow order. Escape closes it; arrow keys and Tab cannot carry the
focus to the screen behind it.

## In town

The town's menu was read-only. It now takes the town's own artifact and
specialty orders (`TownRules.get_artifact_actions`, `get_specialty_actions`) for
the hero those orders act on, the active hero, so artifacts are worn and stowed
and specialties chosen there with the town's rules and its result feedback. A
hero in the garrison who is not the active hero is still only shown. Troops are
moved on the town's army bar, and map spells are cast on the map.

## Artifact slots

A hero wore five artifacts: boots, banner, armor and two trinkets. A hero now has
fourteen slots of nine kinds:

| Kind (an artifact's `slot`) | Slots | Artifacts today |
| --- | --- | --- |
| `head` | head | 1 |
| `neck` | neck | 4 |
| `cloak` | cloak | 3 |
| `armor` (chest) | armor | 4 |
| `hand` | hand, hand_2 | 18 |
| `ring` | ring, ring_2 | 1 |
| `boots` (feet) | boots | 3 |
| `banner` | banner | 11 |
| `trinket` | trinket, trinket_2, trinket_3, trinket_4 | 24, and every spell scroll |

27 of the 69 artifacts moved to the kind their description names: the crown ring
from banner to head; the gorget, the beads, the tally chain and the crown-tooth
to neck; the three mantles to cloak; the stone ring to ring; and the compasses,
lanterns, sextant, astrolabes, dial, lens, duelglass, rod, horn, fan, tuning fork,
censer and signal pennon to hand. Head and ring have one artifact each until more
are written.

The rules' copy of the lists is `artifact_slots.hpp`, used by every rule that
walks a hero's equipment (bonuses, sets, wearing, the computer player's choice of
what to wear, worn scrolls); `ArtifactRules.gd` mirrors it for the screens. The
five old slots come first in the list, so a saved hero reads as before; an
artifact saved in a slot of its old kind moves to a free slot of its new kind
when the hero is read, or to the backpack if there is none. A hero can now wear
four scrolls. The hero exchange screen shows the fourteen slots in two rows.

## Art

`art/ui/runtime/hero_menu`: twelve gold emblems (the pages, the stats, the
meters, a laurel), ten outlines for empty slots and the figure, cut by
`tools/build_hero_menu_icons.py` from three imggen sheets
(`art/ui/source/generated/hero_menu_20261110`, with the mockup; the paintings are
in the source art archive).

## Not in this slice

- An artifact placed by dragging plays no cue on the map or in town, as the
  button's orders do.
- The army bar's All, Half, One and Exact buttons and the hero exchange screen
  keep their older look.
- At a window lower than about 720 pixels the artifact page is taller than the
  window.
- The old sheet's layout and focus tests (`tests/hero_sheet_regression.py` and
  the like) were not run or updated.

## Validation

In the game at 1920 by 1080, on a generated map: every page on the map; a stack
picked; an artifact worn from the backpack into the head slot and one stowed in
town, each through the rules; an empty slot picked; the town's menu; the hero
exchange screen with two heroes; artifacts dragged with the mouse from the
backpack to a slot, to a slot of another kind (refused), between two hands (they
swap), between trinket slots and back to the backpack, on the map and in town,
and the card reading the item under the mouse. A hero saved with the five old slots and three
moved artifacts read back with each in its new slot. Six seeds played the same in
the game and in the match runner. Content check and core suite.
