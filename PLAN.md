# PLAN.md

Task: #10184

Reality reset date: 2026-04-16

## Strategy
We are building toward a full, original, release-bound fantasy strategy game, but the current repository is a prototype / pre-alpha foundation, not a playable product and not close to HoMM2/3 parity.

The planning story now changes from "many completed release-facing slices" to "prove one playable scenario, then grow breadth." Existing architecture is useful, but every feature claim must be tied to live-client behavior a real player can exercise.

## Locked Stack
- engine: Godot 4 stable series
- gameplay code: GDScript
- content source of truth: JSON files in `content/`
- save format: versioned JSON snapshots
- primary validation target: the live client, supported by automated checks

## Architecture Guardrails
- Keep simulation and serialization logic outside scene controllers.
- Use stable content ids instead of embedding authored data in saves.
- Autoloads are for cross-cutting services, not for hiding gameplay rules.
- Preserve a clean split between overworld, battle, town, AI, economy, save/load, UI, and content pipeline.
- Treat JSON-authored content as the scalable boundary for factions, heroes, units, spells, artifacts, towns, map objects, scenarios, encounters, and campaigns.
- Keep scenic and play surfaces primary. Do not solve missing usability by stacking text panels over the game.
- Every slice must be judged by live-client player flow, not just by data existence, rule coverage, or smoke-test routing.
- Do not expand broad campaign or faction count until River Pass proves the basic player loop.

## Phase 0: Honest Reset / Parity Ledger / Stop Fake-Complete Language
Status: active reset now becomes the baseline for future work.

Purpose:
- Replace stale implied-completion docs with an honest pre-alpha roadmap.
- Keep the long-term ambition while clearly separating foundations from playability.
- Establish a parity ledger that prevents future docs from claiming parity without evidence.

Execution order:
1. Rewrite `project.md` around the true current state, retained architecture, and staged delivery strategy.
2. Rewrite this plan around phases that start with River Pass manual completion rather than broad release claims.
3. Reset `ops/progress.json` to in-progress status with the active slice focused on River Pass playability and battle/town/UI recovery.
4. Create or maintain a parity ledger in planning docs before future scope expansion. The ledger should track:
   - implemented system
   - live-client usable state
   - manual-play evidence
   - automated coverage
   - known blockers
5. Stop using these labels until proven: release-ready, release-facing, fully playable, HoMM2 parity, HoMM3 parity, complete campaign, complete faction, shippable UX.

Acceptance criteria:
- Docs clearly state the project is prototype / pre-alpha.
- Docs do not claim release readiness.
- The immediate milestone is River Pass manually completable by a real player.
- Progress tracking is no longer marked completed.
- Valid architecture decisions remain visible and usable.

## Phase 1: River Pass Manually Completable End-To-End
Status: immediate active milestone.

Purpose:
- Make one scenario, River Pass, honestly playable from start to finish in the live client.
- Recover the actual player loop before adding more breadth.

Primary scenario target:
- River Pass, also referred to by existing campaign content as Reedfall River Pass where applicable.

Current save/resume focus:
- Town manual-save resume route truthfulness is verified: the fresh routed live-flow blocker was a harness final-frame scene-detection race, not a product route failure.
- Preserve the existing useful coverage for selected manual save identity, resume target, scenario id, town state restoration, and downstream overworld/battle routing.
- Continue proving any remaining River Pass save/resume surfaces through live-client routes before treating the save/resume milestone as complete.
- Recently completed slice: overworld selected-site primary action usability added a primary selected-site order path with Enter/Space activation and routed live validation coverage.

Current display/layout focus:
- Recently completed slice: the Godot project display baseline now targets 1920x1080 with `canvas_items` / `expand` stretch, repo validation guards that display contract, and battle layout smoke promotes 1920x1080 as the primary viewport while retaining compact 1280x720 and 1024x600 regression coverage. The audit found the remaining 1280x720 coupling was test-side; at 1080p the battle board validation now reports when neighboring stack hit-shape overlap is geometrically impossible instead of treating that compact-layout edge case as a failure. Focused menu/outcome, overworld, town/battle, battle layout, and repo validation are green; no manual visual proof is claimed.
- Recently completed slice: Settings now has durable runtime resolution controls for the approved 16:9 desktop set (`1280x720`, `1600x900`, `1920x1080`, `2560x1440`) while keeping the Godot project baseline at 1920x1080. `SettingsService` persists and applies the selected resolution through the presentation settings path, the MainMenu Settings tab exposes a compact picker and summary, repo validation guards exact 16:9 options up to 1440p, and the menu/outcome smoke exercises the picker integration. No manual visual proof is claimed.

Current battle focus:
- Recently completed slice: the live battle board now reflects the landed hex legality model by showing legal movement and legal attack targets distinctly, marking selected-but-blocked targets as blocked, and keeping button previews aligned with the same rule checks that execute actions.
- Recently completed follow-up: target cycling, board-click focus, validation target alignment, and compact action/target summaries now prefer legal attack targets when any exist and explicitly call out selected targets that are blocked from the current hex.
- Recently completed follow-up: board clicks on legal enemy targets now dispatch the matching player attack order directly through the normal `strike` or `shoot` path, blocked enemy clicks remain explicit non-actions, green hex clicks still move, and focused smoke coverage exercises the scene-level click dispatch.
- Recently completed follow-up: direct enemy board clicks now use occupied-hex hit testing when the pointer misses the small stack token but remains inside the highlighted enemy hex, so ranged target clicks dispatch through the normal `Shoot` path instead of falling through as a no-op. Focused battle layout coverage stages a ranged hex-edge click that exercises the host-style mouse path, focused validation is green, and AcOrP manually confirmed the Ghoul Grove ranged shot path on the live shared screen.
- Recently completed follow-up: commander spell casting now clears ordinary closing-on-target context just like normal unit actions, so a spell after a closing move cannot leave stale movement wording in target/action guidance or board summaries. Focused core coverage stages the stale state with `Cinder Burst`, and focused core, battle layout, town/battle visual, repo validation, and X11 River Pass resolved-flow validation are green.
- Recently completed follow-up: invalid commander spell attempts now leave existing ordinary closing-on-target guidance intact, so a rejected repeat/stale spell command cannot erase truthful target guidance when no action occurred. The focused core spell-closing regression now proves rejected spells preserve closing context while valid spells still clear it.
- Recently completed follow-up: invalid ordinary battle orders now also leave ordinary closing-on-target guidance intact, so a rejected stale `Strike`/`Shoot`-style command cannot erase truthful target guidance when no action occurred. Successful ordinary actions still clear the context before resolving. Focused core coverage stages a rejected `Shoot` order after closing movement, and focused core plus battle layout smokes are green.
- Recently completed follow-up: visible outer-ring clicks inside a selected enemy hex now resolve against the actual hex polygon instead of the old center-radius cutoff, so highlighted ranged enemy hex-edge clicks that miss the token still dispatch through occupied-hex targeting and the normal `Shoot` path. Focused battle layout coverage stages the token-miss outer-ring click, and focused battle layout plus town/battle visual validation are green.
- Recently completed follow-up: visible green movement hex clicks now win over oversized friendly/active stack hit shapes when the resolved cell is a legal destination, so edge clicks in highlighted move cells are not swallowed as friendly stack focus no-ops. Focused battle layout coverage stages a legal movement cell overlapped by the active stack hit shape and proves the normal Move path executes.
- Recently completed follow-up: overlapped legal green movement hex tooltips now use the same Move-priority resolution as clicks, so a visible green destination partly under a friendly/active stack hit shape does not preview friendly-stack focus while the click executes movement. Focused battle layout coverage captures the tooltip before the overlapped click and proves it matches the movement intent.
- Recently completed follow-up: legal green movement destination clicks and tooltips now also win over oversized enemy token hit-shape overlap when the resolved cell is the green hex, so an adjacent enemy token cannot swallow a visible Move hex as target focus. Focused battle layout coverage stages an enemy-shape overlap on a legal destination, proves the tooltip stays on the Move intent, and proves the normal Move path executes.
- Recently completed follow-up: occupied enemy hex clicks and tooltips now prefer the actual resolved hex occupant over a neighboring enemy token's oversized hit shape, so a visible highlighted enemy hex cannot accidentally shoot the adjacent enemy stack. Focused battle layout coverage stages the neighboring-token overlap, proves the tooltip stays on the resolved hex target, and proves the normal `Shoot` path damages that target only.
- Recently completed follow-up: town-defense battles now derive retreat/surrender availability from the defense context as well as stored flags, so stale restored battle payloads cannot advertise open withdrawal buttons, pressure text, or summaries for actions that execution rejects. Focused core coverage stages stale open withdrawal flags on a restored Riverwatch defense battle, and focused core plus battle layout smokes are green.
- Recently completed follow-up: same-round player commander spell cooldown now surfaces truthfully after a cast in the spellbook, spell timing board, and order consequence command-tools line, matching the execution rejection for repeat casts. Focused core coverage stages a player cast followed by another friendly stack in the same round, and focused core plus battle layout smokes are green.
- Recently completed follow-up: invalid friendly/non-enemy battle-board stack clicks now surface their rejection in the visible battle dispatch instead of returning an invisible signal result, while preserving the current enemy target focus. Focused battle layout coverage clicks the active friendly stack and proves the `Only enemy stacks` rejection reaches the dispatch label without changing selected target state.
- Recently completed follow-up: opening tactical briefing text no longer masks real latest battle dispatch messages, so invalid board-click feedback can surface before the briefing is dismissed. Focused battle layout coverage keeps the briefing cached while clicking the active friendly stack and proves the `Only enemy stacks` rejection reaches the dispatch label without changing selected target state.
- Recently completed follow-up: empty in-board battlefield clicks on non-green movement hexes now route through the existing blocked Move rejection instead of disappearing as silent no-ops, so the visible dispatch can tell the player that the clicked hex is not a legal move destination. Focused battle layout coverage keeps the opening briefing cached, clicks an empty non-green hex, and proves the blocked Move rejection reaches the dispatch label without moving the active stack or changing target focus.
- Recently completed follow-up: empty non-green in-board battlefield hex tooltips now preview the same blocked Move intent that the click dispatches, so pre-click hover text and post-click dispatch feedback agree. Focused battle layout coverage captures the tooltip before the empty non-green hex click and proves it matches the blocked Move rejection.
- Recently completed follow-up: enemy-turn active stack hover text no longer advertises player green-hex or highlighted-enemy actions while input is locked to enemy initiative. The tooltip now matches the visible board-click rejection, and focused battle layout coverage drives the real board mouse path on the active enemy stack.
- Recently completed follow-up: enemy-turn empty hex hover/click feedback now surfaces locked initiative instead of calling those cells green movement input when the active enemy stack could legally move there. Focused battle layout coverage drives the real board mouse path on an empty enemy-turn movement cell and proves the tooltip, click rejection, and movement-intent summaries all avoid green-hex action wording while the player order window is closed.
- Recently completed follow-up: enemy-turn battle-board footer state now surfaces locked input instead of deriving target melee/ranged/blocked labels from the acting enemy stack. Focused battle layout coverage stages an adjacent enemy/player target during enemy initiative and proves the footer stays on `Input locked` while the existing hover/click rejection remains truthful.
- Recently completed follow-up: enemy-turn movement hover can no longer add a `Green:` movement footer label while input is locked. Focused battle layout coverage hovers an enemy-side legal movement cell during enemy initiative and proves the tooltip/preview stay locked while the footer movement affordance stays empty.
- Recently completed follow-up: enemy-turn board fallback tooltips now surface locked input instead of the generic `Green hex` / highlighted-enemy player instructions when the pointer is on board frame space that does not resolve to a hex or stack. Focused battle layout coverage stages enemy initiative, samples an empty fallback tooltip position, and proves it says the player turn is locked without action wording.
- Recently completed follow-up: enemy-turn battle-board attack highlights and validation summaries no longer expose player-click attack affordances from the acting enemy stack. The board presentation still leaves enemy AI legality available to rules, but the player-facing board snapshot locks legal target highlights, selected-target attackability, and board-click wording while input is locked. Focused battle layout coverage stages enemy initiative and proves no legal attack target highlight or board-click message leaks into the board presentation.
- Recently completed follow-up: enemy-turn target-cycle controls no longer advertise cycling legal enemy targets through disabled button tooltips while input is locked. Focused battle layout coverage stages enemy initiative and proves Prev/Next target controls stay disabled with locked-input tooltips and no target-cycling wording.
- Recently completed follow-up: enemy-turn spell action controls no longer advertise player casting buttons while input is locked. `get_spell_actions` now returns no player cast actions unless a player stack is active, and focused battle layout coverage stages enemy initiative and proves the footer spell action row is hidden.
- Recently completed follow-up: enemy-turn Timing tab guidance now uses an enemy-initiative branch instead of reusing player protection timing lines, so it surfaces that the player spell/order windows are closed and avoids player-turn wording such as trading this turn while input is locked. Focused battle layout coverage stages enemy initiative and proves the visible Timing panel plus core timing text stay locked.
- Recently completed follow-up: enemy-turn pressure and opening withdrawal labels now report the retreat/surrender window as closed while the active stack is enemy-side, instead of advertising open withdrawal actions that execution would reject until player initiative returns. Focused battle layout coverage stages enemy initiative with withdrawal generally allowed and proves pressure text says `Window closed` with no `Open` wording.
- Recently completed follow-up: enemy-turn primary command summaries and disabled button tooltips now use explicit input-lock wording instead of generic await text, and selected-target board-click intent now reports locked input without `Board click` wording while the active stack is enemy-side. Focused battle layout coverage stages enemy initiative and proves Advance/Strike/Shoot/Defend/Retreat/Surrender are disabled with not-player-turn summaries; focused core systems smoke is green.
- Recently completed follow-up: enemy-turn Risk board priority guidance no longer tells the player to shift focus while retargeting is locked during enemy initiative. Focused battle layout coverage stages enemy initiative and proves the visible Risk board plus tooltip say retargeting is locked without shift/cycle focus wording; focused core systems smoke is green.
- Recently completed follow-up: battle boards load checked-in generated terrain PNGs from `art/battle/terrain/` when available, with `plains` mapped cleanly to the grass texture and terrain rendering validation tracking texture path, loading, and mapping.
- Recently completed follow-up: AcOrP's manual terrain-alignment finding is addressed by rendering terrain art as clipped per-hex samples instead of a single full-board backdrop, so natural features are snapped to the tactical grid while existing movement/attack highlights, stack tokens, objective markers, turn strip, and footer remain readable. Missing textures fall back to per-hex procedural color/detail rather than a full-field wallpaper. Focused town/battle visual smoke, battle layout smoke, and repo validation are green.
- Recently completed follow-up: AcOrP's post hex-snapped terrain visibility finding is addressed by making the battle grid pass texture-aware: loaded terrain textures now render at full hex coverage with much lighter readability wash, textured cells no longer receive semi-opaque all-cell fills, front/center cues remain as subtle tactical tints, and textured grid borders use a deduplicated single-line path to avoid the double-border look. Missing textures still use the stronger hex-snapped color/detail fallback. Focused town/battle visual smoke, battle layout smoke, and repo validation are green.
- Recently completed follow-up: AcOrP's fresh terrain-sampling diagnosis is addressed by converting each clipped per-hex terrain source sample from texture pixel space into normalized `0..1` UVs before passing it to `draw_polygon`, while preserving the hex-snapped texture path, light tactical tints, cleaned deduplicated borders, and missing-texture procedural fallback. Focused validation now checks UV range and source-sample bounds rather than claiming direct visual proof. Focused town/battle visual smoke, battle layout smoke, and repo validation are green.
- Recently completed follow-up: pre-click battle guidance now surfaces the exact `Strike` or `Shoot` board-click intent for legal selected/hovered enemy targets through compact target context, action guidance, board footer/tooltip text, and validation snapshots; blocked selected targets keep the same explicit board-click contract.
- Recently completed follow-up: legal green movement hexes now surface explicit `Move` board-click intent through the existing board tooltip/footer/action context and validation summaries; blocked selected-target guidance now points to green-hex movement without adding panel clutter. Focused automated validation is green, but live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: legal green movement previews now include exact destination detail with hex and step count, hover/validation snapshots retain the same compact preview, and destinations truthfully call out when a move sets up a later `Strike` on the currently blocked target. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: legal green movement clicks now reuse the same compact preview language for the executed move result, and shell validation returns the same destination detail, step count, preview message, and later-attack setup hint when applicable. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: setup green-hex moves now preserve the blocked selected target after the move when that target remains valid, even when another legal enemy could become the default target. Post-move validation exposes the preserved target, current legality, board-click action/block state, and compact guidance so the UI truthfully reflects whether `Strike`/`Shoot` is now legal or the target remains blocked. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: preserved setup-move targets now surface as preserved setup targets in the immediate post-move action guide, target context, board footer, board validation summary, and move-click validation response. If the preserved target is now legal, the compact state names the `Strike`/`Shoot` board click and keeps the action enabled; if it is still blocked for the immediate active stack, the same compact surfaces say it is still blocked. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: explicit battle retargeting now clears preserved setup-target context instead of letting the old setup target linger as sticky emphasis. Target cycling and board enemy focus use the same target-selection rule path; preserved setup guidance remains only while the preserved target is still the selected context, and focused core/layout validation proves retargeting drops the special action guide, target context, board footer, board emphasis, and continuity key. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: explicit retarget clear is now durable when focus returns to the old setup target without a fresh setup move. Core coverage proves cycling back and direct target selection keep the old target as normal focus with no continuity key or preserved setup wording; layout coverage proves blocked board-click refocus does not restore preserved setup context through compact action guidance, target context, shell snapshots, or board summaries. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: post-clear movement toward the old setup target now has focused regression coverage proving ordinary movement, move-result payloads, post-move target guidance/context, board summaries, and shell validation snapshots stay normal target focus with no preserved setup wording or flags. The same core coverage proves a later fresh setup move can still recreate continuity truthfully. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: ordinary non-setup movement toward a selected blocked target now carries an explicit closing-on-target context through move results, post-move target/action guidance, board validation summaries, board footer state, and shell snapshots without setting preserved setup continuity. Focused regression coverage proves post-clear old-target movement stays ordinary while still communicating closing progress, and that a later fresh setup move clears the ordinary closing context before recreating preserved setup continuity. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: ordinary closing-on-target context now self-clears when it stops being truthful: if the selected target becomes directly attackable, target selection changes, or the active stack changes, compact battle surfaces drop the closing wording/flags and return to the real `Strike`/`Shoot` or blocked-target action state. Focused core and battle-layout regression proves closing appears for ordinary progress moves, then clears through move results, target/action guidance, board summaries/footer state, shell snapshots, and validation payloads. Focused automated validation is green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: ordinary closing movement that immediately turns the same selected blocked target into a directly attackable target now clears the ordinary closing context without converting it into preserved setup continuity, and the move result, target/action guidance, board summary/footer, and shell snapshot surface the normal `board click will Strike` / `Shoot` state right away. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: the immediate board-click attack after that direct-actionable post-move state now reports normal attack result payloads and post-attack selected-target/board/shell state, with no stale closing, preserved setup, or direct-actionable-after-move markers. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: the same direct-actionable post-move chain is now covered through the normal `Strike`/`Shoot` action-button path. Shell validation preserves the attack result payload plus refreshed selected-target, board, action-guide, and target-context state, and focused coverage proves no stale closing, preserved setup, or direct-actionable-after-move markers remain after the immediate button attack. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: invalidating immediate attacks after the direct-actionable post-move state now settle onto normal post-attack focus. If the original attacked target is destroyed or no longer the selected active focus, post-attack payloads report the handoff, remove post-move transition fields, clear preserved setup and ordinary closing state, and compact board/footer/shell snapshots settle on the surviving normal target. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: invalidating immediate attacks after the direct-actionable post-move state now also cover the branch where the selected-target handoff lands on a newly selected target that is itself directly attackable. Post-attack payloads explicitly mark handoff, direct-actionable handoff, or blocked handoff state; board-click and `Strike`/`Shoot` validation prove compact target/action guidance, board summaries/footer labels, and shell snapshots settle straight onto normal `board click will Strike` / `Shoot` guidance for the new target with no stale closing, preserved setup, direct-actionable-after-move, or invalidation-transition residue. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: invalidating immediate attacks after the direct-actionable post-move state now also cover the no-selected-handoff branch where the original target is the last enemy and battle resolution clears the active battle. Post-attack result payloads explicitly settle on an empty selected target with no handoff, no direct-actionable target, empty legality/click intent, and no stale closing, preserved setup, direct-actionable-after-move, or post-move transition fields. The blocked replacement handoff core regression now also asserts the no-direct-action blocked-handoff flags, while existing layout coverage keeps the compact blocked-handoff board/footer/shell surfaces green. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: post-attack selected-target handoff now explicitly prefers a surviving directly attackable enemy over an earlier blocked survivor after an immediate post-move attack invalidates the original target. The default target-selection rule uses the active stack's legal attack target order before falling back to the first living enemy, and focused multi-enemy core coverage proves the attack result, selected target, legality, board-click intent, and compact hex summary land on the actionable survivor with no stale closing, preserved setup, or direct-actionable-after-move residue. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: the actionable-preferred post-attack handoff branch now has scene/snapshot-level truthfulness coverage. A battle layout smoke case stages an immediate post-move attack that destroys the original target while an earlier blocked survivor and a later attackable survivor both remain; the shell response, attack result payload, selected-target state, compact board summary/footer, selected board cell, and validation snapshot all land on the attackable survivor with no stale closing, preserved setup, or direct-actionable-after-move residue. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: the same actionable-preferred post-attack handoff branch is now mirrored through the immediate `Strike`/`Shoot` button path. The battle layout smoke restages the blocked-survivor plus attackable-survivor invalidation branch through shell button validation and proves the button response, attack result payload, selected-target state, compact action/target guidance, board summary/footer, selected board cell, and validation snapshot settle on the attackable survivor with no stale closing, preserved setup, or direct-actionable-after-move residue. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: the no-selected-handoff final-kill branch now has scene/snapshot-level truthfulness coverage through both board-click and immediate `Strike`/`Shoot` button attacks after a direct-actionable post-move setup. The battle layout smoke uses isolated shell validation to prove the routed response/result payload, empty selected target, empty legality/click intent, cleared board summary, and empty-battle snapshot contain no stale closing, preserved setup, direct-actionable-after-move, handoff, or selected-target residue. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: the same final-kill branch now has routed-resolution truthfulness coverage with normal battle routing enabled. The battle layout smoke drives both board-click and immediate `Strike`/`Shoot` button final-kill paths through the real `AppRouter` handoff, proves the validation response and immediate shell snapshot expose empty selected-target/battle guidance state, then verifies the routed scene lands on the truthful next state (`OverworldShell` while the scenario remains in progress, or `ScenarioOutcomeShell` if the scenario resolves). Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: immediate post-move final-kill routing now has save/resume-facing truthfulness coverage. The battle layout smoke checks board-click and immediate `Strike`/`Shoot` button final-kill routes through the routed scene, autosave/latest summaries, manual save from that routed scene, and restore semantics. The coverage proves the next resume target is overworld for in-progress sessions or outcome for resolved sessions, with empty battle payloads, no battle resume advertising, no selected-target residue, and outcome routes normalized to an explicit `outcome` game state. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: immediate post-move final-kill routing now also has menu-facing save-browser/latest-surface truthfulness coverage. The battle layout smoke returns routed in-progress and resolved final-kill paths to the main menu after both board-click and `Strike`/`Shoot` button attacks, opens the save browser, and verifies Continue Latest, latest save pulse, latest save row, selected save details, and load action labels advertise overworld resume or outcome review with no battle wording or selected-target residue. Main menu validation snapshots now expose the save-browser labels needed for this proof without changing the player-facing shell. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: immediate post-move final-kill menu action execution now has truthfulness coverage. The battle layout smoke triggers the actual Continue Latest action and the selected save-browser Load action after routed in-progress and resolved final-kill paths, then verifies the executed route lands on overworld resume or outcome review with empty battle payloads, matching session game state, matching routed scene snapshots, and no selected-target/battle guidance residue. Main menu validation now exposes a Continue Latest execution hook and strengthens selected-save resume result payloads for this proof. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.
- Recently completed follow-up: immediate post-move final-kill outcome action execution now has truthfulness coverage. After the resolved routed final-kill branch lands on `ScenarioOutcomeShell`, the battle layout smoke executes the actual outcome Return to Menu action, resumes the outcome again through the real main-menu Continue Latest path, then executes the outcome Retry Skirmish action and verifies the route lands on a clean restarted overworld session with no battle payload or selected-target residue. `ScenarioOutcomeShell` validation now reports the underlying action route and active session truth fields. Focused core, battle layout, town/battle visual, and repo validation are green; live manual proof remains unclaimed while the host noVNC/X11 path is tooling-blocked.

Execution order:
1. Audit the current River Pass path in the live client.
   - Start from Boot and MainMenu.
   - Launch the scenario through the normal campaign or skirmish surface selected for the milestone.
   - Record the first point where a real player is blocked, confused, misrouted, or forced to know developer-only behavior.
2. Build a parity ledger for River Pass only.
   - overworld launch and objective clarity
   - hero selection and movement
   - fog, map readability, and point-of-interest readability
   - resource pickup and site interaction
   - owned-town entry, construction, recruitment, spell or recovery actions
   - hostile encounter entry
   - battle start, targeting, action clarity, enemy turn handling, and battle end
   - post-battle army sync and overworld return
   - victory condition
   - defeat condition
   - save/resume from overworld
   - save/resume from town
   - save/resume from battle
   - outcome routing and menu return
3. Fix hard blockers before polish.
   - No scenario work counts until the player can route through the basic screens without dead ends.
   - Battle and town UI recovery outrank additional content breadth.
   - Missing affordances outrank extra summaries.
4. Tune the scenario for manual completion.
   - The opening army, accessible reinforcements, first fights, enemy pressure, and victory clock must allow a reasonable first-time player to win.
   - Defeat must remain possible through understandable failure, not through hidden traps or broken routing.
5. Prove save/resume in the same path.
   - Save from overworld, load, continue.
   - Save from town, load, continue.
   - Save from battle, load, continue or resolve.
6. Prove victory and defeat outcomes.
   - Victory routes to a truthful outcome screen.
   - Defeat routes to a truthful outcome screen.
   - Restart, return-to-menu, and save-browser behavior are coherent.
7. Write down any deferred gaps.
   - Gaps can remain only if they do not block a real manual completion.
   - Each deferred gap must have an owner phase.

River Pass acceptance criteria:
- A real player can launch River Pass without editor-only steps.
- The first screen after launch explains objective, threat, and next action through the game UI.
- The overworld map is readable enough to choose where to go.
- Movement, end turn, resource interaction, town entry, encounter entry, and return routing work through visible controls.
- At least one owned town supports useful recruitment or recovery decisions that affect completion.
- At least one battle is entered through normal overworld play and can be resolved with understandable tactical controls.
- The battle UI exposes whose turn it is, legal actions, target selection, expected consequences at a basic level, and the result.
- Post-battle survivors and losses sync back to the overworld state.
- The scenario has one reachable victory condition and one reachable defeat condition.
- Saving and loading from overworld, town, and battle do not corrupt the scenario or strand the player on the wrong surface.
- Victory and defeat outcomes route through the normal outcome/menu flow.
- The scenario can be completed manually at least twice from a clean profile, with notes captured for remaining friction.

Exit gate:
- Do not begin Phase 2 until River Pass can be completed manually end-to-end and the blockers are documented or fixed.

## Phase 2: Playable Alpha Baseline
Status: future, starts after Phase 1 exit gate.

Purpose:
- Convert the single-scenario proof into a small playable alpha with real strategy loops.
- Target two fully realized original factions before returning to wider faction count.

Scope:
- 2 fully realized factions with distinct identity.
- Usable town, battle, and overworld UX.
- Deeper units, spells, artifacts, map objects, hero growth, neutral encounters, and scenario scripting.
- A small set of manually playable scenarios, not a broad campaign promise.

Execution order:
1. Choose the two alpha factions and freeze their identity targets.
2. Define the alpha content matrix:
   - unit tiers
   - town buildings
   - recruit economy
   - hero roles
   - spells
   - artifacts
   - map objects
   - neutral encounters
   - faction-specific battle hooks
3. Repair overworld UX around the alpha loop.
   - map readability
   - movement and pathing
   - fog/scouting
   - site affordances
   - threat surfacing
   - end-turn clarity
4. Repair town UX around the alpha loop.
   - build decisions
   - recruitment
   - garrison and transfer
   - spell learning where present
   - economy and affordability
   - town defense clarity
5. Repair battle UX around the alpha loop.
   - deployment and initiative clarity
   - stack identity
   - targeting
   - retaliation/ranged/melee expectations
   - spell and ability availability
   - win/loss consequences
6. Build 3-5 alpha scenarios that can be manually completed.
7. Add AI enough to contest the alpha scenarios without relying on scripted pressure only.
8. Stabilize save/load across alpha loops.
9. Run manual play passes, then add automated coverage for the issues found manually.

Acceptance criteria:
- Two factions are playable with distinct town, unit, hero, spell, and battle identities.
- A player can complete multiple scenarios without developer guidance.
- Town, battle, and overworld screens are usable at the default target resolution.
- Save/load is reliable across normal alpha behavior.
- The content pipeline catches missing ids, invalid references, impossible starts, and broken objective wiring.
- AI can take turns, contest objectives, and resolve battles without routine dead ends.

## Phase 3: Production Alpha Layer
Status: future.

Purpose:
- Make the alpha suitable for external playtest, not release.
- Replace roughest placeholder gaps with coherent placeholder art/audio and production packaging basics.

Execution order:
1. Establish an external playtest checklist.
2. Add or replace placeholder art so all primary screens have coherent original visual language.
3. Add placeholder audio coverage:
   - menu ambience
   - button/UI feedback
   - overworld movement or interaction cues
   - battle action cues
   - victory/defeat cues
4. Stabilize settings:
   - display/window mode
   - audio volume
   - accessibility basics
   - input affordances
5. Build export pipeline.
   - repeatable desktop export
   - version stamping
   - clean user data behavior
   - crash/log collection path
6. Add playtest telemetry or local report hooks where practical.
7. Create onboarding sufficient for first external players.
8. Run external playtest candidate builds and triage.

Acceptance criteria:
- A non-developer can install or run an exported build.
- The game has coherent placeholder art/audio instead of debug presentation.
- Settings persist and affect the live client.
- Logs and reports are usable for debugging playtest issues.
- Known blockers are tracked before wider playtest.

## Phase 4: HoMM2-Class Breadth
Status: future product horizon.

Purpose:
- Reach a broad, original fantasy strategy game package comparable in systemic breadth to the Heroes II era while remaining legally distinct.

Scope targets:
- Multiple original factions beyond the alpha two.
- A meaningful roster of heroes, units, towns, spells, artifacts, neutral creatures, map objects, and handcrafted maps.
- Campaign framework with several completable chapters.
- Skirmish setup with meaningful map and faction choice.
- AI that can operate adventure and battle loops across broader content.

Execution order:
1. Expand faction count only after alpha loops remain stable.
2. Add content in vertical bundles, not isolated JSON dumps.
   - faction data
   - town data
   - unit data
   - hero data
   - spells/artifacts
   - encounters
   - map/scenario placement
   - AI tuning
   - manual play pass
3. Build HoMM2-class map object variety.
4. Build campaign chapter chains only after single-map completion stays reliable.
5. Balance resources, recruitment pacing, battle difficulty, and AI pressure across the content set.
6. Harden save compatibility and migration.
7. Maintain a parity ledger comparing target breadth versus live playable breadth.

Acceptance criteria:
- Breadth is playable, not just authored.
- Multiple factions support complete town, battle, overworld, and AI loops.
- Campaign and skirmish content can be completed manually.
- Automated validation covers content graph integrity and previously discovered live-client regressions.

## Phase 5: HoMM3-Class Breadth
Status: late future product horizon.

Purpose:
- Expand from HoMM2-class breadth into deeper strategic density associated with Heroes III while keeping the game original.

Scope targets:
- More factions and stronger faction asymmetry.
- Richer hero progression and specialties.
- Larger spell and artifact ecosystems.
- More map objects, object chains, and scripted scenario structures.
- More sophisticated AI pressure and campaign pacing.
- Better balance tooling, QA workflow, accessibility, audio, visual polish, and packaging maturity.

Execution order:
1. Freeze the HoMM2-class baseline before adding HoMM3-class density.
2. Identify which HoMM3-like systems genuinely improve this original game rather than adding complexity for parity theater.
3. Expand one depth layer at a time:
   - hero progression
   - artifacts
   - magic
   - map objects
   - faction mechanics
   - AI
   - campaign scripting
4. Re-run manual play and automated validation after each layer.
5. Balance for readability and player agency.

Acceptance criteria:
- Added depth creates better strategic choices, not just more lists.
- Existing scenarios and saves survive added density or migrate clearly.
- The game remains understandable to new players.
- Parity claims are backed by playable breadth and manual evidence.

## Immediate Execution Order
1. Complete the documentation reset.
2. Run the current validation baseline enough to know whether docs-only changes kept the repo structurally intact.
3. Start the River Pass manual audit from the live client.
4. Record the River Pass parity ledger.
5. Fix launch and routing blockers.
6. Fix battle usability blockers.
7. Fix town usability blockers.
8. Fix overworld objective, map, movement, and end-turn clarity blockers.
9. Tune River Pass for one fair victory path.
10. Add or repair one fair defeat path.
11. Prove save/resume from overworld.
12. Prove save/resume from town.
13. Prove save/resume from battle.
14. Prove victory outcome routing.
15. Prove defeat outcome routing.
16. Repeat a clean manual completion pass and record notes.
17. Only then select Phase 2 alpha scope.

## Parity Ledger Template
Use this structure for each target system or content claim:

- Claim:
- Current implementation:
- Live-client usability:
- Manual-play evidence:
- Automated coverage:
- Known blockers:
- Phase owner:
- Acceptance gate:

No claim should move to "done" unless live-client usability and evidence are filled in.

## Current Acceptance Target
Current target: River Pass manually completable by a real player.

Done means:
- A clean-profile manual player can start River Pass, understand what to do, make meaningful overworld/town/battle decisions, save/resume, and reach victory.
- The same scenario can also reach a coherent defeat.
- The result is not dependent on editor setup, hidden debug controls, or knowledge of internal ids.
- Remaining gaps are documented as alpha gaps, not hidden behind completed language.
