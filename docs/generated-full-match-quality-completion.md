# Generated full-match quality completion — 2026-09-09

Parent: `quality-generated-full-match-20260906`. Requirements:
`docs/generated-full-match-quality-requirements.md`. Implementation boundary:
`512d3b19874a5b5df3128012571f6a2c10f1335a` and its validated ancestors.
The three selected children satisfy their scoped requirements. This closure
records implemented behavior and retained acceptance, not new gameplay or a
release-ready product. Earlier checkpoints' unfinished-work statements describe
their dates; this document is the current disposition of those selected gaps.

## Implemented results and evidence

All paths below are relative to
`.artifacts/generated_full_match_quality_20260906/` unless stated otherwise.

| Requirement | Implemented result and accepted evidence |
| --- | --- |
| Legitimate Medium match | `medium_match_11_continuation_03/report.json`: ordinary Day-97 victory, 2426 observed legal-capacity actions, 66 battles and casualty reports, 137 builds and five complete save/resumes. Exact checkpoint-proven multi-version continuation, not an uninterrupted final-build run. |
| Legitimate Large match | `large_match_08/report.json`: Day-14 defeat after enemy-town conquest, 201 observed legal-capacity actions, 15 battles/reports, 13 builds and three complete save/resumes. No deliberate surrender, injected outcome or deadline defeat. |
| Correctness | Shared army admission/earned-reward retention, consumed-site collision and exact-target routing, controller/team-aware generated objectives, live roster/commander refresh, first-entry Town actions and same-map outcome retry are implemented. Exact failing-before controls and domain/platform evidence: `docs/generated-full-match-quality-report.md`. |
| Responsiveness | Synchronous Town logistics reuse, exact AI support/path/blocker/commander projections, scenery reuse and stored recap freshness remove repeated work without skipped turns/saves. Matched recruitment waiting improves 51.5% Large / 20.5% Medium; complete End Turn improves 19.5% / 18.3%; complete-loop save-surface work improves 68.2%. Complete-state controls and measurement limits: `docs/generated-full-match-performance-report.md`, particularly `closure_endturn_large_4d171105` and `closure_endturn_medium_4d171105`. Percentages are separate comparisons, not additive. |
| Town integration | 173 original exact-faction scene layers cover every non-embedded starter/buildable identity across all 32 towns. Town Hall remains part of each preserved village. `TownStageView.gd`, `TownBuildingHotspot.gd` and the scene manifest share projected, alpha-aware painting/input authority; same-site upgrades retain saved ancestry. Catalog/info art remains separate. |
| Other selected presentation defects | Duplicate Town overlays, compact command/footer text, resource-caption fitting and readable ledgers are corrected. Wreck Quay, Cinder Ore Face, Moss Oath Cache and Marsh Listener Post retain their original subjects without reproduced atlas dividers/magenta contamination; identities, masks, states and saves remain unchanged. Exact controls and inspected captures: `docs/generated-full-match-art-repair-report.md`. |

Town acceptance spans Veilmourn 27, Embercourt 30, Mireclaw 31, Sunvault 29,
Thornwake 29 and Brasshollow 27 mappings. The six corresponding
`*_variant_acceptance.json` / `*_faction_acceptance.json` records retain the
source, Linux and Windows paid-order/input/save comparisons. Earned Bellwake,
Riverwatch and Duskfen progression is distinguished from later isolated build
fixtures and detached developed compositions. Those fixtures do not establish
six-faction full-match or earned full-town completion.

## Final package and visual boundary

The final Brasshollow boundary completed seven acceptance jobs, including the
official Linux/Windows exports, startup and normal generated-Town paid flows,
shared Town layout/dialog and skyline reports, 45 focused Python tests,
repository validation and the identical faction probe in both packages.
Source/Linux/Windows each pass 22050 assertions and 29 ledger actions. All 35
complete saved cases agree within the documented cross-run clock/instance-id
limits; within-run full-state comparisons exclude nothing.

Both final PCKs contain 5482 members and measure **286717700 bytes**. There is
no fixed size ceiling. The final addition preserves 5426 earlier payloads;
only its scene manifest and UID cache change, with 54 new runtime/import entries.
Only `project.binary` differs between platforms. No source art or test scripts
leak into the package. Exact retained packs:

- `brasshollow_faction_release_linux_01/isolated-export/heroes-like.pck`, SHA256
  `c0e806e91d818b6e9683c11f9ba7a8131bb2c2f8a01966c678cec6f648920b39`.
- `brasshollow_faction_release_windows_01/isolated-export/heroes-like.pck`, SHA256
  `8499e8224c0de8bdf6b13da1d2f7278e23d0e3f2c1be2431deba68ef20842ae4`.

The closing read-only refresh confirms both pack hashes, all nine recorded
source/probe hashes from the final source run, all 173 source/trim/runtime/prompt
hashes and the exact 32-town mapping unions. Six faction acceptance records and
the Cinder/Moss and Marsh package records pass. `git diff 4d171105 HEAD --
scripts/core native` is empty: the accepted simulation, save and performance
owners have not changed. Reuse those match/performance measurements, not new
timing claims or repeated multi-day runs. The corrected Thornwake EOF-only
prompt hashes are included; earlier mismatched provenance is not called valid.

Direct visual review at closure reopens the retained Dreamwake and earned
Riverwatch 1280x720 views, Splitprism and Briarwheel 2048x1079 views, Whitegauge
1280x720 and earned Duskfen 1920x1080 views, plus the corrected Medium Marsh
gameplay capture. These show faction-matched, grounded architecture, preserved
main-hall/path composition and usable edge controls. The per-batch reports
retain the full small/wide, starter/intermediate/developed and painted-input
evidence, including rejected placement previews; this review does not relabel
detached views as earned play or claim every possible viewport was inspected.

## Limits and handoff

- Large End Turn p50 remains about **7.4 seconds** on the measured software-
  rendered Linux host. More optimization remains worthwhile; this is not
  universally fast interaction or a hardware-independent guarantee.
- Windows execution is headless Wine, not physical Windows GPU/audio/controller
  certification. Complete generated matches used the shipped Quick Resolve
  flow, not exhaustive manual tactical play, seeds, factions or configurations.
- The legacy keyboard smoke still expects numbered-slot overwrite UI before
  Town, while the game uses named saves. It is not reported passing. The older
  domain development matrix still misses Moonbite's 30-turn target (31/32),
  although all its 32 save/resume cases pass; no balance shortcut was applied.
- This closes reproduced selected art defects, not an exhaustive terrain/asset
  quality certification or H3MapEd/native parity. Save schema, package format,
  gameplay balance, native topology and RMG rules remain outside this art work.
- Preserve the pre-existing unrelated `docs/artifact-retention-policy.md`,
  `reports/`, `tools/__pycache__/` and `tools/artifact_retention.py`. No cleanup
  or replacement goal is inferred from this closure.

The owner-requested batch-first cadence remains in the requirements: substantial
coherent implementation, lightweight checks during assembly and one combined
acceptance boundary. The final documentation/tracker handoff uses repository,
PLAN/queue reconciliation, diff and Git checks, not another export of unchanged
production files. This document closes already delivered implementation; it
must not be counted as an additional runtime improvement.

Final `python3 -B tests/validate_repo.py` passes (retained log:
`quality_completion_repo_20260909.log`). PLAN reconciliation finds no missing
slices, the actionable queue is empty and `git diff --check` passes. A semantic
tracker comparison confirms only the selected parent/child changed; prior
evidence history, paused work and risks remain intact. The unrelated untracked
files still match their pre-existing retention-audit hashes.
