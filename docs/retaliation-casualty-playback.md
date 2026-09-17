# Retaliation casualty playback

Owner-directed Phase 6 slice: `bugfix-retaliation-casualty-playback-20260917`.
Status: runtime correction implemented and focused/platform validation passed;
full closure blocked by pre-existing historical-report retention checks.

## Cause and scope

Both player and enemy attack resolution applied retaliation damage before
capturing `battle_retaliation`. That snapshot already contained the dead attacker
but only the defender's attack event, so the board displayed the attacker's
corpse. The next snapshot scheduled the attacker's death; its reaction delay
temporarily displayed idle, then the death animation. Health never recovered.
The same ordering also lost retaliation damage/casualty deltas between snapshots.

Capture the counterattack before applying its damage. Keep simulation damage,
RNG, retaliation spending, effects, AI, save schema and outcomes unchanged.
Do not modify/regenerate art, clear caches, change animation timings, or touch RMG.

## Acceptance

- Player- and enemy-origin attacks, lethal and surviving retaliation.
- During counterattack windup the target retains pre-hit health and is not a corpse.
- Exactly one lethal reaction; after completion the corpse stays dead across
  following snapshots and final-state synchronization, including battle exits.
- Retaliation damage/casualty captions reflect the actual health/count delta.
- Normal, Fast, reduced-motion and Instant controls preserve final simulation state.
- Source and Linux/Windows packaged focused regressions, rendered Normal/Fast
  inspection, existing battle readability coverage, `python3 tests/validate_repo.py`,
  official platform export smokes and `git diff --check` pass.

Python owns the regression driver and temporary Godot probe. Final results are
recorded here after validation; generated logs/screenshots/packages are removed
under the owner's non-RMG evidence retention rule. Windows Wine checks are not
physical Windows GPU certification.

## Reproduction

```sh
python3 -B tests/battle_retaliation_playback_regression.py --label focused --timeout-seconds 120
python3 -B tests/battle_retaliation_playback_regression.py --label visual --render --resolution 1280x720 --timeout-seconds 180
python3 -B tests/battle_retaliation_playback_regression.py --label fast --render --resolution 1920x1080 --speed fast --reduced-motion --timeout-seconds 180
```

For release probes, use the same driver with `--platform linux|windows`, matching
`--binary`/`--pack` paths, and a fresh `--wine-prefix` for Windows. The existing
isolated-package bootstrap checks compiled owner hashes and export immutability.
Use unique labels and task-owned platform export directories. The 36-case matrix
uses controlled presentation clocks; the rendered shell cases use real clocks
and assert the victim never becomes a living actor again after showing a corpse.

## Validation results (2026-09-17)

- Source focused: 660 checks / 36 cases passed. Covers both attack paths, lethal,
  surviving and battle-ending retaliation, three speeds and reduced motion.
- Source rendered Normal: 690 checks, both sides passed. Fast/reduced motion at
  1920×1080: 682 checks, both sides passed. Inspected counterattack/death/corpse
  captures; real-clock playback never returned a displayed corpse to a live actor.
- Existing battle readability regression: 39 checks passed.
- Official Linux and Windows export/startup smokes passed, including Windows
  generated-map/Town/build entry and managed Wine cleanup.
- Linux packaged regression: 685 checks, including both real rendered shell cases
  at 1280×720. Windows packaged regression under headless Wine: 660 checks.
  Compiled-owner verification, unchanged-package checks and all assertions passed.
- Both PCKs: 638,705,572 bytes / 8,846 members; all 8,845 non-`project.binary`
  members byte-identical. No art or package contents added by the fix.
- Python syntax and `git diff --check` passed.

The first rendered probe exposed a fixture setup error: it bypassed the shell's
entry normalization, then compared its artificial pre-normalization state with
normalized exit state. Moving normal shell refresh before the action fixed the
fixture without removing the equality assertions. A requested-resolution reset
was also corrected and screenshot dimensions are now asserted. Those initial
probe failures are not counted as passing runs.

`python3 tests/validate_repo.py` **failed with exactly 26 missing historical
consolidated smoke reports**, unrelated to the changed combat owners. For example,
`validate_uncrowned_circuit_campaign` unconditionally requires
`.artifacts/uncrowned_circuit_campaign_smoke/report.json`; `validate_six_marchland_seats`
has the same retention requirement. These checks conflict with the owner's
approved removal of non-RMG generated evidence. No validator checks were weakened,
reports fabricated, or unrelated campaign smokes rerun to recreate disposable
history. Needed follow-up: align that validator/report-lifecycle policy with the
owner's retention rule. Until resolved, this slice remains blocked on full
repository validation, not on the retaliation implementation.

Cleanup removed 68 task-owned non-RMG outputs (screenshots, logs, reports, test
packages and disposable profile links), recovering 1,527,164,928 allocated bytes
(1.42 GiB), after confirming no open process references. They are rebuildable.
Six cache/save/map-dependency/configuration files (2,710,994 bytes) remain with
unchanged hashes. Original art, RMG recovery material, pre-existing `/tmp` files
and unrelated untracked files were untouched. The source regression and this
result summary remain reproducible.
