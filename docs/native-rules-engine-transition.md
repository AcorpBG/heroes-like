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

A kernel moves only if it is 3% or more of match CPU, takes packed arrays and scalars, uses no transcendental math, hash
or RNG, and had no behaviour commit for 7 days. Candidates: `_level_surface`, `_war_paths`, fog `_explored`/`_reveal`.

### Gate G3: re-plan from measurements

Re-estimate Phases 4-7 from Phase 1's measured rate (lines per day, mismatches per 1,000 lines). If AiHeroRules had
behaviour commits on more than 4 of the last 14 days, do Phase 5 before Phase 4, keeping the AI in GDScript longer. The
owner decides whether to continue toward whole-game speed.

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
| D10 | **Decided 2026-10-20:** main is tagged before each port merge, and the merged subsystem takes no behaviour commits for 7 days after it | each merge |

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
