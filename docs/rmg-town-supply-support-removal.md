# Remove Generated Town Supply Support

Owner request, 2026-09-18: remove the generated town cache and its guard.
Phase 6 slice: `rmg-remove-town-supply-support-20260918`, derived from
`project.md` and selected in `PLAN.md`.

## Scope and source diagnosis

Before this change, `NativeRandomMapPackageSessionBridge.build_session_from_adoption` called
`_ensure_generated_town_source_route_support` after normalizing the native
session. That helper appends `site_generated_town_required_source_cache`
(Generated Town Supply Cache), with placement prefix
`h3maped_small_town_source_support_`, and an exactly linked supplemental guard.
This is additional project economy content, not a recovered H3MapEd placement.
Remove this injection and its exclusive placement/search helpers; do not mask
objects at render time or alter the recovered native payload.

Keep normal rare-source/reward guard handling and all native object records,
positions, footprints, encounters, starts, terrain and deterministic state.
`ScenarioFactory` separately adds support to authored enemy towns and explicitly
skips generated scenarios; that authored-content policy is outside this request.
The resource definition, original art and guard profiles remain for legacy saves
and authored scenarios. Native low-level reward-reference fallback mappings are
also separate from the removed per-town injection; do not erase source objects
or alter native recovery code in this slice.

Existing saved maps are not migrated or stripped. New generated sessions no
longer receive guaranteed all-resource income at every town. Historical economy
reports promising universally nearby guarded supplies describe the old policy,
not acceptance for new maps. This removal is owner-directed, not evidence of
new native parity or a general economy-balance correction.

## Completion and validation

- No automatically injected town-support node or linked guard in representative
  fresh native Small/Medium and two-level sessions, including all town owners.
- Exact native package object/terrain preservation and repeat-adoption
  determinism; normal mines, rare-source/reward guards and entrances remain.
- Save/restore retains new map state and legacy cache/guard pairs.
- Python-owned Godot regression with an actual Overworld capture and Linux/
Windows immutable-release probes; verify bootstrap execution, not just hashes.
- Run `python3 -B tests/validate_repo.py`, `git diff --check` and official
  Linux/Windows export/startup smokes, including Windows generated Town entry.
- Record results, clean task-owned disposable outputs while preserving saves,
  caches and native RMG reverse-engineering material; commit/push coherent work
  and verify HEAD equals origin/main. No unrelated untracked files staged.

Non-goals: changing recovered native phases, tuning topology/density/retries,
rebalancing costs or normal encounters, deleting ordinary caches/guards or old
saves, changing art/UI/save schemas, or clearing filesystem caches.

## Implementation and reproducible checks

Removed the post-normalization injection call and 13 exclusive helper methods
(326 removed lines). The other 37 surviving bridge methods are byte-unchanged;
normal resource/reward guard creation remains. No native C++, libraries,
gameplay-rule owners, content definitions or art changed.

The Python-owned probe generates native maps without seed retries, adopts each
twice, verifies every source object/mask plus terrain/layers, checks exact normal
resource/guard identity sets, writes/loads native packages under isolated
`user://maps`, and enters through the existing Skirmish startup path with real
provenance. New and representative legacy cache/guard sessions pass normal
SaveService writes/restores. A Medium Overworld capture was visually inspected
at 1920x1080: hero at its town entrance, ordinary nearby props retained, no
injected town-support pair. This is adoption compatibility, not native parity.

| Native case | Source objects | Normal resource nodes | Remaining guards | Town owners (player/enemy/neutral) |
| --- | ---: | ---: | ---: | --- |
| Small, seed 165429308, one level | 306 | 76 | 20 | 1/1/3 |
| Medium, seed 10, one level | 1,326 | 306 | 57 | 1/1/5 |
| Medium, seed 10, two levels | 1,302 | 383 | 79 | 1/1/3 |

Source and immutable rendered Linux probes each pass 9,360 checks; the immutable
Windows headless probe passes 9,359 (no screenshot assertion). All three produce
identical native object hashes and case counts. Initial probe
errors were in the new fixture: invalid helper/type assumptions, JSON numeric
layer-key comparison and omitted startup provenance. Those attempts are not
acceptance; the final test uses existing startup/restore rules without bypasses.
The runtime removal did not require further changes.

Both official export/startup smokes pass, including Windows' 23-step generated
map, Overworld and Town construction/information flow. Both release probes
execute the exact original GDScript body through the immutable package bootstrap;
four relevant compiled adoption/rules owners are present. Exports remain
unchanged. Each PCK is 648,449,360 bytes: 8,914 of 8,915 entries are identical,
with only platform-specific `project.binary` differing. Managed Wine cleanup
passes and preserves user data.

Full repository validation reports `VALIDATION PASSED`; its 26 absent historical
smokes are explicitly unexecuted, not inferred passes. The first repository
process ended with signal exit 143 and no verdict; only the completed rerun is
accepted. `git diff --check` passes. The focused source and platform checks above
are actual current executions, independent of the historical-report policy.

Reproducibility fingerprints (SHA-256):

- Python probe: `2578b54b1a7b477eab1e72e4fd6c27a46fabfe3e893f72901ad14d97ba6d3955`.
- Executed GDScript: `313db7e16388c627518597343172ef797a03863aab878074a652821830d7b57e`.
- Linux PCK: `758e86c8b6b8aacb7aa79e6d55f1309ed5cada53fb7e43954d6ac64affb1aeea`.
- Windows PCK: `2656ebb44f615c8a1f897b8b4b3c8d70a26a5a663956ee7e3fdc5e6573965838`.

```sh
python3 -B tests/rmg_town_supply_removal_regression.py --label source --render --timeout-seconds 300
python3 -B tests/validate_repo.py
HEROES_PACKAGING_LINUX_ARTIFACT_DIR=<task>/linux python3 -B tests/packaging_linux_export_smoke.py
HEROES_PACKAGING_WINDOWS_ARTIFACT_DIR=<task>/windows python3 -B tests/packaging_windows_export_smoke.py
python3 -B tests/rmg_town_supply_removal_regression.py --platform linux --binary <task>/linux/export/heroes-like.x86_64 --pack <task>/linux/export/heroes-like.pck --label linux-accepted --render --resolution 1920x1080 --timeout-seconds 300
python3 -B tests/rmg_town_supply_removal_regression.py --platform windows --binary <task>/windows/export/heroes-like.exe --pack <task>/windows/export/heroes-like.pck --wine-prefix <fresh-prefix> --label windows-accepted --timeout-seconds 300
git diff --check
```

Labels/prefixes must be fresh. Tests own isolated profiles and never rewrite
the owner's generated-map directory. Windows acceptance uses headless Wine,
not physical Windows GPU certification. Historical universal resource-route
and pacing scorecards were not rerun or claimed as current-policy acceptance.

Completion cleanup removed 1,509,302,272 allocated bytes (1.51 GB) of task-owned
rebuildable exports, captures, reports and logs after recording results. Managed
Wine prefixes were also removed by the platform helpers; 26.55 MB of user data
and save/package dependencies remain under the task's `preserved-user-data`.
No active process held the cleanup targets. Source, art/provenance, caches,
owner saves, native RMG recovery material and unrelated untracked files remain
untouched; no disposable task files remained in `/tmp`.
