# Complete Battle Unit Animation and Size

Owner goal, Phase 6: `combat-unit-animation-and-size-20260913`.
Requirements derive from `project.md`; execution is tracked in `PLAN.md` and
`ops/progress.json`.

## Current implementation

2026-09-19 follow-up: [six common creatures](creature-idle-expansion.md) now have
eight-pose idle loops shared with the overworld. All stacks use independent idle
timing. Action pixels remain unchanged. The six acceptance records carry their
own review status and hashes; the original roster review below is historical.

All 160 authored units (90 faction, 70 neutral) have original articulated raster
idle, move, attack, defend and death clips plus a persistent dead pose. Ranged
units have distinct firing/casting routing. All 160 have explicit size profiles;
37 use true two-adjacent-hex bodies. Implementation and visual acceptance are
complete as of 2026-09-16; final Linux/Windows packages and repository closure pass.

`battle-unit-animation-acceptance.json` records every reviewed identity, atlas
hash, pose-metadata hash, actual action contact sheet and small-screen resting
sheet. Manifest review status is not an automatic test result: it was assigned
only after inspecting all 160 identities. The packing test rejects a stale
review after changes to pixels, clips, grounding or facing.

## Acceptance requirements

- Every current unit, including neutrals and alternate identities, needs readable
  idle, movement, attack, defense and death animation plus a persistent dead
  sprite. New units inherit this requirement. Animated clips contain genuinely
  different painted poses, not duplicates or transforms of a standing cutout.
- Preserve identity, equipment, transparent original-raster provenance,
  anatomical grounding and readable silhouettes. Ranged and retaliation events
  retain their appropriate poses; accessibility may suppress movement without
  suppressing state information.
- Dead sprites persist until battle exit, survive save/resume, remain below
  living units and have no health readout, targeting or live occupancy. Revival
  removes the corpse presentation. A living unit may stand over a freed casualty
  cell; this is not resurrection or a missing corpse.
- Large bodies have explicitly authored scale and two horizontally adjacent
  cells. Facing determines the rear cell. Deployment, paths, movement preview,
  melee/reach/retaliation, AI, spells, pointer/controller targeting and collisions
  use the full body. Death releases both cells.
- Legacy battles without footprint metadata keep one-cell occupancy rather than
  silently expanding into overlaps. New body fields survive save/resume.
  Presentation clocks, art and settings must not alter simulation RNG or rules.
- Validate actual battle flow, all-unit playback, small/wide visuals,
  accessibility, deterministic simulation, save/load, repository consistency and
  Linux/Windows packaging. Keep source art out of runtime packages.
- No native RMG, overworld footprints, Town/UI redesign, copied Heroes art,
  balance tuning or procedural replacement sprites. No fixed package-size
  ceiling; measure sizes and preserve platform parity.

## Runtime ownership and corrections

`BattleFootprint.gd` owns shared body geometry for `BattleRules.gd`,
`BattleAiRules.gd` and `BattleBoardView.gd`.
`content/unit_battle_size_manifest.json` supplies scale/footprints, not unit
names or tiers. Battle saves store these body fields; pose data remains
presentation-only.

`BattleUnitPose.gd` resolves manifest clips, explicit aliases, source facing,
event-relative frame clocks and anatomical ground margins. Board owns drawing,
not combat decisions. Corpses use the same authored ground/facing metadata as
living sprites and draw below living actors.

Queued hit/death/retaliation no longer displays before its scheduled start.
The actor keeps idle or its held guard; displacement, casualty drawing and VFX
wait for contact. Delayed movement remains at its source cell. Fast clocks scale
pose cadence with movement; reduced motion holds the authored informative frame.

Whole-roster review corrected 29 static guards into non-looping ready-to-brace
transitions using distinct existing original paintings. Six explicit cast aliases
now receive their ranged checks. Resonant Choristers and Prismwake Raylings have
dedicated newly painted ranged poses; Raylings retain all three tails. Sources,
rejected drafts, exact prompts and hashes remain under each unit directory.

## Consolidated evidence (2026-09-16)

Local evidence root:
`.artifacts/battle-unit-animation-size-20260913/full-roster-validation-20260916/`.
Packages, raw captures and runtime reports:
`/tmp/heroes-battle-roster-validation-20260916-RbzwGc/`.

| Requirement | Current evidence |
| --- | --- |
| All 160 required states, original source lineage, reproducible packing | Nine packing/provenance/review tests plus nine cutout and seven report-recovery tests pass (25 total). Every registered atlas repacks byte-exactly; animated clips contain distinct pixels; death settles in its dedicated dead frame. |
| All 160 source and Windows action/ranged/death/save routes, Fast/reduced motion | `source-fast-reduced-controlled-r3` and `packaged-poses-fast-reduced-controlled-r3`: 32,507 checks each, all 160 checkpoints, clean exit. These are explicitly controlled-headless clocks, not GPU visual certification. |
| Normal real-time all-roster playback | `packaged-poses-wide-r3`: all 160 completed, 27,107 checks, one late-capture assertion. Original report remains failed. Unchanged focused `packaged-capture-followup-unit_neutral_milestone_bucklers`: 311 checks passed. All 160 final action contact sheets inspected. |
| Small-screen idle and unobscured corpse art | `source-resting-roster-small-r2`: 2,153 checks, 160 distinct real-time idle pairs, 480 images at 1280x720; all inspected. |
| Body geometry, both facings/edges, crowded deployment, paths, near-body attacks, AI, pull/relocation, legacy saves and revival | Source wide/small: 1,033 checks; Windows headless: 1,030. `packaged-bodies-small-final`: 1,033 checks and inspected 1280x720 captures. Three omitted Windows checks require rendered image dimensions, not gameplay. |
| Actual board select/confirm, enemy queue, input locking, focus restoration and Instant setting | `packaged-shell-input-small-r2`: 64 checks, nine rendered event frames including six enemy frames, actual 1280x720 resolution; inspected. |
| VFX and deterministic battle flow | `consolidated-vfx`: 1,333 checks; `consolidated-readable-actions`: 39 headless checks. |
| Repository and package completeness | `repository-closure.log`: VALIDATION PASSED, clean exit at 18:42 UTC. Final official exports pass, including Windows generated-map/Town/build and managed Wine cleanup. |
| Final exports and cross-platform payload parity | `accepted-r2-linux` and `accepted-r2-windows` pass; final packages have 8,846 members / 638,705,108 bytes each, with only `project.binary` differing. Fresh packaged body checks pass 1,033/1,030 and each reads 160 accepted units. `accepted-r2-payload-equivalence.json` proves every art/compiled-owner/other payload identical to the full-roster-tested packages; only review metadata in the animation manifest changed. |

The small and wide captures are battle fixtures using actual game rules and
rendering, not an entire-match playthrough or a whole-game release claim.
Windows runs use headless Wine and validate packaged code/content/rules;
native Windows GPU presentation still requires owner hardware observation.

## Failures retained and explained

- The sole final wide-run failure sampled Milestone movement at 767ms after a
  700ms event (earlier samples: 109/275/454/653ms). Returning idle after expiry
  was correct. The focused unchanged replay passed and its replacement images
  were inspected. No relaxed deadline or art substitution was used.
- Earlier Fast Windows headless wall-clock captures failed 69 timing assertions
  after their 109ms event lifetime. Headless tests now sample actual event records
  with controlled clocks; rendered tests retain real clocks and strict expiry.
  Clock mode is explicit in each report.
- An initial resting capture failed 32 assertions because PNG work and nominal
  timers did not guarantee distinct displayed idle phases. The corrected probe
  observes real frame regions away from boundaries before copying images; it
  never rebases the idle clock. Its pixel ROI is explicitly limited to 1280x720.
- Earlier partial/time-limited/interrupted jobs remain incomplete, not green.
  Finished-unit checkpoints preserve diagnostics but cannot replace a final
  report and clean exit.
- A small-shell launcher initially moved its temporary res:// probe outside the
  repository while selecting an external evidence folder. The wrapper now
  selects only the report destination; probe scripts remain inside res://.
  The corrected packaged shell run passed. Production game code was unaffected.
- The first accepted-metadata export lacked the transient service's user template
  search path and produced no binary. Explicit XDG paths fixed the launcher;
  both final exports pass. Its failed report remains, and its task-created stray
  editor settings file (3,280 bytes) was removed after handle/ownership checks.

## Reproduction and maintenance

Run generation/refinement as complete batches before one consolidated acceptance
pass, per owner sequencing. Do not resume per-pose test/export loops.

Commands:
```sh
python3 -B tests/test_pack_unit_pose_art.py
python3 -B tests/test_battle_pose_cutout_preparation.py
python3 -B tests/test_battle_pose_report_recovery.py
python3 tests/validate_repo.py
python3 -B tests/battle_pose_playback_regression.py --label roster --render --resolution 1920x1080 --motion-samples --timeout-seconds 7000
python3 -B tests/battle_unit_body_runtime_regression.py --label resting --render --resolution 1280x720 --roster-resting-samples --timeout-seconds 2400
python3 -B tests/packaging_linux_export_smoke.py
python3 -B tests/packaging_windows_export_smoke.py
git diff --check
```

Use unique task-owned labels. Package drivers accept `--platform`, `--binary`
and `--pack`; Windows also requires a fresh managed `--wine-prefix`.
`HEROES_BATTLE_READABILITY_ARTIFACT_DIR` redirects bulky evidence, not res://
scripts. Official exports accept platform-specific artifact-directory variables.
Linux probes sharing an export directory must run serially because the strict
bootstrap rejects concurrent loose probe files.

## Retention

Original/generated sources, selected alpha, recipes, provenance, caches, saves,
native reverse-engineering material and final validation evidence are retained.
Four verified rounds removed only superseded export binaries, recovering
7,085,194,272 bytes (about 6.60 GiB); their reports/screenshots remain. Final
packages are in the `accepted-r2-linux/export` and `accepted-r2-windows/export`
directories above. Disposable Wine system
files were cleaned through the managed lifecycle, preserving user data.
Historical production notes were moved to the same evidence root as
`production-notes-before-closure.md` and `workflow-notes-before-closure.md`;
per-unit source records remain the provenance authority.
