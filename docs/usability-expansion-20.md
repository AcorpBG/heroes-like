# Twenty Further Usability Improvements

Owner-directed Phase 6 parent `ux-usability-expansion-20-20260917`, derived from
`project.md` and the explicit request to propose and implement 20 more ideas.
This is a new batch after `ux-graphical-usability-cohesion-20260917`.

## Concrete acceptance

### Spell discovery — `ux-spell-discovery-20260917`

1. Case-insensitive spell-name search with a clear action.
2. School filter populated from the actual known/library spell catalog.
3. Stable name/mana-cost sorting using the hero's adjusted spell costs.
4. Affordable-only filter using current mana, explicitly not a casting-legality
   promise. All filters combine; empty states and keyboard focus remain usable.

### Construction discovery — `ux-construction-discovery-20260917`

5. Building-name search, without querying/building on each keystroke.
6. All/Ready/Trade/Locked/Built status filter over the current authoritative catalog.
7. Exact missing-resource quantities for the selected plan, distinct from cost.
8. Click/focus prerequisite navigation to the corresponding plan; never builds
   automatically. Preserve existing scene previews, confirmation and paid rules.

### Battle reading controls — `ux-battle-reading-controls-20260917`

9. Search retained battle history without deleting any events.
10. Jump to latest, including while reviewing older messages.
11. Unread-message counter while collapsed or reading history; bounded retention
    and scrolling remain intact.
12. Compact direct playback-speed selector using the existing persisted speed
    command/error path. It never issues a battle action.

### Owned roster readiness — `ux-owned-roster-readiness-20260917`

13. Compact movement meters on owned hero cards, with exact accessible values.
14. Compact mana meters on those same cards, not additional main-screen panels.
15. Owned-town defender-count badges using actual combined defending troops,
    with an explicit zero-defender warning rather than readiness-as-troops.
16. Next movable hero command, skipping depleted/unselectable commanders and
    preserving existing selection/centering, modal and turn guards.

### Hero decisions — `ux-hero-decision-details-20260917`

17. Experience progress and amount remaining to the next level.
18. Unit role, ranged/melee and one/two-cell body information from current
    authored unit/size metadata, without changing footprints or combat stats.
19. Artifact-name search over equipped and backpack entries.
20. Read-only artifact replacement comparison through the existing artifact
    rules on a deep copy; include set-bonus consequences and actual replacement
    target. Never equip, consume, mutate or save from inspection.

## Ownership and validation

Owners: `SpellbookView.gd`, `TownShell.gd`, `BattleMessageLog.gd`,
`BattleShell.gd`, `OverworldShell.gd`, `HeroSheet.gd`, and small shared
presentation helpers where necessary. Keep simulation rules outside UI.

Implement the batch before consolidated validation. Add Python-owned Godot
coverage for all 20 outcomes, empty/stale/locked cases, non-mutation, actual
mouse/keyboard routing and viewport bounds. Run existing graphical-usability,
spellbook, hero, battle-history and targeting regressions; inspect 1280x720 and
1920x1080 screenshots. Run `python3 -B tests/validate_repo.py`,
`git diff --check`, official Linux/Windows export smokes and immutable packaged
probes with payload parity. Report absent historical smokes as unexecuted.

No new art, balance, gameplay rules, save schema, native RMG, source-content
migration or unrelated cleanup. Preserve all original art/caches/saves/RMG and
pre-existing untracked files. Remove task-owned disposable evidence/test exports
after recording results. Complete only after implementation and real validation;
commit/push coherent work and verify local HEAD equals origin/main.

## Implementation

- Spell discovery is shared by Town/Battle/Hero. Search is case-insensitive;
  schools come from `school_id`, costs from `adjusted_spell_mana_cost`. The mana
  toggle is disabled without a hero and never bypasses target/context legality.
  Clearing a query explicitly restores all matching rows. Scroll/visibility
  layout notifications keep a formerly hidden hero spellbook multi-column.
- Town search/status changes filter cached catalog cards, not simulation rules.
  Empty results clear the selected plan and disable confirmation. Prerequisite
  buttons clear hiding filters, select/scroll/focus the real prerequisite and
  use the existing scene preview. Shortfalls are cost minus current stock, with
  zero/covered resources excluded. Folded scenic viewing hides these controls.
- Battle history retains its 200-entry bound. Search is a view; Latest clears
  the query and acknowledges new messages while restoring the tail. New events
  do not pull a reader away from older messages. The speed picker sits in the
  compact log strip without widening the footer; wide layouts retain the
  existing speed buttons. Both use the established persisted setting/error path.
- Owned hero cards retain their original portraits and gain thin movement/mana
  meters with exact accessible values. Town badges use `town_defense_force`,
  including the eligible visiting hero plus garrison, never readiness. Next
  selects/centers through the existing hero-selection command, skips depleted
  entries and obeys turn/modal guards; it does not march or inspect automatically.
- Hero XP shows current experience against the next threshold with remaining XP
  in its accessible description. Unit details use the same size manifest as new
  battle stacks plus authored ranged/shots data. Artifact search hides nonmatches
  and empty-slot clutter; comparisons lead with replacement/stat/income/set
  consequences. `DecisionDetails` calls equip/aggregate rules only on deep copies.
  Expanded artifact entries scroll into view; no equip intent is issued.

No original raster, content record, core gameplay rule, native library or save
schema changed. The only existing test adjustment is navigating from the new
Latest button to history; the old assumption that history immediately follows
the expand button is no longer correct. All retention assertions remain.

## Reproduction

Use fresh labels; source profiles and probe scripts self-clean:

```sh
python3 -B tests/usability_expansion_regression.py --label source-small --render --resolution 1280x720 --timeout-seconds 240
python3 -B tests/usability_expansion_regression.py --label source-wide --render --resolution 1920x1080 --timeout-seconds 240
python3 -B tests/graphical_usability_regression.py --label prior-six --render --timeout-seconds 240
python3 -B tests/spellbook_regression.py --label spellbook --render --timeout-seconds 240
python3 -B tests/hero_sheet_regression.py --label hero --render --timeout-seconds 240
python3 -B tests/battle_message_log_regression.py --label history --render --timeout-seconds 180
python3 -B tests/targeting_commit_regression.py --label targeting --render --timeout-seconds 180
python3 -B tests/validate_repo.py
git diff --check
```

Set `HEROES_BATTLE_READABILITY_ARTIFACT_DIR` to a fresh task-owned evidence root
to consolidate existing probes. Set `HEROES_PACKAGING_LINUX_ARTIFACT_DIR` and
`HEROES_PACKAGING_WINDOWS_ARTIFACT_DIR` before running the official
`packaging_linux_export_smoke.py` and `packaging_windows_export_smoke.py`.
Then test the immutable exports with:

```sh
python3 -B tests/usability_expansion_regression.py --platform linux --binary <linux>/export/heroes-like.x86_64 --pack <linux>/export/heroes-like.pck --label linux-accepted --render --resolution 1920x1080
python3 -B tests/usability_expansion_regression.py --platform windows --binary <windows>/export/heroes-like.exe --pack <windows>/export/heroes-like.pck --wine-prefix <fresh-prefix> --label windows-accepted --resolution 1280x720
```

Wine acceptance is headless, not physical Windows GPU certification. Package
probes retain the complete source assertions and verify the exported owners;
they never rewrite the release PCK. Temporary outputs are removed after results
are recorded, under the explicit owner retention policy.

## Acceptance record — 2026-09-17

- Final source probe: 985 checks at 1280x720, all 20 numbered outcomes passed.
- Existing regressions: graphical usability 4,197 (including 804 scenic preview
  placements across six factions), shared spellbook 4,633, hero sheet 528,
  retained battle history 87 and targeting 95 checks passed. These ran during
  the consolidated batch before the final card-selection/log-width refinements;
  the final focused probe covers those refinements explicitly.
- Full repository validation exited 0, `VALIDATION PASSED`. The 26 absent
  historical smoke outputs are disclosed as unexecuted, not silently passed.
- Official Linux export/startup and Windows export/startup passed. Windows also
  completed the 23-step generated-map/Overworld/Town construction-information
  flow. Both managed Wine startup prefixes cleaned successfully.
- Final PCKs each contain 8,915 entries and measure 648,459,312 bytes; all 8,914
  non-platform entries are byte-identical, with only `project.binary` different.
  No fixed content ceiling is imposed by current `project.md`.
  Linux SHA-256: `178f6987411f798073a8372f607c2aa38c6034a1d9bdbf2cb66a956edacaadb1`.
  Windows SHA-256: `c8688cca717495a05606efdee948a8abbd8dc08d94c4bb137097f5cc98bef10f`.
- Final review caught a launcher defect in this new Python probe: omitted
  runner-hook forwarding meant early runs labeled `linux-accepted` and
  `windows-accepted` actually exercised source Godot. Those runs are **not**
  packaged acceptance. Hook forwarding is corrected; packaged mode now also
  requires the exact original/packaged probe hashes from the release bootstrap,
  rejecting a metadata-only receipt. Official export smokes and payload parity
  were independent of this defect. Fresh `linux-release-accepted` and
  `windows-release-accepted` runs now pass 985/977 checks respectively, all 20
  outcomes, through the actual exported executables. The latter ran under a
  fresh Wine prefix, which was removed after preserving its user data.
- Both release probes executed the unchanged GDScript SHA-256
  `69f0caf66be71f7abe5fd67ba6d3d43709df43c17f5c1142cc3d00e72678fd5b`;
  all assertions were retained, all 16 compiled presentation owners were
  present, current manifests matched and neither release export was rewritten.
  Python probe SHA-256:
  `68e029e7b982cf2375df78757ac503b78ef937fe6794d610db9cec643f36fac5`.
- Visually inspected source 1280x720 and actual exported Linux 1920x1080
  captures: battle history/speed, construction and folded preview, roster,
  hero/unit details, artifact comparisons and shared spell discovery. New
  controls remain within their existing modal/edge surfaces without clipping;
  scenic/play surfaces stay primary. Windows was headless Wine, not Windows
  GPU certification. No whole-game release-readiness claim.
- Completion cleanup removed 3,042,623,488 allocated bytes (about 3.04 GB) of
  task-owned rebuildable captures, logs, reports and test exports, including
  superseded and accepted copies, after recording their results above. Three
  Wine user-data trees (3.09 MB logical) remain under the task's
  `preserved-user-data` directory. No task-owned `/tmp` profiles remained; active
  file-use checks were empty before deletion. Source, original art/provenance,
  caches, saves and RMG recovery material are intact. The unrelated untracked
  retention-policy/tool files and `tools/__pycache__/` were not staged or changed.
