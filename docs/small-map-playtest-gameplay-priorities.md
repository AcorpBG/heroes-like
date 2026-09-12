# Small-map playtest gameplay priorities

Owner-approved highest-priority Phase 6 queue, 2026-09-12. Combat consequences is **completed**; the remaining four slices are **pending**. PLAN.md sets selection order; ops/progress.json owns operational status. The overall goal and fresh Small-map acceptance remain open.

## Basis and scope

The native Windows Small (36 x 36), three-player Captain skirmish on Jade Brook Deep reached defeat on Day 16: 14 manual battles, 11 victories, two retreats and one defeat; Sunvault eliminated, Mireclaw remaining. The second Riverwatch assault lost 50 attackers against 49 defenders. The observed player experience was rated 5/10, with combat clarity and interface obstruction the main concerns. One match and imperfect assault decisions do not establish a balance defect.

Local evidence: `.artifacts/computer-use-small-rmg-20260912/playtest.md`, `02-battle-tooltip-overflow.png`, `08-riverwatch-lost.png`, `12-one-rival-defeated.png`, `16-riverwatch-defeat.png` and `17-final-skirmish-defeat.png` in that same directory. Preserve the generated `maps/small-jade-brook-deep-be633b81.amap` / `.ascenario` pair and saves. The observations below remain understandable without local artifacts.

These five slices outrank discretionary art/animation, content expansion and polish. They refine existing gameplay and input contracts; they do not reopen completed historical slices or certify release readiness. Keep project.md strategic rather than copying this queue into the charter. Related existing contracts: `docs/battle-readable-turns-and-melee-approach.md`, `docs/battle-message-log.md`, `docs/town-roster-double-click.md`, and `docs/generated-full-match-quality-requirements.md`.

## 1. Combat consequences before commitment

Slice: `ux-combat-consequence-preview-20260912`.

Observed problem: melee approach exposed duelists to retaliation and subsequent enemy attacks that rapidly destroyed them. The final approach position, likely exchange and upcoming actors were difficult to assess.

Required behavior:

- A compact preview shows the exact proposed movement destination, attack/spell target, expected damage and casualty range, and immediate retaliation where applicable before the player commits.
- Derive legality and estimates from authoritative combat rules. Previews must not consume RNG, mutate state or promise exact future outcomes where randomness or enemy choices make them uncertain.
- Distinguish the immediate exchange from subsequent enemy threats. Show the next few known actors and explain bonus/repeated actions when they occur, without exposing hidden AI decisions or debug scores.
- The committed intent matches its preview; stale/illegal intents refresh or reject safely.

Targets: BattleRules, BattleShell, BattleBoardView and their existing action/initiative presentation helpers. Acceptance: manually inspect adjacent and move-and-strike melee, ranged and spell previews; verify resulting damage/casualties against the advertised ranges, retaliation eligibility, final hex and ordered actor handoff. Repeated hover/selection must leave complete combat state and RNG unchanged.

Implemented: `BattleRules.attack_consequence_preview` enumerates authored damage rolls on isolated battle copies using the same damage modifier, legal approach, on-hit abilities, damage pressure and reflection rules as combat resolution. It bounds retaliation after casualties/status changes rather than against the untouched defender. `spell_consequence_preview` uses the existing spell resolver on its copied hero state; Advance uses the existing automatic movement resolver on a copied battle. A bounded, detached cache invalidates on full battle-state changes. `BattleBoardView` shows compact exchange text and a movement-end marker, and its initiative ribbon starts at the current living actor rather than the beginning of the round. Mouse/controller focus and action/spell buttons request these previews; playback and dismissal clear them. Existing attack summaries share the forecast. No RNG/save schema, damage balance, art or native generation changes. Damage/casualty estimates describe the primary target and immediate return, not future enemy choices or secondary area targets. The current turn-order builder schedules each living stack once per round; retaliation remains explicitly labeled separately in forecasts and ordered playback. Explicit two-stage targeting is still slice 4, not silently claimed here.

Accepted evidence: `.artifacts/combat_consequence_20260912/final-source/` passes 1,395 checks at 1920x1080; `reduced/` and `linux-package/` each pass 1,397 at 1280x720, including Advance's committed final hex. `windows-package/` passes 1,363 under headless Wine (not physical Windows GPU certification). Adjacent/approach/ranged/spell captures inspected; compact movement-end and wide spell captures show no forecast/control overlap. Includes 108 seeded exchanges across ordinary, lethal, spent-retaliation, harry, overheat, hookline and reflected-damage cases; full-state/RNG purity, cached-result isolation, live mouse/controller previews and actual ordered playback. Twenty repeat forecasts take 570 microseconds in the wide source fixture, versus 535880 microseconds before caching. Fixtures deliberately keep large health pools for playback; they are not a balance playtest. Original Windows playtest screenshots/saves referenced above are not present in this Linux checkout; the owner-recorded observations remain the requirements, not locally reproduced evidence.

Reproduction: `python3 -B tests/combat_consequence_preview_regression.py --label final-source --render --resolution 1920x1080`; add `--reduced-motion` for reduced settings. `tests/packaged_combat_consequence_preview_regression.py` runs identical assertions against isolated release binaries/PCKs with `--platform`, `--binary`, `--pack`, `--label`, and a new `--wine-prefix` for Windows. Both official export/startup checks pass (`linux-release/report.json`, `windows-release/report.json`), including Windows generated Overworld/Town entry. Both PCKs are 313226008 bytes with 5,605 identical member paths; only `project.binary` differs across platforms. No asset content/package expansion was introduced. `python3 tests/validate_repo.py` passes (log `/tmp/heroes-combat-consequence-repo-20260912.log`); existing deterministic RNG, controller-board navigation and quick-resolve reports pass under `.artifacts/full_play_runtime_20260905/combat-consequence-existing/`; `git diff --check` passes. A temporary initiative type-inference error and background export environment failures remain as diagnostic logs, not accepted results. Cleanup removed 206870664 bytes of aborted, rebuildable export output; final packages, captures, logs, user data, caches and unrelated files remain.

## 2. Bounded contextual tooltips

Slice: `ux-bounded-contextual-tooltips-20260912`.

Observed problem: hover text covered most of the battlefield or construction ledger, ran off-screen, and sometimes survived an Overworld-to-Battle transition.

Required behavior:

- Ordinary hover shows a short bounded summary positioned within the viewport, away from the active target and essential controls. Long explanations use explicit inspect/detail actions in contextual popouts.
- Hide obsolete tooltips when their target disappears, on scene/modal transitions and when pointer/focus context changes. Keyboard/controller inspection must have an equivalent dismissal path.
- Preserve scenery and the dominant play surface; do not replace overflowing tooltips with permanent text panels.

Targets: shared tooltip/inspection ownership and affected Overworld, Town and Battle controls. Acceptance: inspect long content at viewport edges in 1280x720 and a wide resolution, including 2560x1440; move focus, open/close modals and transition from map to battle. No clipped, stale or input-blocking hover surface may remain.

## 3. Actual town garrisons and exposed-town warnings

Slice: `ux-accurate-town-garrison-20260912`.

Observed problem: Riverwatch showed Guard readiness 33 but the subsequent AI assault defended with zero troops. Readiness and defending strength were not sufficiently distinguished.

Required behavior:

- Show actual defending troop/stack counts, including an explicit empty garrison, separately from a plainly labeled readiness modifier.
- Use the same authoritative defender eligibility as battle setup, including applicable visiting-hero rules; do not imply a hero is defending merely because remote management is open.
- Before ending a turn, provide a compact actionable warning for an exposed, empty owned town based on available player information. Allow the player to inspect/reinforce or deliberately proceed without repetitive modal friction.

Targets: TownRules, HeroCommandRules, TownShell and Overworld end-turn/roster summaries. Acceptance: empty, occupied, transferred and visiting-hero cases show counts matching actual assault defenders. Warning updates after reinforcement, ownership changes and save/resume; it must not reveal hidden enemies.

## 4. Consistent targeting and commitment

Slice: `ux-consistent-targeting-commit-20260912`.

Observed problem: selecting an adjacent destination could immediately start a battle, board clicks could immediately attack, and Next sometimes appeared not to change targets despite multiple legal choices. Counters sometimes appeared to include defeated stacks; the exact cause still needs reproduction.

Required behavior:

- Establish and document one understandable selection/preview/commit contract for map interactions and tactical actions. The first ordinary selection must not accidentally spend an action or enter combat; any deliberate quick-action shortcut must be explicit and equivalent across supported inputs.
- Make the intended order and committed destination/target unmistakable, with cancellation or reselection before commitment. Preserve authoritative movement, guard interception and legal combined move-and-strike behavior.
- Cycle valid live targets predictably; counts, highlights and selection agree after casualties and state changes. Explain unavailable targets without silently choosing a different victim.
- Selecting a spell enters an explicit target-selection mode with legal targets, cost and effect preview; casting occurs only on commitment. Input during playback or scene handoff cannot issue a second order.

Targets: OverworldShell, BattleShell, BattleBoardView and existing intent/selection helpers. Acceptance: mouse and keyboard/controller equivalent flows; adjacent/distant map routes, hostile/guarded interactions, melee/ranged/spells, cancel/reselect, target death and playback transitions. Only a committed order may change authoritative state, and no order may execute twice.

## 5. Recruitment logistics and identity clarity

Slice: `gameplay-recruitment-logistics-clarity-20260912`.

Observed problem: recruiting through remote town management immediately added troops to the distant active hero. Shard Guard / Shard Wardens, Prism Adept / Prism Adepts, Mirror Duelist / Mirror Duelists and duplicate Shard Yard labels made roles and prerequisites difficult to distinguish. Similar names alone are not proof of duplicate underlying content.

Required behavior:

- First trace and record the intended recruitment/logistics contract using existing Town/Hero rules and design requirements. Choose explicitly between immediate remote recruitment and town-local recruitment/delivery; this planning update does not silently select or implement a transport model.
- Enforce the selected contract in live recruitment. Before purchase, show destination army/garrison, immediate versus delayed arrival, capacity and full cost; after purchase, confirm where the troops went. Preserve remote town-management access independently from troop delivery rules.
- Audit ambiguous display identities and prerequisites. Consolidate true duplicates only with content/save compatibility, and clearly distinguish legitimate different tiers, roles, variants and building upgrade paths. Preserve stable IDs unless a validated migration is part of the implementation.

Targets: TownRules, HeroCommandRules, TownShell, recruitment summaries and the affected unit/building catalogs. Acceptance: remote and local purchases, different active heroes, full armies/garrisons, lost towns, costs/reserve depletion and save/resume all respect the chosen rule. The roster, battle labels and construction prerequisites consistently identify the same content. A design note or renamed labels without verified recruitment behavior does not complete this slice.

## Shared validation and completion

- Keep all five pending until their runtime behavior is implemented and validated. Use Python-owned focused regressions and the existing repository/progress checks; avoid new report-only gates as substitutes for behavior.
- Inspect compact and wide real UI with normal, fast/instant and reduced-motion battle settings where applicable. Validate relevant source and Windows/Linux packaged flows; record physical-hardware versus Wine/headless limits accurately.
- Preserve deterministic combat RNG, saves, original art, authoritative paths/occupancy and Native RMG source semantics. Do not rebalance damage, alter generation density or add heuristic map repairs from this playtest.
- After the queue is implemented, run a fresh manual Small-map match through a legitimate terminal outcome. Assess whether players can predict actions, defend towns and understand recruitment; report tactical mistakes separately from unclear feedback or rules defects. Revisit balance only with that clearer evidence.
