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

Medium10 driver-policy correction: a known recruit-reward site that the current
army cannot claim must not repeatedly displace feasible exploration or combat.
Use the existing claim-admission authority, including fitting/matching-stack
controls and changed-army freshness; do not mark the real site collected, hide it
or remove troops. Retain a legal visible target across partial travel, refreshing
its live position/availability after a turn, instead of oscillating toward nearer
failed sites. Verify the observed stop is a driver defect, not an unhandled live
movement/pathing failure, before changing the policy. Use ordinary Town specialty
actions for earned choices. Preserve no-progress history and complete checkpoint
provenance on continuation; an old partial snapshot lacking adequate proof is a
reason to start fresh, not reset or relax terminal acceptance. Driver-only work
does not require re-exporting identical production files, but must identify the
unchanged validated runtime/package hash and preserve Linux/Windows parity.

No-progress observation must include actual first resource/artifact claims even
when their tiles were already explored. Compare stable category/placement ids
with authoritative `collected` and player-collector state before/after the order;
do not infer success from movement, result prose, income, spending or revisiting
an already claimed site. Reclaiming an enemy-held persistent site is a real
control change; rejected claims and unchanged repeat visits are not progress.
Keep the existing exploration, resolved-battle and scene-route observations,
14-day diagnostic horizon, terminal acceptance and saved driver history. Prove
the condition with real claim-rule mutations and negative controls. Existing
running tests keep their launch driver; never rewrite their action history or
reset their no-progress clocks to adopt this repair.

The full-match driver's existing owned-Town management priority may be checked
before computing unrelated encounter approaches, but must select exactly the
same catalog-first eligible town. Preserve current visibility/level, failed-target
and managed-day cooldowns and the original guard-risk check, even for remote
management. When no town qualifies, ordinary target order, scores, retained
intent and failure bookkeeping must remain identical. Prove complete targets
and serialized game state against the prior driver on a recorded real save;
use explicit ineligible inputs for boundary controls. Removed test-policy work
is not a runtime game-performance improvement. Do not restart a live match or
rewrite its history to adopt this optimization.

Existing Town recruitment-surface validation must open the real Muster modal
before observing recruit buttons. A closed lazy dialog's synthetic action
snapshot is not proof of visible UI. Python-owned invocation may adapt that
setup, while preserving all original tier, affordability, portrait and tooltip
assertions and explicitly requiring a visible modal.

The reproduced Medium seed-10 (50,48) stall requires a consumed-site lifecycle
correction: a collected cache no longer rendered or actionable must not leave an
invisible collision body. Use the existing site presence rules for collision,
rendering and interaction; retain persistent/repeatable sites and native transit.
Do not edit recovered package masks or remove overlapping scenery/other actors.
Prove live collection invalidates cached occupancy, backtracking and save/resume
work, rewards cannot repeat, and authored permanent body rules remain intact.

The Medium Day-54 continuation exposes scenic resource footprints redirecting
clicks on adjacent real artifacts. Exact live interaction tiles must retain
selection/route ownership before visual Town/resource footprint shortcuts;
selection, labels and execution descriptors must agree. Preserve ordinary scenic
body-to-entrance selection where no other interaction owns the tile. Prove both
recorded artifacts can actually be collected through pointer input, guards and
save/resume, plus encounter/entrance, level and stale-cache controls. Do not move
objects, alter masks or hide legitimate sites to avoid the overlap.
Guard control zones and town art anchors are not exact object positions. The
Medium10 saved-state reproduction corrects an earlier overly broad shortcut
assumption: an active same-level guard approach must remain directly selectable
even underneath resource scenery, otherwise a reachable combat square redirects
to an unreachable interior entrance. Keep the approach distinct from the guard's
anchor, use the existing encounter descriptor, preserve exact resource entrances,
and release priority on resolution/level change. Do not change movement masks or
combat triggers. Town art anchors still use their normal entrance shortcut.
Generated support-site visit tiles remain authoritative without an authored
scenic object descriptor. Recheck the real guarded opening arrival/primary-action
flow as well as both artifact collections.

### Army capacity and non-destructive recovery

Normal paid recruitment, unit transfers, site rewards and reinforcement delivery
must not create an eighth army stack. Use the existing `HeroCommandRules` seven-
slot authority, with one shared admission/merge plan before costs, reserves,
source troops or claim state change. Matching units may reinforce an existing
stack, including split formations, but each incoming unit is granted only once.
Rejected actions must explain capacity and leave all resources/troops/rewards
intact. Cached Town offers must agree with execution and refresh after transfers.

Older oversized armies must keep every saved troop. Show their real total,
occupied slots and explicit excess details instead of an empty formation. Keep
slot editing fail-closed for oversized holders; make the existing Town per-unit
transfers usable for reducing excess without overflowing a destination. Preserve
save version 9, movement, identities and recruitment prices. Tests must include
the unchanged recorded 18-stack/970-troop save, normal seven-stack admissions,
split-stack reinforcement, rejected-action atomicity, live UI and save/resume.
Deliveries and scripted reinforcement grants require separate explicit capacity
and reward-preservation coverage before this defect is called fully resolved;
no silently dropped rewards, new unlimited carry-reserve rule or truncated saves.
Existing Town Log & Logistics owns per-unit transfers; instructions must name that
actual dialog. Icons and troop counts must not overlap in the compact army row.
AI recruitment, site grants, roster reinforcement and raid/garrison handoffs also
require capacity-safe admission before consuming money, source troops or claims.
Whole-army consolidation/defense handoffs are atomic; an incompatible destination
must not consume any donor stacks or retire its commander. Resupply can accept
only fitting stacks and must retain rejected source stacks. Current-tile,
ordinary, explicit-objective and saved/live task selection must not repeatedly
assign a recruit claim or owned-town handoff that the same army cannot execute.
Retain fitting controls and deterministic generated-turn complete-state replays;
these rule-level controls do not replace terminal-match acceptance.
One-shot scenario hooks must retain earned reinforcement eligibility if full;
marking a hook fired and discarding its grant is not a correction. Preserve current
ownership/capture semantics and document the exact retention mechanism before
implementing it. Full-match acceptance must retain capacity observations across
all resumed segments and reject any overflow or unobserved historical segment.

Scripted retention mechanism (selected before implementation):

- Keep `fired_hook_ids` and all non-reinforcement effects' existing once/ordering
  semantics. A capacity-blocked grant creates one `pending_reinforcements` entry
  per hook/effect index inside the existing `scenario_script_state`; it records
  the validated earned unit manifest, day, original hero/town id and controller
  (and town owner). This is unclaimed source eligibility, not army inventory:
  it grants no strength, movement, transfer, sale or combat participation.
- Retry previously pending grants once at the start of ordinary hook evaluation,
  using the same seven-slot admission authority. Deliver the complete manifest
  exactly once to its original recipient, including a non-active owned hero.
  Do not re-evaluate transient earning conditions or repeat flags/resources/
  recruits/spawns/messages from the hook. Keep unmet grants saved unchanged.
- Missing recipients or changed town/hero ownership suspend that source grant;
  never create an actor or give it to a replacement/current commander or captor.
  Original-recipient/control restoration can make it eligible again. Grants
  that fit immediately retain existing ownership semantics. Existing fired hooks
  without pending records stay fired and must not receive retroactive rewards.
- All 106 currently authored reinforcement hooks are one-shot. For the existing
  generic repeatable-hook facility, at most one outstanding invocation per hook
  is allowed: do not accumulate repeated grants while a previous grant waits,
  or fire the same hook again in the pass that delivers its pending reward.
- Store the optional key only while grants wait; no save-version bump or default
  snapshot churn. Explain waiting/delivery through existing event messages and
  the recent-events surface, without a new screen or per-frame mutation/retry.
  Prove complete-state save/resume, fixed recipients/control, unchanged unrelated
  effects, fitting/split grants, bounded repeat handling and legacy no-regrant.

Capture full action latency including rules/AI, autosave, refresh, animations and
input re-enablement. Use the same seed, commands, conditions and instrumentation
for comparisons; preserve complete state and decision/RNG equivalence for
optimizations. Report p50/p95/max and the actual host/backend. Select the dominant
hotspots from measured evidence; do not promise a game-wide percentage from a
lookup microbenchmark. No skipped autosaves, removed opponents or hidden deferred
stalls. Retain the existing command/turn performance guardrails while explicitly
reporting any remaining player-visible multi-second delays.

The selected responsiveness work starts with the real Large Day-20 save: repeated
Town order preflight, recap and presentation reads must share calculations only
within synchronous read scopes closed before mutation. Compare complete saved
states and recap text against the original button handlers, test fresh/stale
affordability across all six factions, and retain existing action-feedback flows.
Use `tests/generated_town_order_profile.py` and
`tests/town_order_read_scope_regression.py`; `tests/generated_end_turn_profile.py`
then separates full End Turn/AI phases from the same recorded save. Benchmark
pauses may target only verified isolated test engines and must resume them on
exit; paused full-match timings are not uncontaminated performance measurements.
If the prior optimization fixture predates level-aware AI visibility, update
only its old-method reference call to retain the current level while disabling
the optional sight-source cache; do not change AI decisions or native semantics.

End Turn's resource-target scorer needs a town's support radius, not its full
linked-site logistics report. A lightweight radius projection must retain the
same plan/default/invalid-controller semantics and immediately reflect changed
towns. Verify it against the original complete logistics read and linked-town
bonus across factions, radius boundaries, ties, captures and real Large targets
using `tests/ai_town_support_radius_regression.py`. Complete End Turn serialized
states, including AI choices and autosaves, must still match the recorded control.

Overworld scenery-index reuse must not rebuild unchanged decorative/standalone
objects when a town, resource, artifact or encounter changes. The cache belongs
to the view only: identify every input used to construct those records, including
session identity, dimensions, view level, terrain rows, complete ordered map-object
payloads and relevant manifest mappings. Null/reset, session replacement, changed
body masks/order/metadata/terrain/level/assets and forced reference rebuilds must
refresh correctly. Compare every indexed payload against the prior uncached
owner, including generated-body overlap/source ids and raster assignments; equal
counts alone are insufficient. Preserve complete serialized game state, original
save files, ordinary collection/collision/fog behavior and rendered appearance.
Use real Medium/Large saved cases plus explicitly separate boundary fixtures;
measure cold and changed-interaction refreshes and real usable commands without
claiming microbench timings as whole-game improvement. Do not modify generation,
placement, masks, art, manifest contents, gameplay or saves to make reuse succeed.

## Presentation and compatibility

Inspect early/developed towns, Overworld and battle/outcome screens at 1280x720
and 1920x1080. Reproduce and fix the existing stray Town resource text, crowded
footer controls and building/background composition defects where current code
confirms them. Preserve scenery, action dialogs, hover/focus/click alignment,
input navigation and authoritative construction/save progression. Use current
original assets; no procedural art substitutes or unscoped art regeneration.

The recorded Town footer's apparent resource zeros are actually the standalone
stage's district-count strip drawn underneath TownShell navigation. When the
shell owns external overlays, the stage must not draw that strip or its duplicate
town title/count header. Keep district/garrison/action-count information in the
existing Log dialog; the top identity/resources, five action icons and footer
navigation remain authoritative. Standalone stage previews retain their own
overlays. Prove ordinary build and save/resume do not change, with real generated
opening saves and inspected 1280x720/1920x1080 captures. This corrects overlay
ownership, not the still-unfinished building/art integration requirement.

The Town command rail must show a short readable active-hero identity without
letting multi-line descriptive prose crowd the scene. Retain full hero details
in its tooltip and keep commander/specialty actions accessible. Empty-state copy
must wrap or ellipsize within its actual available width, never clip a word with
no indication. The Overworld save-status label must sit inside the system frame's
safe content inset, remain distinguishable from adjacent buttons and preserve
normal Save/End Turn/Settings/Menu actions plus save/load/error feedback. Check
both generated opening fixtures at both supported resolutions and retain every
serialized gameplay field through layout and dialog-only interactions.

The first Town entry must show pending specialty choices and stationed-commander
actions immediately, without requiring a build, purchase or tab refresh. Consume
the existing full entity view's cached command rows even when presentation is
minimal; keep hidden management lanes lazy. Verify empty and populated controls,
keyboard activation through the existing handlers, refreshed choices/identity,
full save/resume and bounded two-resolution layout. Explicitly isolated test
fixtures may grant experience through the existing progression authority and
pay normal tavern hire costs; these are UI controls, not accepted full matches.

Outcome presentation must not show a generated runtime id as the scenario title.
Use an existing legitimate display name where present, otherwise a short clear
generated-realm label; keep internal identity and stored package references
unchanged. Long authored names must wrap or ellipsize intentionally with the full
title available, without expanding the banner over scenery or clipping controls.
Reproduce the real Large terminal save and inspect both supported resolutions.
The offered Retry Skirmish action must genuinely start a fresh same-map/setup
game after the existing confirmation, or explain an unavailable source while
preserving the outcome. Audit this through actual UI routing rather than assuming
that authored-scenario startup accepts native generated ids. A confirmed defect
may use existing generated/package session startup authority, but must not alter
RNG/topology, faction/hero/difficulty choices, save versions, terminal save bytes,
campaign progress or cancel/stale-request/rollback semantics. Missing packages
must not silently create a different map or default-faction game.

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
