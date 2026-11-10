# The map's information card

Slice: `ui-map-info-card-art-20261110` (owner decisions, 2026-11-10).

The hover card and the right-click report of the adventure map
(`docs/overworld-tile-description.md` says what they tell) looked out of place: the
report borrowed the main menu's dark map panel at a fixed 480 by 480 pixels, more
than half of it empty, with its corner ornaments stretched; the hover card was a
flat teal box; and a stack's icon was the whole standing figure shrunk to 36
pixels.

## The look

The owner picked direction B of three mockups made with the imggen skill
(GPT Image 2.6): the sidebar's family, a dark warm lacquer with a thin antique-gold
border and compass-star corners set with a teal gem. The other two were a parchment
field note and a walnut plaque with a crimson banner.

- `art/ui/source/generated/info_card_20261110/` holds the approved mockup, the
  empty panel generated from it, both prompts and `provenance.json`. The PNG
  sources are not tracked (`art/*/source/**/*.png` is ignored); they stay in the
  owner's checkout.
- `tools/build_info_card_panel.py` cuts the two nine-slice frames from the panel:
  `art/ui/runtime/overworld/info_card.png` (corners of 48 px, the report) and
  `info_card_small.png` (corners of 28 px, the hover card). It keeps the four
  corners and takes one strip of each edge and one patch of the middle, so the
  corners are drawn at their own size and only plain lacquer and line stretch.
- `FrontierVisualKit.info_card_style(small)` is the style box; high-contrast mode
  falls back to the plain ink panel.

## The report

`ScoutInspectionDialog` is the card itself: no title bar or close button around it,
440 pixels wide and only as tall as its content (it scrolls only when the content
would pass the screen). Gold title, a muted kind line, thin gold hairlines between
the parts, the status in its tone. Holding the right button still opens it and
letting go still closes it; the Inspect button's version keeps "Return to map".

## The hover card

`OverworldMapView._build_hover_tooltip_card` uses the small frame. The first line is
gold; the status line takes the description's tone (the shell hands the card
`OverworldInspection.hover_card`: the text, the status line's index and the tone).
Other tooltips of the game keep their own card for now.

## Unit icons

The owner chose crops of the existing portraits over newly generated bust icons
(four samples were made; all 232 would have cost about 12 USD).

- `tools/build_unit_bust_regions.py` writes `content/unit_bust_regions.json`: for
  each unit the rectangle of its 384 by 512 portrait an icon shows. A standing
  figure gets a square of 36% of its height, centred on the body and starting just
  above the head (the first solid row in a narrow column over the body, so a weapon
  raised beside the head does not count). A beast, a winged creature or a machine
  (a box wider than 1.2 times its height, or wide where a head would be) shows
  whole. 181 units get a bust, 51 show whole.
- `UnitPortraitTexture.bust_for_unit` draws that rectangle; the report shows it at
  56 pixels in a gold-framed tile on a backing lighter than the card, so a
  dark-cloaked unit keeps its outline.
- The rule misses for about ten units (a wing or a plant crown where it looked for
  a head). A rectangle can be edited by hand in the JSON; list the unit in the
  tool's `OVERRIDES` to keep the edit across runs.

## Validation

Medium land seed 4103 as Embercourt, in the game: the report on an army, a guarded
treasure, a hero-visit building and the Wayside Exchange, and the hover card on
four kinds of object, compared with the approved mockup. All 232 crops were read
on one sheet.
