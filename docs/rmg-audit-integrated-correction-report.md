# RMG audit correction integration

Status: completed, 2026-09-06. Child `bugfix-rmg-audit-integrated-regressions-20260905` completes the Phase 6 correction parent within the explicitly audited boundary. Source requirements: `rmg-audit-corrections-requirements.md` and the completed `rmg-start-placement-and-h3maped-audit.md`. This integration slice corrects regression tooling over the five implemented corrective children; it makes no additional native generation, topology, gameplay, balance, art or save-schema change.

## Regression corrections

The legacy XLarge boundary still required source type 17/subtype 45 to remain raw and rejected it during its exact-catalog dwelling interaction check. The authoritative registry already maps it through `neutral_dwelling`. Original payload `33610c0a`, 365,777 bytes and 2,779 objects remains unchanged. Source ordinals 2124 `(118,106,0)` and 2614 `(16,42,0)` resolve to `object_noonshard_prism_aviary` / `site_noonshard_prism_aviary` and `object_last_memory_mooring` / `site_last_memory_mooring`, with selection tokens `c43f0d7b` and `32e87d71`. Evidence: `content/random_map_object_eligibility.json`, immutable map-object/resource-site definitions, `MapPackageService::runtime_authored_pool_proxy_entry`, and `water_final_all_entrances/xlarge_seed77.json`.

`native_rmg_end_to_end_runtime_boundary_report.gd` now requires these distinct pool identities, source provenance, exact ordered positions/body/visit masks and repeat generation. Its ten exact-catalog dwelling claims retain their existing rewards, recruitment, repeated-claim rejection, unrelated-state equality and save assertions; the two pool dwellings must remain untouched by those ten claims. This is not a claim that this helper plays the two pool dwellings' complete guard/recruitment chains. The separate pool report verifies sorted eligible candidates, source-ordinal selection, registry provenance and zero unclassified visitable objects across four generated size cases. `validate_repo.py` had the same stale raw-subtype requirement; it now enforces the mapped identities and exact mask/provenance checks instead of requiring placeholders.

Python-owned permanent coverage adds the exact Medium normal-water seed-10 case to the default entrance matrix. `rmg_retained_authority_audit.py --private-join PC:PHASE:REGISTER` supports explicit same-run grid/writeout ledgers: every requested checkpoint must exist once, complete words and nonzero dimensions are required, and repeated native invocation indices/conflicting words fail. Unselected events and pointer vectors are explicitly not certified. `full_play_validation_suite.py --rmg` selects 18 existing native/adoption/pool/art/battle/movement/fog/save/AI reports and checks filenames before any engine launch. Fourteen entrance/private/suite unit tests and twelve player/transit classifier tests pass.

## Implementation chain and retained limits

| Required outcome | Implemented owner and evidence |
| --- | --- |
| Exact own-town entrance starts, including supplemental placement reservation | `rmg-town-entrance-correction-report.md` |
| Layer-aware movement, objects, battles, UI/fog/minimap, AI and saves | `rmg-level-aware-runtime-report.md` |
| Source player/team identity independent of faction; compatible old saves | `rmg-player-team-identity-correction-report.md` |
| Source-linked caves/portals, safe player/AI travel and source-proven diagonal edges | `rmg-native-transit-correction-report.md` |
| Actual normal-water endpoint-producer correction with private/writeout proof | `rmg-normal-water-correction-report.md` |
| Current authored-pool expectations and combined regressions | This slice and commands below |

Native and gameplay ownership are separate: entrance positioning is an explicit Aurelion product requirement; native adjacency has an original private-state predecessor proof; original source masks and actual destination blockers are retained. The water correction removes duplicated future-state endpoint records at their producer, not by carving topology or adjusting RNG/counts after the fact. No foreign art or executable is packaged. Legacy pooled saves retain actual historical ownership/economy, not fabricated per-player histories.

This goal does not certify arbitrary seeds, allocator histories, all H3MapEd private buffers or unsupported modes. Transit journeys documented in their child report are post-neutral-guard navigation tests plus a real turn-spawned field battle, not all neutral-guard battle balance or a full conquest/naval campaign. The separately observed Large seed-1 original/native setup join remains unproven and is not included in the selected parity claim. Existing unrelated town-development deadline and authored-test timing limitations remain disclosed in their child reports, not silently relabeled as whole-game success.

## Validation commands

Use fresh labels; native export/private proof and Godot runtime runs remain distinct workflows.

```text
python3 -m unittest tests/test_rmg_start_placement_audit.py
python3 -m unittest discover -s tests -p 'test_rmg_*validation.py'
python3 tests/full_play_validation_suite.py --rmg --label <fresh> --accessibility disabled --timeout 1200
python3 tools/rmg_start_placement_audit.py --label <fresh> --require-entrance-starts
python3 tools/rmg_player_identity_validation.py --label <fresh>
python3 tools/rmg_native_transit_validation.py --label <fresh> --render --resolution 1280x720
python3 tools/rmg_retained_authority_audit.py --label <fresh>
python3 tests/validate_repo.py
python3 tests/packaging_linux_export_smoke.py
python3 tests/packaging_windows_export_smoke.py
git diff --check
```

## Current evidence

`water_source_flags_retained/summary.json` retains 24/24 byte-exact selected owner payloads. `integrated_water_same_run_private/summary.json` verifies four same-run water checkpoints; `integrated_water_outer_private/summary.json` verifies the two outer grids. All 5,184 cells/eight words per grid are exact. Native implementation and binaries remain unchanged since the fully validated water commit `78e366f4`; both native selftests and platform Debug/Release builds are recorded in its report.

- `.artifacts/full_play_runtime_20260905/rmg_audit_integrated_complete/report.json`: **18/18 reports pass**, all real completion markers, exit zero and zero runtime errors. Includes the full native end-to-end report (24 generated shapes; original object/proxy/guard/entrance/package-save controls), authored pool/weighting, map-object/decorative original sprites, deterministic battle/report, live movement/full route, fog, transactional/deferred saves and five AI reports. The pool report preserves 422 authored eligibility decisions, 336 eligible/86 excluded, 2,449 mapped sampled records, 418 native passthroughs and 6,599 renderer-owned bodies, with zero unclassified visitable objects. This is eligibility plus sampled selection, not every possible object's complete gameplay certification.
- `integrated_final_all_entrances/summary.json`: the permanent default matrix passes **37 requests, 36 supported maps, 85 exact own-town entrance starts**, all 36 primary-hero movement/entry/return/save cases, no runtime errors. Unsupported `impossible` strength is correctly refused. The failing Medium water seed is included without an ad hoc injected case. All 36 cases retain identical native objects, terrain, payload hashes/lengths, starts and slots against the water-child matrix despite inserting that seed earlier in the sequence.
- `integrated_final_players/report.json`: all 32 required checks pass in six-player, eight-player and explicit-team cases, including distinct opponents/ownership/commanders/economies, real turns, battle/capture, legacy historical state and production saves. Zero runtime errors.
- `integrated_final_caves/report.json`: all eight reciprocal cave ends and source-adjacency, player/AI, safety and save checks pass with no changed inputs or engine errors. Both actual 1280×720 surface/underground screenshots were visually inspected. `integrated_final_islands_journey_confirmed/report.json` reaches all six other town approaches, including multi-passage travel, real turns and production saves, and completes a real raid victory with remote towns unchanged and production Overworld handoff. The explicit wrapper and engine both exit zero. The first journey attempt had a completed passing engine report but its outer shell reported 143; it is retained, not used as the final process-success claim.
- The exact corrected water map's 37 live checks and inspected captures at 1280×720 and 2048×1079 remain in `water_final_rendered_1280` / `water_final_rendered_2048`. The 85-start matrix and all native/gameplay sources remain unchanged through this integration; no fresh art was produced.
- `integrated_final_packages_linux/report.json` and `integrated_final_packages_windows/report.json`: exports and startup pass, both PCKs **248,438,264 bytes**, **1,561,736 bytes below** the ceiling. Windows fresh-prefix generated setup → Overworld → owned Town passes under Wine. `integrated_final_linux_generated/live_validation_report.json` passes the same three steps in the actual Linux release binary at 1280×720; its final Overworld and Town captures were inspected. No engine errors; host-only root/VSync/MSAA warnings do not constitute GPU or accessibility certification.
- Fourteen entrance/private/suite unit tests and twelve player/transit classifier tests pass. `integrated_tools_repo.log` and final `integrated_completed_tracker_repo.log` record passing `python3 tests/validate_repo.py`; `git diff --check` and progress PLAN/queue reconciliation pass.

Artifact labels above are under `.artifacts/rmg_start_audit_20260905/`; the existing runtime suite writes under `.artifacts/full_play_runtime_20260905/`. The initial integrated repository check failed on the stale validator token described above; the corrected repository check passes. An initial hand-selected suite used nonexistent shorthand AI test names; its 13 completed passing native/content/runtime rows and separately passed five correctly named AI reports are retained, but that incomplete orchestration is not the final passing suite. The permanent `--rmg` selection passed in full.

Disk scope: after checking successful prior reports and absence of active users, only this goal's disposable `water_final_packages_windows/{wine-prefix,generated-wine-prefix}` and older `transit_packages_{linux,windows}/export` directories were removed to allow final packaging. They are rebuildable; their reports/screenshots, newer validated builds and all source captures remain. The pre-existing unrelated retention-policy/tool files and `reports/` were not edited. Those items and the existing `tools/__pycache__/` directory remain untracked and unstaged; Python may refresh its own import caches.
