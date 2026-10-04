# Source material storage map

Date: 2026-10-03. Scope: current checkout at the selected source-material inventory slice.

This document records the source inventory, verified external archive and completed local cleanup below. Mapped binary sources now reside in the N: archives; required source metadata and editor images remain locally. Git historical blobs and external H: generation environments are outside the art archive. Inventory sizes are logical file bytes, not NTFS allocation.

## Git history migration

The owner authorized history rewriting without a full Git backup. All 51,185 tracked removal paths came from the verified source archives; historical path enumeration found no additional paths to remove. Metadata, editor-required images, runtime assets, build code, RMG/reference material and maps remain.

The filtered candidate retains all 3,830 main commits and all 3,832 commits reachable through local refs, including the stash. Every complete rewritten commit tree was compared against its original after applying only the exact path removals. All parent edges, authors, committer identities/dates, messages and encodings match. The two private checkpoint trees were also filtered, including 336 checkpoint-only source-preview entries absent from published branches; every other checkpoint entry was verified unchanged. Private refs are never pushed. Commit IDs change, and 21 old commit signatures are removed because signatures cannot authenticate the rewritten commits.

The self-contained filtered object database is 7.15 GiB. All nine GitHub branches were updated with exact-tip leases; the temporary transfer branch was removed in the same atomic transaction. Local reclamation is complete: total `.git` is 7.099 GiB, down from 89.241 GiB (approximately 82.142 GiB recovered). The source ZIPs are unchanged. No full Git backup was created; older source versions absent from the ZIPs will no longer be recoverable once old objects are reclaimed.

Uncommitted work was preserved and read-back verified in `N:/heroes-like-archives/history-migration/2026-10-03-ccc0d334/uncommitted-work.zip` (961 existing working files plus staged versions/index, 203,195,135 bytes). This is a small working-state safeguard, not a copy of Git history. The same directory holds the old-to-new `commit-map` and branch migration metadata.

`tools/check_source_material_tracking.py` and the Source storage workflow reject production media added back to Git. Ignore rules keep newly generated source binaries outside ordinary staging; editor exceptions remain versioned. `tools/validate_release_inputs.py` checks concrete art references and matching platform exclusions without loading archived authoring masters; it is not a replacement for the complete release audit.

The focused art-reference check passed 3,841 references; two storage regression tests and nine existing release-pipeline tests passed. Windows headless startup passed 180 frames without warnings/errors. The existing content/scene audit reported 846 non-archive errors with unchanged content and validator code. The full source-authoring audit still requires restoring archived inputs. Release-builder validation was not weakened, and no fresh complete Linux/Windows release package is claimed.

Existing clones must not merge or push their old history back after migration. Preserve their uncommitted files, saves, maps and RMG material before adopting the new history. The Linux server has not been modified. Ordinary new clones will receive the filtered branches; GitHub may retain old objects through hidden pull-request refs or server retention, so immediate backend purging is not promised.

## Completed D-drive cleanup

Owner-authorized cleanup on 2026-10-03 removed exactly 51,214 mapped binary sources and 4,275 paired import sidecars: 91,594,793,086 bytes (85.304 GiB). Every affected ZIP was freshly verified; every original SHA-256 matched its backup under an exclusive Windows handle before deletion. No changed or busy file was skipped; no recursive source-folder sweeps were used.

A further 57 old, unlocked files explicitly reported as garbage by Git were removed: 4,215,434,990 bytes (3.926 GiB). No valid object or history was removed. Git now reports zero garbage and its connectivity check passes.

All 17,817 art files outside source folders retained identical hashes. Retained source metadata and all 7,334 export PNG paths are unchanged; both platform exclusion rules agree. All 598 editor-source/image-sidecar records remain. Caches, saves and RMG material were preserved.

Windows Godot 4.6.2 headless startup passed 180 frames at up to 60 FPS without errors. The initial sandbox certificate-store restriction was resolved by normal Windows access. No full source-dependent suite, fresh game package or Linux run is claimed. Source-dependent authoring/tests require restoring archived inputs. Task test fixtures and startup profiles/logs were removed.

Project size is approximately 108.084 GiB: art 4.544 GiB, retained sources 0.963 GiB and Git 89.241 GiB. D: free space increased from about 285.965 to 375.335 GiB; allocation/free-space deltas differ slightly from logical file-byte totals.

The archive directory's `local-cleanup-20261003-185518.json` records removals and checks; its index and README identify the cleanup state. ZIP payloads are unchanged. Tracked source removals remain local Git changes. Reducing the remaining Git database and distributing the reduced repository require a separate history/source-control migration; no commit, publication or server change was performed here.

## Completed external archive

On 2026-10-03, the owner-requested archive operation created `N:\heroes-like-archives\source-art\2026-10-03-ccc0d334` from the current Windows working copy, based on Git revision `ccc0d3343002729a52f644824f88f21390aeac98`.

- 23 ZIP64 archives preserve all 86,342 regular files in the 14 source domains: 92,628,571,835 bytes (86.267 GiB).
- ZIPs total 92,243,923,421 bytes (85.909 GiB); the complete directory including manifests and verification helpers totals 85.942 GiB.
- All 51,214 mapped binary candidates are included. Complete source snapshots also include recipes/provenance, editor-required sources, import sidecars and small existing caches as backup copies. Their inclusion does not make those retained categories removal candidates.
- Every original file was SHA-256 hashed while copying; every archived payload was read back and matched that hash and its ZIP CRC. Exact member sets, embedded/external manifests, manifest hashes, aggregate counts and byte totals were checked. The final source file set, sizes and modification times matched the initial inventory. No partial archives remain.
- Original sources and Git history were retained during archive creation. The separately verified local cleanup is recorded above; history migration remains separate. The server was not changed and nothing was published.

`archive-index.json` identifies each ZIP and companion SHA-256 manifest. `README.txt` explains restoration: extract the selected ZIPs into a chosen repository root to restore their original relative paths, reviewing any existing files before overwrite. The directory includes standalone copies of both Python tools. Reverify on Windows or Linux with:

```text
python archive_source_material.py --destination <archive-directory> --verify-only
```

The snapshot includes current uncommitted/untracked sources; it is not an archive of every historical Git revision. The copy of this map inside the archive directory is the planning map used when the snapshot was created.

## Restore sources for tests

The game itself needs no archived source. These checks assert source provenance and fail until the named originals are restored:

| Check | Archived originals it opens |
|---|---|
| `tests/six_elder_wilds_smoke.gd` (contact sheet) | `art/units/source/curated/<unit>.png` |
| `tests/six_faction_field_muster_captains_smoke.gd` | `art/heroes/source/curated/<hero>.png` |
| `tests/six_horizon_company_field_musters_smoke.gd` | `art/overworld/source/generated/resource_sites/horizon_company_field_musters/` |
| `tests/six_horizon_relic_commissions_smoke.gd` | `art/artifacts/source/generated/horizon_relic_commissions/` |
| `tests/overworld_resource_delta_cue_playback_report.gd` | `art/economy/source/resource_icon_atlas.png` |
| `tests/test_overworld_*_cutouts.py`, `tests/town_biome_art_regression.py`, `tests/test_pack_unit_pose_art.py` | Generated, trimmed and recovered masters named in their manifests |
| `tests/validate_repo.py` | Stops at the first missing original (`tests/overworld_object_density_contract.py`); 49 of its validators read archived sources |

Restore exactly what a check needs (dry-run without `--apply`). Every payload is verified against the archive SHA-256 and a differing local file is never overwritten:

```text
python tools/restore_archived_source_material.py --archive-dir N:/heroes-like-archives/source-art/2026-10-03-ccc0d334 --prefix art/units/source/curated/ --apply
```

Restored media stays ignored by Git. Remove it again with `tools/remove_archived_source_material.py`.

## Decision summary

- Source trees contain **86.267 GiB** across **86,342 files**.
- **85.300 GiB / 51,214 binary files** are external-archive candidates: excluded by both release presets and not found as direct existing-file literals in live scripts/scenes. 50,922 of these files, totaling 84.920 GiB, are currently Git-tracked.
- Retain **0.447 GiB** of source-side recipes, selections, scripts, prompts and provenance in Git; include copies in source ZIPs as well.
- Retain **0.508 GiB** of editor-required source images and sidecars until those editor checks support archived sources.
- Source-dependent authoring, repacking and validation still need archived originals restored at their original relative paths. A package exclusion does not prove that a source is unnecessary for every development task.
- Game code, content JSON, build tools, tests, native dependency source, packaging scripts and current runtime art remain in the repository. Their absence from a release archive is not a reason to remove them from Git.

## All art source domains

The archive column includes recognized binary masters, candidates and extracted media only. It excludes recipes, editor exceptions, generated import sidecars and caches. These are preservation candidates, not disposable files.

| Source directory | All files | Total GiB | Archive files | Archive GiB |
|---|---:|---:|---:|---:|
| `art/units/source/` | 69,907 | 75.553 | 43,553 | 75.252 |
| `art/animation/source/` | 5,545 | 4.109 | 2,588 | 3.968 |
| `art/overworld/source/` | 5,831 | 2.218 | 2,847 | 2.208 |
| `art/towns/source/` | 2,321 | 1.885 | 739 | 1.571 |
| `art/audio/source/` | 1,717 | 1.606 | 1,133 | 1.603 |
| `art/magic/source/` | 241 | 0.261 | 120 | 0.260 |
| `art/campaigns/source/` | 302 | 0.204 | 4 | 0.008 |
| `art/heroes/source/` | 148 | 0.160 | 73 | 0.160 |
| `art/battle/source/` | 182 | 0.142 | 87 | 0.142 |
| `art/artifacts/source/` | 130 | 0.112 | 61 | 0.112 |
| `art/town/source/` | 12 | 0.011 | 6 | 0.011 |
| `art/economy/source/` | 2 | 0.003 | 1 | 0.003 |
| `art/factions/source/` | 2 | 0.002 | 1 | 0.002 |
| `art/ui/source/` | 2 | 0.001 | 1 | 0.001 |

The smaller domains include artifact icons, battle/VFX masters, campaign identity sheets, resource and faction atlases, hero portraits, spell art, overworld objects/terrain/actors, town buildings/backdrops and UI masters. `art/town/` and `art/towns/` are separate existing domains.

## Creature and animation archive boundaries

| Directory/group | Total GiB | Archive binary GiB |
|---|---:|---:|
| `art/units/source/generated/fluid_animation` | 0.001 | 0.000 |
| `art/units/source/generated/fluid_animation/batch_a` | 3.693 | 3.625 |
| `art/units/source/generated/fluid_animation/batch_b` | 11.706 | 11.650 |
| `art/units/source/generated/fluid_animation/batch_c` | 12.964 | 12.918 |
| `art/units/source/generated/fluid_animation/batch_d` | 23.713 | 23.654 |
| `art/units/source/generated/fluid_animation/batch_e` | 15.625 | 15.579 |
| `art/units/source/generated/fluid_animation/comparison_20260924` | 0.050 | 0.045 |
| `art/units/source/generated/fluid_animation/guides` | 0.002 | 0.002 |
| `art/units/source/generated/video_trials` | 7.466 | 7.446 |

For ZIP organization, preserve each creature directory intact inside its existing batch path. Include the small local scripts, workflow JSON, prompts, selections and provenance in the ZIP even though they also remain versioned. The `art/animation/source/` recipes and selected pose sources link these original creature generations to the final runtime atlases. Preserve these relationships.

Creature source binary formats:

| Type | Files | GiB |
|---|---:|---:|
| `.mkv` | 1,314 | 56.854 |
| `.png` | 39,609 | 9.040 |
| `.latent` | 1,134 | 8.431 |
| `.mp4` | 1,314 | 0.628 |
| `.npy` | 124 | 0.284 |
| `.webp` | 18 | 0.009 |
| `.gif` | 36 | 0.004 |
| `.jpg` | 4 | 0.002 |

## Exceptions that stay locally

| Exact boundary | Reason |
|---|---|
| `art/towns/source/buildings/curated/` | Editor-side building validation loads the curated source: `scripts/autoload/ContentService.gd:1406-1411`. |
| `art/campaigns/source/generated/emblems/` | Editor validates source existence: `ContentService.gd:2155-2166`. |
| `art/campaigns/source/generated/chapter_seals/` | Editor validates source existence: `ContentService.gd:2203-2218`. |
| Source `.json`, `.py`, `.txt`, `.sha256`, `.md`, shell/config files, `.gitattributes` and `.gdignore` | Recipes, provenance, prompt/reference lineage, source-selection decisions, hashes and rebuild/import rules remain useful Git inputs. |
| Source `.import` / `.uid` files | Review with the corresponding archived source. They are derived/editor metadata, not an additional master; some are currently tracked. |
| `art/**/__pycache__/` | Generated Python caches; current owner policy preserves caches. They are not archive masters. |

The 299 editor-required image files comprise 160 building sources, 25 campaign emblems and 114 chapter seals (plus their 299 import sidecars). These editor requirements do not ship: both release presets exclude `art/*/source/*`.

## Art outside source directories

Keep published runtime atlases/audio, portraits, battle standees/icons, overworld icons, main-menu art, branding and all other export-eligible art. Do not select material for archiving merely because it is not under a directory named `runtime`.

The following **excluded** art requires a separate legacy/reference review; it is not included in the source-archive total:

| Boundary | MiB | Files | Decision |
|---|---:|---:|---|
| `art/overworld/runtime/fog` | 1.09 | 1 | Retain pending review. |
| `art/overworld/runtime/terrain` | 8.66 | 8 | Retain pending review. |
| `art/overworld/runtime/terrain_tiles` | 150.33 | 556 | Retain pending review. |

The excluded terrain/fog/detail assets have replacement paths and/or old generated variants. This inventory does not prove all of them are obsolete. `art/overworld/runtime/homm3_local_prototype/` and its reference documentation are protected source-reference material and must remain intact.

## Other repository and local material

| Boundary | Git / game packaging decision |
|---|---|
| `scripts/`, `scenes/`, `content/`, project files and current art | Keep in Git and make available to the game/build. |
| `src/`, `third_party/godot-cpp`, `.gitmodules`, `packaging/`, `.github/`, `tools/` | Keep build and release inputs; native source/dependencies are needed for both Windows and Linux. |
| `tests/`, `docs/`, `ops/`, `archive/document-reset-2026-04-27/` | Keep development source/specifications/history; excluded from the game payload. |
| `bin/` | Preserve required native libraries. Generated helper executables, linker outputs and debug symbols need separate tracking/rebuild review. |
| `.godot/`, native build directories under `.artifacts/`, Python caches | Local reproducible caches, already largely ignored; preserve under current policy. |
| `.artifacts/audio-production/export-tools/` | Export templates/toolchain cache, not art sources; packaging depends on tool availability. |
| `.artifacts/audio-production/` validation outputs | Packages, validation ZIPs, logs and review captures were removed on 2026-10-04 under the owner retention direction. The live-review and test profiles stay because they hold saves. |
| `.artifacts/town_match_east_20260923/`, `.artifacts/town_match_west_20260923/` | Mixed profiles, validation outputs and saved state. Saves/maps/backups are protected; do not sweep these folders. |
| Other `.artifacts/` art/review folders | Mixed previews, evidence and possible originals. Not automatically disposable or source-archive candidates. |
| Native RMG / H3MapEd / HoMM3 recovery/reference files anywhere | Explicitly preserve, regardless of Git tracking or package exclusion. Name-based inventory protection is conservative, not a complete provenance detector. |
| `maps/`, save and backup directories, `.amap` / `.ascenario` / `.save` / `.bak` | Preserve owner/runtime state and map assets. |
| Root `townscreen-suggestions..png` | Owner's annotated town-screen feedback. Kept locally outside Git through `.git/info/exclude`; a verified copy is in `uncommitted-work.zip`. |
| `.git/` | Separate history/object migration; not part of source ZIPs or runtime assets. |

Largest local support directories (mixed contents; sizes overlap the protected/cache categories above):

| Directory | GiB |
|---|---:|
| `.artifacts/audio-production` (export-tools cache and save-bearing profiles after 2026-10-04) | 1.339 |
| `.artifacts/map_persistence_native_build_windows_msvc` | 2.344 |
| `.artifacts/town_match_east_20260923` | 0.611 |
| `.artifacts/town_match_west_20260923` | 0.530 |
| `.artifacts/map_persistence_native_build_windows_msvc_release` | 0.417 |
| `.artifacts/fluid_runtime_20260923` | 0.252 |
| `.artifacts/repo_update_20261001` | 0.060 |
| `.artifacts/biome-blocker-library-20260913` | 0.021 |

## Build and packaging evidence

- Linux and Windows release exclusion lists are identical in `export_presets.cfg`; both exclude `art/*/source/*`.
- `tools/prepare_lossless_texture_imports.py:exported_pngs` uses those exclusions when preparing release texture imports. The inventory archive candidates have zero overlap with its export PNG set.
- `tools/package_release.py:export_platform` exports with those presets. Its bundle staging copies the exported game/PCK/native library plus installer metadata/helpers, not production source directories.
- Existing source references in `content/*.json` were checked. They are provenance/source-description fields, not runtime texture/audio fields; an unfamiliar source-reference key is classified for review by the tool.
- Exact source-file literals were scanned in live GDScript/scenes/resources. None of the candidate files appeared as a live literal. Dynamically constructed paths and arbitrary authoring scripts are not proven absent by this static scan.
- Source-dependent tests and rebuild scripts are expected to need restored sources. No claim is made that every development test runs with the originals archived.
- No game build, export, archive, delete, Git-history rewrite or archive restore was performed in this mapping slice.

## Reproduce the complete map

Run from the repository root on Windows or Linux:

```text
python tools/source_material_inventory.py
python tools/source_material_inventory.py --files --category archive_source_binary
python tools/source_material_inventory.py --files --path-prefix art/units/source/generated/fluid_animation/batch_e/
python tools/source_material_inventory.py --files --category keep_editor_source
python tools/source_material_inventory.py --files --category review_excluded_art
```

The tool writes JSON to stdout only. Each detailed record gives the relative path, byte size, Git tracking, classification, both preset exclusions, content-reference locations and exact live-code references. The default summary covers every regular file in the checkout, including hidden local directories. Reparse points/symlinks are skipped and reported; filesystem/read errors are reported and cause failure. No binary content hashes are calculated in this mapping pass.

Archive candidates require a later verified ZIP and original-file hash comparison before any local removal. Preserve the original relative paths so extraction restores the existing build recipes. Removing tracked working files alone does not shrink existing Git history.

## Validation

- Enumerated 173,138 current regular files without scan errors, skipped links or missing content source paths.
- Classified all 86,342 source-tree files; category byte/file totals reconcile.
- Checked 7,334 export-eligible PNG paths against the independent release-import selector: no source-archive candidate is selected.
- Passed 24 focused classification/grouping assertions, including editor sources, unknown content/runtime references, asymmetric platform exclusions, native libraries, saves/backups, RMG boundaries and the `stormgrass` false-positive case.
- Actual command-line JSON/category filtering passed: 598 editor-source/sidecar records totaling 545,803,944 bytes.
- Scope is static inventory validation. No full suite or Linux runtime/export execution was needed or claimed.
