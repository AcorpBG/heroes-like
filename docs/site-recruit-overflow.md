# Full-army site claims

Slice: `gameplay-site-recruit-overflow-20261008` (owner playtest report and decision, 2026-10-08).

## Problem

68 resource sites add troops when claimed (`claim_recruits`), among them the guarded reward sites Glassbound Eyrie and Railblock Camp. A claim was refused as a whole when the troops' new unit types did not all fit in the hero's seven army slots, and the only feedback was a status line, so stepping on a beaten site looked like nothing happened. The game has no other way to dismiss a stack, so the site could stay locked. AI heroes were refused the same way ("capacity blocked").

## Rule (owner choice: "claim, ask to make room")

- A full army never blocks the claim. The site is claimed and pays out gold, resources, experience, artifact, map reveal and route opening as before.
- Troops join as far as they fit: unit types matching a stack merge, new types take free slots in unit-id order (`HeroCommandRules.army_addition_split`).
- Troops without a slot wait in `overworld.pending_site_recruits` (hero, tile, site, troops). A dialog lists them and the hero's stacks:
  - pick a stack and press **Dismiss and take them**: the stack is dismissed and the first waiting troop type takes its slot (`OverworldRules.take_site_recruits_by_dismissing`); if more remain, the dialog returns for them;
  - **Leave them** (or Escape): the waiting troops are lost (`leave_site_recruits`).
- The offer survives a save and reload (the dialog reopens) and ends when the hero walks away or another hero is active.
- The dialog holds overworld movement until answered; a level-up earned from the claim opens after it.
- AI heroes claim the same way: troops that fit join their army, the rest stay behind (`EnemyAdventureRules._apply_resource_site_claim_recruits_to_raid`).
- A free route site (Railblock Camp and other reward camps on a road) now asks to **Claim** and names its reward, instead of "Pay nothing to open it".

## Validation

`tests/site_recruit_overflow_report.tscn` (generated small map): the claim with one and with no free slot, payout, waiting troops, stale answers refused, dismissal into the freed slot, leaving, walking away, save and reload, the AI raid claim, the overworld dialog (opens on a fresh overworld, holds movement, returns for remaining troops, closes on Leave) and the free gate prompt. Also checked on copies of the owner's Day 25 save: Glassbound Eyrie (one free slot, two troop types) and Railblock Camp (gate prompt, then the dialog).
