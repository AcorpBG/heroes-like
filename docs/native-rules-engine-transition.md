# Moving the rules engine to C++: transition plan

Status: approved by the owner on 2026-10-20 with decisions D1-D3 (section 8). Phase 0 is done and the owner passed
gate G0 on 2026-10-20: Phase 1 starts with decisions D5, D6, D8 and D10 made, and Phase A runs alongside. Later phases
start only through their gates. Line references are as of commit 50929125a; each slice brief re-checks them.

## 1. Why, and what "done" means

- **Goal.** AI-vs-AI games an order of magnitude cheaper, so balance work can use 600-6,000 full games per change and
  genetic algorithms can use tens of thousands of games or millions of battles.
- **Today, measured** after the round-2 speed-up: 60 large 4P games took 29 minutes at 16 at once (on 50929125a) and
  40 minutes at 10 at once (round 7, on 7fa4a228d), both recorded in PLAN.md. That is about 7-8 slot-minutes per game,
  since batch games run to day 107-320. At that rate 600 games take about 5-7 h and 6,000 about 2-3 days on this
  machine, which also becomes barely usable at 16 at once.
- **Battles today.** The battle-AI tuner (`tools/battle_ai_arena`, already a generation-by-generation weight search)
  plays its 480-battle `standard` suite in about 75 s on 24 workers (`tools/battle_ai_arena/README.md:58`).
- **Not a second simulator.** C++ *replaces* the GDScript, one subsystem at a time. Main always holds one copy of
  every rule; the game, the match runner, the battle tuner and any command-line tool run the same native code.
- **End state.**
  - **Native** (`aurelion::rules`, a pure C++ core in a new `aurelion_rules` GDExtension for Windows and Linux): battles,
    battle AI, battle payloads, the overworld AI faction turn, day processing, and the human-side rule actions.
  - **GDScript keeps:** UI and scenes, `describe_*` text built on native queries, SaveService file I/O, ContentService
    parsing (feeding the native content tables), the map editor.
  - **Unchanged contracts:** save version 9 (`SessionStateStore.gd:4`), the session Dictionary shape, the battle RNG
    stream format.
  - **AI tuning numbers** live in content JSON, per controller, so tuning them never needs a C++ build.

## 2. Scope

A match executes at most about 42k GDScript lines per day (a reachability trace, an upper bound; Phase 0 records what
actually runs):

| Part | Lines | Notes |
|---|---|---|
| Battle core | about 15k | BattleRules (10.1k reachable of 16.2k), BattleAiRules 3.7k, battle parts of SpellRules 0.9k, BattleAutoResolve, footprint, damage, town battle |
| Overworld AI | about 11k | AiHeroRules 6.4k, EnemyAdventureRules 3.8k, EnemyTurnRules 0.8k |
| Day processing and shared rules | about 16k | OverworldRules 9.1k reachable, HeroCommand, Artifact, HeroProgression, Scenario, town development, water travel, transit |
| Text built during the day | about 2.8k | `end_turn` builds message text even in headless matches |

How often it changes (commits since 2026-09-01): the rules layer was rebuilt until Oct 10 and has been quiet since
(7 commits after Oct 11, all alongside AI work). The AI is the hot spot: AiHeroRules is 13 days old with 43 commits.
Balance mostly lives in content JSON (33 content commits since Oct 1). All 22 unit ability ids are named in code, so a
*new* ability is a code change. The battle code has no `pow`, `exp`, `log` or `sqrt` at all.

## 3. Rules for every phase

1. **One copy on main.** During a slice, the GDScript reference lives only on the slice's branch behind a
   `HEROES_NATIVE_<SUBSYSTEM>=gdscript|native|shadow` switch. The merge switches every caller and deletes the replaced
   GDScript. Deleting it is an exit criterion (the RMG precedent: `RandomMapGeneratorRules.gd` is still used).
2. **Port semantics, not a redesign** (`docs/lessons-learned.md`, lesson 3). Keep Dictionary key order, int/float typing,
   sort tie order, the order of float operations, and per-call-site defaults. Typed rewrites, deterministic math and
   merging duplicate code (for example the AI's own damage estimate, `BattleAiRules.gd:2492-2567`) come later, each as a
   separate behaviour commit with owner approval and a new baseline.
3. **Fix the first function that differs**, found at the finest checkpoint (per call, then per action, then per day).
   After three failed fixes on the same function, stop and name it as a blocker in PLAN.md. Never tune toward win ratios.
4. **Bugs found while porting** are recorded by name and fixed in their own commit, never inside a port commit.
5. **Progress means native code runs the game.** Digest tools, corpora and switches are support work and land only with
   the slice that uses them (AGENTS.md "Implementation progress discipline").
6. **Speed claims are measured only:** plain runs, HEAD against the change, same concurrency, idle machine, in the binary
   flavour batches actually load. Estimates in this document are bounds, never promises.
7. **Pure, thread-safe core:** no mutable globals, caches per engine instance, read-only content tables (the map
   generator's pattern, `h3maped_rmg_core.cpp:58-87`).
8. **No builds, parity runs or timing while an owner batch is running.** Builds go to the Linux server or CI at low
   priority; batches run from a frozen copy of `bin/` so a sync never hits a locked DLL.

## 4. Architecture shared by all phases

**Code layout.** `src/gdextension/rules/` builds once as a static/object library and links into the `aurelion_rules`
GDExtension (its own `rules.gdextension`), `rules_selftest`, and later `battle_sim_cli`. Keeping it out of the map
persistence library means rules commits never rebuild the 45k-line `h3maped_rmg_core.cpp` (today compiled three times,
`src/gdextension/CMakeLists.txt:49-68`) or recommit the map generator binaries.

**Engine-exact helpers** (`rules/compat/`), copied from Godot 4.6.2 and each landed with the first slice that needs it:
PCG32 seed/state and `randi_range`, `randf` (which very likely returns a 32-bit float that GDScript widens; obstacles
test `rng.randf() < 0.4`, `BattleRules.gd:9403`), `String.hash`, `SortArray` tie order, `round` (half away from zero),
`posmod`, `snappedf`, `str()` of numbers, int64 wraparound. Each is fuzzed against the engine (at least 1M inputs)
before it is trusted. Seeds built from Variant `hash([...])` (`BattleRules.gd:15444`, `AiHeroRules.gd:1303, 1433`)
stay computed in GDScript. The in-battle fallbacks for a `combat_seed` of 0 do need copies: `_resolved_damage_seed`
hashes the session id, and SpellRules' `_stable_percent` takes `posmod` of `hash(text_parts)`, so the Variant and Array
hash, `is_equal_approx` and `strip_edges` join the helpers with slices 02 and 07. Memo keys built from `hash()` only
need the same hit/miss behaviour.

**C++ determinism checklist.** `int64_t` everywhere (`long` is 32-bit on Windows); no locale-dependent functions
(`std::to_string(double)`, `printf("%f")`, `strtod`, `tolower`), ASCII-only lowering; no `unordered_*` iteration or
`std::hash` reaching any output; no behaviour depending on `DEBUG_ENABLED` (godot-cpp makes it public in
`template_debug`); `/fp:precise`, `-ffp-contract=off`, no fast-math, no `-march=native`; checked division; every
exception caught at the adapter. Numbers become text only in the Godot adapter, through godot-cpp `String::num`/`JSON`.

**Content.** A native content table is built once per content revision from the Dictionaries ContentService has already
parsed (no second JSON parser), keeping first-id-wins, file order and per-field presence (defaults differ per call
site). Genetic-algorithm overrides go through one in-memory override layer *in ContentService* that bumps the content
revision, so GDScript and native code never see two different contents in one match. Overrides are validated (no zero
hit points, reversed damage ranges and similar) at that boundary.

**State.** The session Dictionaries stay the save and UI format throughout. Native calls convert in, compute on a copy,
and write back only on success: known keys in place, new keys appended in GDScript's order, int/float types kept, array
identity kept (29 `is_same()` uses), unknown keys carried through. After each write-back a listed set of session-meta
caches is cleared (for example `_resolved_lookup_entry` assumes `resolved_encounters` only grows in place,
`OverworldRules.gd:3376-3398`). On failure the call returns `{ok: false, error}` and leaves the session untouched, so the
game can still save.

**Build and binaries.** The rules target compiles at `/O2 /Ob2` (`-O2` on GCC) in both flavours (batches load the
`template_debug` library, today `/Ob1`). The Linux debug `.so` is stripped; PDBs and Linux debug info are archived
outside git per build id. A repo script replaces the remote Linux build procedure that today exists only in the owner's
notes. Native slices run one at a time, because committed binaries conflict between branches. A new `.gdextension`
needs one `--headless --import` in every checkout; the runner and tuner check `ClassDB.class_exists` and fail loudly.
Release export excludes the rules debug library, `rules_selftest` and `battle_sim_cli` (`export_presets.cfg:10,34`),
and the release-candidate build (`tools/build_release_candidate.py`) builds and tests the rules library on both systems.

**Debugging.** An input-capture switch dumps each native call's input to a ring buffer written out on error or crash;
the input replays in `rules_selftest` or the CLI. ASan/UBSan builds of the CLI and self-test run on the Linux server.
Every match and tuner record carries the native build id, content hash and override hash, so results can be reproduced.

## 5. The standing parity check

1. **Corpus (committed):** the six seed setups with exact seed strings (large 4P one and two levels, large 4P with water
   on two levels, medium 3P with water, medium 3P on two levels, small 2P); the tuner's `standard` and `holdout` suites;
   about 200 battle payloads whose fixtures carry their own content rows (so balance edits to `units.json` do not break
   them); a scripted human-seat corpus that drives the public player APIs with turn playback on; and "save on day N, load,
   continue" for every phase (JSON load turns numbers into floats, which no AI match exercises).
2. **Digest:** a canonical serialization that keeps insertion order and int/float types, full float precision, timing
   fields left out (`tests/ai_versus_ai_match_report.gd:159, 171-173`), fixed map sections once on day 0, changing
   sections daily, plus the match record. Sorted output is only for reporting where it differs.
3. **`tools/rules_parity.py`:** finds the first differing day, replays to it with a full dump and reports the first
   differing path.
4. **When** (owner decisions 2026-10-21: Windows only until the owner's Linux pass, and fewer checks; AGENTS.md
   "Validation budget"): per slice on Windows, shadow mode on the six seeds while working, then before pushing one
   six-seed check of native mode against main (HEAD against change) and the core suite. The arena suites, the payload
   corpus, edge probes and the human-seat corpus run only for the formal G1 and before a phase merges. The compiler
   comparison (GCC 13.3, MinGW/Wine) and Linux runs wait for the Linux pass. `rules_selftest` (helper vectors and "two
   runs are equal") joins `tools/core_suite.py`.
5. **Behaviour changes** record a new baseline in the same commit, with owner approval.

## 6. Phases

The sizes in "Totals" are the proposal's unmeasured guesses, not a schedule. Phase 0, guessed at 6-12 agent-days,
took 2 h 20 min from the start to both slices on main, two sessions in parallel (3 h 20 min with the review fixes). The
first Phase 1 slice measures the porting rate; G1 and G3 re-plan from it, and only measured times are quoted. The
whole-game gain of porting a part is bounded by `1 / (1 - share of match CPU it removes)`, filled in from the Phase 0
profile. Large whole-game gains come only once the AI, day processing *and* the fixed cost per match are native.

### Phase 0: measure, decide, prove the pipeline

- **Cheap levers first, all GDScript, each proven with identical digests:**
  - Run batches on the release export template instead of the editor binary (batches use
    `Godot_v4.6.2-stable_win64_console.exe`, `tools/core_suite.py:35`; a batch preset that includes `tests/`). The rules
    have no debug-only branches, so games should be identical; measure the gain.
  - Delete code no match or player path reaches, and stop building end-of-day text nobody reads in headless matches,
    each only if digests stay identical.
- **Exclusive profile** on length-weighted games including a long (day 300) one: boot, content validation, map
  generation, opening/closing normalize, each AI phase, AI battles split into payload / fight loop / finalize, scenario
  evaluation, fog, the runner's bookkeeping, and the cost of converting one day's changing state.
- **Baselines:** are GDScript-only games identical on Windows and Linux today? Collect script errors from recent
  batches; an error on a path to be ported is fixed in GDScript first (C++ cannot imitate "abort the function, return a
  default").
- **Foundations:** the rules library layout, flags, server build script, symbol archive, worktree submodule fix.
- **Spike:** move one integer kernel end to end (edit, build on both systems, sync, digest, delete the GDScript loop).
  Chosen: the battle hex search (`BattleRules` `_reachable_empty_hexes`, `_walk_steps_to_target`,
  `_obstacle_field_stays_open`). Battle code is quiet and Phase 1 needs it anyway. It saves less per game than the BFS core
  of `AiHeroRules._search` (`:5508-5702`, up to 13-27 s), but AiHeroRules changes almost daily and would need an
  exemption from the quiet-code rule.

**Gate G0** (thresholds are proposals for the owner):

| Check | Go | Otherwise |
|---|---|---|
| Spike correctness | 0 shadow mismatches on every call in the six seeds; identical daily digests | name the first differing function, do not merge |
| Across compilers | Linux digests equal the Linux GDScript baseline; fixtures identical under MSVC, GCC, MinGW | fix flags; if GDScript itself differs between systems, identity becomes per system |
| Speed per call, boundary included | 20x or more | 5-20x: fix the interface first; under 5x: stop the C++ route |
| Battle share | AI battle work is 20% or more of match CPU, fight loop half of that | under 15%: do overworld phases first, or stop |
| Fixed cost per match | 10% of CPU or less | bring Phase 6's GDScript part forward |
| Developer loop | owner accepts the measured edit-to-local-match and edit-to-push times | owner decides |

### Phase 0 results (measure slice, 2026-10-20)

Measured at 329a8c490 on the owner's machine (16 cores, 32 threads), editor binary unless stated. No owner batch ran;
another project's Godot processes (1-3) ran during the profile, not during the editor/release timing.

- **Parity check** (`tools/rules_parity.py`, `HEROES_AI_MATCH_DIGEST` in the match runner). HEAD against a copy of
  HEAD: identical daily digests and records on all six seeds, 5.3 min at 6 at once. A copy with
  `ATTACK_BONUS_PER_POINT` 0.05 -> 0.0501 differs from day 2-5 per seed, first path `flags.ai_battle_log[3].power`,
  6.4 min including the replays. A run fails when it prints a SCRIPT ERROR line, and the match runner stops at once
  when the native rules library is not registered (`NativeRules.available()`); `check`, and `compare` of two `run`
  outputs, report a seed with a failed run as FAILED (exit 2). So two editor copies broken the same way never compare
  identical. A release export prints no SCRIPT ERROR lines (the GDScript VM reports them only in debug builds), so on
  an exported side only the runner's own failures count. `prepare` registers the prepared revision's own
  `.gdextension` files.
- **Windows and Linux** (the 4.6.2 Linux editor binary on the server): identical daily digests on all six seeds. The
  match records differ in the 15th significant digit of some floats (`power`, `defender_power`, `survivor_power`,
  `estimated_loss_share`) in five seeds (s2 is byte-identical): the record is written at JSON's default precision, the
  digest at full precision, so the numbers are equal and only their text differs. Compare across systems by digest.
- **Script errors:** none, in the six seeds on both systems and in the nine owner batch folders of 2026-10-17 to
  2026-10-20 (`ai_batch_20261017_*` to `ai_batch_20261020_r7_large4p_60`). Nothing on a path to be ported needs a
  GDScript fix first.
- **Release template.** The 4.6.2 export templates were not installed here (copied from the server into a scratch
  profile for this). Official release templates refuse a scene on the command line (`disable_path_overrides`), so the
  batch presets `Windows AI Batch` and `Linux AI Batch` (the release presets plus `tests/`, feature `ai_batch`) start
  the match runner through `application/run/main_scene.ai_batch` in `project.godot`. The first export takes 3 min,
  later ones 30-40 s, and writes a 4.7 GB pack.
  - Identical to the editor binary on all six seeds: every daily digest and the match record, compared with
    `rules_parity.py --portable`. That flag blanks the 9 kinds of field that hold where the map package was written
    (`res://maps` under the editor, `user://maps` in an export): its paths and the package signatures that include
    them, 68 values on day 1 inside the package keys (`map_package_ref`, `native_random_map_runtime_scenario_record`,
    the provenance and others); the rest of those keys, such as the runtime scenario record's objectives, player
    slots and starting resources, is compared. Nothing else differs on day 1, so the `template_release` native
    library builds the same maps. (Measured with the first version of the flag, which left those keys out whole;
    the 68 values it blanks now are the 68 that differed.)
  - Speed, plain runs of the five profile games below, editor and release side by side (10 at once, nothing else
    running): 2,221 s against 1,840 s, **1.21x** (1.20-1.21x per game), identical records. The six seeds during
    the check: 1.20-1.27x.
  - `tools/ai_match_batch.py --release` exports into `OUT/game`, plays on it and deletes it when the batch
    completes. Owner decision 2026-10-20: the editor binary stays the batch default, `--release` is opt-in. The Linux preset is not tested (the
    server checkout has no import cache to export from).
- **Profile.** Five full-length large 4P land games, the set-ups of owner round 7 (`ai_batch_20261020_r7_large4p_60`
  m011, m044, m053, m013, m054; one or two levels, normal or strong guards) replayed at 329a8c490, where they end on
  days 97, 135, 181, 222 and 320 (cap), 5 at once. Exclusive time per part: a wrapper on each listed function, so a
  part includes the unwrapped helpers it calls. Percent of each process's time (one core per game). The probes cost
  1.1%: the same games uninstrumented take 178, 193, 300, 549 and 965 s and end the same way.

  | Part | m011 (day 97) | m044 (day 135) | m053 (day 181) | m013 (day 222) | m054 (day 320) | all five |
  |---|---:|---:|---:|---:|---:|---:|
  | Boot (engine, autoloads) | 2.2 | 2.0 | 1.3 | 0.7 | 0.4 | 0.9 |
  | Content validation | 0.5 | 0.4 | 0.3 | 0.2 | 0.1 | 0.2 |
  | Map generation | 2.0 | 1.6 | 1.3 | 1.0 | 1.0 | 1.2 |
  | Session start, record write, exit | 1.4 | 1.0 | 0.7 | 0.6 | 0.3 | 0.6 |
  | Normalize, opening (skipped by the runner) | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
  | Normalize, closing | 1.9 | 2.3 | 1.7 | 2.6 | 1.5 | 1.9 |
  | Normalize, other callers | 2.6 | 2.5 | 2.0 | 2.7 | 1.7 | 2.1 |
  | Player fog normalize | 2.3 | 1.6 | 1.3 | 1.9 | 1.4 | 1.6 |
  | AI economy | 0.3 | 0.4 | 0.3 | 0.4 | 0.3 | 0.3 |
  | AI towns (hire, recruit, build) | 1.9 | 2.6 | 4.7 | 1.9 | 2.7 | 2.7 |
  | AI `_search` | 9.1 | 13.0 | 12.2 | 11.9 | 11.2 | 11.5 |
  | AI `_vetted_candidate` (choosing a target) | 14.8 | 18.5 | 20.5 | 18.3 | 16.3 | 17.4 |
  | AI `_strategic_candidate` | 3.0 | 4.9 | 5.7 | 3.5 | 3.6 | 3.9 |
  | AI `_gate_candidate` (two-level games only; 19.3% of their time) | 4.8 | 0.0 | 0.0 | 14.7 | 24.5 | 15.0 |
  | AI `_level_surface` | 2.3 | 2.2 | 1.8 | 2.4 | 1.6 | 1.9 |
  | AI fight checks, outside the battles | 4.2 | 2.0 | 2.1 | 2.4 | 1.2 | 1.9 |
  | AI hero day, rest (moves, actions) | 7.4 | 7.7 | 8.2 | 8.6 | 8.0 | 8.1 |
  | AI faction and enemy turn, rest | 0.6 | 0.8 | 1.3 | 1.0 | 1.2 | 1.1 |
  | AI enemy-state and roster normalize | 7.9 | 10.4 | 9.1 | 7.6 | 6.2 | 7.4 |
  | AI sight (fog) | 0.8 | 1.0 | 0.9 | 1.1 | 0.9 | 0.9 |
  | Battles: payload | 1.3 | 1.2 | 1.3 | 0.7 | 0.5 | 0.8 |
  | Battles: fight loop, rules | 10.9 | 8.8 | 7.0 | 5.1 | 4.6 | 5.9 |
  | Battles: fight loop, battle AI | 14.6 | 11.9 | 12.5 | 8.4 | 8.9 | 10.0 |
  | Battles: end of battle (finalize, read-back) | 0.9 | 0.7 | 0.7 | 0.5 | 0.4 | 0.5 |
  | Battles: apply the outcome to the session | 1.8 | 1.6 | 2.3 | 1.3 | 1.0 | 1.4 |
  | Scenario evaluation, elimination | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
  | End-of-day text | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 | 0.0 |
  | `end_turn`, rest | 0.3 | 0.4 | 0.3 | 0.4 | 0.3 | 0.3 |
  | Runner bookkeeping | 0.2 | 0.3 | 0.3 | 0.3 | 0.2 | 0.2 |
  | **Seconds** | 178 | 195 | 302 | 553 | 981 | 2,210 |

- **G0 numbers.**
  - Battle share: **18.6%** of match CPU over the five games (29.4, 24.2, 23.8, 15.9 and 15.4% per game, falling with
    length), between the Go (20%) and stop (15%) thresholds. 3,911 AI battles (1,938 free-fight checks, 988 previews,
    985 real), 105 ms each on average.
  - Fight loop: **85.6%** of the battle work (rules 5.9 and battle AI 10.0 points of match CPU).
  - Fixed cost per match: **2.8%** (1.8-6.0% per game), 10-17 s per game: boot 3.9 s, content validation 0.8 s, map
    generation 3.1-9.7 s, session start 1.3-1.7 s, record and exit 0.6-1.5 s. Under the 10% threshold.
  - The overworld AI is 72.3% (the AI rows, its sight included); day processing outside it (normalize, player fog,
    scenario, text, the rest of `end_turn`) is 6.0%. Dropping the end-of-day text would save under 0.1%.
- **JSON round trip of one day's changing state** (m054, every day, per top-level key: `JSON.stringify` at full
  precision, then `JSON.parse_string`; a key has changed when its text has). The whole session is 25-30 MB and takes
  1.75 s per day both ways, about 60 ms per MB. 5-7 of its 43 keys change on a day: `flags`, `encounters`,
  `enemy_states`, `towns` and `command_risk_forecast` daily, `resolved_encounters` and `resource_nodes` on 208 and
  139 days. They are 9.9 MB on the median day and cost **0.54 s** per day (0.27 each way), 173 s over the game,
  against 3.0 s of play per day (965 s uninstrumented). Most of `flags` never changes: a 3-6 MB copy of the map
  package record sits beside the growing AI battle log (0.8 MB by day 80 in mg-a). Without that copy, the changing
  state is about 3.6 MB on the median day and 7 MB on day 320. A deep copy (`duplicate(true)`) of the changed keys
  takes 0.10 s per day.

### Phase 0 results (toolchain and spike slice, 2026-10-20)

**Toolchain.** `src/gdextension/rules/` is its own CMake project. It builds the `aurelion_rules_core` static library
(std:: only), the `aurelion_rules` GDExtension (`rules.gdextension`, class `AurelionRules`, `get_build_info()`) and
`rules_selftest`, so rules commits never rebuild the map generator. Both flavours use `/O2 /Ob2 /fp:precise` or
`-O2 -ffp-contract=off`. Other pieces:
- `tools/build_native.py windows|linux` builds here with MSVC, or on the Linux server in a fresh `/tmp` directory at
  nice 19 (GCC 13.3, plus the self-test built with MinGW and run under Wine). Every file comes back sha256-checked, and
  PDBs and Linux debug files are archived per build id outside git (`heroes-like-native-symbols/`). The remote build
  has a deadline (`--remote-timeout`, 120 min) and says whether stopping it worked. Each poll ends within a minute
  (keep-alives and a timeout); a build that dies without an exit code, a removed directory or a host that does not
  answer for 2 minutes stops the script, and every failure names the remote directory.
- Exports leave out the debug libraries, PDBs, `rules_selftest`, `battle_sim_cli` and the rules sources.
- `tools/build_release_candidate.py` (and with it the workflow) builds and tests the release rules library on both
  systems. The release export copies it beside the binary, as it does the map library, so `tools/package_release.py`
  and the Linux and Windows installers carry both libraries (fixed after review: the first push left them expecting
  one). Checked by exporting both release presets: the payload check passes, the pack lists `rules.gdextension`, and
  the exported Windows game loads both libraries.
- Release packaging still stops before the archives, for a reason older than this slice: the export writes a 4.7 GB
  pack, above the 2 GB bound of `tools/compact_export_pck.py` and the 2 GiB archive-member bound of
  `package_release.py`. A headless boot of that export also fails some preloads (a town shader, result textures).
- `tools/core_suite.py` runs `rules_selftest` and fails when a checkout has not registered a `.gdextension`.
- Worktrees take godot-cpp from the main checkout when it is at the pinned commit.

**D3.** The Linux map debug library was rebuilt with the script and stripped: 50.8 MB → 4.2 MB.
- The rebuilt map self-test and CLI are byte-identical to the committed ones.
- The library's read-only strings differ only in embedded source paths.
- The six seeds play identically with the old and the new library on Linux.

**Determinism.** Two checks pass identically under MSVC 19.44 (VS 17.14), GCC 13.3 and MinGW 13 (Wine), with sweep digest
`c6f6ecf4989d40bd`:
- 587 golden vectors carrying their own inputs, picked from 42,019 distinct calls of the GDScript search. The calls
  come from the arena suites, the six seeds, the battle core tests and 70 hand-made obstacle boards.
- A 20,000-board sweep.

**Correctness (G0 row 1).** Shadow mode ran both searches on every call and compared the answers, int/float types
and key order included:

| Run | Calls compared | Mismatches |
|---|---|---|
| Battle AI arena `standard` suite (Windows) | 72,590 | 0 |
| Battle AI arena `holdout` suite (Windows) | 75,286 | 0 |
| Six parity seeds (Linux) | 91,466 | 0 |
| Six parity seeds (Windows) | 91,466 | 0 |

`tools/rules_parity.py` gives identical daily digests and match records for the final native build against main on all
six seeds, on Windows and on Linux (415 game days per system). The core suite passes on both systems.

**Speed per call (G0 row 3).** The captured calls were replayed through the GDScript loop and through the native call
(`PackedByteArray` in, `PackedInt32Array` out), 5 passes, idle machine. The last column comes from the shadow runs
of the six seeds (six games at once). All values are µs per call.

| Search | System | GDScript | Native, boundary included | Native + the game's Dictionaries | Whole function, six seeds (shadow) |
|---|---|---|---|---|---|
| `_reachable_empty_hexes` | Windows | 25.2 | 1.44 (17.5x) | 13.6 (1.85x) | 99.7 → 88.2 (1.13x) |
| | Linux | 23.6 | 1.28 (18x) | 11.5 (2.0x) | 91.7 → 79.6 (1.15x) |
| `_walk_steps_to_target` | Windows | 278.6 | 2.97 (94x) | 48.5 (5.7x) | 431.7 → 145.7 (3.0x) |
| | Linux | 246.8 | 2.73 (90x) | 32.3 (7.6x) | 408.5 → 124.5 (3.3x) |
| `_obstacle_field_stays_open` | Windows | 91.3 | 1.63 (56x) | 1.69 (54x) | 118.7 → 7.7 (15x) |
| | Linux | 94.6 | 1.81 (52x) | 1.85 (51x) | 123.5 → 9.4 (13x) |

What the numbers say:
- The search itself crosses the boundary cheaply: 17-94x.
- Turning its answer into the game's format costs more than the search: one Dictionary per cell, or `"q,r"` string
  keys.
- In a game, the GDScript that builds the battle's blocking map before each search costs the most. It stays GDScript
  in this spike and is shared by both columns.
- So the whole-function gain is 1.13x on Windows (1.15x on Linux) for the reachable search and 3.0x (3.3x) for
  the walk.

By the G0 table, the call through the boundary is a go for the walk and field checks and is in "fix the interface
first" for the reachable search. With the Dictionaries, the reachable search falls below 5x. That is the interface
shape Phase 1 removes: battle state and the open mask live natively, and callers read id/step arrays.

**Developer loop (G0 row 6).** Measured on this slice's own changes.
- **Edit to local match: about 25 s.** A one-line change in `battle_hex.cpp` takes 5.1 s for the incremental MSVC
  build of the debug flavour plus the self-test. The small 2P match that follows (seed s2, 33 days) takes 19.3 s. A
  GDScript change skips the 5 s.
- **Edit to push on both systems: about 18 min**, the sum of the measured steps on the critical path below. Commit,
  push and syncing the owner's checkout are not included. The steps:
  - Windows: both flavours 9 s, parity check 5.0 min, core suite 36 s.
  - Linux build on the server: 8-10 min (490-584 s). It runs in parallel with the Windows steps. The script builds in a
    fresh directory every time, so godot-cpp compiles twice; a persistent remote build tree would avoid that (not
    measured).
  - Linux checks: upload 35 s, the six seeds 5.5 min per side on its 4 cores, core suite 58 s. Comparing against main's
    digests from an earlier run saves the second side; running main too adds about 6 min (24 min in all).
- **For comparison:** a GDScript port change needs only the Windows parity check and core suite: 5.6 min.

### Gate G0 result (owner, 2026-10-20): passed

Row by row, after an independent review of both slices and its fixes (8b9adbdb6, bd8d2ddf0, 26f83c7d4,
7ccb4bf9b): spike correctness and compilers are Go; per call through the boundary the walk and field checks are Go and
the reachable search is in "fix the interface first", which Phase 1 does by keeping battle state native; the battle
share (18.6%, between the 15% and 20% thresholds) and the developer loop were accepted by the owner; fixed cost is Go.
Expected gain, from the profile: battles alone bound whole games at about 1.23x (1.18x on the longest games); Phase 2's
battle tool serves battle-level balance work; the large whole-game gain needs the overworld AI (72.3%), Phases 3-5.
Release packaging still stops on the 4.7 GB export pack, which predates the rules library.

### Phase 1: native battle engine, one merge

- **Scope:** the rules part of BattleRules, all of BattleAiRules, in-battle SpellRules, BattleAutoResolveRules,
  BattleFootprint, BattleDamageRules, TownBattleRules, the order-by-order API for battles the player fights, and the UI
  queries. Events become structured records turned into today's strings by a GDScript formatter (exactly, or excluded
  only with owner approval, because presentation events are saved state in player battles). About 6k lines of
  `describe_*` stay GDScript.
- **Boundary:** a `BattleEngine` class: `resolve(battle, caster_profiles, step_limit, stop_below)` replacing the loop in
  `BattleAutoResolveRules.gd:147`; `apply_player_order`, `cast_player_spell`, `move_active_stack_to_hex`,
  `drain_enemy_turns`; queries for legal hexes, approach cells, damage ranges, turn-order forecast and the Auto decision.
  The combat seed, obstacles and `_finalize_*` stay GDScript in this phase.
- **Order:** hex geometry, damage (the multiplier chain in exact order), movement, turn order and effects, attacks and
  the 22 abilities, cohesion and momentum, town defences, in-battle spells, enemy turns and battle AI, autoplay.
- **Checkpoint G1** after the hex, damage, movement and turn layers: the native loop, conversion included, is 10x or
  more faster on the tuner's corpus. Under 5x: fix the interface before porting the AI part.
  - Owner decision 2026-10-21: G1 is first measured on layer 1 as a projection.
    - The baseline is main at the branch point: per resolve, the time in `resolve_active_battle` without payload and
      finalize (T_gd), and the inclusive GDScript time of each outermost entry into the ported functions (T_gd_ported).
    - Those entries' inputs and results are captured and replayed in a native-only binary, in one State per resolve
      that is never cleared, timing only the calls and checking every result: r = T_gd_ported / T_nat_ported.
    - Conversion is timed at resolve start and end, at the pool size the replay reached: c = T_conv / T_gd.
    - The projection is S = 1 / (c + 1/r). 10x needs r of at least 1/(0.1 - c), about 12.5 at c = 0.02.
    - Under about 12.5, the C++ value layer is sped up before layer 2, without changing ported semantics.
    - Owner decision 2026-10-21, after slice 01b (r 10.4-10.7, S 9.1-9.9): layer 2 starts. The formal G1 after layer 4
      decides. On the arena the gap to 10x is within run-to-run noise; on the six seeds S is clearly under 10. c also
      leaves out the GDScript event formatter, which is unmeasured and probably under 1% of T_gd.
  - The formal G1 follows layer 4, with r per layer from the same replay harness. Per-call native-mode run times and
    single-function benchmarks are not G1: they time the per-call bridge, which the native loop does not have.
  - Formal G1, 2026-10-21 ("Formal G1 after layer 4"): S is 3.47 to 4.98, under 5x on both corpora. Layers 2 and 4
    are at r of about 4. The owner decides.
  - With GDScript's memos ported (2026-10-21, "G1 on `standard` with the memos", measured under sibling load): S is
    5.58 to 6.16 on `standard`, over 5x and under 10x. Layers 2 and 4 rose to r 7.38 and 10.75; layers 1 and 3 fell to
    6.22 and 5.18. The owner decides.
  - Owner decision 2026-10-21: slice 04c replaces the ported board-read cache with a native one (a state change
    counter, no whole-array hashing, no deep copy, none where recomputing is cheaper), re-measures G1 on `standard` with
    Phases 3 and 5 paused, then layer 5 starts whatever the number.
  - With the native board-read memo (2026-10-21, "G1 on `standard` after the native memo", no other load): S is
    7.89 to 9.45 on `standard`, over 5x and under 10x (r 10.79 needed). Layer 5 starts.
- **Identity:** per-action stream (order taken, RNG state and roll count, simulation-key digest) on the tuner suites,
  every AI battle in the six seeds, and JSON round-tripped payloads; shadow mode on every resolve; daily digests; the
  payload corpus across compilers; mid-battle save/load both ways between the native build and the tagged pre-merge
  build; every battle UI query compared in shadow mode on the human-seat corpus.
- **Exit:** all battles native, the GDScript fight loop and BattleAiRules deleted, every deleted name grepped across
  `tests/` and `tools/` (`core_script_compile_check` covers only `scripts/` and `scenes/`), the runner and tuner run,
  core suite on Windows (Linux in the owner's Linux pass), project.md ownership updated.
- **Gain:** large for battle-only work (the tuner); modest for whole games, bounded by the battle share from Phase 0.

### Phase 1 results (first slice: inventory, section 11, engine-exact helpers, 2026-10-20)

**Inventory.** A call counter on every function of the battle scripts, with a phase flag, ran over the arena's
`standard` and `holdout` suites (480 games each) and the six parity seeds (1,536 AI battle resolutions). It counted
every function run inside `resolve_active_battle`, with `_finalize_*` left out. Those functions number 565, with
10,278 lines, in the doc's order:

| Layer | Functions | Lines | Where |
|---|---:|---:|---|
| 1 hex geometry and board reads | 66 | 549 | BattleRules 41/329, BattleFootprint 5/94, BattleAiRules 20/126 |
| 2 damage chain and stat totals | 130 | 2,157 | BattleRules 77/1,283, BattleDamageRules 3/21, BattleAiRules 50/853 |
| 3 movement and targeting | 50 | 721 | BattleRules 42/641, BattleAiRules 8/80 |
| 4 turn order and effects | 26 | 391 | BattleRules |
| 5 attacks and the abilities | 49 | 1,380 | BattleRules 33/1,189, BattleAiRules 16/191 |
| 6 cohesion, momentum, field objectives | 16 | 552 | BattleRules 15/455, BattleAiRules 1/97 |
| 7 town defences | 8 | 43 | TownBattleRules 7/41, BattleRules 1/2 |
| 8 in-battle spells, commander payloads | 76 | 1,282 | SpellRules 57/769, BattleRules 19/513 |
| 9 enemy turns and battle AI | 115 | 2,371 | BattleAiRules 106/2,023, BattleRules 9/348 |
| 10 autoplay | 8 | 316 | BattleAutoResolveRules |
| presentation and events | 21 | 516 | BattleRules 20/477, BattleActionPlayback 1/39 |

- **AI copies.** BattleAiRules has its own copy of 95 helpers from layers 1-6 (1,347 lines), for example
  `_ability_damage_modifier` (156 lines) and `_faction_damage_modifier`. Each copy is ported on its own.
- **Called from the fight outside the battle scripts** (536 lines): ArtifactRules 20/328, HeroProgressionRules 10/105,
  ContentService 8/67, DifficultyRules 7/21, ScenarioSelectRules 2/8. The fight rebuilds the commander payloads from
  the hero: HeroProgressionRules `aggregate_bonuses` ran 591,940 times and ArtifactRules `aggregate_bonuses` 142,750
  times. Caster profiles exist to avoid this work. ContentService `get_content_by_id` ran 1.5M times and `get_unit`
  1.07M times.
- **Not run in fights.** BattleRules: finalize-only 71/1,582, outside the fight 67/1,917, never in this corpus
  267/6,001 (player-battle UI and `describe_*`). BattleAiRules: never 13/144. SpellRules: never 54/1,313, outside the
  fight 4/44. `normalize_battle_state` does not run inside the fight.
- **Callers outside the defining files** (name match, so a few hits are same-named helpers):
  `scenes/battle/BattleBoardView.gd` and `BattleShell.gd` (board reads, targeting, `perform_player_action`,
  `cast_player_spell`, `player_autoplay_decision`), `scenes/shared/SpellbookView.gd`, `AiHeroRules.gd`
  (`resolve_active_battle`, `attack_defense_multiplier`, `ensure_hero_spellbook`), five overworld scripts
  (`ensure_hero_spellbook`, `known_spells`, `mana_max_from_hero`), `tools/battle_ai_arena/worker.gd`, and about 100
  test files, most of them on layers 1, 4 and 8. Each slice's brief lists its own callers.

**Section 11 answers** (Godot 4.6.2-stable sources and the official binaries):
- **`randi_range(from, to)`** binds C `int`: both bounds are cut to 32 bits, equal bounds return `from`, and the
  result is a 32-bit int. Otherwise it returns `pcg32_boundedrand_r(max - min + 1) + min`: a rejection loop below
  `-bound % bound`, one or more draws. A span of 2^32 takes one raw draw.
- **`randf()`** returns `real_t`, a 32-bit float in the official builds, which GDScript widens. It takes two draws, or
  one when the first is 0: `ldexp((float)(second | 0x80000001), -32 - clz(first))`. The obstacle test
  `rng.randf() < 0.4` compares that widened float with the double 0.4.
- **`String.hash()`** is djb2 over the UTF-32 code points, stopping at a NUL.
- **`int(String)`** is `String::to_int`: it reads the digits before the first `.` and skips every other character. A
  `-` before the first non-zero digit flips the sign, so `"a-1b2"` gives -12. A 19-digit value past the int64 range
  wraps silently; from the 20th digit it prints an error and returns INT64_MAX or INT64_MIN.
- **`is_valid_int`** accepts one optional sign, never alone, followed by digits only.
- **`sort_custom`** runs the `SortArray` introsort with validation on: threshold 16, median of three, depth
  2·log2(n), heap-sort fallback, final insertion sort, and a loop stop on an inconsistent comparator. It is not
  stable, so a port must reproduce the algorithm to keep the tie order. The battle code has two call sites
  (`BattleRules.gd:11084-11085`). `_sorted_turn_order` is its own selection sort.
- **JSON** reads every number as a float with Godot's `built_in_strtod`, a Tcl-derived parser that is not correctly
  rounded (it cuts the mantissa at 18 digits and scales by powers of ten in doubles). GDScript float literals go
  through the same parser:
  - All 94 distinct float literals in the battle scripts (1,018 uses) parse to the correctly rounded double, so C++
    literals equal them.
  - The literal `-0.0` folds to +0.0 in GDScript. The battle code has none.
  - Native code never parses text.
- **`round`** is `std::round`, and the two official builds disagree on one input pair. The Windows build (MinGW) gives
  ±1 for ±0.49999999999999994, like `trunc(x + copysign(0.5, x))`; the Linux build (glibc) gives ±0. The helper copies
  each platform's answer, so GDScript and native agree on both, and differ between the platforms exactly as GDScript
  does.
- **Other number functions:**
  - `floor` and `ceil` are exact.
  - `posmod` is `%` with a sign fix; a zero divisor gives 0 and prints an error.
  - `snappedf` is `floor(x / step + 0.5) * step`.
  - `int(float)` truncates; NaN and out-of-range values give INT64_MIN, as x86-64 does.
  - The untyped `max`/`min`/`clamp` return the winning argument as it came, int or float. The first argument wins
    ties, and an int meets a float as a double.
  - `maxf`/`minf`/`clampf`/`maxi`/... are the engine's MAX/MIN/CLAMP templates: the second argument wins ties.
    With `lo > hi`, `clampf` returns `lo` when `x < lo` and `hi` otherwise, where `clamp` always returns `hi`.
  - `str(int)` and `"%d" % x` are the same digits (a float is truncated first).
  - Floats become text only through `String::num` in the adapter.
- **C runtime.** The official Windows binary is MinGW-w64 GCC (GNU ld 2.45) on `msvcrt.dll`, which supplies `acos`,
  `asin`, `atan`, `ceil`, `cosh`, `log10`, `sinh`, `tan`, `tanh`, `_hypot` and `_nextafter`. The battle code calls no
  transcendental function. Inside the engine, float-to-text (`log10` plus `snprintf`) is the only path that depends on
  the C runtime.
- **Caster profiles.** Over 480 arena games (7,240 loop steps), mana aside:
  - `player_commander_state`, `player_hero` and `player_commander_source` never change during a battle.
  - `enemy_hero` and `enemy_hero_payload` are replaced after each enemy spell (`_cast_enemy_spell`,
    `BattleRules.gd:7458`) by the AI's normalized payload. It adds hero-template keys such as `command.initiative`,
    seen in 126 steps.
  - A profile built once per battle must therefore be rebuilt after an enemy cast, or built from the replaced payload.
- **Presentation keys.** The six seeds were played with `_append_presentation_event`, `_mark_stack_animation_event`,
  `_append_animation_event_record` and `_record_event` turned into no-ops. All daily digests and match records came
  out identical, so nothing in AI battles reads the presentation events, animation states or recent events. The
  terminal message is read: the AI battle log stores `resolution.message`.
- **Board-read cache.** Its keys hash the stacks with the Variant `hash()` (`BattleRules.gd:1610`). It is a pure cache
  with a switch to turn it off, so native code needs no copy of it.

**Engine-exact helpers** (`src/gdextension/rules/{core,include/aurelion_rules}/compat/`):
- **What they are.** `GodotPcg` (seed/state, `randi`, `randi_range`, `randf`), `itos`, `to_int`, `is_valid_int`,
  `string_hash`, `sha256_text`, `posmod`, int division, `int(float)`, `round`/`floor`/`ceil`, `snappedf`, the
  Variant-typed `max`/`min`/`clamp` on `Number`, the typed `maxf`/`clampi`/..., and `sort_custom`.
- **How they are fuzzed.** `tools/rules_compat/capture_vectors.gd` runs each helper on 2^20 inputs in the engine:
  integer edge modes, random bit patterns, NaN, ±0, infinities, mixed int/float ties, and 0-40 element sorts full of
  ties. It prints one SHA-256 per helper over the answers. `rules_selftest` draws the same inputs
  (`selftest/compat_fuzz.cpp`) and checks every digest (`selftest/compat_digests.inc`).
- **Results.** All ten digests are identical between the official Windows and Linux engines and this C++, except
  `float_round`, which has one digest per platform (see `round` above).

**Native battle state** (`battle_state.{hpp,cpp}`, `gdextension/battle_state_bridge.cpp`; branch commits
52181b480 and 1e24480be):
- **What it is.** Tagged values over pooled arrays and dictionaries, with interned strings. Loading keeps key order,
  int/float, String/StringName, typed containers, read-only flags and shared references. Storing writes a copy, or
  writes in place: known keys keep their slot, new keys are appended in GDScript's order, and the original arrays and
  dictionaries are reused, so `is_same()` holds.
- **How it is proven.** A probe ran before every AI battle step of the six parity seeds and both arena suites. It
  loaded the battle state, stored it as a copy and in place, and compared both with the original by `var_to_bytes`.
  The same ran on every payload after a JSON round trip, and on a mutated state written over the original. The probe
  kept its in-place store as the live state, so the battles went on from the native copy.
- **Results.** 0 failures over 2,496 battles: 25,805 steps, 8,934 JSON payloads and 25,751 overwrites with a mutated
  state. Over all in-place stores, 29,312 dictionaries were rebuilt (cleared and refilled, because their new key order
  could not be reached by overwriting and appending). The six seeds' daily digests and match records stayed identical. The battle state
  holds no shared containers and no StringNames, and only Dictionary, Array, String, int, float and bool.
- **Cost.** On the six seeds a battle state holds about 3,000 values and 200 containers. Loading takes 0.70 ms,
  storing a copy 0.33 ms and storing in place 0.62 ms, against 9.0 ms for a GDScript step. Converting on every step
  would cap the speed-up near 7x, under G1's 10x. So the native engine converts once per resolve: about 1.3 ms against
  a battle's ~65 ms, which caps it near 50x.

**Layer 1: hex geometry and board reads** (`core/port/`, `gdextension/battle_port_bridge.cpp`,
`scripts/core/BattleEngine.gd`, `tools/native_battle_switch.py`; branch commits dda9a7d04 and a6bbe2fec):
- **What it is.** 56 of the layer's 66 functions (417 of its 549 lines) are in C++ under their GDScript names, with
  GDScript's semantics: key order, int/float typing and the order of operations. Where GDScript stops with an error the
  port throws; shadow mode cannot confirm those cases, because GDScript returns null there and a native error counts as
  a mismatch. 54 have a switch, set per process by `HEROES_NATIVE_BATTLE`: `gdscript` (the default) runs GDScript, `native`
  the port, and `shadow` runs GDScript and compares every call with the port, including types, key order, read-only
  flags and container identity. For the two functions that write into their arguments it also compares the arguments
  afterwards, by contents only (types and key order, not identity or read-only flags).
  `_hex_open_mask` and `_walk_open_mask` became internals of the two native searches. `tools/native_battle_switch.py`
  writes the switches from the port registry and keeps each GDScript body as `<name>__gd`. A native call loads its
  arguments lazily, so it converts only what the port reads. `BattleEngine.gd` holds the mode and the native and
  shadow calls; `resolve` and the order-by-order API join it when the loop is native (slice 10).
- **Not ported.** The board-read memo (`begin_board_read_scope`, `end_board_read_scope`, `_board_read_cache_get`,
  `_board_read_cache_key`), the memo inside BattleAiRules' `_alive_stacks_for_side`, and the `_stack_term_memo` lookups
  in BattleAiRules' `_stack_contact_band` and `_stack_is_engaged`, which the port computes directly. Shadow mode ran with
  these memos live on the GDScript side, so 0 mismatches show they change no answer while the scope contract holds:
  memo keys leave out inputs that the recomputation reads.
- **Moved to other slices.** BattleRules `_stack_is_isolated` and `_stack_is_hex_isolated` call `_allied_melee_count`
  (layer 2): slice 02. Their BattleAiRules copies read the scoring memo: slice 08. `_ensure_battle_hex_state` (with
  `_default_stack_hex`, `_first_open_body_near`, `_hex_board_descriptor`) and `_set_stack_hex` (with
  `_presentation_walk_path`): slice 03, and `_set_stack_hex`'s ActionPlayback capture with slice 10's events.
- **Results, shadow mode:** 0 mismatches and 0 errors.
  - Six seeds: 23,882,826 checks over 52 functions.
  - Arena: 19,171,698 checks on `standard` and 20,257,744 on `holdout`.
  - An edge probe: 1,211,139 checks over all 54 functions, on inputs the corpora never reach. These are off-board and
    negative hexes, float, string and bool coordinates, missing keys, `Vector2i` cells, and stacks without a side or
    a hex. It is the only run that reaches `_hex_distance` and `_offset_to_cube`.
- **Results, native mode:** 0 errors, with 11,432,825 native calls on the six seeds and 9,020,200 and 9,461,204 on the
  two arena suites. In both modes every daily digest and match record of the six seeds and all 960 arena game records
  are identical to GDScript. On Linux, with the official 4.6.2 binary, the six-seed check of shadow against native
  mode was identical: 23,882,826 shadow checks, 0 mismatches, the same count as on Windows. The core suite passed on
  both platforms.
- **Cost.** Shadow mode takes 25 s on seed s2, against 20 s for GDScript.
- **Porting rate.** About one hour of wall time, 19:07-20:07Z, shared with committing the battle state. It produced
  417 GDScript lines as 896 C++ lines, plus parts every layer reuses:
  - the GDScript runtime (`port/gd`, 372 lines);
  - the argument bridge (653);
  - the registry (150);
  - `BattleEngine.gd` (96);
  - the switch generator (180).

  The first build compiled and the first shadow run had 0 mismatches: 0 mismatches per 1,000 lines. Layer 1 has no
  RNG and no damage arithmetic, so its rate is not a forecast for layer 2.

**G1 projected on layer 1** (slice 01b, owner decision 2026-10-21; `tools/battle_port_g1/`,
`src/gdextension/rules/g1/battle_port_replay.cpp`; branch commits d3008d02f and a78100003):
- **How it is measured.** Windows, Ryzen 9 5950X, the official Godot 4.6.2-stable editor binary headless, the rules
  library's template_debug build (MSVC `/O2`). Every timed part ran 6 at once, GDScript and native alike, with no
  other Godot process. Each GDScript run started only when none ran, and the check before the next run found none;
  the one run after which a foreign batch was found was redone. The replay and the conversion were sampled every
  20 s and saw none.
  - Baseline: main at the branch point (d1ec73410), each corpus played three times. The plain run gives T_gd, the time
    in `resolve_active_battle` without `_finalize_*` and `_resolve_result`. A clock on every outermost entry into the
    54 switched functions gives T_gd_ported, less 0.034 µs of clock cost per entry. The third run captures the
    entries of the resolves whose start-battle digest is a multiple of 7 (11 on the six seeds): arguments, results
    and written arguments as `var_to_bytes`.
  - The switched functions take 33.4% of T_gd on `standard` (480 resolves), 33.8% on `holdout` (480) and 31.6% on the
    six seeds (1,536).
  - `battle_port_replay`, native only, replays each captured resolve (82, 84 and 157) in two passes, warm then cold,
    each in its own State and three rounds. The State is cleared at the start of a round as `StateBridge::load`
    clears it, and never between calls. In every round, every result and every written argument must encode to
    GDScript's bytes: 0 mismatches. r uses the cold pass: all arguments decoded first, then every call under one
    clock.
  - c is `StateBridge::load` of the start battle plus `store_in_place` of the end battle, in the branch library, the
    median of 5 rounds on a new State each. The State also holds as many nodes as the replay's calls made; the
    replay's decoded argument copies are left out, since an engine's calls read the State in place.
- **The State the first call finds** decides the result, so three cases are reported:
  - **previous resolve:** the State last held another resolve of the corpus, run untimed first: the capture before
    it in file order (by start-battle digest, wrapping) that starts from a different battle. (The arena plays each
    battle twice, and with the same AI on both sides the two games are identical, so the other game of the pair is
    skipped.) An engine that keeps its State between resolves sees this, so it is the headline.
  - **new State:** a State never used before.
  - **same resolve again:** the median of the three rounds; the last two find the State that held the same resolve,
    a best case.

  "Before" is the value layer of slice 01. It freed every node when cleared, so it compares with "new State".

| Corpus | Before: r / S | Previous resolve: r / S | New State: r / S | Same resolve again: r / S | c | r for 10x |
|---|---:|---:|---:|---:|---:|---:|
| standard | 5.65 / 5.44 | 10.44 / 9.75 | 10.36 / 9.68 | 11.82 / 10.94 | 0.0068 | 10.73 |
| holdout | 5.65 / 5.44 | 10.65 / 9.88 | 10.33 / 9.62 | 11.79 / 10.86 | 0.0072 | 10.78 |
| six seeds | 5.59 / 5.15 | 10.66 / 9.12 | 10.34 / 8.88 | 12.65 / 10.54 | 0.0159 | 11.89 |

- **Warm pass.** Each entry's arguments are decoded just before its call, so the call finds its battle in cache, as a
  native loop finds the battle it keeps updating. There r is 12.20, 13.07 and 12.75 in the previous-resolve case,
  and 14.2-16.2 over two runs for the same resolve again.
- **Per function** (warm, same resolve again, `standard`; the share is of the ported GDScript time):

  | Function | Share | r |
  |---|---:|---:|
  | BattleFootprint `distance` | 28.5% | 18.7 |
  | `_reachable_empty_hexes` | 21.5% | 12.4 |
  | BattleRules `_alive_stacks_for_side` | 7.5% | 14.5 |
  | BattleAiRules `_alive_stacks_for_side` | 5.1% | 7.1 |
  | `_walk_steps_to_target` | 3.8% | 11.7 |

  Beside them, the Phase 0 typed kernels (the search alone, on a packed board) reached 17.5x for the reachable search
  and 94x for the walk. The gap to them is the Dictionary reads that build those boards: in a sampling profile of the
  replay, key lookups take about 62% of native time.
- **What changed in the value layer**, semantics kept:
  - `ValueList` keeps four values inline.
  - A Dictionary scans its string keys until its lookups add up to 8 scans per key. With more than 8 and fewer than
    65,535 keys it then builds a 16-bit slot table, at most half full. An append updates it; it is dropped when an
    append would fill it past half, on any other change, and at 65,535 keys.
  - Nodes live in blocks of 256 that are reset and reused, so a clear is O(1) and a resolve reuses the last
    resolve's buffers.
  - The 99 board-cell keys (`"q,r"`) sit at fixed atoms, so a cell key is arithmetic. `"obstacle:" + id` is cached.
  - The hot accessors are inline.
  - Not done: node reclamation, which does not change call speed, and a native board-read memo. The memo needs the
    read-scope boundaries, which captures do not hold, so it waits for the native loop (slice 10).
- **What the figures leave out.**
  - Each GDScript time is one run. Each replay figure is the first or the median of three rounds, and each
    conversion the median of five. Two native runs of the same build differ by up to 6% in the cold pass (in the
    new-State run the same-resolve median was 12.29, 12.52 and 13.10) and by up to 15% in the warm pass (14.18 and
    16.24 on `holdout`).
  - The cold pass runs in the same process after the warm pass of the same resolve, so its first round finds the code
    and the allocator warm, which favours native.
  - Besides the 8,698,084 entries on `standard`, 39,562 calls reached a wrapper while an entry was open. They are not
    counted as entries, but their wrapper (the depth check, a re-entry count and one more call) runs inside the
    outer entry's clock, so T_gd_ported holds a little wrapper time that a real GDScript run does not.
  - c is timed on a new State, so a State kept between resolves converts no slower.
- **Checks after the change:** the layer 1 checks again on the final build. Shadow mode had 0 mismatches and 0
  errors: 23,882,826 checks on the six seeds, 19,171,698 on `standard` and 20,257,744 on `holdout`. Native mode had
  0 errors: 11,432,825, 9,020,200 and 9,461,204 calls. Every daily digest and match record and all 960 arena games
  are identical to GDScript. The core suite passed on Windows. On Linux, with the official 4.6.2 binary, the core
  suite passed and the six-seed check of shadow against native mode was identical: 23,882,826 shadow checks, 0
  mismatches.
- **Harness.** The formal G1 after layer 4 reruns `tools/battle_port_g1/g1.py`; its docstring lists the steps. Captures
  are not kept (2.8 GB for `holdout`): `g1.py prepare capture` and `g1.py run` make them again.
- **Result.** In the previous-resolve case r is 10.44 on `standard`, 10.65 on `holdout` and 10.66 on the six seeds,
  and S is 9.75, 9.88 and 9.12. A State kept from another resolve is barely faster than a new one (r 10.33-10.36). S
  stays under 10 in both engine cases, and on the arena r is just under the 10.73-10.78 that 10x needs. The seeds'
  conversion share is twice the arena's (c = 0.016), so they need r = 11.89. In the cold pass r stays under the
  owner's 12.5 in both engine cases; only the same-resolve best case reaches it (12.65 on the six seeds, and 12.52
  and 13.10 on `holdout` and the seeds in the second run). So slice 01b stops here and reports to the owner before
  layer 2.

**Layer 2** (slice 02, 2026-10-21; branch commits 35482b17e runtime, 3609b2d11 port, b3310bc15 Windows binaries):
- **Ported:** 137 functions, 1,923 GDScript lines.
  - BattleRules 98/1,524: the damage stream (the damage RNG state with its integrity and canonical checks,
    `_calculate_damage`, `_damage_for_roll`), damage application and restore, the event log, the multiplier chain in
    exact order, the stat totals with their contextual, cohesion, momentum, faction and field-objective bonuses, and the
    ability, tag, trait and side-count reads they use. `_stack_is_isolated` and `_stack_is_hex_isolated` came from
    layer 1.
  - BattleDamageRules 3/25 and TownBattleRules 4/18.
  - From slice 04: SpellRules' effect reads and their normalizers, 10/122.
  - From slice 07, the commander payload: BattleAiRules' payload merge 8/112, HeroProgressionRules 8/101,
    DifficultyRules 6/21, with ScenarioSelectRules' two functions inlined.
- **Not ported:** `DifficultyRules._scenario_select_rules`, which returns a script. The memos `_hero_payload_cache`
  and HeroProgressionRules' specialty catalog index are not ported either; the native calls compute without them.
  Slice 04b ported them ("Layers 1 to 4 with GDScript's memos").
- **Moved:** `_apply_ranged_damage_return` to slice 06, since it calls the damage pressure and the presentation events.
  The native unit and ability tables go to slice 10.
  - Here a native call reads each content row once per call through ContentService's index.
  - A table kept across calls by content revision would go stale wherever code edits ContentService's cache in place
    without a revision bump.
- **Runtime:** the slice 01 review fixes, the Variant hash, the shadow copy for writing functions, `KeyList::push_back`
  and `State::set` copying first, and const `State::array()`/`dict()` views. Shadow mismatches now print SCRIPT ERROR.
  On main since e5006e81b (Windows binaries d7cd33045); the branch merged it in 4c296c997, after which shadow was
  unchanged and native mode identical to main.
- **Found, not fixed:** in `HeroProgressionRules._specialty_catalog`, `_catalog_source` is set before the index is
  built. After a bad specialty id fails `String()` in the first build, later calls get a partial index with no error.
  This only happens with bad content.
- **Checks:**
  - Shadow on the six seeds: 0 mismatches and 0 native errors in 52,861,434 checks over 187 functions. Not reached:
    `_brace_has_held_objective` and `_side_has_linked_unit`, whose abilities no unit on the seeds has.
  - Native mode against main: every daily digest (415) and match record of the six seeds is identical.
  - Core suite: 17/17 on Windows.
  - The Linux libraries in `bin/` are not rebuilt.

**Layers 3 and 4** (slices 03 and 04, 2026-10-21; branch commits e4a7cc61e port, 4c5a72917 Windows binaries):
- **Ported together,** since their functions call each other: 90 functions, 1,614 GDScript lines.
  - Slice 03, movement and targeting, 48/758. BattleRules 47/755: board setup (hex state, deployment, formation rows,
    the stack hex and its walk path), movement points and rooting, legal destinations, the melee approach, the advance
    rules, attack legality and reach, and the legal and selected targets with their legality, click intent,
    continuity and closing context. TownBattleRules `movement_penalty` 1/3.
  - Slice 04, turn order and effects, 42/856: turn order and round preparation 23/374, the readiness writs and foundry
    repair 3/130, pressure shifts, cohesion, momentum and field-objective round effects 4/109, `heal_round` 1/18,
    SpellRules' status immunity and effect normalize and purge 4/20, `_weakest_stack_by_cohesion` and `_role` 2/30,
    and the presentation and animation event records 5/175.
- **Not ported:** the board-read memos and the presentation queue memo; the native calls take the uncached path.
  Slice 04b ported them.
  `_apply_melee_approach` moves to slice 06 and `_apply_auto_advance_movement` to slice 09. `_complete_action`,
  `_evaluate_outcome` and `resolve_if_battle_ready` stay GDScript until slice 10. BattleAiRules' 8 copies of layer 3
  functions go to slice 08.
- **Runtime:** String formatting, `capitalize`, `replace`, `trim_prefix`, `slice` and `sort_custom` in the gd layer. On
  main since 9e84fff83 (Windows binaries db3c59b47); the branch merged it in c0205a359.
- **Found, not fixed:** no GDScript bugs. Ported as they are: `advance_turn` runs `_assign_default_target` twice when
  the round wraps, `_prepare_round` adds an empty `stacks` when the key is missing, and the last `selected` fallback
  of `selected_target_closing_context` cannot be reached.
- **Checks:**
  - Shadow on the six seeds: 0 mismatches and 0 native errors in 55,236,025 checks over 275 functions, 2,374,591 of
    them in the 90 new ones. Not reached: `_presentation_walk_path`, which needs a playback capture, and
    `_player_input_locked_summary`.
  - Native mode against main: every daily digest (415) and match record of the six seeds is identical.
  - Core suite: 17/17 on Windows.
  - The Linux libraries in `bin/` are not rebuilt.

**Formal G1 after layer 4** (2026-10-21; `tools/battle_port_g1/`, harness commit e4350640a on the branch):
- **How it is measured:** as in slice 01b, over the 281 functions of layers 1 to 4.
  - Same machine, binaries and job count. The baseline is main at the branch point (db3c59b47).
  - Captures: 82 of the 480 resolves on `standard` and 157 of the 1,536 on the six seeds.
  - Captures now hold the session and RandomNumberGenerators as objects. The replay keeps the unit, hero, faction and
    spell rows the port reads in its State.
  - A sibling session's Godot runs overlapped two timed GDScript runs, and both were redone. No foreign Godot ran during
    the timed runs used, the replays or the conversion.
  - Every round of every replay: 0 mismatches and 0 errors.
- **Share of T_gd:** the ported functions take 65.1% of T_gd on `standard` and 64.8% on the six seeds. At layer 1 it was
  33.4% and 31.6%.

| Corpus | Previous resolve: r / S | New State: r / S | Same resolve again: r / S | c | r for 10x | r for 5x |
|---|---:|---:|---:|---:|---:|---:|
| standard | 3.76 / 3.61 | 3.61 / 3.47 | 5.09 / 4.82 | 0.0107 | 11.2 | 5.28 |
| six seeds | 3.95 / 3.62 | 3.81 / 3.50 | 5.45 / 4.84 | 0.0230 | 12.99 | 5.65 |

  The new-State replay's median rounds, a second run of the same-resolve case, gave 5.23 / 4.96 and 5.62 / 4.98.
- **r per layer** (warm pass, same resolve again). Each outermost entry counts in its own layer, with its calls into
  other layers. The share is of the ported GDScript time.

  | Layer | standard: share / r | six seeds: share / r |
  |---|---:|---:|
  | 1, hex | 15.0% / 11.0 | 13.6% / 10.8 |
  | 2, damage and stat totals | 22.3% / 3.95 | 25.1% / 4.29 |
  | 3, movement and targeting | 25.8% / 12.6 | 22.6% / 13.1 |
  | 4, turn order and effects | 36.8% / 3.99 | 38.7% / 4.50 |

- **Where native is slow** (warm, `standard`):
  - Two functions are slower than GDScript: `_append_presentation_event` (r 0.69, 0.26 s native) and `_hero_has_trait`
    (r 0.84, 0.085 s). In both, GDScript keeps a static memo that the port leaves out:
    - With `_presentation_queue_written`, GDScript normalizes only the last queue entry. The port normalizes the whole
      queue on every append.
    - `_hero_payload_cache` returns the side's payload. The port rebuilds it and deep-copies it on every call.
  - Next, by native time: `_resolve_wait` (r 3.93, 0.28 s), `_calculate_damage` (2.61, 0.25 s), `_apply_stack_effect`
    (3.94), `_stack_cohesion_total` (3.79) and `_stack_momentum_total` (2.74). Each calls one or both of those paths.
    How much of their time those paths take is not measured.
  - The calls made 4,161,058 Dictionaries and 2,085,064 Arrays over 908,907 entries.
- **Result:** S is 3.47 to 4.98 in every case, under 5x on both corpora.
  - The shortfall is in r. Conversion takes c = 0.011 and 0.023.
  - Layers 1 and 3 stay above 10. Layers 2 and 4 are at about 4.
  - By the checkpoint, the interface is fixed before the AI part. By D8, the branch is dropped if G1 stays under 5x
    after that fix. The owner decides.

**Layers 1 to 4 with GDScript's memos** (slice 04b, 2026-10-21; owner: port every GDScript memo the ported layers rely
on, then re-measure G1 on `standard` only; runtime on main b8c32e69d, merged into the branch in fb9b1ef0f; branch
commits 32e428314 port, ca2f2b058 harness, f4407189e Windows binaries):
- **Ported:** every static memo that the GDScript of layers 1 to 4 reads. The port keeps them in GDScript's own static
  vars through the host, with GDScript's lifetime and invalidation:
  - BattleRules' board-read memo: the scope's cache, battle and depth, the validation switch and the hit count. Legal
    destinations, the melee approach, attack legality, the attack target ids, the walk steps and the walk mask read and
    fill it under GDScript's keys.
  - `_hero_payload_cache`: a side's payload is reused while its payload and commander sources are equal.
  - `_presentation_queue_written`: an append to the queue it last wrote normalizes only the last event.
  - BattleAiRules' scoring scope: the living stacks per side and the stack terms (contact band, engaged).
  - HeroProgressionRules' specialty catalog index.
  - Not ported: `_hex_id_by_key`, a constant table; native uses the State's fixed atoms. GDScript callers open and
    close the scopes, so their begin and end stay GDScript.
- **Registry:** the 55 ported functions that reach a memo count as writing, and the battle switch runs them validating.
  In shadow mode the native call runs first on the arguments themselves and writes nothing back. The check then
  compares the result, the containers it loaded, the static vars it read or set and the RandomNumberGenerators it used
  with what GDScript left.
  - A function marked as only reading cannot set a static var, so one that reaches a memo fails in native mode when
    the memo is cold. Shadow mode does not see this when GDScript warmed the memo first.
- **Runtime:** the validating check accepts a RandomNumberGenerator that both calls made, when its seed and state match.
- **Harness:** a capture's writing entry holds the memos as they were before it and their signature after it. The
  replay hands each call its entry's memos and refuses them to an entry the registry marks as only reading.
- **Found, not fixed:** the arena plays each side's BattleAiRules as its own compiled copy behind a router at the
  script's path, so the scoring memos live in the copies. In arena native or shadow mode the port would read them from
  the router, which has none: `_alive_stacks_for_side`, `_stack_contact_band`, `_stack_contact_band_on`,
  `_stack_engaged_on` and `_stack_is_engaged` would fail. The interface has to say whose memos a call reads before any
  arena native run. The game, the six seeds and the G1 replay are not affected.
  - No ported function reads the weights. None of the 26 ported BattleAiRules functions calls `_w` or reads
    `_weights`, and the port code reads no weights. The arena bakes each variant's weights into its own compiled copy
    (`arena.py` rewrites `static var _weights`).
  - The router declares only `_arena_policies`, `_arena_default` and `_arena_calls`, so a read of any other
    BattleAiRules static by path gets Nil. Every scoring memo read starts at the scope depth, whose `int` conversion
    stops on Nil with an error. A game silently played with the wrong weights cannot happen today. Slices 08 and 09
    port `_w`'s users and must keep that read strict.
  - Options, needed before the merge's arena check. (a) The port asks the router which variant plays the acting side
    and reads that copy's statics; this ties the native engine to an arena tool and to the GDScript copies it replaces.
    (b) Native keeps its own memos and takes each side's weights as data; this fits Phase 2's battle tool but cannot
    play `git:<rev>` code variants. (c) The pre-merge parity check runs the arena without the router, one plain
    BattleAiRules on both sides.
  - Recommended: (c) for the merge check, then (b) in Phase 2. Parity compares native with GDScript on the same code,
    so A/B variants add nothing to it, and (c) needs only a worker switch in the arena tools, with no change to frozen
    battle code or to the port. Weight variants at native speed come with Phase 2's battle tool; code variants stay a
    GDScript-mode tool.
- **Checks:**
  - Shadow on the six seeds: 0 mismatches and 0 errors in 55,236,025 checks over 275 of the 281 functions, 6,648,709
    of them in the 55 memo users, all reached. Not reached: `_brace_has_held_objective`, `_hex_distance`,
    `_offset_to_cube`, `_player_input_locked_summary`, `_presentation_walk_path` and `_side_has_linked_unit`.
  - Native mode against main: every daily digest (415) and match record of the six seeds is identical.
  - Core suite: 17/17 on Windows.
  - The Linux libraries in `bin/` are not rebuilt.

**G1 on `standard` with the memos** (2026-10-21, 21:10 to 21:18):
- **How it is measured:** as in "Formal G1 after layer 4". 82 of the 480 resolves are captured, with 6 jobs. The
  baseline is main at b8c32e69d; the battle GDScript is unchanged since the branch point.
  - Load: sibling sessions' AI match runs (4 Godot commands, 6 to 8 game processes) ran during every timed part. After
    more than 10 minutes of waiting, the timed parts ran anyway, as the owner allowed. Every number below was measured
    under that load, on both sides.
  - Every round of both replays: 0 mismatches and 0 errors.
- **Share of T_gd:** the ported functions take 61.8% of T_gd (88.35 s over 480 resolves).

| Corpus | Previous resolve: r / S | New State: r / S | Same resolve again: r / S | c | r for 10x | r for 5x |
|---|---:|---:|---:|---:|---:|---:|
| standard, with the memos | 5.84 / 5.58 | 5.93 / 5.66 | 6.48 / 6.16 | 0.0080 | 10.88 | 5.21 |
| standard, formal G1 | 3.76 / 3.61 | 3.61 / 3.47 | 5.09 / 4.82 | 0.0107 | 11.2 | 5.28 |

  The new-State replay's median rounds, a second run of the same-resolve case, gave 6.41 / 6.10.
- **r per layer** (warm pass, same resolve again; the new-State replay in brackets):

  | Layer | Share | r with the memos | r in the formal G1 |
  |---|---:|---:|---:|
  | 1, hex | 14.8% | 6.22 (6.24) | 11.0 |
  | 2, damage and stat totals | 22.2% | 7.38 (7.71) | 3.95 |
  | 3, movement and targeting | 25.8% | 5.18 (5.31) | 12.6 |
  | 4, turn order and effects | 37.2% | 10.75 (11.31) | 3.99 |

- **Where native is slow** (warm, `standard`; 1.37 s native in all):
  - The board-read memo's users: `melee_approach_cells` r 3.88 with 0.41 s native (30% of the native time),
    `_walk_steps_to_target` 2.06 (0.097 s) and `legal_destinations_for_stack` 3.43. Before the memos, their native
    calls took the uncached path, and layers 1 and 3 fell from 11.0 and 12.6 to 6.22 and 5.18.
    - Each memo read builds GDScript's key, which hashes the battle's whole stacks and field-objective arrays, and
      returns a deep copy of the cached answer, as GDScript does. GDScript's `hash` is the engine's C++; the port's
      walks the State. How much of the time the key and the copy take is not measured.
  - The two functions that were slower than GDScript: `_append_presentation_event` went from r 0.69 to 5.57 and
    `_hero_has_trait` from 0.84 to 3.01.
  - Their callers: `_resolve_wait` went from 3.93 to 13.58, `_calculate_damage` from 2.61 to 9.19,
    `_apply_stack_effect` from 3.94 to 10.96, `_stack_cohesion_total` from 3.79 to 8.08 and `_stack_momentum_total`
    from 2.74 to 6.97.
  - The calls made 1,477,556 Dictionaries and 864,912 Arrays over the same 908,907 entries (4,161,058 and 2,085,064
    before).
- **Result:** S is 5.58 to 6.16 on `standard`: over 5x in every case, under 10x (r 10.88 needed). The six seeds were not
  re-measured. The owner decides.

**The board reads in a native memo** (slice 04c, 2026-10-21; owner: replace the ported board-read cache with a native
one, then re-measure G1 on `standard` with Phases 3 and 5 paused; runtime on main 9746d75fa; branch commits c50c63f62
port, 7cd5f6cca Windows binaries, 7027f1a5e warning fix):
- **Changed:** six board reads keep their answers in the State (`State::memo_find`, `memo_keep`): legal destinations,
  the melee approach, attack legality, the attack target ids, the walk steps and the walk mask. The key is the battle
  and the stacks asked about, as nodes.
  - An answer stays while nothing it read is written. The State counts every write into a node a memo watches, and a
    changed count drops the memo.
  - There is no hash of the stacks and no copy. The one exception is the melee approach, which still returns a new
    Dictionary per call, as GDScript does.
  - The port no longer reads or fills GDScript's board-read memo. GDScript callers keep it.
  - All six kinds stay. On 40 of the captures, 5 rounds each:

    | Memos on | Warm | Cold |
    |---|---:|---:|
    | all six | 322.2 ms | 408.9 ms |
    | destinations only | 328.1 ms | 408.9 ms |
    | none | 339.0 ms | 403.4 ms |

    The cold pass decodes each entry's arguments as new nodes, which the memo has to start watching. The native loop
    keeps one battle, as the warm pass does.
- **Explicit memo rule:** the battle table lists GDScript's board-read memo as GDScript's own: the scope cache, battle
  and depth, the hit count and the validation switch.
  - `gd::static_var` refuses it to a native port, and the validating check never compares it.
  - The table lists the other memos as shared: `_presentation_queue_written`, `_hero_payload_cache`, the scoring scope
    and the specialty catalog. If the native call left a shared memo alone, it must be as GDScript's call left it, or
    the check fails.
- **Harness:** the replay ignores a capture's board-read memo. If a writing entry left its arguments as it found them,
  the replay reads those arguments from the nodes shared by blob, as for a reading entry. `--fresh-writers` decodes them
  per entry instead.
- **Checks:**
  - Shadow on the six seeds: 0 mismatches and 0 errors in 55,236,025 checks over 275 of the 281 functions. 7,807,636
    of the checks are in the 101 writing functions.
  - Checks per memo user:

    | Function | Checks |
    |---|---:|
    | `legal_destinations_for_stack` | 110,921 |
    | `melee_approach_cells` | 51,839 |
    | `_legal_attack_target_ids_for_active_stack` | 19,431 |
    | `melee_approach_destination` | 16,367 |
    | `_walk_steps_to_target` | 6,987 |
    | `_attack_legality_for_target` | 6,307 |
    | `selected_target_legality` | 5,304 |

  - Native mode against main: every daily digest (415) and match record of the six seeds is identical.
  - The replay over the 82 `standard` captures: 0 mismatches, both with shared and with fresh writers.
  - Core suite: 17/17 on Windows.
  - The Linux libraries in `bin/` are not rebuilt.

**G1 on `standard` after the native memo** (2026-10-21, 22:49 to 22:55):
- **How it is measured:** as in "G1 on `standard` with the memos": the same baseline (main at b8c32e69d), the same 82
  captured resolves and 6 jobs.
  - Load: none. Phases 3 and 5 were paused. A sampler checked for Godot, Python and build processes every 5 seconds
    and logged none during the timed parts. g1.py's own samples also found no other Godot.
  - Every round of both replays: 0 mismatches and 0 errors.
- **Share of T_gd:** the ported functions take 65.5% of T_gd (77.36 s over 480 resolves). The 04b figure, 61.8% of
  88.35 s, was measured under load.

| Corpus | Previous resolve: r / S | New State: r / S | Same resolve again: r / S | c | r for 10x | r for 5x |
|---|---:|---:|---:|---:|---:|---:|
| standard, native memo | 8.97 / 8.42 | 8.38 / 7.89 | 10.15 / 9.45 | 0.0073 | 10.79 | 5.19 |
| standard, with the memos (under load) | 5.84 / 5.58 | 5.93 / 5.66 | 6.48 / 6.16 | 0.0080 | 10.88 | 5.21 |

  The new-State replay's median rounds, a second run of the same-resolve case, gave 9.95 / 9.28. The second row ran
  under sibling load on both sides, so the step between the rows mixes the memo with the load.
- **r per layer** (warm pass, same resolve again; the new-State replay in brackets):

  | Layer | Share | r, native memo | r with the memos |
  |---|---:|---:|---:|
  | 1, hex | 15.1% | 13.73 (13.95) | 6.22 |
  | 2, damage and stat totals | 22.3% | 9.25 (9.38) | 7.38 |
  | 3, movement and targeting | 25.9% | 17.69 (18.41) | 5.18 |
  | 4, turn order and effects | 36.8% | 11.10 (11.35) | 10.75 |

- **Where native is slow** (warm, `standard`): native takes 0.754 s in all, against 1.37 s with the ported memo.
  - The memo's users:

    | Function | r (with the memos) | Native time (with the memos) |
    |---|---:|---:|
    | `melee_approach_cells` | 19.1 (3.88) | 0.076 s (0.41 s) |
    | `_walk_steps_to_target` | 16.68 (2.06) | |
    | `legal_destinations_for_stack` | 17.41 (3.43) | |

  - The most native time:

    | Function | Native time | r |
    |---|---:|---:|
    | `_resolve_wait` | 0.087 s | 12.86 |
    | `advance_turn` | 0.078 s | 12.04 |
    | `melee_approach_cells` | 0.076 s | 19.1 |
    | `_calculate_damage` | 0.069 s | 9.74 |
    | `_mark_stack_animation_event` | 0.061 s | 6.72 |

  - The lowest r among functions with over 3 ms native:

    | Function | r |
    |---|---:|
    | `_hero_has_trait` | 4.03 |
    | `_merged_commander_ai_payload` | 6.21 |
    | `_damage_rng_for_battle` | 6.21 |
    | `_append_presentation_event` | 6.30 |

  - The calls made 1,009,330 Dictionaries and 819,444 Arrays over the same 908,907 entries. With the ported memo they
    made 1,477,556 and 864,912.
- **Result:** S is 7.89 to 9.45 on `standard`: over 5x in every case, under 10x (10x needs r 10.79). Layer 5 starts,
  as the owner decided.

**Layer 5: attacks, abilities, damage pressure and the attack events** (slice 05, 2026-10-22; branch commits
8d2bccfef port, a25b226c3 Windows binaries; merges of main eb30586d8 and f2d8e46f4; switch generator fix on main
a20d0c371):
- **Ported:** 58 functions, 1,371 lines.
  - BattleRules 37/1,162:
    - the attack and retaliation ability effects, the hookline pull, the counter-ambush flare, strike-backs and the
      retaliations and shots an attack spends;
    - pressure artillery, the readiness writ, mending fire and the harry support;
    - the damage pressure: the cohesion and momentum shifts of a hit, the shock of a destroyed stack, the field
      objectives' action pressure and control push, and `_apply_ranged_damage_return` (moved here from 06);
    - the post-attack target context and the damage and text presentation events.
  - SpellRules `build_battle_effect`, 1/32.
  - BattleAiRules' copies of the ability checks, 20/177, from 08. 14 of them call the BattleRules port.
- **Moved:**
  - `_resolve_attack_action` and `_resolve_ai_attack` go to 10, the attack orchestrators. They end in
    `_complete_action` or `_complete_enemy_action`, which call `_evaluate_outcome` and the `_finalize_*` functions,
    and those stay GDScript in Phase 1. A ported function calls only ported functions.
  - BattleAiRules `_readiness_writ_available`, `_readiness_writ_target` and `_stack_cohesion_total` go to 08.
- **Merges of main:**
  - The branch calls main's shared helpers `_default_difficulty_id`, `normalize_difficulty` and
    `_normalize_spell_ids`.
  - The branch calls main's `DifficultyRules.profile_for_session` and `profile_for_difficulty`. Main's
    `profile_for_session` now also takes the SessionData object (a2dc2bb61).
  - The branch calls main's `BattleDamageRules.attack_defense_multiplier`. The branch's copies are gone.
  - `battle_keys.inc` drops 60 keys that main's day and AI key lists hold with the same text.
- **Switch generator:** a switch's locals (`result`, `before`, `native_result`) take a `switch_` prefix when a
  parameter has the same name. `_attach_post_attack_target_context` takes `result`, and its script did not parse.
- **Review:** a read-only review compared every function with its GDScript body, and a second agent tried to refute
  each finding. Two divergences were confirmed; neither can happen in play:
  - `PackedStringArray.has` was missing from two `variant_has` copies (`ability_helpers.cpp`,
    `battle_ai_abilities.cpp`). It is added. Content gives Arrays.
  - `float(String)` throws in the runtime's `gd::to_float` where GDScript converts. This is a runtime gap on main,
    left open. Every bloodrush threshold is a float after the ability is normalized.
- **Checks:**
  - Shadow on the six seeds: 0 mismatches and 0 errors in 63,669,303 checks over 330 of the 339 functions. 10,633,092
    of them are slice 05's, over 55 of its 58 functions.
    - Not reached: `_apply_hookline_pull`, `stack_strike_backs` and `_lowest_health_stack`, plus the six from before.
  - Native mode against main: every daily digest (415) and match record of the six seeds is identical.
  - Core suite: 17/17 on Windows.
  - The Linux libraries in `bin/` are not rebuilt.

**Layers 6 and 7: the pressure of an advance and a defend, the melee approach, the town defences** (slice 06,
2026-10-22; branch commits b888d2336 port, 649d181a7 Windows binaries; merge of main 6924ce383):
- **Ported:** 5 functions, 80 lines. The rest of layers 6 and 7 came earlier: the damage pressure and the field
  objectives in 05, the town effects in 02 to 04.
  - BattleRules 4/79: `_apply_advance_pressure`, `_apply_defend_pressure`, `_apply_melee_approach` (from 03) and
    `_is_town_assault_context`.
  - TownBattleRules `spell_resistance`, 1/1.
- **Moved:** BattleAiRules' layer 6 copy `_field_objective_action_influence` (97 lines) stays with the other copies for
  08.
- **Review:** a review against the GDScript found no divergence.
- **Checks:**
  - Shadow on the six seeds: 0 mismatches, 0 errors and 0 paths left to GDScript in 63,734,372 checks over 335 of the
    344 functions. 65,069 of them are slice 06's, over all 5.
  - Native mode against main: every daily digest (415) and match record of the six seeds is identical.
  - Core suite: 17/17 on Windows.
  - The Linux libraries in `bin/` are not rebuilt.

**Layer 8 without the casts: the battle spells' rules and events** (slice 07a, 2026-10-22; branch commits 387543a23
port, 3e11b0aed Windows binaries; merges of main 4ea510b0b and 8d1985999):
- **Ported:** 52 functions, 585 lines. The commander payloads came in 02.
  - SpellRules 35/352: a spell's battle behaviour, the cast and target checks, spell and control resistance, the
    damage projection, recovery, power and durations, the effect payloads, and the status resolution with its
    resistance roll (`spell_battle.cpp`).
  - BattleRules 13/190: the commander's cast of the round, the casting hero, the commit of a resistance roll, and the
    cast's animation states and presentation events (`spell_events.cpp`).
  - ArtifactRules 3/37 and HeroProgressionRules 1/6: the mana cost. With 8 of the SpellRules functions these are the
    12 shared helpers, put on main unswitched (40cf5f12e, binaries 52c89b266) and switched here. ArtifactRules now
    has the battle engine's switch.
- **Moved:** `cast_player_spell` and `_cast_enemy_spell` to slice 10. The player's cast ends in `_complete_action`;
  the enemy's reaches `_evaluate_outcome` and the battle AI's commander payload (08, 09).
- **Waiting (07b):** `resolve_battle_spell`, `validate_battle_spell`, `_consume_mana`, `known_spells` and
  `_player_spell_resolution`. They need Phase 5's `ensure_hero_spellbook`, `mana_max_from_hero`,
  `mana_max_from_command` and `HeroProgressionRules.mana_max_bonus` on main.
- **Review:** one reviewer on the paths shadow did not reach (`_stable_percent`, the fallback of a battle without a
  seed, and that branch of `_status_resistance_roll` and `_battle_stream_rng`) found no divergence. A float or
  container `resistance_seed` fails loudly in native mode where GDScript's `str()` converts it; nothing in the game
  sets that field.
- **Checks:**
  - Shadow on the six seeds: 0 mismatches, 0 errors and 0 paths left to GDScript in 66,732,872 checks over 386 of
    the 396 functions. 2,998,500 of them are slice 07a's, over 51 of its 52; `_stable_percent` was not reached.
  - Native mode against main: every daily digest (415) and match record of the six seeds is identical.
  - Core suite: 17/17 on Windows.
  - The Linux libraries in `bin/` are not rebuilt.

### Phase 2: one payload builder, AI preview as one call, the battle tool

- Battle payload creation (`BattleRules.gd:256-402`), stack and hero payloads, obstacles, and the end-of-battle numbers
  (survivors, experience, recovery, level-ups, `army_power`) move native; every payload caller switches.
- `AiHeroRules._simulate_battle` becomes one native call with no scratch session, if shadow mode proves the read-back
  fields identical.
- Transcendental math first appears here (`army_power`, `HeroProgressionRules.gd:646`): decision D4.
- `battle_sim_cli` (or an in-Godot threaded runner, decision D7) becomes a backend for `tune.py` and `arena.py`.
- **Gate G2:** a battles-per-second target the owner sets (the synthesis proposes 1M battles in 2 h on this machine).
  **Battle-level genetic algorithms (unit stats, battle-AI weights) run at full speed from here.**

### Phase A: overworld AI numbers into data (GDScript only, any time after G0)

The tuning numbers among the 99 constants at `AiHeroRules.gd:26-297`, and inline literals, move to `content/ai_hero_weights.json`, with weight
sets per controller. Proof: identical digests with every controller on the default set. AI number tuning then needs no
code edit, before or after the AI goes native, and a genetic algorithm can give each seat its own genome.

**Result (2026-10-20, done):** `content/ai_hero_weights.json` holds 97 per-controller numbers (61 constants, 36 inline
literals) plus the resource values as set `default`, and the 10 `army_power` terms shared by all players (battle rewards
and generated guards use them). Sets are applied once per faction turn and decision context; `ai_weight_set` in a
computer player's enemy state picks its set; `ContentService.set_content_override` is the override layer (validated for
this document so far); `HEROES_AI_MATCH_WEIGHTS` and `ai_match_batch.py --weights` assign sets per seat. JSON float
parsing checked for these values: all 117 reach the code with the old literals' type and bits. Six seeds identical
against main on Windows and Linux; plain runs of the six seeds (main, change, change, main; 6 at once) took 750 and 754
s on main and 743 and 734 s with the change, not slower. This covered `AiHeroRules.gd` only; the AI numbers in its
helpers followed the same day (below).

**Follow-up (2026-10-20, done):** the AI numbers outside `AiHeroRules.gd` that live play reaches are in set `default`
too, 28 values: the dwelling-hire floor (`EnemyAdventureRules`), what a hero spends and buys in its own towns and how it
scores a loadout (`EnemyTownServices`), when it uses a faction service (`FactionTownServices.useful_to_ai`), and what
visit buildings and dwelling creatures are worth to it (`VisitBuildingRules.ai_value`,
`CreatureDwellingRules.week_value`). Each helper keeps them in typed static vars that `AiHeroRules._apply_weights` fills
with the controller's set, the default set until it does. How computer heroes pick specialties is a second shared table,
`specialty_pick` (4 values), because they also level up in battles outside their own turn. The integer halves (`x / 2`,
`c * 2 <= m`) became shares of 0.5, identical for every value below 2^53. Kept in code: the scouting and sighting memory
caps and the rebuild-pressure window (only older saves carry that memory), the resource values of the event log's reason
codes (only their sign is read), the commander deploy floor (public summaries only: AI heroes always have a roster
hero), the dwelling-guard threshold (the AI fights the guard first), the one-tile attack step in reach checks, and
AI-only rules that are not decisions (commander experience and recovery days). The validator now also refuses unknown or
missing keys inside tables and a fraction for any of the 39 whole-number weights; the company generator and
`power_fit.py` read `army_power` from the document. Proof: every moved value reaches the code with the old type and
value; the six seeds are identical against main on Windows and Linux, with the same digests on both.

### Phase 3: overworld kernels by rule

A kernel moves only if it is 3% or more of match CPU, takes packed arrays and scalars, and uses no transcendental math,
hash or RNG. Its code takes no behaviour changes while its port runs; there is no waiting period before it (owner
decision 2026-10-21). Candidates: `AiHeroRules._search` (11.5%), `_level_surface`, `_war_paths`, fog
`_explored`/`_reveal`.

Owner decision 2026-10-21: the `_search` kernel starts now beside Phase 1, on its own branch `native-phase3-search`,
merged to main once its games are identical. G3 is skipped for it.

**`_search` kernel** (completed 2026-10-21, branch `native-phase3-search`):
- Moved: `_search` calls two functions of the rules library on packed arrays (`core/ai_search.cpp`, rules API 2).
  `ai_search_masks` builds the per-search masks: the surface's blocked and stop tiles, open neutral bodies and guard
  zones, units, heroes and their hostile guard zones, the sea without armies, and the site stops the decision's site
  record already answered. `ai_search_walk` is the breadth-first walk with GDScript's step order and tie breaks,
  corners, portals, water, sailing, bought boats, docks and the radius cap. GDScript keeps the pending site stops
  (`_site_stop_passable` reads node and artifact Dictionaries) and the stop refs of each reached tile. Tables that change
  only with the surface, the open guard zones or the resolved encounters are cached on the surface.
- Measured on the six seeds, main d7cd33045 against the change on it. Runs went in the order main, change, change,
  main, six at once, on a machine shared with Phase 1's and Phase 5's runs, with a timer around `_search` only.
  `_search` totals over the six games went from 68.0 s to 35.1 s (1.94x): l1 18.9 to 10.7, l2 20.6 to 11.4, mg-a 14.2
  to 6.1, mg-b 9.7 to 4.4, mw 4.1 to 2.2, s2 0.66 to 0.39. Whole games went from 778 to 725 s (-6.8%); the two main
  runs differed by 33 s. In one probe run the pending site stops took 4.1 of the 9.5 s left on l1.
- Checks:
  - shadow mode on the six seeds: 18,211 calls, 0 differences (types, key order and the site record included);
  - `rules_selftest`: 58 captured vectors and a sweep of 3,000 generated boards;
  - `rules_parity.py check` against main: identical on 6/6 seeds (415 daily digests and the match records);
  - core suite 17/17 on Windows.

**AI targets** (completed 2026-10-21, branch `native-phase3-ai-targets` merged; owner decision 2026-10-21:
`_vetted_candidate` and `_gate_candidate` in C++ with the shared runtime, games identical; owner decision 2026-10-21:
merged although whole games got no faster):
- Profile on main 37d547fac, six seeds: `_vetted_candidate` takes 20.5% of match time and `_gate_candidate` 6.7% (15.6%
  on l2, 12.5% on mg-b). Under them the battle previews take 8.4%, `_search` 0.9% and the scoring 17.8%.
- Boundary: `_best_candidate` and `_gate_candidate` run native. `_vetted_candidate` keeps its veto loop in GDScript,
  because its previews (`_fight_looks_good`, `_simulate_battle`) are Phase 1's battle engine.
- Shared helpers (coordinator, 2026-10-21): ports of other scripts' functions live on main in their own files, one
  namespace per script, with nothing on main switched to them; each helper has one owner, claimed in the coordination
  notes, and the branch that first switches it proves it in shadow mode.
- The static call closure of the two entries, 445 functions, 7,188 lines, frozen from the slice's start to the merge:
  - AiHeroRules (135): `_add_guard_position`, `_add_stop`, `_add_stop_index`, `_apply_power_terms`, `_artifact_guard`, `_avoided_today`, `_best_candidate`, `_beyond_gate`, `_beyond_key`, `_boat_market`, `_boat_price`, `_build_value`, `_burst_share`, `_can_afford`, `_can_hire_any`, `_candidate`, `_damage_spell_figures`, `_dangers`, `_decision_field_ids`, `_decision_main_id`, `_decision_site_pass`, `_deters`, `_encounter_candidate`, `_encounter_guard_index`, `_entry_index`, `_expected_loss_value`, `_exploration_candidate`, `_explore_value`, `_explored`, `_far_ahead`, `_ferries_from`, `_field_hero_ids`, `_garrison_pickup`, `_gate_candidate`, `_gate_far_dist`, `_gate_routes`, `_guard_fight_value`, `_guard_positions`, `_guard_power`, `_guarded_node_value`, `_guarded_object_value`, `_guards_tile`, `_hero_guards`, `_hero_war_key`, `_hero_war_value`, `_hero_zone_tiles`, `_hostile_heroes`, `_hunt_value`, `_in_danger`, `_in_hero_zone`, `_last_stand_share`, `_leave_defense`, `_level_regions`, `_level_stretches`, `_level_surface`, `_main_hero_id`, `_main_shortfall`, `_market_cover`, `_market_trade`, `_meet_candidate`, `_merge_stacks_into`, `_movement_max`, `_neutral_army`, `_note_alternative`, `_open_guard_zones`, `_opened_value`, `_overworld_rules`, `_own_town_doors`, `_passage_value`, `_patch_root`, `_path_to`, `_payload_value`, `_plans_far`, `_player_hero_seen`, `_portal_exits`, `_portal_leads_unseen`, `_position_seen`, `_profile_add`, `_recruit_dict`, `_recruit_set_value`, `_resolved_lookup`, `_resource_candidate`, `_resource_guarded`, `_resource_needs`, `_rival_town_within`, `_rival_towns_unknown`, `_route_gate_open`, `_route_loss_limit`, `_route_map`, `_route_through`, `_route_towns`, `_route_unseen`, `_search`, `_search_tables`, `_sight_context`, `_site_artifact_value`, `_site_door_key`, `_site_door_value`, `_site_doors`, `_site_pass_class`, `_site_spell_value`, `_site_stop_passable`, `_spell_burst`, `_spell_damage_per_round`, `_split_for_handover`, `_step_offsets`, `_stretch_key`, `_strongest_threat`, `_sync_power_memos`, `_sync_site_pass_memo`, `_threatened_town_share`, `_tile_index_of`, `_tile_span`, `_town_candidate`, `_town_defense_need`, `_town_entrance_free`, `_town_hero_defender_index`, `_town_rules`, `_town_seen`, `_town_threatened`, `_town_worth`, `_townless_raider`, `_towns_held_by`, `_trial_growth`, `_turn_rules`, `_unit_power`, `_unit_power_figures`, `_war_paths`, `_weakest_stack_index`, `_would_hold_gate`, `_zone_guarded`, `active_hero_entries`, `army_power`, `hero_power`, `is_ai_hero`.
  - OverworldRules (113): `_add_resource_sets`, `_ai_hero_guards_against_player`, `_append_building_with_requirements`, `_append_generated_body_tiles_to_blocked_index`, `_append_spatial_lookup_entry`, `_apply_resource_percent_scale`, `_blocked_scenery_layer`, `_build_blocked_scenery_layer`, `_build_blocked_tile_index`, `_build_spatial_lookup_index`, `_build_spatial_resource_section`, `_build_status_copy`, `_building_category`, `_building_category_counts`, `_calculate_town_income`, `_collection_size`, `_compute_town_logistics_state`, `_default_logistics_requirements_for_role`, `_default_logistics_support_radius`, `_economy_profile_income`, `_empty_live_resource_stockpile`, `_empty_market_usage_bucket`, `_empty_town_logistics_state`, `_encounter_has_guard_engagement_surface`, `_encounter_neutral_metadata`, `_find_guard_engagement_at_tile`, `_generated_body_tiles_for_placement`, `_guard_engagement_world_tiles`, `_map_object_blocks_body_tiles`, `_map_object_footprint_origin`, `_map_object_for_resource_node`, `_map_object_world_body_tiles`, `_map_object_world_interaction_tiles`, `_market_bulk_resources`, `_market_cap_state_for_quote`, `_market_caps_for_profile`, `_market_quote_from_state`, `_market_rate_adjustment`, `_market_resource_abundance_score`, `_market_value_scale`, `_missing_build_requirements_among`, `_multiply_cost`, `_normalize_built_buildings_for_town_state`, `_normalize_market_usage_bucket`, `_normalize_recruit_payload`, `_normalize_resource_dict`, `_normalize_support_requirements`, `_normalize_town_market_usage_state`, `_normalize_town_occupation_state`, `_read_scope_town_digest`, `_recruit_payload_total`, `_resolved_lookup_entry`, `_resource_node_blocks_body_tiles`, `_resource_node_has_runtime_object_contract`, `_resource_node_has_runtime_visit_tile`, `_resource_node_linked_town`, `_resource_node_world_interaction_tiles`, `_resource_site_delivery_line`, `_resource_site_delivery_state`, `_resource_site_family_short_label`, `_resource_site_guard_link_for_encounter`, `_resource_site_is_persistent`, `_resource_site_is_repeatable`, `_resource_site_response_state`, `_resource_site_spell_ids`, `_resource_site_town_support`, `_resource_site_under_threat`, `_seed_recruits_for_town`, `_seed_scenario_recruits_for_town_state`, `_spatial_lookup_entries`, `_spatial_lookup_index`, `_spatial_lookup_signature`, `_spatial_resource_section`, `_support_requirement_progress`, `_terrain_id_is_passable_uncached`, `_tile_key`, `_town_build_context`, `_town_build_status`, `_town_build_status_in`, `_town_content_read_scope_key`, `_town_controller_id`, `_town_entrance_at`, `_town_faction_id`, `_town_logistics_gap_penalties`, `_town_logistics_plan`, `_town_logistics_state`, `_town_market_state`, `_town_name`, `_town_occupation_front_proxy`, `_town_occupation_relief_per_day`, `_town_occupation_state`, `_town_pressure_label`, `_town_read_scope_cache_get`, `_town_read_scope_cache_has`, `_town_read_scope_cache_key`, `_town_read_scope_cache_store`, `_town_recovery_state`, `_town_strategic_role`, `_week_of_day`, `_world_tiles_from_payload_array`, `derive_map_size`, `encounter_key`, `get_town_build_options`, `get_town_build_status`, `hero_guard_zone_tiles`, `is_encounter_resolved`, `resolved_encounter_lookup`, `resource_definition`, `resource_node_is_present`, `resource_site_blocking_guard`, `terrain_id_is_passable`, `town_income`, `town_market_state`.
  - ContentService (26): `_build_biome_terrain_index`, `_build_map_object_site_index`, `_indexed_content_row`, `_items_from_raw`, `_map_object_footprint_area`, `_scan_biome_for_terrain`, `canonical_town_id`, `default_ai_hero_weights`, `get_army_group`, `get_artifact`, `get_biome_for_terrain`, `get_building`, `get_content_by_id`, `get_content_revision`, `get_encounter`, `get_faction`, `get_hero`, `get_map_object`, `get_map_object_for_resource_site`, `get_resource`, `get_resource_site`, `get_spell`, `get_town`, `get_unit`, `load_json`, `normalize_terrain_id`.
  - ArtifactRules (17): `_append_inventory_artifact`, `_apply_bonus_payload`, `_artifact_exists`, `_artifact_is_owned`, `_blank_bonus_totals`, `_blank_equipped_slots`, `_compatible_equipment_slots`, `_first_empty_slot_from_candidates`, `_register_equipped_candidate`, `_set_states_for_equipped`, `_string_array`, `aggregate_bonuses`, `artifact_set_insignia_state`, `artifact_set_record`, `artifact_slot`, `ensure_hero_artifacts`, `normalize_hero_artifacts`.
  - TownRules (13): `_format_market_amount`, `_market_bulk_text`, `_market_limit_reason`, `_market_pair_reason`, `_market_ratio_text`, `_market_resource_name`, `_market_resource_title`, `market_conversion_give_amount`, `market_conversion_rate`, `market_resource_ids`, `market_sale_gold`, `market_trade_mode`, `market_trade_quote`.
  - HeroCommandRules (15): `_first_open_army_slot`, `_hero_is_stationed_at_town`, `_normalize_position`, `_slotted_stacks`, `_valid_stack_count`, `_week_bonus`, `army_addition_plan`, `hero_by_id`, `movement_max_for_hero`, `scouting_radius_for_hero`, `stationed_heroes`, `town_defending_hero`, `town_defense_force`, `town_garrison_hero`, `within_scout_radius`.
  - EnemyAdventureRules (14): `_artifact_guard_encounter_for_node`, `_artifact_guard_link_targets_node`, `_encounter_is_pressure_host_candidate`, `_find_artifact_by_placement`, `_find_resource_by_placement`, `_generated_object_guard_targets`, `_guard_link_for_encounter`, `_is_active_raid`, `_placement_resolved`, `_resource_node_contestable_by_faction`, `_resource_site_claim_rewards`, `_resource_site_is_persistent`, `_visit_key`, `apply_ai_weights`.
  - CreatureDwellingRules (20): `_refugee_candidates`, `_stable_roll`, `apply_ai_weights`, `base_unit_id`, `creatures`, `full_guard`, `guard_beaten`, `guard_blocks`, `guard_stacks`, `guard_unit`, `is_dwelling`, `is_guarded`, `is_refugee_camp`, `population`, `refugee_unit`, `unit_cost`, `unit_tier`, `week_index`, `week_value`, `weekly_growth`.
  - TownDevelopmentRules (14): `_compute_active_buildings`, `_satisfied_ids`, `_sync_memo_sources`, `active_buildings`, `choice_blocked`, `choice_blocked_among`, `data`, `faction_id`, `growth`, `has_dwelling_tier`, `has_dwelling_tier_among`, `income`, `is_current`, `satisfied_ids`.
  - HeroProgressionRules (8): `_merge_bonuses`, `_normalize_specialties_in`, `_rank_bonuses`, `_rank_in_array`, `_resolve_bonus_key`, `_specialty_catalog`, `_sum_bonus`, `aggregate_bonuses`.
  - VisitBuildingRules (11): `ai_value`, `apply_ai_weights`, `cadence`, `choices`, `cost`, `effects`, `is_visit_building`, `readiness`, `required_level`, `spec`, `week_index`.
  - OverworldLevelRules (9): `hero_level`, `level_count`, `level_of`, `on_level`, `position`, `query_level`, `same_level`, `terrain_rows`, `town_entrance`.
  - ResourceNodePayloadRules (4): `_erase_claim_recruits`, `_has_node_payload`, `claim_payload_spent`, `site_for_node`.
  - PlayerIdentityRules (8): `allied`, `controller_id`, `faction_id`, `identity_fields`, `player`, `raid_controller_id`, `resource_controller_id`, `town_controller_id`.
  - ScenarioFactory (5): `_apply_growth_profile`, `_duplicate_array`, `_seed_recruits`, `_seed_recruits_for_town_state`, `_unit_growth`.
  - WaterTravelRules (4): `boats`, `dock_tile`, `hero_boat_id`, `is_water`.
  - NativeTransitRules (6): `destinations`, `is_native`, `link_of`, `point`, `portal_kind`, `uses_native_adjacency`.
  - CommonMineRules (5): `block_tiles`, `body_tiles`, `entry_tile`, `origin`, `resource`.
  - BattleRules (2): `_enemy_army_for_encounter`, `battle_rewards_for_strength`.
  - DifficultyRules (5): `_default_difficulty_id`, `movement_bonus`, `normalize_difficulty`, `profile_for_difficulty`, `profile_for_session`.
  - EnemyTurnRules (2): `_owned_town_entries`, `_town_controller_faction_id`.
  - SpellRules (2): `_normalize_spell_ids`, `knows_spell`.
  - MineRules (4): `block_tiles`, `entry_tile`, `origin`, `resource`.
  - ScenarioSelectRules (2): `default_difficulty_id`, `normalize_difficulty`.
  - BattleDamageRules (1): `attack_defense_multiplier`.
- What runs native: the whole closure, in `core/port/ai_hero_rules_*.cpp` and one `<script>_ai.cpp` per other script
  beside Phase 5's `<script>.cpp` (the coordination notes name each function's file). Registry `core/port/ai_registry.cpp`
  (64 entries), keys `ai_keys.inc`. `AiEngine.gd` makes a session's view and calls the port; a call that reaches a path
  the port leaves out prints an error. The `HEROES_NATIVE_AI` switch and shadow mode went with the merge;
  `HEROES_NATIVE_AI_LOG` still collects the port's call and not-ported counts.
  - AiHeroRules: 131 functions' GDScript is deleted. 64 of them (the entries and 62 that GDScript outside the closure
    still calls, such as `_search`, `_candidate`, `army_power`) are wrappers that call their native port.
  - EnemyAdventureRules `_find_artifact_by_placement`: deleted (no caller left).
  - Two copies: the closure's other 313 functions keep their GDScript, which day processing, the UI and the battle
    code still call, beside the C++ port the AI calls. 214 were ported and switched here (OverworldRules 92,
    CreatureDwellingRules 20, HeroCommandRules 14, TownDevelopmentRules 14, EnemyAdventureRules 13, TownRules 13,
    VisitBuildingRules 11, PlayerIdentityRules 8, 9 more 29; AiHeroRules `is_ai_hero` among them), 63 are Phase 5's
    shared helpers, 26 ContentService reads, and 10 more: BattleRules 2, SpellRules 2 and BattleDamageRules 1 (frozen
    until Phase 1's merge), AiHeroRules' 3 script loaders and ScenarioSelectRules 2. A behaviour change to one of them
    changes both copies (AGENTS.md), until its script's port deletes the GDScript.
  - The ported functions keep their static vars (the weights, memos and caches) in their scripts, where the port reads
    and writes them, so those declarations stay.
  - Runtime on main first (cba124b9c): the engine's pow, exp and log for ported code, calls of up to 16 arguments.
  - Paths the port leaves out, none of which the AI reaches: non-ASCII `to_lower`/`to_upper` (shipped content is ASCII
    where the AI lowercases), `_market_ratio_text` of a fraction (only with texts, which the AI never asks for), the
    read-scope town digest and cache key (no read scope is open during an AI turn), `_town_occupation_relief_per_day`
    with no front (its one caller always passes one), packed arrays where GDScript converts them to Array.
- Speed: whole games are not measurably faster. Six seeds at once, editor binary, in the order main, change, change,
  main, on a machine shared with other sessions' runs: 804, 868, 860 and 844 s; the final parity check, both sides at
  once, took 911 s on main and 864 s with the change. Profiled on l1, l2 and mg-a: `_choose_plan` went
  from 236 to 197 s, `_best_candidate` from 105 to 40 s and `_gate_candidate` from 39 to 24 s, but the 1.65M calls
  from GDScript into the port take 151 s. The bridge loads a call's arguments lazily and starts empty on every call,
  so each call reads the session from Godot again. Of 141 s in the port, 64 s are 240M Dictionary reads (266 ns
  each), 13 s Array reads, 17 s whole-container fills, 5 s content rows and statics, and 14 s the calls' start and
  write-back; the C++ work itself is about 25 s. Within one call 48% of the Dictionary reads and 31% of the Array
  reads repeat, so a per-call read cache would save about 3 to 5% of match time. The gain needs the session loaded
  once per faction turn (Phase 4).
- Checks:
  - shadow mode on the six seeds with all 346 ported functions switched: 94,431,208 checks, 0 mismatches, 0 errors,
    0 not ported; 307 of the 346 are called from GDScript, the other 39 only from other ported functions;
  - `rules_parity.py compare` of the measured runs against main: identical on 6/6 seeds (415 daily digests and the
    match records); `rules_parity.py check` against main 4ea29c0dd after the rebase: identical on 6/6 seeds (415
    daily digests and the match records);
  - core suite 17/17 on Windows. The Linux libraries in `bin/` wait for the Linux pass.

### Gate G3: re-plan from measurements

Re-estimate Phases 4-7 from Phase 1's measured rate (lines per day, mismatches per 1,000 lines). The owner picks the
order of Phases 4 and 5 (the churn rule that picked it was removed on 2026-10-21) and decides whether to continue toward
whole-game speed.

### Phase 4: the overworld AI faction turn

AiHeroRules, the AI paths of EnemyAdventureRules and EnemyTurnRules, and the rule functions they reach. One native
`run_faction_turn` per faction turn: load a view of the session, run, patch back, clear caches. Functions with human or
UI callers keep a thin GDScript wrapper. Must reproduce sort ties, first-wins comparisons on float scores, `stops.keys()`
order, the tavern and spawn RNG, and the decision and battle logs. Proof adds a codec round trip
(`to_dict(from_dict(d)) == d` with types and key order) on every day of the six seeds and on owner-approved save copies.
AI code is frozen during the slice; the Phase A numbers stay open.

### Phase 5: day processing

`normalize_overworld_state`, `commit_active_hero`, town occupation and recovery, income, growth, reserve deliveries,
`PlayerEliminationRules.apply_daily`, `ScenarioRules.evaluate_session`, and `_finalize_*` for human battles: one native
call per day. The end-turn confirmation dry run in `OverworldShell.gd:1464-1529` must invalidate native caches too.

Owner decision 2026-10-21: Phase 5 starts now beside Phase 1, on its own branch `native-phase5-day`, merged once like
Phase 1. G3 is skipped for it. First, the shared C++ runtime moves from the Phase 1 branch to main, with no behaviour
change. That runtime is the value layer, its Dictionary bridge, the GDScript-semantics helpers, the port adapter and the
switch generator. From then on, a branch that changes the runtime lands that change on main as its own commit, and the
other branches take it from main. `_finalize_*` stays in `BattleRules`, which is frozen until the Phase 1 merge, so
Phase 5 ports it after that merge.

**Shared runtime on main** (2026-10-21, 79056b04f source, f9c828eb4 Windows binaries), from `native-phase1-battle`
a78100003 without the battle port:
- What moved: the engine-exact helpers with their fuzz digests and capture tool, the value layer (`battle_state`,
  `battle_keys.inc`), its Dictionary bridge, `port/gd`, the port adapter and the switch generator.
- The split for a second subsystem: each subsystem lists its functions in a `Table` of its own file (`registry.hpp`;
  the battle port's stays `core/port/registry.cpp`), and `registry_tables.cpp` joins the tables. The adapter's methods
  are `port_call`, `port_check`, `port_report` and `port_stats`, and each table names its log variable.
  `tools/native_battle_switch.py --subsystem` touches only the switches that read that subsystem's mode.
- Nothing on main calls it. Checks: core suite 17/17 on Windows, `rules_selftest` digests unchanged.

**Shared helpers from Phase 5** (2026-10-21): following the shared-helper rule (Phase 3, "AI targets"), Phase 5's
ports of the 63 functions Phase 3's AI targets also reach moved here from `native-phase5-day`, unswitched on main:
OverworldRules 21 (the map size, the blocked-tile index with its cached scenery layers and resolved-encounter set,
resource-node presence, the recruit payload), ArtifactRules 17, HeroProgressionRules 8 (Phase 1's port, copied),
OverworldLevelRules 7, CommonMineRules 5, MineRules 3, HeroCommandRules 1, NativeTransitRules 1, and 4 day-only
functions that share their files. They live in `core/port/<script>.cpp` and `include/aurelion_rules/port/<script>.hpp`,
their keys in `day_keys.inc`. A function that takes a session takes its view (`session_view.hpp`: SessionData's fields,
its metadata under "meta"). Shadow mode on the six seeds checked them on the branch, 0 mismatches.
- Also here, the runtime for paths a port leaves to GDScript: a native function throws `state::NotPorted` before any
  host side effect; the call writes nothing back, `port_not_ported()` is true, the stats count it as `not_ported`,
  and the switch generator writes a GDScript fallback for subsystems marked `fallback` (day only).
  - Since 2026-10-22 the subsystem's table says so too (`Table::fallback`; the day table sets it). In a subsystem
    without that fallback (battle, AI) a NotPorted fails the call: a native null could pass for GDScript's result
    and hide the gap from every later check. It is a native failure:
    - in native mode and in shadow mode;
    - a SCRIPT ERROR, which fails the core suite, rules_parity runs and G1;
    - counted as an error in the port stats.
  - The AI match runner (`tests/ai_versus_ai_match_report.gd`) fails its report on any error, mismatch or unknown
    name in the port stats, because a release export prints no SCRIPT ERROR.
- Phase 1 takes `hero_progression_rules` and the keys `day_keys.inc` shares with its branch from main and drops its
  copies (in `commander_payload.cpp` and its `battle_keys.inc`).
- Slice 04's shared helpers (2026-10-21; Phase 3 had claimed them and handed them over): PlayerIdentityRules 6
  (`controller_id`, `raid_controller_id`, `town_controller_id`, `player`, `faction_id`, `identity_fields`; the day-only
  `enemy_configs` shares the file), DifficultyRules `_default_difficulty_id` and `normalize_difficulty` (Phase 1's port,
  copied; ScenarioSelectRules' two functions inlined), SpellRules `_normalize_spell_ids`, EnemyTurnRules
  `_owned_town_entries` and `_town_controller_faction_id`, EnemyAdventureRules `_placement_resolved`, OverworldRules
  `resolved_encounter_lookup`, AiHeroRules `is_ai_hero` (`ai_hero_rules.cpp`; Phase 3 keeps its AiHeroRules ports in
  `ai_hero_rules_*.cpp`). `gd::stringify_or_fallback` is `String()` for a port with a GDScript fallback (day): a float
  or a container leaves the call to GDScript instead of failing it. In battle and AI calls it fails the call. Phase 1 drops its `difficulty_rules`
  definitions from `commander_payload.cpp` and the 29 keys of `day_keys.inc`'s second "Also in battle_keys.inc" block
  from its list.
- Slice 05's shared helpers (2026-10-21; Phase 3 handed them over): AiHeroRules `active_hero_entries` and
  `_resolved_lookup` in `ai_hero_rules.cpp`, with the day-only `active_hero_count`.

**Slice 04, frozen functions** (2026-10-21, until the Phase 5 merge; AGENTS.md): `EnemyTurnRules.normalize_enemy_states`
(every caller: the AI turn, scenario evaluation, the threat and pressure readers, the risk forecast) and what it runs in
AI matches, 126 functions. EnemyAdventureRules 60: `_active_commander_map`, `_apply_commander_army_metadata`,
`_apply_commander_memory_metadata`, `_apply_commander_record_metadata`, `_apply_commander_role_metadata`,
`_army_continuity_status`, `_army_continuity_summary`, `_army_headcount`, `_army_strength`, `_base_enemy_army`,
`_commander_renown_from_record`, `_commander_veterancy_rank_from_record`, `_faction_commander_ids`,
`_fallen_hero_settled`, `_hero_starting_spell_ids`, `_is_army_continuity_payload`, `_merge_unique_strings`,
`_normalize_army_payload`, `_normalize_command_payload`, `_normalize_commander_roster_entries`,
`_normalize_commander_roster_entry`, `_normalize_commander_status`, `_normalize_enemy_hero_sighting_records`,
`_normalize_enemy_progression`, `_normalize_enemy_scouted_target_records`,
`_normalize_resource_defender_commander_states`, `_normalize_string_array`, `_normalize_town_defender_commander_states`,
`_normalized_commander_army_continuity`, `_normalized_commander_memory`, `_normalized_commander_record`,
`_normalized_commander_role_state`, `_normalized_commander_target_kind_counts`, `_normalized_specialty_focus_ids`,
`_normalized_specialty_ranks`, `_placement_resolved`, `_preferred_enemy_specialty_id`, `_resolved_encounter_lookup`,
`_resource_has_ai_defender`, `_sync_specialty_pick`, `_sync_unit_strength_memo`, `_town_has_ai_defender`,
`_unit_strength_value`, `build_raid_commander_state`, `build_roster_commander_state`, `commander_army_brief`,
`commander_army_continuity`, `commander_army_status`, `commander_army_summary`, `commander_memory_brief`,
`commander_memory_summary`, `commander_record_summary`, `commander_roster_for_faction`, `commander_veterancy_label`,
`ensure_raid_army`, `normalize_all_commander_rosters`, `normalize_commander_roster`,
`normalize_enemy_known_world_memory`, `normalize_raid_armies`, `sync_commander_army_continuity`. EnemyTurnRules 15:
`_blank_resource_pool`, `_default_raid_encounter_ids_for_faction`, `_default_spawn_points_for_faction`,
`_enemy_faction_config_with_runtime_defaults`, `_enemy_faction_configs_for_session`,
`_enemy_faction_configs_with_runtime_defaults`, `_find_state`, `_normalize_enemy_states_body`, `_normalize_posture`,
`_normalize_rebuild_pressure_request`, `_normalize_resource_pool`, `_normalize_string_array`, `_owned_town_entries`,
`_town_controller_faction_id`, `normalize_enemy_states`. HeroProgressionRules 25: `_build_choice_group`,
`_distinct_specialty_count`, `_enqueue_missing_choice_groups`, `_normalize_pending_choices`, `_normalize_specialties`,
`_normalize_specialty_id_list`, `_offer_order`, `_reconcile_pending_choices`, `_specialty_is_available`,
`_specialty_row`, `available_specialty_ids`, `choose_specialty`, `command_path`, `current_pending_choice`,
`ensure_hero_progression`, `growth_seed`, `has_specialty`, `mana_max_bonus`, `max_rank_for_specialty`,
`max_specialties_per_hero`, `raw_pending_choices_remaining`, `specialties`, `specialty_definition`, `specialty_rank`.
PlayerIdentityRules 7: `controller_id`, `enemy_configs`, `faction_id`, `identity_fields`, `player`,
`raid_controller_id`, `town_controller_id`. DifficultyRules 6: `_default_difficulty_id`, `_scenario_select_rules`,
`normalize_difficulty`, `normalize_session`, `profile_for_difficulty`, `profile_for_session`. AiHeroRules 5:
`_overworld_rules`, `_resolved_lookup`, `is_ai_hero`, `migrate_legacy_raids`, `normalize_ai_heroes`. SpellRules 4:
`_normalize_spell_ids`, `ensure_hero_spellbook`, `mana_max_from_command`, `mana_max_from_hero`. OverworldRules 1:
`resolved_encounter_lookup`. ScenarioSelectRules 2: `default_difficulty_id`, `normalize_difficulty`. OverworldLevelRules
1: `canonical_spatial_records`. The paths AI matches never run stay GDScript and are not frozen by this slice: a roster
memo already open, legacy raid hosts and support columns, defender commanders in towns and sites, scouted targets and
hero sightings from old saves, hero task boards, enemy configs without player records.

**Slice 05, frozen functions** (2026-10-21, until the Phase 5 merge; AGENTS.md): `ScenarioRules.evaluate_session` and
`PlayerEliminationRules.apply_daily` (every caller) and what they run in AI matches beyond slice 04's functions, 20
functions. ScenarioRules 5: `_objective_met`, `evaluate_session`, `normalize_scenario_state`, `objective_definitions`,
`scenario_record_for_session`. ScenarioScriptRules 5: `_join_messages`, `_retry_pending_reinforcements`,
`_sorted_hooks`, `normalize_script_state`, `process_hooks`. GeneratedScenarioObjectiveRules 3: `definitions`,
`progress`, `uses_kind`. PlayerEliminationRules 4: `applies`, `apply_daily`, `heroes_held`, `towns_held`. AiHeroRules 3
(also Phase 3's): `_resolved_lookup`, `active_hero_count`, `active_hero_entries`. The paths AI matches never run stay
GDScript and are not frozen by this slice: script hooks and pending reinforcements, other objective types, a scenario's
completion, the rival count of a human game, the human player's townless days and defeat, a computer player's removal.

**Slice 03, frozen functions** (2026-10-21, until the Phase 5 merge; AGENTS.md): `HeroCommandRules.commit_active_hero`
(every caller) and what it runs in AI matches beyond slices 01, 04 and 05's functions, 17 functions. HeroCommandRules
12: `_hero_index_by_id`, `_normalize_army`, `_normalize_authored_specialties`, `_normalize_movement`,
`_normalize_player_hero`, `_normalize_position`, `_sync_active_hero_mirror`, `_week_bonus`, `active_hero`,
`commit_active_hero`, `movement_max_for_hero`, `new_growth_seed`. DifficultyRules 3: `movement_bonus`,
`profile_for_difficulty`, `profile_for_session`. HeroProgressionRules 1: `has_specialty`. ContentService 1: `get_hero`.
Six of them are also Phase 3's: the three DifficultyRules ones, `movement_max_for_hero`, `_week_bonus` and
`_normalize_position`.

**Slice 06b, frozen functions** (2026-10-22, until the Phase 5 merge; AGENTS.md): the rest of
`OverworldRules.normalize_overworld_state` (every caller) and what it runs in AI matches beyond the earlier slices'
functions and Phase 3's, 80 functions. OverworldRules 51: `_advance_town_occupation`, `_advance_town_recovery`,
`_blank_project_vulnerability_penalties`, `_build_scenario_army_state`, `_command_risk_field_item`,
`_command_risk_forecast`, `_command_risk_forecast_from_normalized_session`, `_command_risk_grade_label`,
`_command_risk_items`, `_command_risk_logistics_items`, `_command_risk_objective_items`,
`_command_risk_player_town_daybreak_contexts`, `_command_risk_posture_items`, `_command_risk_town_items`,
`_copy_town_runtime_metadata`, `_fog_grids`, `_fog_grids_uncached`, `_fog_state_ready`, `_grid_cell`,
`_mark_runtime_normalized`, `_migrate_generated_transit_meanings`, `_nearest_town_for_controller`,
`_normalize_active_town_visit_context`, `_normalize_artifact_nodes`, `_normalize_command_briefing`,
`_normalize_command_risk_forecast`, `_normalize_enemy_states`, `_normalize_generated_runtime_materialization`,
`_normalize_live_resource_stockpile`, `_normalize_scenario_resources`, `_normalize_scenario_state_rules`,
`_normalize_town_front_state`, `_normalize_town_recovery_state`, `_normalize_towns`, `_project_dependency_ids`,
`_project_player_town_at_daybreak`, `_raid_is_public`, `_reduce_command_risk_items`, `_refresh_blocked_tile_index`,
`_runtime_normalization_signature`, `_town_building_bonus_total`, `_town_capital_project_ids`,
`_town_capital_project_recovery_relief`, `_town_capital_project_state`, `_town_command_risk_state`,
`_town_matches_controller`, `_town_recovery_relief_rating`, `hero_position`, `is_tile_visible`,
`normalize_overworld_state`, `town_strategic_role`. NativeTransitRules 9: `_network_colour_key`,
`_portal_contract_error`, `assign_network_colours`, `contract_error`, `is_dead_end`, `network_index`, `nodes_by_id`,
`normalize_legacy_session`, `validate`. HeroCommandRules 3: `_normalize_town_garrison_heroes`, `_replace_hero_in_array`,
`normalize_session`. ArtifactRules 2: `build_artifact_nodes`, `normalize_artifact_nodes`. ContentService 2:
`get_scenario_readonly`, `get_terrain_layers_for_scenario`. EnemyAdventureRules 2: `_raid_is_public`,
`_sync_unit_strength_memo`. PlayerIdentityRules 2: `has_human_seat`, `normalize_compatibility`. ScenarioFactory 2:
`_build_army_state`, `_normalize_resources`. TownDevelopmentRules 2: `convert_reserves`, `migrate_town`. DifficultyRules
1: `normalize_session`. OverworldLevelRules 1: `canonical_spatial_records`. ScenarioRules 1: `objectives_for_session`.
SessionStateStore 1: `normalize_launch_mode`. WaterTravelRules 1: `normalize`. Eight of them are also private helpers in
Phase 3's port (`overworld_rules_ai_recovery.cpp`, `overworld_rules_ai_sites.cpp`): `_town_matches_controller`,
`_nearest_town_for_controller`, `_normalize_town_recovery_state`, `_normalize_town_front_state`,
`_town_building_bonus_total`, `_town_capital_project_recovery_relief`, `_town_recovery_relief_rating` and
`_sync_unit_strength_memo`; those copies fold into Phase 5's at its merge. The paths AI matches never run stay GDScript
and are not frozen by this slice.

**Slice 02, frozen functions** (2026-10-22, until the Phase 5 merge; AGENTS.md): the day's economy steps of
`OverworldRules.end_turn` (town occupation and recovery, town, hero and site income, site musters, reserve deliveries,
difficulty scaling) and what they run in AI matches beyond the earlier slices' functions and Phase 3's, 24 functions.
OverworldRules 19: `_add_recruit_growth`, `_add_resources`, `_advance_all_town_occupations`,
`_advance_all_town_recovery`, `_advance_player_reserve_deliveries`, `_clear_resource_site_delivery`,
`_describe_recruit_delta`, `_find_encounter_by_placement`, `_movement_max_from_hero`, `_player_hero_states`,
`_player_heroes_daily_income`, `_refresh_all_player_heroes_for_new_day`, `_resource_node_matches_controller`,
`_resource_site_control_income_for_day`, `_resource_site_delivery_target_label`, `_resource_site_weekly_recruits`,
`_weighted_recruit_value`, `apply_controlled_resource_site_musters`, `controlled_resource_site_income`. DifficultyRules
3: `_scale_amount`, `scale_income_resources`, `scale_resource_payload`. SpellRules 1: `refresh_daily_mana`.
HeroProgressionRules 1: `daily_income_bonus`. Three of them, `_describe_recruit_delta`, `_find_encounter_by_placement`
and `_weighted_recruit_value`, are also private helpers in Phase 3's port (`overworld_rules_ai_sites.cpp`); those copies
fold into Phase 5's at its merge. The paths AI matches never run stay GDScript and are not frozen by this slice.

**Slice 07, frozen functions** (2026-10-22, until the Phase 5 merge; AGENTS.md): `OverworldRules.end_turn` and
`_finalize_action_result` (every caller) and what they run in AI matches beyond the earlier slices' functions and Phase
3's, 21 functions. OverworldRules 15: `_compact_enemy_activity_events`, `_describe_resource_delta`,
`_end_turn_muster_summary`, `_end_turn_resolution_summary`, `_end_turn_town_economy_summary`, `_enemy_activity_line`,
`_enemy_activity_public_text`, `_evaluate_scenario_state`, `_finalize_action_result`, `_resource_keys_for_payload`,
`_reveal_current_fog_sources`, `_short_player_text`, `describe_enemy_activity`, `end_turn`, `is_weekly_growth_day`.
EnemyAdventureRules 6: `_ai_event_summary`, `_public_event_log_text`, `_public_reason_from_codes`,
`ai_public_event_log`, `ai_public_event_log_entry`, `ai_public_event_log_leak_check`. The port splits `end_turn` around
the AI turn (`_run_enemy_turn_cycle`) into two native calls; the paths AI matches never run stay GDScript and are not
frozen by this slice.

**Inventory and boundary** (2026-10-21, main 6d7471276; every function of `scripts/core` and ContentService probed on
the six seeds; times from l1, a large four-player game to day 90, on a machine shared with Phase 1's runs):
- Reach: the Phase 5 entries reach 440 functions, 6,020 lines; 311 of them also run outside day processing, nearly all
  in the AI turn. OverworldRules 156/2,408, EnemyAdventureRules 74/1,125, HeroProgressionRules 36/362, ArtifactRules
  19/317, EnemyTurnRules 15/247, NativeTransitRules 13/205, HeroCommandRules 18/189, ScenarioScriptRules 5/171,
  ContentService 20/144, GeneratedScenarioObjectiveRules 3/135, ScenarioRules 8/118, AiHeroRules 8/103, 14 more 65/496.
- A day on l1: `end_turn` 1,408 ms, the AI turn 1,222 ms, day processing 186 ms. The closing normalize takes 106 (the
  risk forecast with the enemy-state and roster normalize 55, the resource-node rebuild 33, the blocked-tile index 12,
  fog 8.5), `_finalize_action_result` 71, the part before the AI turn 7, `apply_daily` 0.5; the 4.4 normalize calls
  inside the AI turn 3. In AI matches every town belongs to a computer player, so player income, growth and deliveries
  do almost nothing.
- Converting the whole overworld (179,000 nodes, 1.64M values on day 90) into the value layer takes 392 ms and back
  153 ms per day, three times the day processing itself. Its largest keys are ones day processing barely reads: flags
  (573K values), the runtime scenario record (527K), the package source objects (481K), the map objects (333K).
- Boundary: view and patch through the port bridge, no whole-state conversion. Two native calls per day around the AI
  turn (`end_turn` before `_run_enemy_turn_cycle`, and after it), plus `normalize_overworld_state` where else it runs.
  A call reads its arguments lazily, writes the containers it changed back in place and exports the ones it made, so it
  costs the state it touches. `DayEngine.gd` hands a session over as a view (its fields, the very overworld, battle and
  flags Dictionaries, its metadata) and writes the fields back; content comes from ContentService's own cached
  documents in a context argument, so rows keep their identity. Estimate, unmeasured: the steps that rebuild data
  value by value (the resource nodes, the fog grids) stay near their GDScript cost, the computing ones (enemy states
  and forecast, scenario evaluation, the blocked-tile index) gain several times; Phase 5 alone gives under 1.1x on such
  games, and Phase 6, keeping the session native across days, removes the conversion.

**Static reach** (2026-10-21): the static call closure of the Phase 5 entries, paths AI matches never run included (the
human player's towns, heroes and artifacts, scenario scripts), is about 712 functions / 9,100 lines, 1.5 times the
probed reach. Each slice ports the whole closure of its entries, so no fallback to GDScript is needed. Slices go in the
order of their cost in AI matches: 01, 06, 05, 04, 03, 02, 07.
- Corrected after slice 01 (the first count missed functions reached through `load()` accessors): about 799 functions /
  14,260 lines, 1.8 times the probed reach; the risk forecast's closure alone is 483 / 8,276 and `evaluate_session`'s
  443 / 7,345. So a slice ports the paths AI matches run and leaves the others to GDScript: a native function throws
  `state::NotPorted` where such a path starts, before any side effect, and the switch runs the GDScript body (shadow
  mode counts the call as not ported). Slice 06 splits into 06a (the blocked-tile index and the resource nodes) and
  06b (the rest, 164 / 2,444, almost nothing in AI matches). Order: 01, 06a, 04, 05, 03, 06b, 02, 07.

**Slice 01, fog** (2026-10-21, branch `native-phase5-day`): `DayEngine.gd` hands sessions over as views; the day
registry has `OverworldRules._normalize_fog_of_war` and its 54 functions (OverworldRules 17, ArtifactRules 20,
HeroProgressionRules 8 copied from Phase 1, OverworldLevelRules 7, HeroCommandRules 2). Checks: shadow on the six seeds
4,047 calls, 0 mismatches; core suite in shadow mode 17/17, 182 calls, 0 mismatches; native mode against main on the
six seeds identical (every daily digest and match record); core suite 17/17. One call on a 108x108 two-level map:
12.8 ms in GDScript, 4.1 ms native.

**Slice 06a, blocked tiles and resource nodes** (2026-10-21, branch `native-phase5-day`): the day registry adds
`OverworldRules._build_blocked_tile_index` (it writes the cached scenery layers and the resolved-encounter set into the
session's metadata) and `_normalize_resource_nodes`, with 31 more functions (OverworldRules 22, CommonMineRules 5,
MineRules 3, NativeTransitRules 1). Ports that other ports share are in one file per script; their 63 functions shared
with Phase 3 are on main (above). Checks: shadow on the six seeds 10,243 calls, 0 mismatches; native mode against main
on the six seeds identical; core suite 17/17.

**Slice 04, enemy states** (2026-10-21, branch `native-phase5-day`): the day registry adds
`EnemyTurnRules.normalize_enemy_states` for every caller: the computer players' states, raid hosts and commander
rosters, with the 126 functions listed above (EnemyAdventureRules 60, HeroProgressionRules 25, EnemyTurnRules 15,
PlayerIdentityRules 7, DifficultyRules 6, AiHeroRules 5, SpellRules 4, ScenarioSelectRules 2, OverworldRules 1,
OverworldLevelRules 1); the paths AI matches never run throw `state::NotPorted`, and so does `String()` of a float or a
container (`gd::stringify_or_fallback`). Checks: shadow on the six seeds 2,511 calls, 0 mismatches; native mode against
main on the six seeds identical; core suite 17/17.

**Slice 05, scenario evaluation and elimination** (2026-10-21, branch `native-phase5-day`): the day registry adds
`ScenarioRules.evaluate_session` and `PlayerEliminationRules.apply_daily` for every caller, with the 20 functions listed
above (ScenarioRules 5, ScenarioScriptRules 5, PlayerEliminationRules 4, GeneratedScenarioObjectiveRules 3, AiHeroRules
3; AiHeroRules' two shared ones on main) and slice 04's. Generated maps have no script hooks and one objective,
defeating every rival, which counts only with a human player. Left to GDScript: script hooks and pending reinforcements,
other objective types, a scenario's completion, a human game's rival count, the human's townless warning and defeat, a
computer player's removal (4 calls on the six seeds), and a script state whose hook list is not yet an `Array[String]`
(the value layer makes a typed Array only from one it holds). Checks: shadow on the six seeds `evaluate_session` 1,652
calls, `apply_daily` 409, 0 mismatches; native mode against main on the six seeds identical; core suite 17/17.

**Slice 03, hero commit** (2026-10-22, branch `native-phase5-day`): the day registry adds
`HeroCommandRules.commit_active_hero` for every caller: the active hero's overworld mirrors (position, army,
movement) written back into the player's roster, the hero normalized as a hire is, and the mirrors rebuilt from the
roster entry, with the 17 functions listed above and slices 01, 04 and 05's. The six it shares with Phase 3 are
Phase 3's, from main. Checks: shadow on the six seeds 2,442 calls, 0 mismatches; core suite in shadow mode 17/17,
92 calls, 0 mismatches; native mode against main on the six seeds identical; core suite 17/17.

**Slice 06b, the rest of normalize_overworld_state** (2026-10-22, branch `native-phase5-day`): the day registry adds
`OverworldRules.normalize_overworld_state` for every caller: the session's fields and heroes, its towns (occupation,
recovery, fronts, capital projects, garrison heroes), resource and artifact nodes, transit networks and boats, blocked
tiles, fog, the command briefing and risk forecast and the scenario state, with the 80 functions listed above and the
earlier slices'; it records the runtime signature in `_runtime_normalized_signatures`. The scenario script state's hook
list is built as `Array[String]` natively (`gd::new_typed_array`, on main f6d6d178c); before that, the untyped list of a
new or loaded session sent 80% of the calls to GDScript. Left to GDScript: a session without towns or resource nodes, an
artifact still to be drawn from a reward table, town fields of an odd type, a human primary hero missing from the
roster, the garrison migration, generated rewards other than transit objects, the risk forecast's raid and objective
items and a player town under threat, `to_lower()` of non-ASCII text, JSON edge cases and `_fog_grids` with a fog read
scope open. Checks: shadow on the six seeds `normalize_overworld_state` 1,986 calls, 0 mismatches, none left to GDScript
(19,826 day checks in all, 0 mismatches); core suite in shadow mode 17/17, 115 calls, 0 mismatches (3 left to GDScript:
enemy configs without player records); native mode against main on the six seeds identical; core suite 17/17.

**Slice 02, the day's economy** (2026-10-22, branch `native-phase5-day`): `OverworldRules.end_turn` is two native calls
around the AI turn (`_run_enemy_turn_cycle`, GDScript): `_end_turn_open_day` closes the old day (the closing normalize,
the hero commit) and opens the new one: town occupation and recovery, town, hero and site income scaled by difficulty,
weekly growth and site musters, the heroes' daily refresh (movement, mana) and reserve deliveries, with the 24 functions
listed above. Left to GDScript: a player town's weekly growth (`_growth_tick_town`), a player reserve delivery's arrival
(interception), towns or nodes that are no Array, and the debug rules profile. Checks: shadow on the six seeds
`_end_turn_open_day` 409 calls, 0 mismatches; core suite in shadow mode 17/17, 20 calls, 0 mismatches (1 left to
GDScript: a player town's growth); native mode against main on the six seeds identical; core suite 17/17.

**Slice 07, the day's close** (2026-10-22, branch `native-phase5-day`): `_end_turn_close_day` (elimination, the action
result, the closing normalize, the day's summaries and the computer players' public event log with its leak check) and
`_finalize_action_result` for every caller, with the 21 functions listed above. Sessions are views and no native state
outlives a call, so `OverworldShell.gd` and the session-meta caches invalidate nothing. Left to GDScript: an action's
scenario check narrowed to its event facts (`evaluate_session_for_event`, only the active hero's own actions), the human
paths of slice 05 (a human game's rival count, the townless warning), JSON edge cases in the leak check and the debug
rules profile. Checks: shadow on the six seeds `_end_turn_close_day` 405 calls and `_finalize_action_result` 409, 0
mismatches (4 left to GDScript: a computer player's removal, slice 05); core suite in shadow mode 17/17, 9 calls, 0
mismatches (40 human paths left to GDScript); native mode against main on the six seeds identical; core suite 17/17.
Timing, from the native check on the six seeds (beside another session's parity run): whole games 728 s on main, 674 s
with the day native (1.08x); l1 186 to 174 s, l2 194 to 181 s.

### Phase 6: match throughput

The runner keeps a native session handle across days and writes Dictionaries back only for the digest and record (with
a check that runner mode and game mode give the same digests); several matches per Godot process (match N identical in a
reused and a fresh process); a pre-generated map corpus for genetic-algorithm work. The GDScript parts do not need C++
and move forward if G0 finds a high fixed cost. **Whole-game genetic algorithms become practical here, if the measured
gain is there.**

### Phase 7: human-side actions and the last GDScript rules

Movement, routes, context actions, overworld spells, town actions, hero transfers and artifact equipping: about 378
functions the UI calls, at 1,221 call sites. Needed for the one-copy end state, not for speed, so it can interleave with
other work. Merging the separate human and AI forms of heroes, treasury and fog is a later save-schema slice.

### Phase 8 (optional): a match runner without Godot

The same core as a command-line tool. Needs the copied Variant hash and either deterministic math or accepted last-bit
differences against the game.

### Totals

Sizes are the proposal's unmeasured agent-day guesses, useful only to compare phases (see section 6).

| Up to | Size guess (unmeasured) | What it buys |
|---|---|---|
| Phase 0 | 6-12 (measured: 2 h 20 min, two sessions) | a measured go/no-go, cheap GDScript levers |
| Phases 1-2 | 44-88 more | battle-level genetic algorithms at native speed |
| Phases A, 3 | 2-19 more | AI numbers as data; some overworld kernels |
| Phases 4-6 | 49-100 more | whole-game speed (the large gain) |
| Phase 7 | 35-70 more | one copy of every rule |

## 7. AI and balance changes during the transition

| Change | Policy |
|---|---|
| Content JSON balance | Always open; the native tables rebuild per content revision. |
| Battle-AI weights (`content/battle_ai_weights.json`) | Always open; per side; much faster to tune from Phase 2. |
| Overworld AI numbers | Open; data after Phase A and its follow-up, per controller except the shared `army_power` and `specialty_pick`. Numbers only older saves, the event log or AI-only rules read stay in code (Phase A results). |
| Battle rule or battle-AI code | Frozen during Phase 1. An urgent fix lands in GDScript on main, is ported on the branch and passes shadow mode again. After Phase 1 it is a C++ change in its own commit. |
| Overworld AI code | GDScript and open until Phase 4; frozen only during its slice. |
| New unit abilities | C++ changes after Phase 1. |
| Comparing AI code variants | Build `battle_sim_cli` from two git revisions under a namespace macro; nothing extra on main. |

## 8. Owner decisions

| | Decision | When |
|---|---|---|
| D1 | **Decided 2026-10-20:** `project.md:49` records the move to C++ subsystem by subsystem; the ownership list changes as each phase lands | before Phase 0 code |
| D2 | **Decided 2026-10-20:** parity runs are allowed on port slices, never while an owner batch is running (AGENTS.md "Validation budget") | Phase 0 |
| D3 | **Decided 2026-10-20:** native binaries stay committed; the Linux debug library is stripped (50.8 MB today) and its debug info kept outside git | Phase 0 |
| D4 | Math: engine math through godot-cpp in the game, or a later deterministic-math behaviour change | Phase 2 |
| D5 | **Phase 1 decided 2026-10-20:** battle-rule and battle-AI code take no behaviour changes from the start of Phase 1 to its merge; an urgent fix lands in GDScript on main and is ported on the branch; content JSON and `battle_ai_weights.json` stay open (AGENTS.md "Native rules port"). AI code: decided before Phase 4 | before each |
| D6 | **Decided 2026-10-20:** tests that call private battle functions the port deletes are retired at the Phase 1 merge by the `docs/rmg-test-retirement.md` process; the parity corpus and the core suite cover battles | Phase 1 |
| D7 | Whether a tool built from the same core counts under "no simulator outside Godot" (`PLAN.md:328`), or an in-Godot threaded runner instead | Phase 2 |
| D8 | **Decided 2026-10-20:** Phase 1 lives on one port branch, `native-phase1-battle` on GitHub, rebased on main at least weekly and before each slice, and merges to main once, when every battle is native and identical; it is dropped if checkpoint G1 stays under 5x after the interface fix (AGENTS.md "Native rules port") | Phase 1 |
| D9 | Where owner-save copies for the codec proof live (outside git); asked when a slice first needs owner saves | Phase 1 |
| D10 | **Decided 2026-10-20:** main is tagged before each port merge. Owner 2026-10-21: no waiting period after it (the 7 days without behaviour commits was removed) | each merge |

## 9. Risks and how the plan contains them

- **Parity debugging eats the schedule.** Finest-checkpoint diffing, the three-strikes blocker rule, and G1/G3 re-plans
  from measured rates.
- **The AI changes faster than it can be ported.** The AI stays GDScript until the order rule allows it; its numbers
  move to data first.
- **Builds compete with batches for the machine.** Builds on the server or CI at low priority; batches from a frozen
  `bin/` copy.
- **A native crash takes the game down.** Copy-in/copy-out calls, caught exceptions, input capture, archived symbols.
- **Saves strand after a revert.** No subsystem version bump inside a port slice (`damage_rng_version`,
  `ai_heroes_version`); two-way save tests at every merge.
- **Engine upgrades.** The copied helpers are tied to Godot 4.6.2 and godot-cpp is pinned to `10.0.0-rc1`; any bump
  re-runs the helper fuzz and full parity. Move godot-cpp to a release tag before rules ship.
- **A stopped phase leaves dead code.** If a gate says stop, delete whatever no live path uses.

## 10. Brief for each port slice

The exact functions to port (from Phase 0's executed-function list), every caller in `scenes/`, `scripts/`, `tests/` and
`tools/`, the boundary signature, the corpus and parity commands, the freeze notice, what is forbidden (redesign, fixes
inside port commits, builds or parity runs during an owner batch), the blocker format, and "done": native code runs in
the game, the GDScript is deleted, callers are updated, parity is identical, the core suite passes on Windows (Linux waits
for the owner's Linux pass),
cleanup is done. Slices are cut small enough for an agent to hold their functions in context; BattleRules alone is 16k
lines.

## 11. To verify in Phase 0 before relying on this plan

Godot 4.6.2 internals (PCG bounded draw, `randf` width and draw count, String hash, `SortArray`, JSON float parsing);
the C runtime of the official Windows binary; Windows/Linux identity of GDScript games today; whether caster profiles
stay constant through a battle; which presentation keys nothing reads in AI battles; whether release templates run the
match scene with identical results; the exclusive time split on full-length games. The Godot internals, the C
runtime, caster profiles and presentation keys are answered in "Phase 1 results (first slice)". Measured so far (Phase 0 results):
Windows/Linux identity, release templates, the time split; JSON float parsing for the AI weights (Phase A).
