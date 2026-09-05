# RMG starting heroes and H3MapEd comparison audit

Owner-directed audit, 2026-09-05. Status: completed, with confirmed correctness failures and open implementation gaps below. This is an audit, not a generator or gameplay correction.

Implementation follow-up: the entrance-start and level-aware runtime children now correct findings 1–3 within their documented boundaries; see `rmg-town-entrance-correction-report.md` and `rmg-level-aware-runtime-report.md`. All 83 sampled starts and 35 supported primary-hero entrance/movement/save cases pass. The baseline measurements below remain historical evidence, not current failures after those fixes. Player/team identity, native paired transit/water, normal-water native parity and integrated regressions remain open.

## Requirements and scope

Reproduce heroes starting away from their own town using deterministic generated maps. Trace the recovered town/player record, native runtime start selection, package contract and live session position separately. Inspect town ownership, faction/hero selection, exact masks, reachable entrance, map levels and AI starts. Audit the wider native phase and runtime adoption boundary against recovered H3MapEd evidence, not against visual resemblance, object counts or old tracker completion claims.

Source hierarchy: `project.md` → the audit slice in `PLAN.md` → `docs/lessons-learned.md`, `docs/h3maped-rmg-end-to-end-behavior.md`, `docs/rmg-python-validation-workflow.md` and current source/private-state evidence → deterministic validation → findings here.

Coverage must identify tested size/water/level/player/seed combinations, actual Linux/Windows checks, historical versus fresh executable comparisons and unavailable source evidence. Infinite seeds, broader unsupported H3MapEd modes, copied game content, heuristic topology fixes and release certification are excluded.

## Result

The reported starting-hero issue is real. The native package adapter deliberately moves every sampled start off the main-town entrance. Live adoption can subsequently put a blocking guard on that tile, and two-level maps lose the hero's level entirely. Separately, one of the 24 retained H3MapEd comparison cases fails with the current native build; a fresh executable capture reproduces the owner bytes and private-state divergence. The previous blanket current “24 workflows complete, including adoption” claim is therefore not supported.

Audited runtime revision: `e08da0990a24ac1e4cabf365bbb3c50ff3b30165`. No production scripts, native implementation, binaries, assets, generation inputs, topology, masks, balance, or save schema were changed. New Python audit tooling and tests collect evidence without supplying owner payload bytes to generation or repairing its output.

Evidence root below: `.artifacts/rmg_start_audit_20260905/`. Raw evidence is local ignored project evidence; the methods, selected cases, hashes, measurements and findings are recorded here for durable review. Original unrelated artifact-retention files/reports remain untouched.

## Coverage and limits

The runtime matrix generated 35 of 36 requested cases; the remaining case intentionally requests unsupported `impossible` monster strength and is rejected with `native_rmg_monster_strength_unsupported`. All 24 size/water/level combinations were actually generated, not merely normalized:

- Seed 1, weak monsters, one human/one computer: widths 36, 72, 108 and 144; one/two levels; land, normal water and Islands.
- Additional controls: Medium land seed 165429308 with four players (the previous ordinal-95 regression), Medium land seed 10 and an exact repeat, Small two-level land seed 68, XLarge two-level normal-water seed 77.
- Medium land seed 10 with three, six and eight players; Small land seed 1 with normal, strong, random and unsupported impossible strength.
- A separate Small land seed-1 three-player reproduction identifies the existing legacy creature-bank assertion failure; it is not counted in the 36-case matrix.

The 35 generated cases contain 83 player starts. All 83 reference an existing town, and all are displaced from the actual town **entrance**, not its painted/source anchor: 68 by Manhattan distance 2, ten by 3, five by 4. Thirteen starts are underground. Five primary hero origins become blocked after adoption; four still have an unblocked first step, while Small seed 68 has none. Eleven of 83 town destinations are unreachable in the diagnostic fixed-body native graph.

Graph counts hold object bodies fixed, allow eight-way movement with the runtime's both-sides-blocked diagonal rule, and open the town destination. They do **not** simulate battles, removable objects, transit, water travel, or legal interaction approach. Eleven failed graph routes are leads, not eleven proven unwinnable games. The zero-step Small seed-68 case is additionally checked against production `tile_is_blocked` and corner rules.

This is a broad boundary/phase audit with deterministic sampling, not an exhaustive review of every seed, instruction, template, allocator history or full-game outcome. Runtime matrix collection succeeding means the probe ran, not that gameplay passed. Team relationships, multi-human play, all six faction selections, all object effects, full naval play, and all 18 phase/private-state checkpoints across every workflow are **not certified** by these tests.

## Confirmed findings and responsible code

### 1. Starting heroes are intentionally moved away from their town

`src/gdextension/src/map_package_service.cpp::runtime_start_tile_for_slot` builds exact native body/action/road sets, excludes all three from candidate starts, and begins its search at radius **1**, never at the town entrance. It first prefers a road-adjacent candidate within 18 tiles, then one connected to any road, and finally the nearest available candidate without proving a route to the owning town. The scenario writes this result into `hero_start_tile` and `runtime_start_tile`. `NativeRandomMapPackageSessionBridge.gd::_primary_start` adopts it.

This behavior was deliberately restored by `native-rmg-exact-mask-runtime-start-selection-10184`; its “not on the town tile, can take a first step” contract did not establish return-to-town access. It explains the owner's observation without requiring RNG nondeterminism. Repeat Medium seed-10 terrain, objects, player slots, starts, towns, hero position and enemy states are exactly equal (`e76c8967` payload hash).

The recovered `0x4ac857` header/player serializer in `h3maped_rmg_core.cpp` carries a main-town coordinate/level and create-hero flag. That editor record is not evidence for Aurelion's off-road search policy. The exact foreign game's subsequent hero-spawn implementation is outside `h3maped.exe`; this audit does not invent an executable-backed claim that the editor itself instantiates a hero at a particular adjacent square.

Required correction boundary: preserve native town/entrance/masks and establish a source-/product-backed start contract, then validate it **after** all live adoption and support placement. Merely changing a search radius or clearing bodies would not address the demonstrated causes.

### 2. Two-level adoption flattens an underground hero into the surface

Small, seed **68**, weak, land, two levels, one human/one computer:

- Native payload `30c31418`; own-town entrance `(8,16,1)`, selected hero `(10,14,1)`.
- Live hero `(10,14)` on the level-0 terrain map; **zero unblocked first steps**, one reachable cell.
- Native objects: 291 surface and 79 underground, all 370 passed into the same two-dimensional session.
- A surface placement, `native_h3maped_30c31418_object_0273` / `object_badlands_coin_sluice`, blocks the flattened hero coordinate. This is not a missing town binding or corrupt native body mask.

`NativeRandomMapPackageSessionBridge.gd::_primary_start` drops level; `_map_rows_from_document` always selects terrain layer zero. `OverworldRules.gd::_normalize_towns` / `_copy_town_runtime_metadata` omit the top-level town level and runtime-start fields, while visit metadata can still contain level 1. `_world_tiles_from_payload_array`, `_tile_key`, `_build_blocked_tile_index`, and `tile_is_blocked` use `Vector2i`; the Overworld map view has no active-level object filter. Rendering, occupancy and interaction therefore disagree with the otherwise level-preserving package.

The standalone native final payload for this exact seed matches the retained owner binary byte-for-byte. The confirmed failure is downstream adoption, not a reason to alter recovered generation. All 13 underground slot starts in the sample encounter a level-discarding path; the directly rendered immobility reproduction is the primary player in seed 68.

### 3. Supplemental economy support can place a guard on the chosen start

Medium, seed **165429308**, weak, land, one level, four players: payload `1744e025`, 1,283 objects, 76,831 bytes. Own-town entrance is `(31,10,0)`; the painted/source anchor is `(33,10,0)`; selected hero is `(34,9,0)`.

The native-selected start is clear of native bodies. After live support adoption it is occupied by:

`h3maped_small_rare_source_guard_h3maped_small_town_source_support_native_h3maped_1744e025_object_0957_required_sources`

Its identity is `encounter_mire_raid`. `NativeRandomMapPackageSessionBridge.gd::_ensure_generated_town_source_route_support` chooses a usable support tile and appends a resource node plus `_supplemental_rare_source_guard`; the guard copies the node coordinates into its blocking body. Neither selection nor guard insertion reserves the hero's current tile. Normalization repeats after insertion. The final rendered first view offers **Enter Battle** at the starting position.

The other blocked origins in the main matrix are Medium seed-1 two-level land, Large seed-1 two-level land, and XLarge seed-1 one-level land. Their full blocking-owner causes were not separately classified; they must not all be attributed to this guard defect. “Origin blocked” also does not imply “cannot leave”: ordinal 95 retains two unblocked first steps.

### 4. Opponent identity is collapsed by faction, not preserved by player slot

`map_package_service.cpp` exports `enemy_factions` as strings. `NativeRandomMapPackageSessionBridge.gd::_enemy_states_from_document` accepts dictionaries, so those entries do not produce initial enemy states. `EnemyTurnRules.gd::_enemy_faction_configs_for_session` reconstructs them from enemy-owned towns and deduplicates by faction; subsequent enemy state identity is also keyed by faction.

Medium seed 10 with six players produces five native enemy slots but only **four** live enemy states. Eight players produce seven enemy slots but again four states. Default runtime faction assignment cycles Embercourt, Mireclaw, Sunvault and Thornwake. A same-faction opponent is not necessarily the same player. Native slot/team relationships are not proved preserved by this fallback. This affects the public native configuration surface; visible setup player-count choices can additionally vary with the selected profile.

Existing faction/hero-selection checks still pass for the selected Veilmourn/Orso case. This does not establish separate player identity, full team behavior, or initial field deployment of every enemy hero. Original warband/AI policy is not automatically a source-parity defect.

### 5. Native transit placements do not retain their source connectivity in play

Seed 68 has native type-103 underground/surface cave records, including ordinals 0226, 0227, 0230, 0231, 0232, 0233, 0235 and 0236. Authored pool projection maps these independently to original transit identities `object_tide_bore_marker`, `object_pressure_rail_stop`, `object_mileward_route_post`, `object_root_pass_arch`, `object_toll_chain_court`, `object_brass_toll_arch`, `object_thorn_seal_gate` and `object_rope_lift`, respectively.

`OverworldRules.gd::active_linked_transit_edges` constructs local two-dimensional offset endpoints around a placement. It does not adopt the native relationship between separated entrances or switch terrain/object layers. Alongside finding 2, generated cross-level connectivity is therefore not implemented as a level-preserving live route.

The #10223 authored-pool requirements explicitly allow original gameplay effects rather than foreign object-effect cloning. Re-theming is not itself a bug. Losing a necessary connection while offering two-level generation is a functional gap. Water/Islands also need separate navigability/embarkation certification: current ground-passability rejects terrain codes 8/9, and this audit did not execute a complete naval campaign. No “all Islands maps are unwinnable” claim is made.

## Native executable comparison

### Authority and reproducibility

`tools/rmg_retained_authority_audit.py` freshly invokes the standalone CLI without supplying recovered payload bytes, compares complete resulting uncompressed H3M bytes to 24 retained owner captures, and records each exact input/capture path. Its wrapper's `same_run_payload_authority_missing_recovered_profile_metadata` refusal is retained: these are offline diagnostic comparisons, **not** permission to ship an otherwise blocked CLI package.

All cases use two players and weak monsters. Small one-level land seed 59 uses two humans; the other 23 use one human/one computer. Each table cell gives the selected seed and full-binary result; this is one seed per shape, not universal shape parity.

| Size | Land 1 level | Water 1 level | Islands 1 level | Land 2 levels | Water 2 levels | Islands 2 levels |
| --- | --- | --- | --- | --- | --- | --- |
| Small | 59 exact | 62 exact | 60 exact | 68 exact | 69 exact | 70 exact |
| Medium | 10 exact | **10 mismatch** | 63 exact | 13 exact | 71 exact | 72 exact |
| Large | 11 exact | 64 exact | 66 exact | 73 exact | 74 exact | 75 exact |
| XLarge | 12 exact | 65 exact | 67 exact | 76 exact | 77 exact | 78 exact |

Result: **23/24 exact**. Land control seed 10 is 79,333 bytes, SHA-256 `5c257e740c5743d215110a8575059402cd945bfe31670c2acb0db1e99bbc795c`; XLarge two-level water seed 77 is 365,777 bytes, SHA-256 `3760cbf8b03b9e84b1670ef296cab84a6756eebf9018c3a19bac484108e4d12a`.

The mismatching Medium normal-water seed-10 case was then generated by **H3MapEd itself under Wine**, not inferred from the native port. Clean source executable `/root/Downloads/h3maped.exe` SHA-256 is `4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37`. The established trace tool makes an artifact-only seed-constructor patch for seed 10, retaining the editor's RNG seed setter; patched SHA-256 is `c4500a9ee2aa48c79fcf6388278ac9d36c5b3de1a51ffa6db0c7fd82e23c47b2`. Raw final-stream redirection occurs only at final writeout. Source game binaries/resources are research inputs and are not included in this commit or the game package.

The historical “canonical” recovery executable with SHA-256 `f1ab1565fdfb7581cf67ca18a5349bf26fce59f696ea33061f941d80fcc069be` is already seed-58 patched, not a clean input to that seed-patch workflow. An initial attempt using it was rejected by the expected-byte check. No unexpected-byte guard was bypassed.

### Confirmed mismatch and first unproven private-state window

- Fresh and retained owner final payloads both: **72,924 bytes**, SHA-256 `7616922adb5865ceb727e995ff4fac72041b030bcb702c55f7a1259c413872e3`.
- Current native: **72,595 bytes**, SHA-256 `16a010a69563d502c8b390961ae028c72568e7261f5881776b423a3af3148cbc`.
- First complete-file difference: byte **341**, in header metadata. It is not a town-coordinate difference and is not evidence for a header-only fix.

A second fresh executable run captured complete generated-cell grids at three caller PCs. The comparator merges overlapping Wine dumps (including cell zero), requires every cell/word, rejects inconsistent dumps, and joins explicit native phases:

| Owner checkpoint | Current native checkpoint | 5,184 cells, eight words each (+0x10 through +0x2c) |
| --- | --- | --- |
| `0x004a8c25`, after `0x4a8260` | `after_0x4a8260_0x4a8c25` | Exact |
| `0x004a8c2c`, after `0x4a4c8e` | `after_0x4a4c8e_0x4a8c2c` | Exact |
| Entry `0x0049eb8d` | `after_0x49a1ef_0x4ac83d` | Divergent |

Before decoration, differing cell counts are: `+0x10`: 542; `+0x14`: 633; `+0x18`: 226; `+0x1c`: 1,539; `+0x20`: 3,544; `+0x28`: 1,501. Fields `+0x24` and `+0x2c` match. The first `+0x20` difference is cell zero: native 353370121 versus owner 353370116.

The first **unproven window** is after the `0x4a4c8e` route/free-cell sweep through mine/reward/guard/connection work before `0x49eb8d`. Named owners for the next source/call-order investigation include `0x4a9d6a` / `0x4a9911`, `0x4aab7e` / `0x4aa3e9`, and `0x4a79a3` / `0x49a1ef`. This audit has **not isolated a single faulty function or missing structure** inside that window. Final-map deltas must not be used to invent a correction.

A separate Medium seed-10 land comparison matches all 5,184 cells/eight words before `0x49eb8d` against the retained matched-profile July-12 owner trace. That is a useful land control, not a fresh land executable run or proof of all earlier phases. Raw pointer fields, pointed-to object vectors, RNG histories between checkpoints and all other phase buffers are not certified by these grid comparisons. The fixed R1-R7 ledger's 178-function/18-phase recovery inventory remains historical source evidence, not current native parity.

## Wider boundary review

| Boundary | Reviewed owner and evidence | Current conclusion |
| --- | --- | --- |
| Setup/seed/configuration | `map_package_service.cpp`, native controlled-case parser, `ScenarioSelectRules.gd`, seed/control records | Actual 24-shape generation exercised; weak/normal/strong/random accepted in selected cases; impossible rejected; exact repeat passes. Team/multi-human gameplay not certified. |
| Template, zones, terrain, relations, town placement | Recovered end-to-end ledger and `h3maped_rmg_core.cpp`; owner captures | Full retained bytes tested across 24 selected cases; water grid is exact through `0x4a4c8e`, later differs. Not all earlier buffers/calls compared. |
| Mines/rewards/guards/connections | Same native core, three fresh owner grid checkpoints | Named unresolved water phase window above; no count/density tuning. |
| Decoration/final header/tile/object writeout | Core serializers and complete owner streams | 23 exact, one mismatch; complete-file mismatch precedes final object table. Earlier state divergence disproves a cosmetic-only explanation. |
| Native object projection and original content | Package service, `content/random_map_object_eligibility.json`, #10223 report, current object-pool runtime report | All 422 authored map objects have eligibility decisions: 336 eligible/86 intentional exclusions. Four-size report passes with 9,466 source placements classified, zero unclassified. This is not complete foreign object-effect adoption. |
| Heroes/towns/occupancy | Package start selector, session bridge, `OverworldRules.gd`, live reproductions | Off-town policy, post-adoption guard collision and level flattening confirmed. |
| Rivals/teams | Bridge and `EnemyTurnRules.gd` | Native slots can merge into faction-keyed AI states. Team preservation not proven. |
| Transit/naval routes | Bridge projection, `active_linked_transit_edges`, terrain passability | No native paired cross-level route adoption; naval completion unverified. |
| Persistence/rendering | Native package save/load, production provenance, OverworldShell | Both exact problem cases survive disk round trip and briefing autosave; inspected at 1280x720. Persistence preserves the adopted bug, not the missing level. |
| Platform/package | Linux and Windows selftests, release exports/startup, both packaged generated flows | Pass; both PCKs 248,376,908 bytes, under the unchanged 250,000,000-byte ceiling. Wine is not native Windows hardware/GPU certification. |

### Existing validation gap

`native_rmg_end_to_end_runtime_boundary_report` currently exits 1 at `creature_bank_rows_exact=false` in `_validate_live_proxy_site_projection`. Small seed 1, three players still produces payload `457dba6b` (23,664 bytes, 294 objects). The test expects source type 16/subtype 6, ordinal 0258 at `(14,16,0)`, to remain a raw `h3m_object` with no original identity. The later #10223 compatible authored-pool projection makes that expectation stale. A fresh `legacy_proxy_repro/legacy_proxy_seed1.json` confirms this exact ordinal now resolves to `resource_site`, `object_chainboom_fort` / `site_chainboom_fort`, pool `guarded_reward`, catalog `authored_pool_proxy_16_6_guarded_reward`; its source anchor and body/visit `(13,16,0)` are unchanged. Other reported mine/resource/artifact/scroll/generator rows and repeat checks pass; the entire legacy report does **not** pass, and its later checks cannot be claimed as executed after this early failure.

Its `_validate_supported_workflow_matrix` normalizes 24 configurations; that method alone never proved 24 playable maps. The separate new matrix here actually generates/adopts them and reveals the missing level/player/start assertions. The old test has not been weakened or edited during this audit.

## Validation and evidence

- Python measurement tests: **9 pass** (`tests/test_rmg_start_placement_audit.py`), including exact-byte truncation/mutation detection, fixed-mask graph rules, complete shape coverage, and overlapping private-dump/missing-word handling.
- `matrix/summary.json`: 36 requests, 35 generated, expected unsupported-strength refusal, zero logged runtime errors; exact Medium repeat confirmed across full terrain/object/start/adopted-state records.
- `rendered_final/{ordinal95,small_seed68}.json` and `.png`: both production package disk round trips preserve position, both briefing autosaves succeed, no engine errors; screenshots visually inspected. Initial incomplete audit-fixture attempts lacked save provenance and are superseded by this final production-provenance run, not reported as game save defects.
- `retained_matrix/summary.json`: **23 exact / 1 mismatch**, comparator exits 1 as intended for the discovered defect.
- `owner_medium_water_clean/{winedbg_interactive_trace_ledger.json,extraction_summary.json,final_payload.bin}`: fresh executable owner bytes confirm the mismatch, not stale retained evidence.
- `owner_water_private/winedbg_interactive_trace_ledger.json`, `private_water_compare/summary.json`: two exact checkpoints followed by one divergent checkpoint; comparator exits 1. `private_land_compare/summary.json`: exact retained land checkpoint, exits 0.
- `linux_selftest.log`, `windows_selftest_configured.log`: native selftests pass on Linux and Windows/Wine. An initial default-Wine-prefix kernel32 failure was resolved by using the repo's established win64 prefix; it was not a native test failure.
- `object_pool.log`: existing four-size object table/pool report passes (2,449 authored-pool, 418 intentional native passthrough, 6,599 renderer-only placements; zero unclassified).
- `faction_hero_isolated_final.log`: current `random_map_faction_hero_selection_report` passes with isolated user data and no engine errors: six faction options, 11 Veilmourn heroes, selected Orso, Bellwake Harbor and Bellwake Privateers army. An earlier invocation mistyped the scene filename and is not test evidence.
- `runtime_boundary.log`: known failing legacy creature-bank expectation above; **not green**.
- `validate_repo_final.log`, Linux/Windows package logs: repository validation and both exports/startups pass. Linux `linux-generated-flow/live_validation_report.json` and the Windows package report both pass generated setup → Overworld → own Town entry with zero errors. Both release PCKs are 248,376,908 bytes; no package-limit increase. `git diff --check` passes.

Primary rerun commands (use a fresh `--label` because evidence directories are not overwritten):

```bash
python3 tools/rmg_start_placement_audit.py --label matrix_rerun
python3 tools/rmg_start_placement_audit.py --label rendered_rerun --case ordinal95,small_seed68 --render
python3 tools/rmg_retained_authority_audit.py --label retained_rerun
python3 tools/rmg_retained_authority_audit.py --label private_water_rerun --private-log .artifacts/rmg_start_audit_20260905/native_water_private/rmg_native_batch_export.log --owner-ledger .artifacts/rmg_start_audit_20260905/owner_water_private/winedbg_interactive_trace_ledger.json
python3 -m unittest discover -s tests -p test_rmg_start_placement_audit.py
bin/h3maped_rmg_core_selftest
WINEPREFIX=/root/dev/heroes-like/.artifacts/wine-rmg-win64 WINEDEBUG=-all wine bin/h3maped_rmg_core_selftest.exe
python3 tests/validate_repo.py
python3 tests/packaging_linux_export_smoke.py
python3 tests/packaging_windows_export_smoke.py
git diff --check
```

Run standalone native comparisons when no Godot process is active. The native wrapper intentionally refuses concurrent engine use. The live adapter uses isolated `XDG_DATA_HOME`, dummy audio, and disabled accessibility for this host; it does not certify AT-SPI behavior.

Fresh executable reproduction uses `tools/rmg_h3maped_recovery_interactive_trace.py` with the clean executable above, existing `.artifacts/wine/h3maped` prefix, `--map-size medium --level-count 1 --human-computer-down 1 --computer-only-down 1 --monster-strength-down 1 --water-mode normal --seed 10 --seed-control-mode pe-patch --defer-breakpoints-until-generate`. Final capture stops at `0x004ad3de` after intercepting `0x004ad1e3`; all exact breakpoint/address-command arguments and seed-patch evidence are in its ledger. Extraction uses `tools/rmg_h3maped_redirected_memory_payload_extract.py` with `--ledger`, `--out`, and `--bytes-out` pointing to fresh evidence paths.

The private capture stops at `0x0049eb8d`, after `0x004a8c25` and `0x004a8c2c`, dumping the generator header at EBX+0x14 for the first two events and ECX+0x14 for the last, then all 62,208 grid words. Native trace flags are `AURELION_RMG_TRACE_POST_4A8260_GRID=1`, `AURELION_RMG_TRACE_POST_4A4C8E_GRID=1`, and `AURELION_RMG_TRACE_POST_49A1EF_GRID=1`, with controlled case `water_private:medium:2:10:normal_water:1:1:1:1:2:-1:1:1:1:0:-1` and `--include-unsupported --emit-final-h3m-payload`. The two fresh owner captures are separate matched-configuration runs; they are not misrepresented as one same-run private/final-stream trace.

## Prioritized follow-up implementation boundaries

1. **Starting-town/hero correctness:** resolve the intended entrance/start contract, reserve occupied hero positions during supplemental support placement, and validate a legal own-town interaction/exit after full adoption. Add exact seed-165429308 regressions without modifying recovered topology or masking blockers away.
2. **Layer-aware runtime adoption:** carry hero/town/object level through occupancy, rendering, navigation, visibility, transit and persistence; seed 68 must be playable on its real layer. If that implementation is not selected, separately decide whether the exposed two-level launch option must be withheld. This audit does not silently change the product surface.
3. **Native normal-water parity:** investigate the named post-`0x4a4c8e` window using recovered call order/private buffers; isolate the missing behavior before any port correction. Require fresh matched owner evidence and land/water controls, not final-count tuning.
4. **Player/team identity and native transit relationships:** retain distinct native slot ownership through AI state and preserve functional source connections independently of original visual/gameplay re-theming.
5. **Correct regression coverage:** replace the stale raw-bank expectation with the current authoritative pool contract, then exercise starts, levels, all exposed player-count boundaries and complete cross-level/naval play. Preserve intentional exclusions and original content semantics.

These are open behavior/recovery gaps, not completed implementation slices. The audit can be complete while its correctness checks expose failures; the RMG feature and game are not thereby complete or release-certified.
