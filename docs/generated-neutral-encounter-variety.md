# Generated Neutral Encounter Variety

Owner-directed Phase 6 slice: `bugfix-generated-neutral-encounter-variety-20260910`.
Sources: `project.md`, `PLAN.md`, `docs/lessons-learned.md`.

## Requirement

Generated maps must not collapse unrelated neutral guards into the same Mireclaw raid and fixed army. Provide appropriate original-content species/companies, varied quantities and stack compositions, with map icons representing the actual encounter army. Variation must be deterministic and readable, not random cosmetic labels over identical battles.

## Investigation and boundaries

Trace native object identity and available strength/composition metadata through package adoption, encounter hydration, map art, battle creation and saves. Record representative Medium/Large distributions before and after. The confirmed collapse occurs in both C++ exporters, followed by the GDScript adoption fallback; supplemental source guards independently used the same fixed raid.

Preserve recovered placement, coordinates, footprint masks, linkage, object count and RNG/private-state generation behavior. Do not invent native source semantics; name missing recovered fields as blockers if required. Keep authored encounters and existing saves compatible. Avoid unrelated faction balance, rewards, AI or presentation changes. Use existing semantically correct manifest-backed original art; investigate missing artwork before requesting or generating additions.

## Acceptance

- Exact source-to-content trace and deterministic reproduced repetition.
- Content-backed neutral variety in species/compositions, unit quantities and stack counts across representative generated maps; honor available source strength rather than replacing it with arbitrary tuning.
- Preview/icon/actual battle army agree; no generic fallback or UI-card world icons.
- Repeat adoption yields identical state; save/resume preserves armies and identities, and native map topology remains unchanged.
- Focused automated coverage, representative Medium/Large runtime/battle cases and visually inspected captures.
- Repository validation, diff checks and official Linux/Windows exports with packaged affected gameplay checks pass, with platform limits stated.
- Source-backed completion report and tracker closure only after actual implementation and acceptance. Retain concise final evidence; dispose of newly created redundant export/Wine workspaces after validation while retaining required evidence.

## Confirmed root cause and correction

The pinned `tests/fixtures/overworld_cutout/native_day97_roundtrip.json` contains 41 native guards with 34 distinct `h3m_subtype` values; all 41 have `encounter_mire_raid`. Both `map_package_service.cpp` and `rmg_native_batch_export_cli.cpp` explicitly assign that single id. The GDScript bridge additionally falls back to it for unresolved guards. The authored raid is exactly four Bog Brutes and five Mire Slingers, explaining the repeated two-stack composition.

Quantity is recoverable without changing generation: `connection_monster_materialization_0x4a5e03` stores `allocation_0x4a5c07.selected_quantity_0x20` in the object record. Serializer `0x49bb92` writes the twelve-byte base, the sequence for pass >= 1, then the quantity as little-endian u16. The runtime projection previously retained the payload offset and size but discarded this quantity. The additive projection now exports quantity, subtype, source level and AI value through both C++ exporters. The native selftest compares projected counts directly with private-state +0x20 and verifies source level/AI metadata. Generation, private-state writes and serialization are unchanged.

Both exporters retain their legacy encounter/object id fields for backward compatibility. `GeneratedNeutralEncounterRules.gd`, called before the bridge's legacy fallback, is the authoritative original-game translation for metadata-bearing guards. It writes the actual encounter identity, army and manifest sprite. Invalid source metadata or missing original art is rejected, not replaced with a generic raid.

## Original content translation

`content/generated_neutral_encounter_profiles.json` selects 51 existing neutral company/creature profiles across lead-unit tiers 1–7. The source creature table's zero-based level selects the corresponding original tier; SHA-256 of `native_species_v1:<subtype>` selects a stable profile within that tier. This is original-game content translation, not a claim of HoMM combat balance parity. Source AI value is retained as metadata; source creature names/art are not used as game content.

Total headcount is the actual serialized quantity, not a strength multiplier. A SHA-256-derived placement key selects one to three primary stacks and optional support from the selected authored army. Mixed groups retain three quarters or more of their headcount in the primary unit; splitting conserves total count. No native RNG call, map position, guard link or footprint changes. Legacy saves/packages without the additive metadata keep their existing armies.

Map art is keyed to the actual primary unit: existing original cutouts are reused, and 22 additional runtime files are byte-exact copies of existing curated transparent paintings. No new artwork, UI-frame extraction or pixel processing has been performed. The manifest and `tools/prepare_generated_neutral_icons.py` validate source identity and hashes. The older final-cutout validator now checks its frozen historical membership as a required subset, allowing new independently validated art rows without rewriting historical acceptance evidence.

The 51 profiles represent 46 distinct primary-unit paintings. The original final-cohort producer is archived byte-exactly as `art/overworld/source/generated/cutout_recovery_20260909/final_families/accepted_preparation_tool.py` (SHA-256 `5897bd0210b264ca4d20158226f7a29a81004107c0ecbe483deafb009e57b43b`) so the historical proof still identifies its actual producer after membership-validator maintenance. Historical recipes, proof and accepted pixels are unchanged; reconstruction and source/projection-tool hashes remain enforced.

Supplemental guards are original-game content, not native creature records. Six rare-resource sites and the generated town supply cache now have seven explicit thematic company mappings. Their varied armies stay within the previous raid's strength ceiling of 149 using the existing `max(6, hp + min_damage + max_damage + ranged_bonus)` metric. No synthetic native quantity is attached. Existing guarded-reward contracts keep their authored armies and gain troop art where a matching profile exists. The first Windows smoke exposed the town-cache caller missing from the initial six-site mapping; that seventh mapping and bridge integration coverage correct it.

## Validation evidence

Status: completed 2026-09-10. Evidence root: `.artifacts/generated_neutral_variety_20260910/`. All acceptance results below are real completed runs; limitations and earlier rejected runs remain explicit.

- Focused Godot contract: **7,471 checks pass**, covering 700 native metadata cases plus 56 supplemental cases and all seven bridge site routes. Pure/mixed armies, one-to-four stacks, positive counts, exact native totals, deterministic conversion, JSON preservation, battle army selection, invalid metadata/missing art rejection. The pinned Day-97 save passes actual SaveService write/restore without encounter changes. Final result: `focused.json`.
- Real public native generation, normalization, SaveService restore, five BattleRules payloads and live renderer per case: Medium seed `10`, 41 guards, 22 identities, 31 quantities, 40 compositions; Large seed `large-runtime-profile-10225`, 88 guards, 32 identities, 48 quantities, 88 compositions. Largest identity shares are 5/41 and 13/88. Both exercise all four stack counts plus supplemental supply-cache guards. Clean source reports: `medium-acceptance-1280/report.json` (**337 checks**) and `large-acceptance-1920/report.json` (**674 checks**). Older `*-final-*` and initial packaged reports predate the seventh site mapping: their numeric variety assertions passed but their logs contained supplemental mapping errors. They are **not clean acceptance**. The harness now rejects ordinary `ERROR:` as well as script errors; the corrected acceptance logs contain neither.
- Visually inspected normal-fog openings and diagnostic scouted regions at 1280x720 and 1920x1080. Diagnostic captures reveal existing positions only; scouting is not saved. Troop/creature cutouts represent the actual primary units, without UI-card frames. Renderer assertions check manifest identity and loaded raster textures.
- All four Linux/Windows native debug/release builds succeeded. Final Linux native selftest passed. The standalone CLI wrote Medium/Large native final payloads byte-identical to retained executable references (below). Its separate runtime-package export remained gated, and is **not** counted as a pass.
- Original-art source validation passes (22 byte-exact additions, 51 valid profiles); all nine historical final-cutout tests pass after explicitly allowing separately validated neutral additions outside the frozen 71-asset cohort.
- `python3 tests/validate_repo.py`: **VALIDATION PASSED**, final service `heroes-neutral-repo-acceptance-20260910` exited 0; log `/tmp/heroes-neutral-repo-acceptance-20260910.log`. `git diff --check` passes. This is repository consistency, not a release-ready claim.
- Official exports: `linux-export-final/report.json` and `windows-export-final/report.json` both pass, including Linux boot and Windows startup/generated-map/Town-building flows. Both PCKs are **313,168,728 bytes**, with **5,589 identical member keys**; only `project.binary` differs. The owner removed the former size ceiling; no new limit is imposed.
- Isolated packaged neutral gameplay: Linux Medium **337 checks** (`linux-packaged-medium-final/`), Windows Large **670 checks** (`windows-packaged-large/`). Same SHA-locked GDScript assertions, actual native generation, five battle rosters, saves and map texture loading; no loose game resources. Linux captures were visually inspected. Windows is headless Wine, not physical Windows GPU validation. Windows logs separately checked for zero `ERROR:` entries.
- Disposable Wine prefixes are removed with user data/logs retained (`wine-prefix-cleanup.json` and per-export receipts). Two superseded export product directories were deleted (810,609,992 logical bytes, approximately 773 MiB); their reports/logs/screenshots remain. Those binaries can be rebuilt, not undeleted. Final platform products, build caches, original art and RMG reference evidence are retained.

Native payload controls:

| Case | Current output | Retained H3MapEd reference | SHA-256 |
| --- | --- | --- | --- |
| Medium seed 10 | `native-cli/neutral_medium.final_payload.bin` | `.artifacts/rmg_recovery/medium_seed10_1h1c_weak_memory_stream_authority_20260716a/final_payload.bin` | `5c257e740c5743d215110a8575059402cd945bfe31670c2acb0db1e99bbc795c` |
| Large seed 11 | `native-cli/neutral_large.final_payload.bin` | `.artifacts/rmg_recovery/large_seed11_1h1c_weak_memory_stream_redirect_raw_dump_20260715a/final_payload.bin` | `2fab2929259a04929bdf7a9c908194b58de6ef1536d32914b764c980ac2f91df` |

The legacy CLI gate is `runtime_projection_requires_parity_proven_native_owned_final_payload`; the supplied historical authority summary was not recognized as a known same-run profile. No fabricated authority metadata or generation tuning was added. Actual gameplay acceptance uses the public MapPackageService through ScenarioSelectRules, not that gated CLI export mode. These two unchanged payload controls do not assert universal native parity.

## Compatibility and evidence hygiene

Reproduction commands (use a new `--label` if retaining an existing run):

```sh
python3 -B tests/generated_neutral_encounter_regression.py
python3 -B tools/prepare_generated_neutral_icons.py
python3 -B tests/generated_neutral_map_regression.py --size medium --render --label medium-acceptance-1280
python3 -B tests/generated_neutral_map_regression.py --size large --render --resolution 1920x1080 --label large-acceptance-1920
python3 -B -m unittest discover -s tests -p test_overworld_final_cutouts.py
bin/h3maped_rmg_core_selftest
python3 tests/validate_repo.py
git diff --check
HEROES_PACKAGING_LINUX_ARTIFACT_DIR=.artifacts/generated_neutral_variety_20260910/linux-export-final python3 -B tests/packaging_linux_export_smoke.py
HEROES_PACKAGING_WINDOWS_ARTIFACT_DIR=.artifacts/generated_neutral_variety_20260910/windows-export-final python3 -B tests/packaging_windows_export_smoke.py
python3 -B tests/packaged_generated_neutral_regression.py --platform linux --binary .artifacts/generated_neutral_variety_20260910/linux-export-final/export/heroes-like.x86_64 --pack .artifacts/generated_neutral_variety_20260910/linux-export-final/export/heroes-like.pck --size medium --render --label linux-packaged-medium-final
python3 -B tests/packaged_generated_neutral_regression.py --platform windows --binary .artifacts/generated_neutral_variety_20260910/windows-export-final/export/heroes-like.exe --pack .artifacts/generated_neutral_variety_20260910/windows-export-final/export/heroes-like.pck --wine-prefix .artifacts/generated_neutral_variety_20260910/windows-neutral-prefix --size large --label windows-packaged-large
```

Exports must be serialized because they share the source import cache. Packaged probes use isolated user directories and remove only their owned temporary test files. The progress skill was used to establish and update the owner-directed Phase 6 implementation slice; its documentation chain was kept separate from passing runtime evidence.

Generate a new map to get the full new native metadata-driven variety. Existing saves/packages without these fields retain their saved armies and identities; no forced migration or save-schema change. New saves preserve the translated armies. Terrain/topology, placement masks, guard links, object counts, rewards and native RNG are not changed. This is not a comprehensive combat-balance or Windows GPU/hardware certification.

Initial source probes refreshed four ignored deterministic test packages under `maps/` (the Medium Moon Field Fen and Large Fallow Lantern Fen `.amap`/`.ascenario` pairs). The harness now backs up and restores those exact paths, rejects symlinks and removes only newly created test outputs. No owner saves were deleted. Calling the legacy CLI with `--help` unexpectedly rewrote its zero-case default `.artifacts/rmg_native_batch_export_cli/manifest.json`; that CLI does not implement help. Its prior summary contents cannot be proven unchanged. No recovery payload or trace files there were removed; retained reference hashes above are verified. This side effect is recorded rather than represented as untouched evidence.
