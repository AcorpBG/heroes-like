# Battle screen and battle flow rework

Slice: `battle-rework-design-20261009` (owner request, 2026-10-09: "We need to completely rework the BattleScreen and how battles play."). The owner signed off the mockup on 2026-10-09, accepted every recommended decision and asked for the right-hand hero to face the battlefield; the implementation slices below are being built in order.

Mockup (pass 2, signed off): https://claude.ai/artifact/Hy6UZnkYaLjXSwsAhqtsBF

## The owner's points

1. The battle shows in a small window, which breaks immersion.
2. Spells are cast by the units, wasting their turn.
3. The hero who actually casts the spells is not shown.
4. The battle order is shown only for the current turn; it should be updated all the time.
5. There is no Wait command.
6. A melee unit cannot choose the hex it ends on when it attacks.
7. Holding the right mouse button over a stack should show a preview with its details.
8. When a stack is selected and the pointer is over an enemy, the cursor should be a sword or an arrow (melee or ranged attack) with the estimated damage range in units.
9. Ranged stacks should show their shots left, and every stack its retaliations left.
10. The ground tiles need work, and blocking objects should exist.
11. It should be visible which enemy stacks are ranged and which are melee.

## Today's battle

Code facts at `9ad02be62`. BR = `scripts/core/BattleRules.gd`, BV = `scenes/battle/BattleBoardView.gd`, BS = `scenes/battle/BattleShell.gd`, TS = `scenes/battle/BattleShell.tscn`.

1. **Small window.** The board is the `BattleBoard` control (TS:277) in a framed panel between the banner (TS:53), a log row (BS:221) and a two-row footer with the action and system panels (TS:550). The hex grid is fitted inside the board at about 1.8:1, limited by its height (BV:5263-5269). At 1920x1080 the grid covers roughly 940x600 px, about a quarter of the screen, and units stand about 90 px tall; the rest is chrome and empty terrain. A Tactical Details sidebar (TS:345) is hidden by default.
2. **Spells end the stack's turn.** The commander already supplies the mana and spell power, and the once-per-round limit per side exists (`COMMANDER_SPELL_CAST_ROUNDS_KEY`, BR:72; `_commander_spell_cast_this_round`, BR:8658). But casting is offered only on one of the player's stack turns (`get_spell_actions`, BR:2187), the active stack plays the cast (`cast_player_spell`, BR:6055), and the cast ends that stack's turn (`return _complete_action(...)`, BR:6187, which calls `advance_turn`, BR:6688).
3. **No hero on the field.** BV has no hero or commander references. Hero data shows only in the hidden sidebar's command panel (BS:1937) and in the Spellbook dialog (BS:2409).
4. **Turn order for the current round only.** The board strip shows `upcoming_actor_ids(battle, 5)` (BR:2515, through `_turn_strip_entries`, BV:4632): at most five stacks still to act this round, and its comment rules out next-round ordering (BR:2513-2514). The order comes from `_sorted_turn_order` (BR:9412) in `_prepare_round` (BR:9369): initiative, then speed, then the player first; `_resort_remaining_turn_order` (BR:10305) re-sorts the rest of a round when initiative changes.
5. **No Wait.** Defend is worded as "the hold/wait order" (BR:5621). The orders are advance, strike, shoot, defend, retreat, surrender, move (which ends the turn) and cast (`perform_player_action`, BR:6231; `move_active_stack_to_hex`, BR:6189).
6. **The approach hex is automatic.** `melee_approach_destination` (BR:2052) takes the reachable cell next to the target with the fewest steps, ties going to the first found; `_apply_melee_approach` (BR:6382) applies it. The player only sees it as an END ring.
7. **No right-button details.** `_gui_input` (BV:303-324) handles pointer motion and the left button only. Hover tooltips show intent text, not stats (`_stack_board_tooltip`, BV:5702).
8. **No attack cursors; the forecast sits far from the pointer.** The only cursor is the global arrow (`_sync_pointer_cursor`, `scripts/ui/FrontierVisualKit.gd:269`). `attack_consequence_preview` (BR:2532) already returns the damage, losses and retaliation ranges and `spell_consequence_preview` (BR:2634) the spell outcome, but both are drawn in a caption box at the bottom of the board (BV:4739-4749).
9. **Shots and retaliations are hidden.** `shots_remaining`, `retaliations` and `retaliations_left` (BR:8555-8557) reset each round and show only in text summaries (`_stack_summary_line`, BR:15165) in the hidden rosters and the sidebar.
10. **Plain ground, no obstacles.** `_draw_terrain` (BV:2139) lays a terrain texture under the field plus hex tiles at 0.24 alpha; `_draw_hex_grid` (BV:2769) tints columns by distance band. Movement checks only bounds and occupancy; field objectives are markers that block nothing.
11. **Ranged and melee look alike.** A stack's plate shows only its name (BV:6011); the bow glyph appears only for units without art (BV:3048).

Also relevant:
- The board is 11x7 (BR:76-77), pointy-top hexes with odd rows shifted right (`_hex_neighbors`, BR:8875). Deployment uses columns 4, 3, 1 against 5, 7, 9, picked by the starting distance band (`_deployment_column`, BR:8727; `_starting_distance_for_encounter`, BR:13654), so the armies usually start in columns 3 and 7.
- The legacy distance band `battle["distance"]` (0-2, `_distance_band_from_hex_distance`, BR:8956; `_sync_distance_from_hexes`, BR:8963) still drives Advance (`_best_advance_destination`, BR:8971), the movement gate, the shot penalty (a shot at band 0 does x0.6, BR:9572-9573), most AI scoring and the column tints.
- Spell effects count the affected stack's turns (`spend_effect_turns`, BR:10274, called from `advance_turn`); an effect landing on the active stack skips the current turn (`skip_current_turn`, BR:10261-10262). Ability and town effects still count rounds.
- Retreat (`_finalize_retreat`, BR:7506), Surrender (`_finalize_surrender`, BR:7546) and Quick Resolve (`resolve_active_battle`, `scripts/core/BattleAutoResolveRules.gd:124`) exist.

## Design

The mockup shows every point below; "Mockup:" says where to look.

| # | Owner point | Design answer | Slice |
|---|---|---|---|
| 1 | Small battle window | D1 full-screen battlefield | fullscreen-screen |
| 2 | Units waste their turn casting | D3 the hero casts as a free action | hero-casting |
| 3 | The casting hero is not shown | D2 heroes stand on the field | fullscreen-screen |
| 4 | Turn order only for the current turn | D4 live ribbon | wait-turn-order |
| 5 | No Wait | D5 Wait | wait-turn-order |
| 6 | Melee end hex cannot be chosen | D6 directional approach | melee-approach, cursor-forecast |
| 7 | No right-button details | D7 details cards | plates-details |
| 8 | Sword or arrow cursor with damage | D8 cursors and forecast badge | cursor-forecast |
| 9 | Shots and retaliations not shown | D9 stack plates | plates-details |
| 10 | Ground tiles, blocking objects | D10 painted ground and obstacles | board-obstacles, battlefield-art |
| 11 | Ranged and melee look alike | D9 bow and sword icons | plates-details |

**D1 Full-screen battlefield.** The battle is one painted scene across the whole window. The board is scaled to a central field (about 74% of the width and 76% of the height); the heroes stand at the left and right edges, the ribbon runs along the top edge and the command bar sits at the bottom edge. No sidebars, caption plates or text panels over the field. Mockup: the whole screen; Board in the mockup pill compares 11x9 (proposed), 11x7 (today) and 15x11.

**D2 Heroes on the field.** Both commanding heroes stand beside their armies, full figure, each with a small plate: crest, name, mana bar, "Spell ready" or "Spell cast this round". Clicking the own hero or its plate, or pressing S, opens the spellbook; the hero glows while a cast is available and plays the cast, and a bolt flies from the hero to the target. Holding the right button on a hero or plate shows the hero card. An army without a hero (neutral guards) has no figure. Mockup: Lyra on the left, Vaska on the right.

Found while building the hero casting (2026-10-09): every encounter in content names an `enemy_commander` (204 of 204, 116 with starting spells), and a battle keeps it as the enemy hero, so guards have a commander who casts by the same rule as a hero. In a 111-battle benchmark on four generated small maps none of them knew a battle spell. Settled in the full-screen slice: only a hero from the content roster stands as a figure; a town captain or a guard's commander has none and shows only a plate, and only when it knows battle spells, so its casts still name it.

**D3 The hero casts and the stack keeps its turn.** One spell per round per side, cast by the hero during any of that side's stack turns, as a free action: the active stack then still moves, attacks, shoots, waits or defends. The cast leaves the stack's actions and becomes the hero's; creature abilities stay with the creatures. The enemy hero follows the same rule. Mockup: cast Cinder Burst, then attack with the same stack.

**D4 Live turn ribbon.** The ribbon always shows the active stack (large chip), the rest of this round in order, the waiting stacks, then "Round N+1" with the predicted order. It re-sorts at once when initiative changes (haste, Staggered) and when stacks die or wait, and the prediction includes effects running out. Chips carry the side colour, count, a bow or sword badge and a wait badge. Hovering a chip lights its stack and the other way round; holding the right button on a chip shows the stack card. Mockup: the top edge.

**D5 Wait.** Wait (W), once per round: the stack moves to the waiting segment and acts after every stack that has not waited, slowest first (HoMM3). A stack that waited cannot wait again that round. Defend (D) stays. Mockup: press W.

**D6 Directional melee approach.** With a melee stack active, where the pointer sits around an enemy picks the hex the attacker strikes from (six sides; it snaps to the nearest legal side). A ghost of the attacker stands on that hex, dots show the path, the sword cursor points at the struck side and the forecast says how far it walks; Q and E cycle through the legal sides. Two-hex attackers pick a head or tail placement. Rooted stacks strike only from where they stand. Mockup: point around an enemy with River Guard.

**D7 Right-button details.** Holding the right button on a stack, ribbon chip, hero or hero plate opens a card beside it; releasing closes it. Stack card: portrait, count, faction, tier, ranged or melee, large; top creature health and stack health; attack, defense, damage, health, speed and initiative with modifier deltas; shots and strike-backs left; cohesion and momentum; abilities; effects with turns left; waiting or defending. Hero card: portrait, class, mana, attack, defense, power, knowledge, specialty, spells. Mockup: hold the right button on any stack.

**D8 Cursors and forecast badge.** Sword (melee, turned toward the struck side), arrow (shot), broken arrow (penalised shot), move, spell, blocked, info. A small badge beside the cursor: "Kills 3-5" with "50-76 damage", then "Strikes back: lose 1-4 (12-41 damage)" or "No retaliation (reason)", then the steps; shots add "shots 8 -> 7"; spells show their damage and kills or their effect and turns. Blocked hexes say why. The first few hovers over a stack hint "Hold the right button for details". Mockup: hover enemies with a melee and a ranged stack.

**D9 Stack plates.** Every stack has a compact plate at its feet: side colour, a bow or sword icon, the count, shots left for ranged stacks, one pip per strike-back left this round (dim once spent), status icons, a wait or defend flag; the active stack's plate is lit. The bow or sword icon is also on ribbon chips, cards and the result screen. Mockup: every plate.

**D10 Painted ground and obstacles.** One painted battlefield per terrain, with a clear centre for the board and scenery at the edges where the heroes stand. The grid is a light etched overlay (Options: Full, Range only, Off). Obstacles are painted props on one or two hexes, chosen per battle from the terrain's set by the battle seed; they block movement and standing, never sit on deployment columns and always leave a path between the armies. Mockup: rocks and deadwood on the meadow.

**D11 Command bar.** Bottom centre, compact: Options, Surrender, Retreat, Auto | the latest log line (click: full log) | Spellbook with a mana badge, Wait, Defend. Hotkeys: Esc options, S or C spellbook, W wait, D or Space defend, A auto, R retreat, Q and E approach side, Ctrl to strike in melee with a shooter. Save, settings and the main menu move into Options. Mockup: the bottom edge.

**D12 Single-click orders.** Hovering already shows the whole outcome (cursor, ghost, path, forecast), so one click commits; no staged confirmation. Retreat and Surrender still ask.

**D13 Feedback.** Damage floaters ("-66", "5 killed") over the target, death animations, the log line and a short banner for rounds and casts. Battle speed Normal, Fast or Instant in Options.

**D14 Result.** A compact panel over the field: Victory, Defeat, Retreat or Surrender, one line of story, both sides' losses as unit icons with counts, then View the field and Continue.

**D15 Deployment.** Each army stands on its own edge: the first column (two-hex units on the first two), the enemy mirrored on the last; rows spread over the board height (11x9: rows 0, 2, 3, 5, 6, 8).

**D16 Retired.** The distance bands, the battle sidebars and caption plates, staged confirmations, and casting as a stack action.

## Rule changes

Rules stay in `BattleRules` and `BattleAiRules`; the screen only asks and shows. The AI plays by the same rules as the player.

1. **Board**: 11x9 (one constant pair), edge deployment and obstacle cells in the battle state, saved and loaded with it. Reachability, approach, placement and the AI treat obstacle cells like occupied ones. The distance bands go; the x0.6 shot penalty applies to a shooter next to an enemy instead of band 0. Obstacles are 2-4 rocks or deadwood of one or two hexes, seeded from the combat seed and the terrain with their own generator, so the damage rolls do not change. They stay off each army's two edge columns, never touch each other and always leave a two-hex body a way across. Town battles keep an open field. Advance walks toward the nearest enemy as far as the stack's movement allows. It stops next to the enemy for melee, two hexes away for reach, and out of contact for a shooter with shots. Until the AI and balance slice, the old band survives only as a value derived from the stacks' positions, which field objectives and AI scoring still read. It no longer sets up the battle or decides movement or shots.
2. **Wait**: a per-round waited flag and a waiting queue after the main order, slowest first; the round ends when both are empty. Waiting does not spend the stack's turn, so its effects do not count down. A turn-order forecast returns this round, the waiting queue and the predicted next round. The computer waits with a melee stack that cannot reach an enemy this turn while enemy stacks are still to act.
3. **Hero casting** (built): the cast is the hero's free action. `cast_player_spell` is refused outside the player's stack turns and no longer advances the turn, so the active stack still gives its order; the once-per-round limit, the mana and the spell power stay as they are. The cast's events name the hero (`hero:player`, `hero:enemy`, `BattleRules.hero_actor_id`), so the log, the playback and the board show the hero as the caster and leave the active stack still; the casting hero's figure rises and flares and effects that travel start from it; a commander without a figure casts from half a hex past its army's edge. The enemy hero casts at most once per round, at the start of one of its stacks' turns, and that stack then gives its own order (`_run_enemy_turn`). The AI casts a spell that destroys its target, or one that scores at least the conservation bar (damage 2.0, control 2.25, recovery and cleansing 1.0, buffs 1.75, all 0.75 lower for a magic hero), and holds back a damage or control spell on a stack its own attack would destroy (`BattleAiRules._hero_cast_worthwhile`); the side Quick Resolve or auto-resolve plays casts a buff only while its stacks are under pressure. Quick Resolve and the computer players' auto-resolve cast and then give the same stack its order.
4. **Effect turns**: today's rule that an effect landing on the active stack does not spend its current turn (`docs/battle-spell-effects.md`) now also covers hero casts, which no longer end that turn: a haste cast before moving speeds up this move and the next turn. Players read it as "until the end of its next turn".
5. **Melee orders** (built): `melee_approach_cells` lists every hex a stack can strike a target from this turn: where it stands when it can already strike from there (two hexes off counts with reach or a hookline), then each hex next to the target it can reach, in walking order. A stack that walks always ends next to the target, so reach strikes from two hexes off only from where the stack stands, as before. A two-hex body lists each placement by its head's hex and says whether its head or its tail strikes (`strike_part`); a rooted stack strikes only from where it stands. A strike order can name its hex (`perform_player_action(session, "strike", approach)`, or the destination of `perform_presented_action`); a hex not on the list is refused and changes nothing. Without one, today's nearest-cell choice applies (`melee_approach_destination`); the screen sends none until the cursor slice. The computer picks among the listed hexes by the expected trade (`BattleAiRules.choose_melee_approach`): the units it destroys times their damage, minus the strike-back's, plus a quarter of the volley of each enemy shooter it ends up next to (whose shots then take the x0.6 penalty); ties go to the shorter walk. The enemy's strike and advance orders and the strikes of Quick Resolve and auto-resolve use that choice, so a stack with reach facing a target without reach strikes from where it stands instead of stepping in, and a stack steps around its target to stand next to a shooter. In a 110-battle benchmark on four generated small maps, the side Quick Resolve plays won 35 battles instead of 38: the guards' melee stacks gain the most. Quick Resolve's advance still only walks, where the enemy's advance walks and strikes; the AI and balance slice evens that out.
6. **Previews**: `attack_consequence_preview` and `spell_consequence_preview` grow into one hover forecast: damage and kill range, strike-back range or why there is none, shots after, path and steps for the chosen approach, or why the order is illegal. They never draw from the battle RNG.

## Implementation slices

Built in this order after the owner's sign-off (2026-10-09). Validation uses battles from generated maps (authored scenarios are archived) and runs on Windows and Linux.

| Order | Slice | Scope | Validation |
|---|---|---|---|
| 1 | `battle-rework-board-obstacles-20261009` | 11x9, edge deployment, obstacles in rules, distance bands retired, save/load | focused report: blocked cells, routing, same layout per seed, save/load; AI benchmark |
| 2 | `battle-rework-wait-turn-order-20261009` | Wait, waiting queue, turn-order forecast, AI waiting | focused report: order, no second wait, forecast equals the actual next round, save/load mid-wait |
| 3 | `battle-rework-hero-casting-20261009` | the hero casts once per round as a free action, effect turns, AI casting | focused report: turn kept, second cast refused, mana spent once, effect turns; spell effects and stat scaling reports; AI benchmark |
| 4 | `battle-rework-melee-approach-20261009` | legal approach cells, melee order with an approach cell, AI approach scoring | focused report: every legal side, illegal ones refused, two-hex, Rooted, the walk and strike playback (the readability regression runs on the archived River Pass scenario) |
| 5 | `battle-rework-fullscreen-screen-20261009` | full-screen composition, heroes on the field, ribbon, command bar, result panel; sidebars and confirmations retired | captures at 1920x1080 and 1280x720 on Windows and Linux; a whole battle by mouse and by keyboard |
| 6 | `battle-rework-cursor-forecast-20261009` | cursors, forecast badge, directional approach, spell targeting | forecast bounds equal the resolved damage bounds; captures of every cursor |
| 7 | `battle-rework-plates-details-20261009` | plates with role, shots, strike-back pips, statuses and flags; right-button cards | card values equal rules values; captures |
| 8 | `battle-rework-battlefield-art-20261009` | painted battlefield and obstacle props per terrain, grid and speed options | provenance, captures per terrain, import settings, package size |
| 9 | `battle-rework-ai-balance-20261009` | AI and balance for the new flow, Auto battle, auto-resolve parity | AI benchmark, AI-vs-AI generated-map matches, owner playtest |

Slices 1-4 change rules and can land one by one under today's screen, keeping the game playable. Slice 5 replaces the screen, and slices 6 and 7 build on it. Slice 8 can run beside them. Slice 9 closes the rework.

**Full-screen screen** (built, slice 5). The board and a HUD layer fill the window, and the HUD lets the pointer through to the field. The board draws the battlefield fitted to the window, both hero figures at the field's edges and the turn ribbon along the top edge. The HUD holds the round banner, the hero plates, the command bar and three popovers: Options, Spellbook and Log. It scales with the smaller of width/1920 and height/1080 times the UI scale setting, so at 1280x720 it draws at two thirds of its size.
- Heroes: a hero from the content roster stands as its adventure-map figure, else its faction's (`BattleHeroFigure`, no new art), the enemy's mirrored. Its plate shows the portrait or crest, the name, a mana bar and whether it can cast. Clicking the own hero or its plate, or pressing S or C, opens the spellbook.
- Ribbon: the active stack's large chip, the rest of the round, the waiting stacks, then the next round from the turn-order forecast. Chips show the side colour, the count and a bow or sword badge; hovering one names its stack.
- Command bar: Options, Surrender, Retreat, Auto battle and Quick Resolve; the latest log line (a click opens the full log); Spellbook with the mana badge, Wait and Defend. Options holds the battle speed (Normal, Fast, Instant), saving, Settings and the main menu. Quick Resolve shows only before the player's first order (`BattleRules.record_player_order`, `player_has_given_orders`). Auto battle gives the player's orders with Quick Resolve's choices (`BattleAutoResolveRules.player_autoplay_decision`, with the AI's approach hex) until it is toggled off (A) or the player gives an order.
- Orders take a single click; Retreat, Surrender and Quick Resolve still ask. Esc puts away a spell being aimed, else closes a popover, else opens Options; an open dialog keeps its own keys. The spellbook popover lists the hero's battle spells with icon and cost, and why one cannot be cast; choosing one lights its targets on the field. It replaces the shared spellbook dialog in battle.
- Result: a compact panel over the darkened field with the outcome, the encounter and rounds, one line of story, both sides' losses as unit icons with counts, rewards and forces, then View the field and Continue. `AppRouter.go_to_battle_report` and `route_checkpointed_battle_resolution` take `in_place`, which saves and records the route without leaving the battle scene. A save loaded with a pending result still opens the battle report screen.
- Retired: the sidebars and their tabs, the footer and action guide, the briefing, risk, consequence, timing and initiative panels, the rosters, the spellbook dialog, staged confirmations, the stacks' health bars and captions (the count stays on a small plate until the plates slice), and the intent forecast the shell rebuilt on every refresh. `tests/validate_repo.py` drops the validators of the retired panels and checks the new composition in `validate_battle_fullscreen_composition`.
- Validation: `tests/battle_screen_report.tscn` on a generated map captures the screen at 1920x1080 and 1280x720, checks the layout at 2560x1080 too, plays a whole battle by mouse and one by keyboard, and covers Auto battle, Quick Resolve, the result and Continue. It runs on Windows and on Linux (Vulkan on llvmpipe under xvfb), together with the obstacle, wait, casting, approach and living-count reports.
- Left for later: the shot forecast still names an end hex, and the cursor does not pick the approach yet (Q, E and Ctrl; cursor slice). Plates with role, shots and strike-back pips come with the plates slice; the legacy terrain-context summary keys go with the battlefield art slice. Tests built on authored scenarios that still expect the retired panels stay as they are for the authored-scenario rework: `battle_controller_board_navigation_smoke`, `active_play_keyboard_focus_smoke`, `town_battle_visual_smoke`, `ui_runtime_skin_visual_report`, `battle_layout_smoke`, `active_play_settings_runtime_report`, and the battle parts of `spell_school_icon_runtime_report` and `battle_status_effect_badge_runtime_report`.

The sword cursor turns toward the struck side and a system cursor cannot rotate, so the battle view draws its own cursor and badge over the field and hides the system cursor there. The rework is GDScript and art only, with no native code, so Windows and Linux behave the same.

## Owner decisions

Decided 2026-10-09: every recommendation accepted.

| Decision | Decided | In the mockup |
|---|---|---|
| Board size | 11x9: room to move around obstacles while units stay large; 15x11 makes units small | Board button |
| Waiting order | slowest first, as in HoMM3 | W |
| Obstacles and shots | obstacles block movement only, not shots | the rocks |
| Order confirmation | single click; the hover shows everything | any order |
| Deployment | army edges instead of today's spread columns | the start |
| Shooter next to an enemy | keep today's x0.6 shot; Ctrl strikes in melee instead | Ember Archer next to an enemy |
| Effects on the active stack | the current turn does not count | cast a buff, then hold the right button on the stack |
| Hero figures | standing figures facing the battlefield (the right-hand hero mirrored); mounted ones could come later | the heroes |
| Auto | an Auto battle toggle on the command bar; Quick Resolve stays before the battle | A |

## Mockup

https://claude.ai/artifact/Hy6UZnkYaLjXSwsAhqtsBF (private to the owner; pass 2 mirrors the right-hand hero). A playable HTML page, not game code: the game's unit sheets, hero figures, obstacles, spell icons and effects on a painted meadow, a simplified damage model (count, damage range and the attack/defense curve), a simple AI, and creature abilities listed but not simulated. The heroes get extra mana so the magic shows. N shows numbered notes for the eleven points; Board switches between 11x9, 11x7 and 15x11; Options (Esc) sets the speed and the grid.
