# Main Menu Rework And Visible AI Turns

Owner-directed Phase 6 implementation slice `ui-main-menu-and-visible-ai-turns-20260910`, derived from `project.md` and `PLAN.md`.

## Acceptance

- Main menu receives a coherent visual recomposition, not merely changed button colors: dominant original scenery, clear Aurelion Reach branding, readable primary actions, deliberate spacing and responsive compact/wide layouts. Detailed campaign, skirmish/generated setup, saves, guide and settings stay in secondary surfaces; preserve all their routes and input conventions.
- Ending a turn visibly identifies the acting player/controller, including AI players and the return to the human turn. Animate transitions without covering the map with a dashboard.
- AI heroes revealed under the existing permanent-exploration fog policy have ordered, readable movement/action presentation using their actual original art. Hidden heroes, hidden path portions, levels and targets must never leak through camera movement, labels or animation.
- Presentation observes authoritative committed actions. It must not change AI decisions, RNG, economy, movement budgets, save schema or ownership. Preserve autosave failure/retry and battle/outcome routing, suppress duplicate input while playback owns the screen, and support reduced motion and skipping.

## Implementation sequence

1. Inspect current menu and turn/render authorities; capture a baseline. Rework the main-menu composition using existing approved original art and typography.
2. Capture minimal actual AI turn/movement records at existing execution boundaries, filter through player-visible fog/layer state, and present player identity and hero actions in order. No inferred straight-line paths from final position deltas.
3. Validate deterministic state equality with capture disabled/enabled, fog boundaries, identity (including repeated factions), route/save/input safety, menu navigation and real rendered small/wide views. Batch broad validation after coherent implementation.

## Validation

Python-owned focused source and isolated-package probes; relevant existing menu, end-turn, fog, save and input regressions; `python3 tests/validate_repo.py`; `git diff --check`; established Linux and Windows export/package gameplay smokes. Visually inspect captures at 1280x720 and 1920x1080 with measured viewport dimensions. Record exact results and Windows Wine/hardware limits before completing the slice.

## Non-goals

No native RMG, content/balance, strategic AI decision changes, art generation, save migration, Town/battle redesign or unrelated cleanup. Retain source art, final evidence, caches and pre-existing unrelated untracked files. Use compact task-owned artifacts and remove only superseded temporary products after their processes finish.

## Implemented behavior

`MainMenuComposition.gd` replaces the baked-panel first view with an existing original castle panorama, restrained navigation shading, a two-line wordmark and six keyboard-focusable primary commands. The existing MainMenu launch/save/settings authorities remain intact. Secondary panels hide primary navigation and restore it when closed. Wrapped error notices reserve space without pushing Quit outside the viewport; obsolete torch placement is disabled for this composition.

Previously, the complete enemy simulation committed before the map refreshed, so moving heroes appeared to jump and the acting player was not presented. `OverworldTurnPlayback.gd` now observes actual player-cycle and committed movement/site-interaction boundaries in EnemyTurnRules/EnemyAdventureRules. Records are opt-in, transient and removed before autosave. They contain an allowlisted original-art identity and only visible endpoints, never hidden destinations or AI plans. The current permanent-exploration fog policy and viewed level remain authoritative.

OverworldShell commits the existing turn and durable save before starting the presentation queue. OverworldMapView uses a temporary encounter-position view, interpolates real steps with existing sprites, follows revealed actors only when they leave the camera margin, then restores the live map/camera. The compact presenter names the controller/faction and moving hero, shows site claims and defending-army contact, and announces the human-turn or battle handoff. Esc/Confirm and the skip button end playback without rerunning simulation. Reduced motion suppresses interpolation/fades. Battle routing waits until playback ends; duplicate End Turn is rejected. This is not a replay of hidden AI reasoning, town production or every combat calculation.

## Evidence

Artifacts are under `.artifacts/menu_and_turn_readability_20260910/` unless otherwise stated.

- Final isolated Linux release probe: `linux-release-probe/report.json`, 61 checks; measured/rendered 1280x720 menu, error notice, AI turn, movement and site action. Includes real keyboard focus traversal, secondary-panel routing, double-turn rejection, skip/state equality and exactly-once battle handoff.
- Final isolated Windows release probe: `windows-release-probe/report.json`, 48 checks under headless Wine; all probe assertions retained, compiled UI owners hashed, no loose runtime scripts substituted. Headless execution does not certify Windows GPU animation.
- Native generated Medium, seed 10, two players: `generated-scouted-accepted/report.json`, 62 checks at 1920x1080. Capture-on/off full-state equality across four actual turns; multiple actual commanders and site claims. The visual fixture deliberately scouts the sampled route corridor while retaining surrounding fog; it is not an assertion that a fresh game starts with enemy territory revealed. Generated source map files are restored by the existing preservation helper.
- Focused boundary checks cover entering/leaving fog, fully hidden movement/actions, other levels, allowlisted records and two players sharing one faction. Both small/wide final menu and generated fog/movement screenshots were opened and visually inspected, not accepted solely from rectangle assertions.
- Official `linux-release/report.json` and `windows-release/report.json` pass export/startup and established Windows generated Overworld/Town gameplay checks. Each PCK is 313194076 bytes with 5597 members; member sets match and only `project.binary` differs. The owner's existing removal of the package-size ceiling is unchanged.
- Existing end-turn confirmation, injected autosave failure/retry, fog and safe-close reports pass under `.artifacts/full_play_runtime_20260905/menu_turn_existing_20260910/`. The safe-close test's expected OS error dialog was acknowledged to let its existing recovery probe finish; no game process was forcibly stopped. Existing stage-dock reveal report also passes.
- Known legacy exception: `main_menu_keyboard_navigation_smoke` expects four fixed empty-save-slot rows, but the current named-save browser has zero rows when empty. Its old empty-list expectation fails; the save browser and its unchanged empty-state text were not rewritten here. This test is not counted as a pass. The new focused test exercises all six first-view commands and opening/closing all five secondary tabs.
- Four superseded task-owned export directories (about 1.5 GiB) were removed after their producers/consumers exited. Final release exports, logs/screenshots, source art, caches and unrelated untracked retention files remain. Deleted exports are rebuildable; diagnostic reports are retained.

- Final reduced-motion source run: `reduced-final/report.json`, 61 checks at 1920x1080; final action screenshot visually inspected. Repository validation passes (`validate-repo-final.log`), as does `git diff --check`.

Status: completed 2026-09-10. No universal AI/balance, native parity or release-readiness claim is made.
