# Generated full-match quality: first corrections

2026-09-06. Active Phase 6 parent `quality-generated-full-match-20260906`,
current child `quality-generated-full-match-playthrough-20260906`. Requirements:
`docs/generated-full-match-quality-requirements.md`. This is an implementation
checkpoint, **not completion of the child, full matches, or release readiness**.

## Gameplay corrections

Three failures were reproduced before their production fixes:

| Failure | Runtime owner and correction | Live proof |
| --- | --- | --- |
| Visit Town disappeared after selecting the current town in the roster; arriving at a guard left a disabled Select Site button | `OverworldShell._refresh_selected_route_action_surface` now uses authoritative current-tile actions when there is an interaction, retaining the compact destination path elsewhere | Roster selection keeps Visit Town; walking to the guard offers Enter Battle; repeated refresh preserves it; actual Town/Battle scenes open |
| A defeated cache guard did not unlock its reward | `OverworldRules._resource_site_guard_targets_node` now treats an explicit placement ID as authoritative, without falling through to the shared site-type ID | The actual guard loses through shipped Quick Resolve, the casualty report continues, and the cache can be claimed while other caches' guards remain unresolved; legacy type-only links still work |
| Owned hero/town navigation disappeared after leaving Town | The compact generated Town-return refresh now initializes the hero/town action phase on the newly instantiated shell | The return immediately contains one owned hero and one owned town with focusable controls |

Exact generated reproduction: Medium, seed `10`, two players, normal difficulty,
Embercourt/default Lyra. Town `native_h3maped_93c0f05a_object_0950` has its native
art anchor at (45,40), its legal entrance/hero start at (43,40), and the required
source cache/guard at (41,41). The guard is
`h3maped_small_rare_source_guard_h3maped_small_town_source_support_native_h3maped_93c0f05a_object_0950_required_sources`.
Before the guard-link fix, unresolved guards for towns 0951–0956 also matched
that cache because they share `site_generated_town_required_source_cache`.

No generator, masks, placement, balance, battle RNG, resources, art or save-schema
changes were used to correct these defects. The focused run uses ordinary
starting forces and real scene actions, not forced combat outcomes.

## Fresh validation

Evidence root: `.artifacts/generated_full_match_quality_20260906/`.

- `arrival_before`: reproducible missing town/guard primary actions.
- `guard_identity_before`: real victory followed by a wrongly locked reward.
- `return_roster_before`: zero hero/town roster buttons after returning.
- `arrival_final_720` and `arrival_final_1080`: all **23 checks pass** at actual
  1280×720 and 1920×1080, zero engine errors. Visually inspected roster, guard,
  combat and reward captures; command controls are available. Broader scenery
  polish and abbreviated/crowded footer copy remain unfinished.
- Five existing route/context-cache, destination-only action, incremental
  refresh, full-route movement and movement-input-ownership regressions pass in
  `route_regressions`.
- Six Python complete-match acceptance tests pass; timeouts, driver stalls,
  early incomplete defeats and missing outcome/save/report coverage fail closed.
- All 26 repository-required consolidated content smokes were regenerated.
  Four stale tests were aligned with the existing 160-unit/299-scenario catalog
  and Charterless Compact campaign/witness contracts already asserted by
  `tests/validate_repo.py`; all their gameplay checks remain. Fresh successes
  are in `required_content_smokes_dbus` and `required_content_smokes_corrected`.
  Initial launches without a desktop bus failed in host accessibility setup;
  old wrappers also emitted unavailable-ALSA-device errors before Dummy fallback.
  Corrected reruns explicitly used Dummy audio/disabled accessibility and had
  no engine errors. These are content smokes, not full-match certification.
- `python3 tests/validate_repo.py` and `git diff --check` pass; final repository
  output is retained in `final_validate_repo.log`.
- Linux/Windows export smokes pass, including native sidecars and startup;
  `linux_generated` and Windows `generated-flow` both enter a generated map and
  player Town. Both PCKs are **248438632 bytes**, below 250000000. Windows evidence
  is Wine, not native Windows/GPU certification.

Additional unresolved validation: the legacy
`native_rmg_small_h3maped_guard_engagement_report` fails with
`no_reachable_hostile_town` for Small seed 1, three players. Its private
`_build_direct_path` cannot produce the requested hostile-town route; a disposable
entrance-target correction alone did not solve it and was reverted. The test and
native generation remain unchanged. The new exact Medium runtime guard/reward
proof passes, but this older Small path-report failure is not claimed fixed.

## Full matches and remaining work

The new Python-owned runner drives production scene handlers, shipped Quick
Resolve/casualty-report continuation, normal town orders and enemy turns. Saves
are compared across every JSON-serialized gameplay field and resumed through the
production router. Raw Godot Variant equality proved too strict for typed/packed
containers; serialized comparison drops no gameplay fields. Evidence is compact
action/profile JSONL, sparse screenshots and selected saves, not per-action world
dumps. Test save storage is isolated from the owner's saves.

Medium attempts reached Days 21, 18 and 21. All failed the
driver's progress gate with no terminal outcome. They exercised development,
recruitment, battles, casualty reports, enemy capture of the home town, and
opening/mid-match save/resume. The first rendered Large attempt reached Day 10
before being stopped for a driver portal-backtracking loop. Its Day-8 checkpoint,
opening town, combat, casualty and map captures remain. A second Large attempt
reached a real Day-5 defeat and terminal save/resume but failed acceptance because
it had neither a mid-match checkpoint nor recruitment coverage. **None is an
accepted complete match.** Follow-up driver work recognizes owned-site waypoints,
avoids re-reading signs/portal shuttling, and retains the same legal movement
rules. The latest Medium run still stopped at (50,48), Day 21; further diagnosis
must separate the driver's target policy from an actual legal-route defect.

Large observations include multi-second builds and roughly ten-second turns;
some runs overlapped validation processes, so these are responsiveness warnings,
not controlled before/after benchmark results. No optimization gain is claimed.
The inspected Veilmourn Town still has detached-looking building sprites and
stray footer resource text; the presentation child remains pending.

Next: establish competent legal Medium/Large exploration/conquest through real
terminal outcomes and terminal save/resume, then select the dominant measured
full-action hotspots and address the recorded Town/Overworld presentation gaps.
Keep all three children and the parent honest; individual fixes and package
success do not establish complete-match or product readiness.
