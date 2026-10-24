# Scene transitions and battle entry

Owner report (2026-10-07): entering battle showed a gray screen and took a while.

## Why a frame could be empty

`SceneTree.change_scene_to_packed()` removes the outgoing scene at once and adds the
incoming scene at the next frame's scene flush. The flush runs after node `_process`
callbacks and before SceneTree timers and tweens. A change requested from a timer,
tween or deferred callback (the battle-approach walk, the battle exit handoff)
therefore renders one frame with no scene: the gray clear color. The incoming scene
then builds in the next frame, so the gray frame stayed on screen for that whole build.

## Rules

- Every `AppRouter._change_scene()` arms `SceneTransitionCover`
  (`scripts/ui/SceneTransitionCover.gd`, a CanvasLayer owned by AppRouter, layer 120).
  It shows a snapshot of the last presented frame until the incoming scene has drawn
  under it once (`SceneTree.scene_changed`, then `RenderingServer.frame_post_draw`),
  then fades it out over 120 ms of wall time, instantly with reduced motion. It
  blocks mouse input while it holds. Headless runs skip it unless a report forces it
  with `AppRouter.validation_set_transition_cover_mode("enabled")`.
- A screen that defers work until it is visible uses
  `AppRouter.call_after_scene_presented(callable)`. The callback runs in the first frame
  after the cover has cleared, or after one drawn frame when no cover is up.
- Battle entry keeps the first battle frame lean:
  - Board art (unit pose sheets, standees, icons, terrain) loads on worker threads
    (`scripts/ui/BattleArtPrewarm.gd`). The overworld requests it when the approach
    walk starts. AppRouter repeats the request before the entry checkpoint, for entry
    paths without a walk. The battle shell collects the requests after its first frame.
  - The entry checkpoint stays a synchronous, durable autosave. The handoff changes
    only the game state, so an overworld that was normalized before it stays marked
    normalized. The autosave then takes the trusted path and caches its own summary
    (`cache_summary`), so the battle save bar does not parse the file it just wrote.
    The battle shell re-normalizes the overworld only if it changed.
- Every battle refresh (entry and after each action) describes one board state:
  - BattleRules memoizes reachable hexes, attack legality, melee approaches and
    attackable target ids inside `begin_board_read_scope()`/`end_board_read_scope()`.
    The battle shell opens a scope around the read part of each refresh, and the
    movement-intent list opens its own. Inside a scope the caller must not change
    stacks, field objectives or town defenses. Each cache key also hashes the
    stacks, field objectives, distance and round, so a changed board misses.
  - Surfaces nobody is looking at are built when they are shown. The save bar's
    visible text (status lines, button labels) comes from
    `SaveService.in_session_save_bar_status()` on every refresh. The full save
    surface and its tooltips, which copy the whole session, are built when a save
    control is hovered or focused. The collapsed Tactical Details sidebar is built when
    it opens; while it is open every refresh builds it.
  - Commander cards stay in every refresh. Reading a commander summary also updates
    that commander's stored state, and the battle state must not change later, when
    the sidebar opens.
  - `validation_snapshot()` and the tab validation getters build anything stale first.

## Validation

- `tests/battle_entry_transition_report.tscn` drives three transitions from timers:
  overworld to battle (through the real approach timer), battle to the next scene
  after Quick Resolve, and overworld to town and back. It records every frame (each
  frame start, and `frame_post_draw` in windowed runs) and fails if a frame without a
  scene is shown uncovered. It also checks the entry checkpoint path, that the battle
  shell's first frame did not build the save surface, that hovering Save builds it,
  and that opening Tactical Details builds the sidebar without changing the battle
  state. In windowed runs, `--shots=<dir>` saves the battle-entry frames.
- `tests/battle_board_read_scope_report.tscn`, which compared the board read scope's
  memoized reads with uncached ones, is retired (2026-10-24, Phase 7 slice 7.9): since
  the battle port nothing read the memo, and 7.9 deleted the scope.
