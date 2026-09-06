# Generated full-match quality

Owner direction, 2026-09-06: improve complete-match player-facing quality after
the source/runtime review rated the current game a playable alpha, not a release
candidate. Phase 6 parent: `quality-generated-full-match-20260906`.

## Acceptance and truthful play

- Complete reproducible Medium and Large generated matches through ordinary
  victory/defeat and the real scene/router outcome flow. At least one accepted
  run must pursue and achieve conquest; losing by deliberate suicide, automatic
  surrender, injected outcomes, a turn deadline or a dead driver is not success.
- Use normal faction/hero setup, resources, armies, movement, fog knowledge,
  construction, recruitment, enemy turns, guards and battle consequences. The
  driver may choose legal orders and use the shipped Quick Resolve flow, but
  must not weaken armies, move actors directly, reveal the map or normalize away
  blockers. Tactical/manual coverage and Quick Resolve coverage stay distinct.
- Exercise meaningful development/exploration/hostile encounters and a complete
  conquest or legitimate defeat, with mid-match and terminal save/resume. Record
  elapsed turns, actions, battles, outcome, objective state, seed/configuration,
  platform/backend, input method and revision/source hashes. A short loss alone
  does not cover the middle/late-match systems.
- Keep a durable latest checkpoint and compact action/profile JSONL plus sparse
  screenshots. Save full state only for selected comparison/failure checkpoints;
  do not recreate tens of gigabytes of per-action duplicate session dumps.

## Correctness and responsiveness

First reproduce and identify exact runtime owners for blockers. Add a failing
focused regression before each correction, then replay the affected path. A
driver correction alone is support work, not a gameplay fix or goal completion.

Capture full action latency including rules/AI, autosave, refresh, animations and
input re-enablement. Use the same seed, commands, conditions and instrumentation
for comparisons; preserve complete state and decision/RNG equivalence for
optimizations. Report p50/p95/max and the actual host/backend. Select the dominant
hotspots from measured evidence; do not promise a game-wide percentage from a
lookup microbenchmark. No skipped autosaves, removed opponents or hidden deferred
stalls. Retain the existing command/turn performance guardrails while explicitly
reporting any remaining player-visible multi-second delays.

## Presentation and compatibility

Inspect early/developed towns, Overworld and battle/outcome screens at 1280x720
and 1920x1080. Reproduce and fix the existing stray Town resource text, crowded
footer controls and building/background composition defects where current code
confirms them. Preserve scenery, action dialogs, hover/focus/click alignment,
input navigation and authoritative construction/save progression. Use current
original assets; no procedural art substitutes or unscoped art regeneration.

Native generation semantics are not selected for change. Follow
`docs/lessons-learned.md` if a failure reaches that boundary: name the unrecovered
function/state proof and create a properly scoped recovery child before changing
generation. No balance/topology/density/RNG tuning to make a test pass. Preserve
the save schema, package format, authored pool and 250000000-byte package ceiling.

## Validation and handoff

Python owns new orchestration; existing scene/domain validation entry points and
disposable engine probes may drive real gameplay. Required commands include the
new `tests/generated_full_match_quality.py` Medium/Large cases, focused new tests,
affected existing domain reports, `python3 tests/validate_repo.py`,
`git diff --check`, `tests/packaging_linux_export_smoke.py` and
`tests/packaging_windows_export_smoke.py`, including startup/generated map/Town
entry. Inspect final screenshots rather than relying only on rectangles.

Windows/Wine execution is not native Windows/GPU certification. Do not claim
whole-product release readiness or exhaustive seed/faction/late-game coverage.
The owner's prior non-RMG artifact cleanup removed old raw run data; historical
docs are context, not substitutes for this goal's fresh evidence. Preserve RMG
recovery data, caches and unrelated untracked retention files/reports.

Keep PLAN/tracker statuses current. Complete children only when their behavior
and validations are real; document exact unfinished work otherwise. Commit only
coherent validated work, push to origin/main and verify HEAD/status on handoff.

### Required validation maintenance

Fresh regeneration after the owner-approved artifact cleanup exposed historical
smoke assertions predating the current 160-unit/299-scenario catalog and the
Charterless Compact's shared campaign/skirmish chapters. Align only those exact
catalog, availability and witness-hook assertions with the already-established
contracts in `tests/validate_repo.py` and current authored content. Retain all
build, recruitment, battle, reward, outcome, provenance and save checks. These
test repairs support validation of the same-slice gameplay fixes; they are not
new content, balance changes, or complete-match proof.
