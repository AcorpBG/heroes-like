# Hero Exchange Screen

Owner feedback (2026-10-07): overworld hero trading was a text drop-down of
orders. It is replaced by a HoMM-style meeting screen.

## Behaviour

- Walking onto a friendly commander, the `Meet` context action, or a `Meet <name>`
  button in the Command drawer opens `scenes/overworld/HeroExchangeScreen.gd`: a
  focused modal over the dimmed map. The active commander stands left, the partner
  right. With several partners on the tile, the spine lists them for switching.
- Each side shows portrait, name, level, archetype, attack/defense/power/knowledge
  (artifact and specialty bonuses included), mana and movement, the seven army slots,
  the five equipment slots, a paged backpack strip and the spells the partner does
  not know yet. No scroll containers.
- Army: click a stack, then a slot. An empty slot takes the stack, the same creature
  merges, a different creature swaps. Drag and drop does the same. Shift-click,
  Shift-drop or the `Split` toggle opens an amount slider (1 to count-1) for a split
  into an empty slot or the same creature on either hero. Legal targets are outlined;
  hovering a target explains the order or why it is refused.
- `All →` / `← All` move every troop to the other hero: stacks merge into the same
  creature or take a free slot (their own index first). If that would empty the
  giver, one creature of its lowest-tier stack stays behind (HoMM3 HD-style).
- Artifacts: a click hands the artifact to the partner (matching empty slot,
  otherwise backpack). Dropping on an equipment slot equips it there if the slot
  type fits; the item already worn goes to that hero's backpack, or swaps between
  the two trinket slots. Dropping on a backpack cell stows it. `All →` / `← All`
  hand over every artifact the receiver does not already own.
- Spells: a click on a spell icon teaches it to the partner; the teacher keeps it.
- `Done` or Escape closes. Escape first closes the split slider, then clears the
  selection.

## Rules

- The screen only emits orders (`HeroCommandRules.field_*_action_id`).
  `OverworldShell` commits each one through `OverworldRules.perform_rendezvous_action`,
  which finalizes the action (scenario evaluation) and re-renders the screen from
  `HeroCommandRules.field_exchange_state`.
- Slot orders use `HeroCommandRules.manage_army_slots`, which now accepts a commander
  sharing the active commander's tile as a holder. Cross-hero orders must include
  the active commander.
- A commander never ends with zero creatures (`_transfer_empties_hero_army`); the
  refusal message is shown in the footer.
- New rules: `move_all_field_troops`, `place_field_artifact` (slot-precise, uses
  `ArtifactRules.equip_artifact_in_slot`), `move_all_field_artifacts`. Movement
  deficits from movement artifacts are preserved like the existing handoff.
- No save-state shape change: armies keep `slot_index`, artifacts keep
  `equipped`/`inventory`.

## Validation

- `tests/hero_exchange_screen_report.tscn` drives the real screen inside
  `OverworldShell`: move, refused last-stack move with reason, keyboard merge, swap,
  Shift-split, Split-button split, drag & drop, move-all both ways, artifact click,
  drag to backpack, incompatible-slot refusal, own-gear equip, slot-precise
  displacement, move-all artifacts, spell teaching, Escape/Done, Meet button and
  context action, partner switch, and a manual save round trip. Layout checks at
  1920x1080 and 1280x720 (panel inside the viewport, no scroll containers).
  Screenshots: set `HEROES_HERO_EXCHANGE_CAPTURE_DIR` and run windowed.
- `hero_field_rendezvous_{army,artifact}_transfer_report` and
  `hero_field_rendezvous_spell_sharing_report` check the screen instead of the old
  selector.

## Follow-ups

- Two heroes stationed in the same town still trade through the Town army bar
  (garrison + stationed heroes); a town meeting could reuse this screen.
- No right-click creature/artifact detail card yet; tooltips carry the details.
