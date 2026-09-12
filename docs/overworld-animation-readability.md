# Overworld animation readability

Owner-directed Phase 6 implementation slice `animation-overworld-readability-20260912`, derived from `project.md` and `PLAN.md`.

## Requirements

- Smooth player travel without cutting route corners or changing committed movement. Add restrained stride/settling to original hero rasters, keeping ground contact, selection and destinations readable.
- Improve revealed AI motion, fog entry/exit transitions and action feedback using the existing allowlisted committed-event records. Never animate toward hidden coordinates or change exploration, controller identity, RNG or AI decisions. Keep skip, reduced motion and battle/save handoffs working.
- Give existing original interaction effects readable arrival, emphasis and decay instead of abrupt appearance/disappearance. No replacement procedural object art.
- Add appropriate subtle environmental motion with bounded viewport-local work. Do not rebuild static terrain/object layers every animation frame. Respect reduced motion/high contrast and visibility. Measure generated Large-map behavior, not only tiny fixtures.
- Retain original art, footprints, gameplay rules and save schema. No native RMG, balance, unrelated UI redesign or asset generation in this slice.

## Owners and validation

Runtime owners: `scenes/overworld/OverworldMapView.gd`, `scenes/overworld/OverworldTurnPresenter.gd`, and a presentation-only motion helper if useful. Capture authorities `scripts/core/OverworldTurnPlayback.gd` and OverworldShell routing remain unchanged unless a reproduced presentation defect requires a narrow correction.

Python-owned tests must exercise actual rendering, deterministic route endpoints/corners, fades and reduced motion; existing AI/fog/skip/state-equality tests remain required. Capture before/after sequences at representative small/wide resolutions and inspect the images; use a compact clip where it materially demonstrates motion. Profile viewport animation and generated Large travel/turns. Run relevant existing reports, `python3 tests/validate_repo.py`, `git diff --check`, and established Linux/Windows exports plus isolated gameplay checks. Record exact scope, errors and hardware limits. Complete only after implementation and real evidence; cleanup and push coherent validated work.

## Baseline findings

Player `_hero_movement_draw_state` traverses committed route segments linearly; AI `_draw_turn_playback_actor` applies a linear translation to an unchanged sprite. AI appearance/disappearance records are safely filtered but lack visual fades. Imported object-resolution effects begin at full opacity and retain nonzero opacity at removal. Ambient particles are viewport-local and explored-only, but redraw unconditionally each animation frame. These are presentation owners, not simulation gaps.

## Implementation

Runtime adds presentation-only acceleration/settling and bounded stride offsets (stationary ground shadows), smooth interaction envelopes, fog-safe AI boundary fades, original manifest-backed capture/contact cues and explored-only water glints. Slow ambient redraws are capped at 30 Hz. No simulation writes were added; the transient action record carries only an allowlisted cue id derived from its already-public action verb. These are motion/timing improvements using existing paintings, not newly generated directional walk sprite sheets.

Frame review additionally exposed an existing town-departure size pop: moving markers bypassed the stationary town-visitor layout. Movement now interpolates the resting visitor/field rectangles and sprite factors across each committed segment, matching the resting endpoint layouts instead of jumping to field size. This does not move towns, alter their art or change the hero's authoritative tile. `OverworldMotion.gd` owns stateless curves; OverworldTurnPresenter, simulation execution and save schemas remain unchanged.

Baseline source render: `.artifacts/menu_and_turn_readability_20260910/overworld-animation-baseline-20260912`, 61 checks. First rendered motion probe: `.artifacts/overworld_animation_20260912/motion-render-draft`, 269 checks; curve/headless control: 256. These precede the latest combined AI cue changes and are not final acceptance. An inferred-type parse error in the subsequent draft was corrected with an explicit Texture2D type; failed logs remain, not counted as passes. Sequence capture, generated Large profiling, accessibility and both-platform validation remain pending.

## Validation record

Evidence root: `.artifacts/overworld_animation_20260912/`. All scripted movement fixtures use legal route execution; controlled fog exposure reveals a diagnostic AI corridor and is not a claim that new games start with enemy territory visible.

- `town-transition-final`: source 1280x720, 345 checks including 9 sampled player frames, real AI travel/action frames, endpoint/size interpolation, fog and full-state controls.
- `large-package-final`: final Linux package, generated seed 10, 108x108 Large, 1920x1080, **375 checks passed**, including the town-size interpolation refinement. Actual player movement, four AI turns, multiple named commanders/site actions and 26 viewport-local ambient entries. Source `large-final` passed 357 checks before that final refinement and is not substituted for this package proof.
- `large-before-profile`: the pre-change release PCK, identical seed/size and probe (new-curve checks explicitly disabled), 144 checks. Actual player/AI/action before sequences retained. The compiled baseline is not substituted into the working source.
- In 120 controlled 1/120-second ticks, baseline ambient redraw requests are 120 and new requests are 30. Final packaged Large viewport entry-building samples average about 1.73–1.77 ms before and 1.72–1.87 ms after; 120 animation ticks total about 0.25–0.31 ms. These are software-host CPU component timings, not FPS/hardware certification or a claim that generation/end-turn simulation became faster. Terrain cache generations remain unchanged through sampled motion frames; preference/layout changes are settled before this check.
- Final isolated Windows `windows-package-final` passes **336 checks**. Headless Windows intentionally bypasses automatic turn playback in production: the probe exercises real player orders and instantiates the shipped presenter with real captured records, while rendered Linux/source tests verify automatic End Turn and battle handoff. No Windows GPU certification is claimed. Earlier 327/318-check packages preceded the town-size refinement and are not final acceptance.
- Existing input ownership, full-route movement and fog reports pass under `.artifacts/full_play_runtime_20260905/overworld_animation_20260912/`. Existing imported object-resolution and hero-route VFX reports pass against both pre-change and changed isolated Linux packages (`before-*` / `after-*`). The older guarded-site cue report fails its same exact context-only selection assertion in both packages, before reaching its resolution assertions; it is not counted as a pass and unrelated selection semantics are not rewritten here.
- `tests/validate_repo.py` source guards now recognize the intentional smooth opacity envelope, isolated actor-opacity multiplier and interpolated hero rectangle while retaining resource-region orientation and authoritative hero identity checks. Initial failures expecting the old exact source text were not accepted as passes. Final full repository validation **passes** (`/tmp/heroes-overworld-animation-repo-final-20260912.log`).
- `reduced-motion-final` uses `--reduced-motion` and passes **309 checks**, including effective reduced preference, snapped player movement and zero ambient animation redraws. A run named `reduced-final` used an overridden environment variable and is normal-motion evidence only.

Official final exports (`linux-final-export`, `windows-final-export`) pass startup and established generated Overworld/Town smokes. Both PCKs are **313207432 bytes**, 5601 members, with only `project.binary` different. `package-parity.json` records matching compiled MapView, Motion and TurnPlayback hashes. No native libraries, content/art or save schema changed.

Small/wide final screenshots were opened and inspected, including original-art travel, the town-size transition, AI movement/site cues and fog surroundings. `town-departure-comparison.mp4` is a 5.94-second loop of sampled before/after Large departure frames, cropped to the same town area and explicitly labeled 4x slow motion; it is not a continuous gameplay recording. Unedited full-viewport PNG sequences remain beside the reports.

Scoped cleanup removed **881390550 bytes**: six superseded task export files and 63 draft PNGs. Final exports, before/after evidence, logs/reports, a diagnostic pre-fix departure frame, original art, caches and preserved Wine user data remain. Managed Wine prefixes were removed by their owning wrappers after shutdown. The four pre-existing unrelated untracked paths are untouched.

Final imported object-resolution and hero-route VFX rechecks also pass against the final Linux PCK (`final-overworld_object_resolution_vfx_asset_runtime_report` and `final-overworld_hero_route_step_vfx_asset_runtime_report`). The earlier guarded-site assertion remains a documented pre-existing limitation, not a new regression or a claimed pass.

Reproduce focused source checks with `python3 -B tests/overworld_animation_readability_regression.py --label <fresh-label> --render --resolution 1280x720`, adding `--reduced-motion` for the accessibility case. For Large, set `MENU_TURN_GENERATED=1 OVERWORLD_ANIMATION_MAP_SIZE=large` and use 1920x1080. The packaged wrapper takes the established `--platform`, `--binary`, `--pack`, `--label`, `--resolution` and fresh Windows `--wine-prefix` arguments. Baseline comparison explicitly sets `OVERWORLD_ANIMATION_BASELINE=1` and uses the retained pre-change PCK; it disables only the new-curve/layout assertions. No production fallback flag is added.

Status: completed 2026-09-12. This is completion of the selected animation slice, not universal animation/hardware certification or release readiness.
