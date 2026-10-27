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
    battle AI, battle payloads, the overworld AI faction turn, day processing, the human-side rule actions, and (owner
    decision 2026-10-23, Phase 7) every other rule: panel text, content loading, game setup, the save format, the
    map editor's rules and the campaign runtime.
  - **GDScript keeps:** the screens only: scenes, layout, input, animation, drawing and audio, reading native results.
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
exception caught at the adapter. Floats become text only through `compat::num` and `compat::json_float` (the engine's
`String::num` and `JSON.stringify`) or in the Godot adapter.

**Content.** The native content tables (Phase 7, slice 7.10) read the content files themselves: `compat::json_parse`
is the engine's `JSON.parse`, and `content::Store` keeps every document read-only with ContentService's lookups
(first id wins, file order, towns by their canonical id). GDScript gets one read-only Dictionary per document and
row, the same object for every caller, and the port bridge reads the store directly. Overrides (the genetic
algorithms', the tests') go through the store's one override layer, which bumps the content revision, so GDScript
and native code never see two different contents in one match; an AI weights override is checked against the
shipped document at that boundary.

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
  nice 19 (GCC 13.3; with `--mingw` also the self-test built with MinGW and run under Wine). Every file comes back sha256-checked, and
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
  - Formal pre-merge G1, 2026-10-22 (slice 11, "The pre-merge suite and the merge"), with host calls: S 11.28 to
    13.95 on `standard` and 8.90 to 10.99 on the six seeds. Native mode measured on whole resolves: 10.84x on
    `standard` and 8.15x on the six seeds after merging main (6.85x and 4.15x before). The branch merges (D8).
- **Identity:** per-action stream (order taken, RNG state and roll count, simulation-key digest) on the tuner suites,
  every AI battle in the six seeds, and JSON round-tripped payloads; shadow mode on every resolve; daily digests; the
  payload corpus across compilers; mid-battle save/load both ways between the native build and the tagged pre-merge
  build; every battle UI query compared in shadow mode on the human-seat corpus.
- **Exit:** all battles native, the GDScript fight loop and BattleAiRules deleted, every deleted name grepped across
  `tests/` and `tools/` (`core_script_compile_check` covers only `scripts/` and `scenes/`), the runner and tuner run,
  core suite on Windows (Linux in the owner's Linux pass), project.md ownership updated.
  - Owner decision 2026-10-22: the GDScript copies and the switch stay at the merge until Phase 2's battle tool is in,
    so the tuner keeps working. The deletion, the grep of deleted names and D6's test retirements move to Phase 2
    (slice 11). Done in Phase 2d (2026-10-23).
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
  - Floats become text only through `compat::num`/`compat::json_float` or in the adapter. On Windows they call
    `msvcrt.dll`'s `_vsnprintf` and `log10`, the functions the official build imports: this library's UCRT prints
    exact digits, where msvcrt keeps 17 and rounds them in its own 80-bit arithmetic (rounding exact digits as msvcrt
    does still missed 1 of 786,432 fuzz values). On Linux both use glibc. The `json_float` digest checks them; the
    Linux digest waits for the Linux pass.
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

**The AI's estimates without the scoring payload** (slice 08a, 2026-10-22; branch commits c94611a8b port,
eb4f8729a Windows binaries; merge of main 2c5bd236a):
- **Ported:** 88 BattleAiRules functions, 1,120 lines; 86 of them switched.
  - The scoring scope of one AI decision and its memos, GDScript's static vars read and written through the host as
    the GDScript does (`battle_ai_rules.cpp`, 8).
  - The AI's copies of the damage modifiers, the field objectives' bonuses and the side reads they use
    (`battle_ai_modifiers.cpp`, 43).
  - Its reads of reach and attack distance, side health, the advance target and destination, the commander's payload
    and template, and the spell estimates (`battle_ai_reads.cpp`, 37).
  - The copies call the AI's own memo-aware helpers, never the BattleRules port of the same name. The six memos
    `_clear_scoring_memos` also touches join the shared memos shadow checks.
- **Not switched:** `_add_scoring_memo_entry` and `_keep_stack_term`. GDScript passes them the static memo itself, or an
  entry of it, and shadow cannot tie a native write to that argument back to the static var. Native callers use the C++.
- **Waiting (08b):** the side's scoring payload and the 41 functions that reach it, through Phase 5's
  `ensure_hero_spellbook`, on main since 379665372.
- **Review:** one reviewer on the five functions shadow did not check (`_allied_melee_count`,
  `_side_has_linked_unit`, `_can_make_any_ranged_attack` and the two kept out): no divergence.
- **Checks:**
  - Shadow on the six seeds: 0 mismatches, 0 errors and 0 paths left to GDScript in 74,657,726 checks over 469 of
    the 482 functions. 7,924,854 of them are slice 08a's, over 83 of its 86; `_allied_melee_count`,
    `_can_make_any_ranged_attack` and `_side_has_linked_unit` were not reached.
  - Native mode against main: every daily digest (415) and match record of the six seeds is identical.
  - Core suite: 17/17 on Windows.
  - The Linux libraries in `bin/` are not rebuilt.

**The casts and the AI's scoring payload** (slices 07b and 08b, 2026-10-22; branch commits 099f519fd port,
cf1190263 Windows binaries):
- **Ported:** 50 functions, 1,080 lines.
  - 07b, 5/162: SpellRules `validate_battle_spell`, `resolve_battle_spell`, `_consume_mana` and `known_spells`
    (`spell_battle.cpp`), BattleRules `_player_spell_resolution` (`spell_events.cpp`).
  - Phase 5's spellbook helpers, 4/33: SpellRules `ensure_hero_spellbook`, `mana_max_from_hero` and
    `mana_max_from_command`, HeroProgressionRules `mana_max_bonus`. On main unswitched since 379665372; switched here
    in the battle table.
  - 08b, BattleAiRules 41/885:
    - the side's scoring payload, the commander's traits and bonuses, and the enemy's withdrawal
      (`battle_ai_payloads.cpp`, 13);
    - the contextual bonuses, the cohesion and momentum totals, the breach of an obstruction and the readiness writ
      (`battle_ai_contextual.cpp`, 14);
    - the damage estimate and its modifiers, the threat to a stack and the lethal attack
      (`battle_ai_estimates.cpp`, 8);
    - the field objectives' worth and the support spells' scores (`battle_ai_spell_scores.cpp`, 6).
  - BattleAiRules' own `_hero_payload_cache` joins the shared memos.
- **Review:** one reviewer on the two functions shadow did not reach (`_enemy_withdrawal_urgency_scale`,
  `_preservation_comparison_score`) and the part of `_enemy_withdrawal_action` behind them: no divergence. The urgency
  scale's lower-casing fails loudly in native mode on non-ASCII hero text, where GDScript converts it; the content has
  none.
- **Checks:**
  - Shadow on the six seeds: 0 mismatches, 0 errors and 0 paths left to GDScript in 81,952,285 checks over 517 of
    the 532 functions. 7,294,559 of them are slices 07b's and 08b's, over 48 of their 50.
  - Native mode against main: every daily digest (415) and match record of the six seeds is identical.
  - Core suite: 17/17 on Windows.
  - The Linux libraries in `bin/` are not rebuilt.

**The AI's decisions** (slice 09, 2026-10-22; branch commits bcdbccacc port, cd3c6accc Windows binaries):
- **Ported:** 30 functions, 816 lines.
  - BattleAiRules 27/789:
    - the weights (`_w`, from `content/battle_ai_weights.json`), the attack, defend and advance scores, whether to
      hold the line, and the melee approach (`battle_ai_attack_scores.cpp`, 11);
    - the commander's spell candidates and choice, and whether a cast is worth its mana
      (`battle_ai_spell_choice.cpp`, 7);
    - an enemy stack's action, a stack's tactical order, the advance plan and the reachable strike
      (`battle_ai_decisions.cpp`, 9).
  - BattleRules 3/27: `ai_melee_approach`, `ai_advance_plan` and `_apply_auto_advance_movement` (`enemy_orders.cpp`).
  - BattleAiRules' `_weights` joins the shared memos. Not ported: `_battle_rules`, a Script (the ports call the
    BattleRules ports), and GDScript's board-read scope, which the native board reads do not need.
- **Moved to 10:** the BattleRules enemy turn (`_run_enemy_turn`, `_run_enemy_stack_order`, `_cast_enemy_spell`, the
  defend and wait orders, `_drain_enemy_turns`): it reaches the battle ends, which stay GDScript.
- **Review:** none; shadow reached all 30.
- **Checks:**
  - Shadow on the six seeds: 0 mismatches, 0 errors and 0 paths left to GDScript in 83,280,050 checks over
    547 of the 562 functions. 1,327,765 of them are slice 09's, over all 30.
  - Native mode against main: every daily digest (415) and match record of the six seeds is identical.
  - Core suite: 17/17 on Windows.
  - The Linux libraries in `bin/` are not rebuilt.

**Autoplay, the orders and the battle screen's queries** (slice 10, 2026-10-22; branch commits 26e2efdd1 port,
a41e38754 Windows binaries; runtime on main 6a8c9a736, 27bee9e26 Windows binaries):
- **Ported:** 59 functions, 2,050 lines. With them every step of a fight runs native: the autoplay loop, the player's
  orders, the enemy turn, the AI and the outcome.
  - 10a, 39/1,664:
    - BattleAutoResolveRules 8/289: `resolve_active_battle`, the player side's decision and its fallback, the focus
      target and the result (`battle_auto_resolve.cpp`).
    - BattleRules 30/1,337: `perform_player_action`, `cast_player_spell`, `resolve_if_battle_ready`,
      `_resolve_attack_action`, `_complete_action` and `_evaluate_outcome` (`player_orders.cpp`, 7);
      `move_active_stack_to_hex`, its movement intent and the post-move target context (`move_orders.cpp`, 14); the
      enemy turn from 09 with `_resolve_ai_attack` and `_complete_enemy_action` (`enemy_turn.cpp`, 9).
    - BattleActionPlayback `capture`, 1/38 (`action_playback.cpp`): board setup and the presentation events now write
      the playback record natively.
  - 10b, 20/386, the battle screen's queries:
    - BattleRules 13/291: the attack, advance and spell consequence previews with their damage and loss ranges
      (`consequence_previews.cpp`, 10) and the turn order forecast (`turn_forecast.cpp`, 3);
    - SpellRules 7/95: the text a battle spell's effect prints (`spell_summaries.cpp`).
  - BattleRules' `_consequence_cache_battle` and `_consequence_cache` join the shared memos.
- **Host calls** (the runtime on main): the battle ends stay GDScript in Phase 1. These are `_finalize_victory`,
  `_finalize_player_battle_loss`, `_finalize_stalemate`, `_finalize_enemy_withdrawal`, `_finalize_retreat`,
  `_finalize_surrender`, and the message of a refused retreat or surrender (`_retreat_action_summary`,
  `_surrender_action_summary`, which read the overworld's withdrawal preview). The ports call them through
  `gd::call_static`.
  - The battle table lists these 8 targets as `HOST` entries in `core/port/registry.cpp`, each with the one call site
    where it is allowed. None is inside the fight's step loop. `gd::call_static` fails on any other target.
  - Native mode: the bridge writes everything back and runs the GDScript function. Then it drops everything: every
    loaded node reads its container again lazily, and the State memo (the board reads' too), the static vars and the
    content are read again.
  - Shadow mode: the native run stops at the host call (`state::Suspend`). The switch's host point checks the run up to
    there (`AurelionRules.port_validate_point`), and GDScript goes on.
  - Counts: on the six seeds, 1,243 host calls in 1,536 resolves (1,215 `_finalize_victory`, 28
    `_finalize_player_battle_loss`), at most one per resolve. On `standard` they are not counted, because the arena
    fails in native mode (below).
  - The two summaries are never reached in autoplay, because BattleAutoResolveRules turns an exit order into a defend,
    and the AI never asks for them. They run only when a player orders a retreat or surrender that is not allowed: the
    order is refused and the battle goes on, one host call per refused order. An allowed one calls its `_finalize_*`
    once, and the battle ends.
- **At the merge:** the owner's decisions of 2026-10-22 on the host-call rule, the events, the tables, the human seat
  and the arena are in slice 11 ("The pre-merge suite and the merge").
  - Still GDScript: battle setup (`create_battle_payload`, `normalize_battle_state`), the battle screen's `describe_*`,
    `intent_forecast_payload` and `get_action_surface`, and BattleActionPlayback's `begin` and `finish`.
- **Review:** one reviewer on the five functions shadow did not reach (`_fallback_player_autoplay_decision`,
  `_select_focus_enemy`, `consequence_range_text`, `upcoming_actor_ids`, `_cleanse_labels`): no divergence.
- **Checks:**
  - Shadow on the six seeds: 0 mismatches, 0 errors and 0 paths left to GDScript in 83,514,931 checks over
    569 of the 621 functions. 234,881 of them are slice 10's, over 22 of its 59.
  - Shadow on 12 generated-map battle screen tests: 0 mismatches in 2,339,481 checks, 18,087 of
    them slice 10's, over 53 of its 59. The two runs together reached 54 of the 59.
  - Native mode against main: every daily digest (415) and match record of the six seeds is identical.
  - Core suite: 17/17 on Windows.
  - The Linux libraries in `bin/` are not rebuilt.

**The pre-merge suite and the merge** (slice 11, 2026-10-22; branch commits 1142ede17 the G1 harness's host calls,
0c25910a0 native by default, f8fac574f merge of main with Phase 5, e2611ac81 Windows binaries; main tagged
`pre-native-phase1-battle` before the merge):
- **Owner decisions at the merge** (2026-10-22):
  - The rule "a ported function calls only ported functions" becomes "...or a registered GDScript host target" (the 8
    in slice 10).
  - Events stay today's exact strings, built in C++, with no structured records and no GDScript formatter. This
    replaces the Phase 1 scope above.
  - The native unit and ability tables per content revision go to Phase 2.
  - The arena check runs `--plain`: the game's own BattleAiRules on both sides, no router (option (c) in "G1 on
    `standard` with the memos"). Option (b), each side's weights as data, comes with Phase 2's battle tool.
  - Human seat: the 12 generated-map battle screen tests in shadow stand in for the corpus. The owner plays a battle
    or two after the merge.
  - The GDScript copies and the switch stay until Phase 2's battle tool is in, so the tuner keeps working:
    - `HEROES_NATIVE_BATTLE` is native by default (`BattleEngine.gd`); `gdscript` and `shadow` stay.
    - `arena.py` sets `gdscript` for its workers when a router plays (code or weight variants, so `tune.py` and
      `power_fit.py` too); `--plain` keeps the caller's switch. `git:<rev>` variants work as before.
    - A battle change goes into the C++ and the GDScript in the same commit, checked with one six-seed shadow run
      of the battle switch (AGENTS.md).
    - The exit's deletion of the GDScript fight loop and BattleAiRules, the grep of every deleted name and D6's test
      retirements move to Phase 2. Nothing is deleted at this merge. Done in Phase 2d (2026-10-23).
- **Merge of main:** `battle_keys.inc` drops the 13 keys main's `day_keys.inc` now holds with the same text.
- **G1 harness:** the replay harness (`tools/battle_port_g1/`) captures the resolve as one entry and replays its host
  calls from the recorded results, with the newer memos.
- **Checks** (Windows):
  - Arena `--plain`, 480 games per suite: native identical to GDScript with 0 errors on `standard` (29,473,853 native
    calls) and `holdout` (27,546,302). Shadow 0 mismatches in 93,996,266 checks (`standard`, 576 functions) and
    96,113,835 (`holdout`, 577).
  - Payload corpus, the battle JSON round-tripped at its start: native identical to GDScript 480/480; shadow 0
    mismatches in 94,284,055 (`standard`) and 96,403,222 (`holdout`) checks.
  - Mid-battle save and load both ways: 12 steps in one mode, the battle through JSON and `normalize_battle_state`,
    the rest in the other mode. GDScript to native (260 battles still running at the save) and native to GDScript are
    identical to GDScript on both sides, 480/480, 0 errors.
  - Shadow on the six seeds: 0 mismatches in 83,514,931 checks over 569 functions.
  - Shadow on the 12 human-seat tests: 0 mismatches in 2,331,148 checks over 581 functions. 11 pass;
    `battle_event_animation_state_report` fails the same way in GDScript mode.
  - Reach: the runs together reach 615 of the 621 functions. An edge probe (the quick suite's battles with mutated
    inputs) reached all 621, 0 mismatches in 43,776,346 checks on the calls GDScript runs without error, except 10
    calls of `HeroProgressionRules._sum_bonus` with a String operand: the runtime's `float(String)` is not ported
    (fails loudly; no content reaches it).
  - Correctness replay: 239 resolves, 0 mismatches.
  - Formal G1 (6 jobs, no other load):

    | | `standard` | six seeds |
    |---|---|---|
    | c | 0.0103 | 0.0239 |
    | r: same resolve / previous resolve / new State | 16.29 / 14.39 / 12.76 | 14.91 / 12.43 / 11.31 |
    | S | 13.95 / 12.53 / 11.28 | 10.99 / 9.58 / 8.90 |
    | native mode before merging main, whole resolves | 6.85x (74.26 s to 10.85 s) | 4.15x (88.85 s to 21.41 s) |
    | native mode after merging main | 10.84x (70.30 s to 6.49 s) | 8.15x (88.88 s to 10.90 s) |

    Before the merge of main, native mode paid about 4 ms per resolve beyond the replay (fit: 4.18 ms + T_gd/8.4 on
    `standard`, 3.81 ms + T_gd/5.7 on the six seeds). Main's container fill (13a7a0c9a) brought it to about 2 ms
    (1.97 ms + T_gd/12.7 and 2.08 ms + T_gd/11.5). The shipped figure is native mode's.
  - After the merge of main: native mode against main identical on the six seeds (415 daily digests and the match
    records); core suite 17/17; a two-generation `tune.py` run plays (its router in GDScript mode).
  - The Linux libraries in `bin/` are not rebuilt.

### Phase 2: one payload builder, AI preview as one call, the battle tool

- Battle payload creation (`BattleRules.gd:256-402`), stack and hero payloads, obstacles, and the end-of-battle numbers
  (survivors, experience, recovery, level-ups, `army_power`) move native; every payload caller switches.
- `AiHeroRules._simulate_battle` becomes one native call with no scratch session, if shadow mode proves the read-back
  fields identical.
- Transcendental math first appears here (`army_power`, `HeroProgressionRules.gd:646`): decision D4.
- `battle_sim_cli`, a command-line tool built from the same core, becomes the backend for `tune.py` and `arena.py`
  (D7, decided 2026-10-22).
- From Phase 1 (owner decisions 2026-10-22): the native unit and ability tables per content revision; the arena's
  native router (each side's weights as data, option (b)); then, once `tune.py` and `arena.py` run on the battle tool,
  the GDScript fight loop, BattleAiRules and the battle switch's other GDScript copies are deleted, every deleted name
  grepped across `tests/` and `tools/`, with D6's test retirements. Done in 2d (2026-10-23).
- **Slices** (owner decision 2026-10-22: the preview first, then the payload builder, then the battle tool; Windows
  only, lean checks). Each merges to main on its own, from a short-lived branch, with main tagged first (D10). Proof
  per slice: shadow on the six seeds, native mode against main on the six seeds, the core suite, and whole-game timing
  on a quiet machine (Phases 4 and 5 paused). Review as in Phase 1.
  - 2a, the AI's battle preview as one native call (`native-rules-phase2-a-preview-20261022`):
    `AiHeroRules._simulate_battle` and `_battle_hero` in `core/port/ai_battle_preview.cpp`, switched in the battle
    table. The scratch session is a native view (SessionData's fields and `meta`), with no SessionData object:
    `gd::member`, `gd::set_member` and `gd::object_view` also take a Dictionary view (runtime, on main, on top of
    Phase 5's object views from slice 09, 4d1c1e298 on its branch). The preview's payload
    path, by static closure beyond the C++ on main: 61 functions, 1,889 lines (BattleRules 47: the
    encounter payload, its stacks, obstacles, battle context, enemy commander, town captain and field objectives;
    OverworldRules 6, the battlefront and delivery contexts; EnemyAdventureRules 4, the raid names and strength,
    which Phase 3 has as file-local C++ copies; AiHeroRules 2; TownBattleRules 1; SessionStateStore's
    `new_session_data`, which the view replaces). It also calls 12 of Phase 5's slice 09 functions (the town,
    resource and context lookups), so it builds on slice 09. It reuses Phase 5's HeroProgressionRules specialty normalization
    (`enemy_states.cpp`) and Phase 3's `_neutral_army` and `army_power`. Its battle end is Phase 5's slice 09
    (`_finalize_*` native), so 2a merges after it. Then Phase 4's faction turn calls the port directly instead of its
    pure host call. The read-back fields (`hero_after`, the survivors, `resources_gained`, the resolution) must be
    shadow-identical. Frozen from 2a's start to its merge (AGENTS.md): the 61 functions it ports, below.
    Merged 2026-10-22: battle shadow on the six seeds 81,038,237 checks, 0 mismatches (`_simulate_battle` 1,536); turn shadow 1,766,016 checks, 0 mismatches; native against main identical on 6/6 seeds; core suite 17/17; whole game on the six seeds (against main c12d4f864, before 4.2) 426.5 s to 403.5 s (0.946) with the turn native, 609.0 s to 599.0 s (0.984) with the
    default. Since the merge the 61 keep two copies (AGENTS.md).
  - 2b, the payload builder for every caller (`native-rules-phase2-b-payload-20261022`): the rest of
    `create_battle_payload` (town assaults and defences, battle contexts, the human's battles), `normalize_battle_state`
    and the end-of-battle numbers; every payload caller switches. Then the battles per second are measured for G2.
    Merged 2026-10-22: battle shadow on the six seeds 81,039,773 checks, 0 mismatches (`create_battle_payload` 1,536); a probe of the six switched functions on generated maps (27 town assaults, 1,020 resource defences, 1,020 dwelling guards, 171 resumes) 315,419 checks, 0 mismatches; turn shadow 1,766,016 checks, 0 mismatches; native against main identical on 6/6 seeds, turn native and default; core suite 17/17. G2 measured: arena `--plain` standard suite, 480 games (240 battles both ways) on 24 workers, the battle native: 54.2 s on main, 54.2 s with 2a, 53.7 s with 2b, about 8.9 games/s; per game on a worker about 900 ms, of which the session rebuild 698 ms, the payload 30, normalize 7, the fight 32 and the rest 133, so the battle itself is about 69 ms (measured before 4.2 merged).
  - 2c, the battle tool (`native-rules-phase2-c-battle-tool-20261022`), the command-line `battle_sim_cli` (D7), to
    G2's 100 battles/s: the backend of `tune.py` and `arena.py`, the native router with each side's weights as data (option (b)), the native
    unit and ability tables per content revision.
    What changed:
    - `battle_sim_cli` (`src/gdextension/rules/cli/`, built into `bin/` with the rules library). Godot setup workers
      (`worker.gd`, a setup job) build each battle's session up to the payload once. They write it as snapshots: a new
      binary format, `aurelion_rules/snapshot.hpp`, with the library's `snapshot_encode` and the core's decoder.
      - `content.snap` holds the content files, the ContentService tables by id and the rules scripts' static vars:
        the native unit and ability tables, one set per run.
      - A group snapshot per map holds its battles, the generated scenario and the content revision.
      - The tool plays every order of every battle, a game per thread, and writes `worker.gd`'s record.
    - The native router: 13 call sites in the battle code enter the side the GDScript router picks
      (`port/ai_route.hpp`, `Backing::routes_ai`, false in the game).
      - Each variant's BattleAiRules static vars are its own.
      - Its `_weights` literal is data, the variants file `arena.py` writes.
    - `arena.py` and `tune.py` take `--backend cli` (the default) or `--backend godot` (as before). `tune.py`'s setup
      workers boot once for the run and build each generation one generation ahead.
    Checks: in-Godot battles against `battle_sim_cli`, records compared without `ms`.
    - Arena `--plain`, Godot's native battles: standard 480/480 identical, holdout 480/480 identical.
    - Arena routed, GDScript router and battles against the native router:
      - standard and holdout, 960 games, identical apart from the `ai_calls` count in 7;
      - the cause: `BattleAiRules._hero_payload_cache` lives across a Godot worker's games, so a repeated battle skips
        one routed `_merged_commander_ai_payload` call; the tool starts every game from the snapshot's statics;
      - scoring reads only whether each side made calls.
    - One `tune.py` generation (17 weight sets, 3,298 games): history, weights and CMA state identical; records
      identical apart from `ai_calls` in 40.
    - Native against main identical on 6/6 seeds; core suite 17/17.
    Speed and the remaining points:
    - G2 met. `tune.py --generations 10` with its defaults (48 maps, 3 battles a map and 17 weight sets a generation;
      24 setup workers, 32 tool threads), quiet machine: 30,974 battles in 188 s end to end, 164.9 battles/s;
      generations 1 to 9 at 188.3/s (16.3 s each).
      - Of the 188 s, waiting for the Godot setup workers took 82.8 s (30.2 s of it the first generation, boot
        included) and `battle_sim_cli` 102.2 s, while the setup workers build the next generation.
      - Before the tool skipped freeing its workers' states at exit (13 to 18 s a generation), the same run took
        299 s (103.7/s).
      - One Godot run of another session overlapped the last 10 s.
    - D4, not needed for identical records: `pow`, `exp` and `log` are the tool's C runtime's, not the engine's
      (counted in the tool's stats). They are reached by:
      - `AiHeroRules.army_power` and `_unit_power_figures`, via `BattleRules.battle_rewards_for_strength` at a
        victory;
      - `HeroProgressionRules._offer_order`, via `_award_commander_experience` and `add_experience` at a level-up.
      None feeds the record; a byte-identical post-battle state needs D4.
    - The Variant hash is native (`gd::hash`), so it is no blocker.
  - 2d, the exit (`native-rules-phase2-d-exit-20261022`, 2026-10-23; main tagged `pre-native-phase2-exit` first):
    battles run native only, with no switch and no GDScript battle. No C++ change.
    - The 725 functions of the battle table lose their GDScript bodies and the `HEROES_NATIVE_BATTLE` switch. The 232
      that the game, the tools and the tests still call are thin wrappers over `BattleEngine.native` and
      `native_writing`. The other 493 are gone, with 198 GDScript functions, constants and statics only they called,
      all of `BattleDamageRules.gd` among them. 41 of the 198 are in other scripts: 20 functions ported with slice 09
      and 2a, whose C++ ports stay, and constants, preloads and helpers only they used. The two host functions (`ProfileLog.emit_general`,
      `OverworldRules._collect_resource_node_result`) get their names back. The static vars the port reads stay.
      `scripts/` loses 23,874 lines and gains 332 (20 files); the retired tests take 28,007 lines.
    - Two copies stay where the battle screen's text, the overworld or towns call a function the port also has in C++
      (AGENTS.md):
      - BattleRules `_enemy_force_name_from_battle_army_id`, `battle_rewards_for_strength`, `_allied_ranged_count`;
      - OverworldRules `_delivery_encounter_matches_node`, `_resource_site_delivery_interception`,
        `_town_battlefront_profile`, `delivery_interception_context_for_encounter`, `encounter_display_name`,
        `town_battlefront_profile`;
      - EnemyAdventureRules `raid_commander_display_name`, `raid_display_name`, `raid_strength`;
      - SpellRules `build_spellbook`, `refresh_daily_mana`, `mana_state`, `knows_spell`, `learn_spell`,
        `effect_summary`, `_normalize_spell_ids`, `_ability_by_id`, `_has_ability`, `_alive_stacks_for_side`.
    - GDScript only for the core battle tests and an RMG tool, which the game never runs: BattleRules
      `_build_battle_stack`, `_normalize_unit_abilities`, `_cohesion_base_for_unit`, `_normalize_string_array` and
      `_enemy_withdrawal_allowed`, and `_normalized_battle_context_fields` with `_battle_context_target_hero_id`
      (`tools/rmg_native_transit_validation.py`).
    - D6: 46 tests retired (`docs/battle-test-retirement.md`). `battle_readability_regression`, the runner of about 30
      tests, measures its distances with `BattleFootprint.distance` instead. Every deleted name was grepped across
      `tests/` and `tools/`: the hits left name live functions of the scripts they name.
    - The arena's variants are weight sets only. `router.py` is gone, `worker.gd` plays the game's own battle AI,
      `--backend godot` needs `--plain`, and `tune.py` and `power_fit.py` run on `battle_sim_cli` only. Two versions
      of the battle AI's code no longer play each other in one run. `native_battle_switch.py` keeps the day switch.
    - Checks (Windows): native against main 6e490c9e2 identical on 6/6 seeds (415 daily digests and the match records); core
      suite 17/17; arena `quick` on `battle_sim_cli` and on `--backend godot --plain`, 72 games each, records identical
      apart from `ai_calls` and timing; `tune.py` two generations of 4 on 12 maps, 430 games. The Linux libraries in
      `bin/` are unchanged (no C++ change).
- **Gate G2:** 100 battles per second (owner decision 2026-10-23; 1M battles in about 2.8 h on this machine),
  measured end to end by `tune.py` on `battle_sim_cli`. Met by 2c: 164.9 battles/s end to end (Slice 2c above). Measured after 2b: about 8.9 games/s in the arena, about 69 ms of each game's 900 ms the battle. Proposed was the synthesis's 1M battles in 2 h (about 139 battles/s); the owner set 100 battles/s, about 11 times the arena now.
  **Battle-level genetic algorithms (unit stats, battle-AI weights) run at full speed from here.**

**Slice 2a, frozen functions** (2026-10-22, until 2a merged, two copies since; AGENTS.md; corrected the same day from 32: the first
count stopped at multi-line signatures): BattleRules 47: `_append_building_with_requirements`, `_apply_hero_battle_boosts`, `_apply_specialty_battle_starts`, `_army_affiliation`, `_army_stack_descriptors`, `_authored_field_objectives`, `_battle_context_target_hero_id`, `_battle_difficulty_value`, `_battle_enemy_army_name`, `_battle_name`, `_build_battle_stack`, `_cohesion_base_for_unit`, `_default_field_objective_pressure_tags`, `_default_field_objective_summary`, `_encounter_enemy_commander_name`, `_encounter_enemy_commander_seed`, `_enemy_army_for_battle`, `_enemy_commander_state`, `_enemy_commander_state_for_battle`, `_enemy_stack_source`, `_enemy_withdrawal_allowed`, `_find_town_at_position`, `_generate_battle_obstacles`, `_new_battle_combat_seed`, `_normalize_command`, `_normalize_enemy_hero_state`, `_normalize_field_objective`, `_normalize_field_objectives`, `_normalize_side_token`, `_normalize_string_array`, `_normalize_town_captain`, `_normalize_unit_abilities`, `_normalized_battle_context`, `_normalized_battle_context_fields`, `_normalized_battlefield_tags`, `_normalized_specialty_focus_ids`, `_normalized_specialty_ranks`, `_normalized_town_buildings`, `_obstacle_cells_clear`, `_obstacle_field_stays_open`, `_player_setup_for_battle`, `_resolved_encounter_placement`, `_titleize_token`, `_town_building_category_counts`, `_town_captain_state`, `_with_army_battlefield_tags`, `create_battle_payload`; OverworldRules 6: `_delivery_encounter_matches_node`, `_resource_site_delivery_interception`, `_town_battlefront_profile`, `delivery_interception_context_for_encounter`, `encounter_display_name`, `town_battlefront_profile`; EnemyAdventureRules 4: `raid_commander_display_name`, `raid_commander_name`, `raid_display_name`, `raid_strength`; AiHeroRules 2: `_battle_hero`, `_simulate_battle`; SessionStateStore 1: `new_session_data`; TownBattleRules 1: `prepare`. `_simulate_battle` is also frozen by Phase 4. `new_session_data` is not ported: the scratch view copies what it sets.

**Slice 2b, frozen functions** (2026-10-22, until 2b merged, two copies since; AGENTS.md): BattleRules 18: `_battle_context_already_resolved`, `_battle_context_is_restorable`, `_battle_context_seed`, `_battle_has_living_opposition`, `_enemy_force_name_from_battle_army_id`, `_normalize_battle_obstacles`, `_normalize_player_commander_state`, `_normalize_stack`, `_normalize_tactical_briefing_state`, `_normalize_waited_stack_ids`, `_normalized_battle_resolved_key`, `_sync_battle_context_anchors`, `_town_assault_enemy_commander_state`, `battle_payload_can_resume`, `create_dwelling_guard_payload`, `create_resource_defense_payload`, `create_town_assault_payload`, `normalize_battle_state`. The payload itself (`create_battle_payload` and the rest of the path) is 2a's, frozen with it.

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
    changes both copies (AGENTS.md), until its script's port deletes the GDScript. Phase 4's exit (4.4) deleted the
    GDScript of four whose last GDScript caller went with the turn: `AiHeroRules._overworld_rules`,
    `EnemyAdventureRules._find_resource_by_placement` and `_resource_site_claim_rewards`, and
    `HeroCommandRules.within_scout_radius`. 309 keep two copies.
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

Owner decision 2026-10-22: Phase 4 starts now, on its own branch `native-phase4-faction-turn`, merged once like Phases
1 and 5; Windows only, lean checks. The goal is whole-game speed. Phase 3's C++ does in about 30 s what GDScript did in
about 180 s, but GDScript calls it 2M times a match and each call reads the session again; Phase 4 removes those
calls. Phase 5 merges day processing first and Phase 1 battles next; the branch takes each from main as it lands.
Phase 5's ports of EnemyTurnRules and EnemyAdventureRules (its slice 04) are this phase's to build on. Each slice's AI
code is frozen from its start to the merge (AGENTS.md names the functions); the Phase A numbers
(`content/ai_hero_weights.json`) stay open.

**Inventory** (2026-10-22, main 4a9f8b178). Six seeds, with a probe counting every function of `scripts/core` and
ContentService inside the computer players' turns. The probe slows the turn, so the turn's shares read high.
- Time: the computer players' turns (`EnemyTurnRules.run_enemy_turn`) take 55% of match time and their hero days 47%.
  Within them, battle previews take 19% (`AiHeroRules._simulate_battle`, Phase 1's engine), real battles 4% and towns
  2.8%. The 2.07M calls from GDScript into Phase 3's port take 22%. Most of that is the bridge reading the session
  again for each call. The calls come from GDScript's planning and moving: `_in_hero_zone` 570k, `_site_doors` and
  `_site_door_key` 419k each, `_site_door_value` 79k, `_explored` 68k, `_hero_guards` 56k, `_candidate` 54k.
- Battles in the turn: `_simulate_battle` is pure. It runs a scratch session through `BattleRules.create_battle_payload`
  and `BattleAutoResolveRules.resolve_active_battle`, and a real battle applies the preview's outcome. A battle against
  a human starts through `create_battle_payload`. Everything of Phase 1's that a turn runs is under these two.
- Reach of `run_enemy_turn` with the two battle entries left to GDScript: 1,074 functions, 16,800 lines (the static
  call closure, plus 12 that the probe saw called by name). The six seeds run 768 of them, 11,416 lines:

  | | Static | Run by the six seeds |
  |---|---:|---:|
  | On main (Phase 3's port) | 320 / 3,127 | 275 / 2,551 |
  | On Phase 5's branch (on main at its merge) | 223 / 4,523 | 163 / 2,799 |
  | Not ported | 531 / 9,151 | 330 / 6,066 |

  Not ported and run: AiHeroRules 111 / 2,588, EnemyAdventureRules 43 / 1,182, ArtifactRules 37 / 629, OverworldRules
  23 / 387, ContentService 22 / 178, EnemyTurnRules 18 / 219, HeroCommandRules 14 / 188, HeroProgressionRules 11 / 101,
  WaterTravelRules 8 / 58, FactionTownServices 6 / 84, 15 more scripts 37 / 452.

**Boundary.** The computer players' day is one native call: `EnemyTurnRules.run_enemy_turn` runs every faction turn,
`AiHeroRules.run_faction_turn` included. The session is a view through the port bridge. It loads lazily, once, and is
written back at the end. Until Phase 1's merge, the two battle entries are host targets (`gd::call_static`: write
back, run the GDScript, reload lazily): `AiHeroRules._simulate_battle` and `AiHeroRules._start_player_battle`, the
two callers of `BattleRules.create_battle_payload`, which is frozen battle code and takes no host wrapper. A path the port leaves out throws `state::NotPorted`, and the whole day's
computer turns run in GDScript from the state the day started from. Nothing may reach Godot before that: the native call
writes back only at its end, and what a pure host call wrote back is undone (4.1's merge below). After a full host call
it is a native failure, so shadow mode counts both. Switch `HEROES_NATIVE_TURN=gdscript|native|shadow`, log `HEROES_NATIVE_TURN_LOG`, registry
`core/port/turn_registry.cpp`, files `core/port/<script>_turn.cpp` (the claims note names each function's file).

**Slices.**
- 4.0, runtime on main first, with no behaviour change: a long call reads each value of a container from Godot once.
  A backed Dictionary went back to Godot on every lookup. A backed Dictionary or Array that a call keeps reading is
  filled instead, once the call has read it as often as it has entries. Done 2026-10-22 (main 13a7a0c9a source,
  c9c25b540 Windows binaries): native mode identical to main on the six seeds, core suite 17/17. Phase 3's calls are
  short, so whole games are not faster yet; the long calls of 4.1 need it.
- 4.1, the computer players' day in one native call: the 330 not-ported functions the six seeds run (6,066 lines),
  calling Phase 3's ports and Phase 5's (from its merge), with battles as host targets and the other 201 not-ported
  functions throwing `state::NotPorted`. The bound on its gain: the turn's share outside battles, about 30% of match
  time, so at most 1.4x for whole games.
  Done 2026-10-22 on the branch (facf320a5 runtime, also for main; ea06c96e5 port; 6298dcb65 Windows binaries). In
  native mode (`HEROES_NATIVE_TURN=native`; GDScript stays the default until 4.4) the computer players' whole day runs
  native: 12,500 lines of C++ in `core/port/*_turn*.cpp` and `turn_*.cpp`. Checks, on main with Phases 5 and 1 merged
  (ade42f86e): native mode identical to main on the six seeds, no day falling back to GDScript; shadow mode on the six
  seeds and the two coverage seeds, 0 mismatches over 418 functions; core suite 17/17. Before Phase 1's merge, the
  codec round trip on all 415 days, 0 differences. Whole games, the six seeds' seconds summed, interleaved on a quiet
  machine: main 609 s (612, 606), native 418 s (420, 416), 1.46x. That is above the 1.4x bound above, because Phase 1's
  native battles shrank the battles' share of a match.
  - Battle previews are a pure host target (`TurnEngine.pure_host_call`, `port::Host::pure`, `Backing::call_pure`):
    the native call writes back, GDScript runs `_simulate_battle`, and the native call reads nothing again. A probe
    hashed every session field, the session's metadata, the three arguments and every static var of `scripts/core`
    around each GDScript preview. On the six seeds no field, metadata or argument changed, only nine caches built
    from content (six of the battle code's, `_damage_spell_memo`, `_unit_strength_memo`,
    `_runtime_normalized_signatures`). The six seeds make 1,536 previews in 1,432 faction turns (409 computer days,
    at most 14 a day). As full host calls (`HEROES_NATIVE_TURN_PREVIEW_HOST=full`) the six seeds take 464 s (467,
    462), 46 s (11%) more. `_start_player_battle` stays a full host call.
  - Coverage seeds (`rules_parity.py`, run only when `--seeds` names them): `isl-b` reaches `_hold_back` (an army saving
    for a boat, 13 checks), `pt-f` the random exits of one-way portals (`native_random_exit_check`,
    `note_native_trip`, 62 checks).
  - Shared with Phase 5: the 68 functions Phase 5's slice 09 calls or reaches are on main unswitched (aa9d9f2be,
    binaries 845b8a45e, with the runtime as 84082d9c1), moved unchanged from the turn files (672a4ee1f) to
    `core/port/<script>_shared.cpp`, declared in the per-script headers, their keys at the end of `ai_keys.inc`. Five
    of their callees are slice 09's and throw `state::NotPorted` from `phase4_shared_stubs.cpp` until it lands.
  - Merged to main 2026-10-22. Owner decision that day: merge 4.1 now; `HEROES_NATIVE_TURN` stays `gdscript` by
    default and AI batches run `native`; a day that reaches an unported path falls back to GDScript before its first
    write; two copies until 4.4 (AGENTS.md); Windows only, lean checks. Main was tagged
    `pre-native-phase4-faction-turn-4.1` first (D10).
    - The switch: the owner's games run GDScript until 4.4. `tools/ai_match_batch.py` runs its games with
      `HEROES_NATIVE_TURN=native` unless the environment names another mode, records the mode in `plan.json` and counts
      the `NATIVE FALLBACK` lines of each game.
    - The fallback: a `state::NotPorted` before the day's first full host call drops the native state, and the whole
      day runs in GDScript from the same session and random state. A preview still writes back first, since GDScript
      reads what the turn changed, but the bridge keeps what each container and static var held before the day's
      first write into it and puts it back (`PortBridge::undo_write_backs`). `TurnEngine.pure_host_call` no longer
      copies the view's fields into the session. The turn seeds its own random generators, so no generator state
      reaches Godot before the end. Each such day prints `NATIVE FALLBACK: <entry> ran in GDScript, not ported:
      <path>` and counts as not ported in the stats.
    - Proof: a probe build threw `state::NotPorted` right after the preview on every third day. s2, mw and mg-b were
      identical to main, with 58 days falling back. The same probe without the undo differed from main from day 6
      on mg-b.
    - After a full host call a `state::NotPorted` cannot fall back. The turn's one full host call is
      `_start_player_battle`, a computer hero's attack on a human's town. AI-vs-AI games never reach it:
      `AiSeatRules.hand_human_seat_to_ai` gives the human seat's towns to the computer and clears its heroes. The
      `_finalize_*` host calls in the stats belong to the battle port, inside the previews' scratch sessions.
    - Checks (e1aceebc2, binaries e5784932f): shadow mode on the six seeds and isl-b, pt-f, 2.32M checks over 418
      functions, 0 mismatches; native mode identical to main on the six seeds, no computer day falling back (the eight
      fallback lines are Phase 5's townless-player days); core suite 17/17; smoke batch (`ai_match_batch.py`, plan seed 16,
      day cap 120): seven games, small 2P twice, medium 2P and 3P, large 3P and 4P, XL 5P, four of them two-level and
      five with water (two islands). All seven finished, five decided and two at the cap; 0 failed, 0 script errors, no
      computer day falling back. Six days in five games ran Phase 5's townless-player path in GDScript (two calls
      each). The slowest computer day took 2.4 s, on XL. No new timing: the 1.46x above stands. It was measured
      before the undo, which copies each container a day's previews first write back.
- 4.2, the paths the six seeds do not run, so that no path of the day is left to GDScript. 4.1 leaves each to a
  `state::NotPorted` (4.4's run on the owner's save copies checks them):
  - the 165 functions in `turn_not_ported.cpp`: OverworldRules 45, EnemyAdventureRules 38, EnemyTurnRules 26,
    ScenarioRules 18, AiHeroRules 5 (`_upgrade_value`, `_attack_player_hero`, `_convert_legacy_host`, ...), 13 more
    scripts 33;
  - four guards: `sort()` of values that are not all Strings (EnemyAdventureRules, HeroCommandRules), `to_lower()`
    of non-ASCII text (EnemyTurnRules), a player town's weekly growth (`OverworldRules.town_weekly_growth`);
  - Phase 5's two in `normalize_ai_heroes`: an AI hero without its movement, a legacy raid host.

  Since 4.1's merge a `state::NotPorted` before the day's first full host call falls back, the previews' write-backs
  undone. After `_start_player_battle`, the one full host call, which only a human's town brings, it is a native
  failure. 4.2 ports each path, or a check before the day starts sends it to GDScript.
  4.2 also folds the 11 functions Phase 5 left with a private copy in Phase 3's AI files
  (`overworld_rules_ai_recovery.cpp`, `overworld_rules_ai_sites.cpp`).
  Done 2026-10-22 on the branch, after merging Phase 5's slice 09, which ported 23 of the 165 (7863c8d91 port, 0f513137a `normalize_ai_heroes`, the bridge and the fold, 9952a0f8c Windows binaries).
  - The other 142 functions: 139 ported and switched in the turn table, 3,650 lines in five new files
    (`enemy_adventure_rules_turn_rare.cpp`, `enemy_turn_rules_turn_rare.cpp`, `overworld_rules_turn_rare.cpp`,
    `scenario_turn_rare.cpp`, `turn_rare_paths.cpp`) and a few in the turn files. By script: OverworldRules 31,
    EnemyAdventureRules 31, EnemyTurnRules 26, ScenarioRules 17, AiHeroRules 5, ScenarioFactory 4,
    TownDevelopmentRules 4, and 11 more scripts 21. `turn_not_ported.cpp` is gone. `ScenarioRules._overworld_rules`
    returns a script and no C++ calls it, so it keeps its GDScript body.
  - The guards. A player town's weekly growth is ported: `_effective_player_town_weekly_growth` with
    `HeroProgressionRules.scale_recruit_growth`. Two guards stay `state::NotPorted`, because no game reaches them:
    - `sort()` of keys that are not all Strings. The keys are always Strings: recruit payloads convert them with
      `String()`, and the other dictionaries come from JSON or content.
    - `to_lower()` of non-ASCII text. Faction names and building labels in content are ASCII, and a player identity
      has no name, so its id is used.
  - `normalize_ai_heroes` (Phase 5's `enemy_states.cpp`, kept in two copies):
    - an AI hero whose movement is not a Dictionary gets `{current 0, max _movement_max}`;
    - a legacy raid host is converted;
    - a support column joins the nearest hero within 3 tiles or disbands.
  - The port bridge. An undoable write-back that sets an object view (a session's properties or metadata) cannot be
    put back. The call now counts as not undoable (`PortBridge::undo_lost`), so a later `state::NotPorted` is a
    native failure, not a fallback from a changed state. Phase 5 found the gap.
  - The fold. 17 private copies in Phase 3's AI files now call the real functions: 11 in
    `overworld_rules_ai_recovery.cpp` and 6 in `overworld_rules_ai_sites.cpp`. `_town_occupation_relief_per_day` no
    longer throws when it has no front. No caller reaches that branch: the only caller passes a front proxy. Three
    copies stay, because the real function differs on an input:
    - `find_encounter_by_placement`: Phase 5's version drops the movement debug profile, so it would not record into
      `_movement_rules_profile`;
    - `delivery_interception` and its `raid_strength`: Phase 5's `_army_strength` skips the unit-strength memo
      statics, which these copies fill as GDScript does.
  - Not wired, for 4.4. Phase 5's nine `missing_*` stubs in `overworld_forecast.cpp` are the command-risk forecast
    for a human's towns. They could now call 4.2's ports, but that would make those day paths native in the owner's
    games, which run the day native by default. The eight AI seeds cannot prove them.
  - Paths only a human player brings stay unproven until 4.4 runs the owner's save copies: a computer hero attacking
    a human's hero (`_attack_player_hero`), sightings of a human's heroes, and a human's towns.
  - Five of the 139 are also Phase 2a's claims: `encounter_display_name`, `_delivery_encounter_matches_node`,
    `_resource_site_delivery_interception`, `raid_display_name` and `raid_strength`. Whichever merges second calls
    the other's C++: 2a merged second and calls 4.2's.
  - Checks: shadow mode of the turn and day switches together, on the six seeds and isl-b, pt-f: 2,362,704 checks over 322 functions, 0 mismatches, 0 errors (the eight not-ported calls are Phase 5's townless-player days).
    - Native mode identical to main on the six seeds. No computer day fell back; the eight fallback lines are Phase
      5's townless-player days.
    - Core suite 17/17.
    - The seeds reach one of the 139 functions. One reviewer read the other 138, `town_weekly_growth`'s player
      branch and `normalize_ai_heroes` against their GDScript and found no divergence.
    - Smoke batch (`ai_match_batch.py`, plan seed 16, day cap 120, the same seven games as 4.1): all seven finished,
      five decided and two at the cap; 0 failed, 0 script errors, and no computer day fell back. The 12 fallback
      lines in five games are Phase 5's townless-player path. The slowest computer day took 2.6 s, on XL.
    - No new timing.
  - Merged to main 2026-10-22, after main was tagged `pre-native-phase4-faction-turn-4.2` (D10).
- 4.3, battles inside the turn with no host calls. Owner decision 2026-10-22: Phase 2 ports `_simulate_battle` as
  one native call (`ai_hero_rules::_simulate_battle`, `core/port/ai_battle_preview.cpp`, the signature 4.1's host
  target has); the turn calls it once it is on main. The start of a battle against a human calls Phase 1's native
  payload.
  Done 2026-10-22 on the branch, on main 618f11309 with Phase 2a (bd1a88620 port, 0bed12196 Windows binaries).
  - 2a's merge already made the turn call its preview directly and removed that host target.
  - `AiHeroRules._start_player_battle`, a computer hero's attack on a human's town or hero, is ported in
    `ai_hero_rules_turn_fights.cpp` and checked in the turn table. It calls 2a's `BattleRules.create_battle_payload`
    port with the session's view and sets the view's `battle` and `game_state`, which the turn writes back as it does
    every field. 2b is not needed: its payloads (a town assault, a defended site, a dwelling's guard) are the human's.
  - The turn calls no GDScript. The turn table has no hosts, `turn_hosts.cpp` and `.hpp` are gone, and `TurnEngine.gd`
    loses `host_point`, `host_call`, `pure_host_call` and `PURE_TARGETS`. One host call stays possible: with profiling
    on (`HEROES_PROFILE_LOG`), the payload's `ProfileLog.emit_general`, after which a `state::NotPorted` that day is a
    native failure, as in 2a's preview.
  - Checks:
    - A scratch probe (deleted): a generated small map with a human; a strong computer hero by the human's town
      (battle on day 1) and by the human's hero in the open (day 2). gdscript, native and shadow mode gave the same
      session, battle payload and turn result. Shadow: 3,461 checks over 197 functions, 0 mismatches, both
      `_start_player_battle` calls and the whole days checked (before 4.3 those days' checks stopped at the host call).
    - Turn shadow on the six seeds: 1,766,016 checks over 302 functions, 0 mismatches, 0 errors (the eight
      not-ported calls are Phase 5's townless-player days). AI-only games never start a battle against a human.
    - Native mode identical to main on the six seeds; core suite 17/17.
  - Merged to main 2026-10-22, after main was tagged `pre-native-phase4-faction-turn-4.3` (D10).
- 4.4, the exit:
  - delete the replaced GDScript; callers outside the turn (UI, day processing, battles) keep a thin wrapper or the
    GDScript copy under the two-copies rule (AGENTS.md);
  - owner-approved save copies through the codec (D9);
  - the six-seed check, the core suite and whole-game timing;
  - main tagged (D10), then the merge.

  Done 2026-10-23 on the branch, on main bf208b7b0 with Phase 2b (157138710 source, effbae9ba Windows binaries).
  - The turn runs native in every game. `HEROES_NATIVE_TURN` and its gdscript and shadow modes are gone, as
    `HEROES_NATIVE_AI` went with Phase 3. `EnemyTurnRules.run_enemy_turn` is a wrapper over its port, and `TurnEngine.gd`
    keeps only `native_writing`. `tools/ai_match_batch.py` and `tools/native_battle_switch.py` no longer know the switch.
    The turn table no longer falls back. A path the port leaves out (4.2's two guards, which no content reaches) prints
    a SCRIPT ERROR, and the computer players' day leaves the session as it was.
  - The replaced GDScript is deleted: `scripts/core` loses 9,758 lines and gains 130.
    - 183 functions of the turn that nothing outside it calls: AiHeroRules 89, EnemyAdventureRules 46, EnemyTurnRules
      37, EnemyTownServices 5, and 5 more scripts 6.
    - 50 more functions whose last caller was that GDScript:
      - 42 of Phase 3's AiHeroRules wrappers (`_best_candidate`, `_in_hero_zone`, `_site_doors`, ...). Their entries
        leave `ai_registry.cpp`, and 22 stay.
      - four of Phase 3's two-copy functions (Phase 3, "AI targets").
      - four helpers.
    - 69 functions of the AI turn's scripts that GDScript outside the turn still calls are thin wrappers over their
      port: AiHeroRules 27, EnemyAdventureRules 28, EnemyTurnRules 13 and EnemyTownServices 1. Their callers are the
      UI, the GDScript copies of the day and battle code, and the test harness. With `run_enemy_turn` (listed under
      EnemyTurnRules) they are the turn table's 70 entries (456 before).
      - EnemyAdventureRules (28): `_ai_hero_task_finish_live_assignment`, `_apply_resource_site_artifact_reward_to_raid`, `_apply_resource_site_claim_recruits_to_raid`, `_apply_resource_site_spell_reward_to_commander`, `_break_dwelling_guard_by_raid`, `_enemy_hero_sighting_sources`, `_find_encounter_by_placement`, `_find_player_hero`, `_find_town_by_placement`, `_hire_dwelling_creatures_into_raid`, `_player_hero_snapshots_for_intercept`, `_preferred_commander_index_for_encounter`, `_secure_resource_target`, `_target_level`, `_town_controller_faction_id`, `_town_is_objective_anchor`, `advance_commander_record`, `commander_can_deploy`, `commander_display_name`, `commander_live_role_state`, `commander_recent_outcome_brief`, `commander_target_memory`, `raid_commander_display_name`, `raid_display_name`, `raid_strength`, `select_raid_commander_roster_hero_id`, `sync_commander_state_to_roster`, `target_is_objective_anchor`.
      - AiHeroRules (27): `_choose_plan`, `_convert_legacy_host`, `_cuts_a_way`, `_desired_hero_count`, `_ensure_starting_hero`, `_find_town`, `_follow_plan`, `_gate_fight_looks_good`, `_govern_towns`, `_hostile_hero_beside`, `_mark_resolved`, `_nearest_hero_index`, `_new_context`, `_record_hero_defeat`, `_return_troops_to_nearest_town`, `_reveal`, `_roster_progression_seed`, `_start_heroes_day`, `_take_artifact`, `_tavern_pool`, `_use_weights`, `_wait_by_home`, `ai_tavern_offer_ids`, `clear_shared_surfaces`, `faction_daily_income`, `hero_name`, `run_faction_turn`.
      - EnemyTurnRules (14): `_config_was_runtime_defaulted`, `_enemy_recruit_cost`, `_faction_capital_state`, `_faction_front_state`, `_latest_enemy_state`, `_max_active_raids_for_strategy`, `_owned_town_count`, `_raid_threshold_for_strategy`, `_town_name`, `_valid_enemy_faction_configs`, `active_raid_count`, `get_pressure`, `normalize_optional_hero_task_state`, `run_enemy_turn`.
      - EnemyTownServices (1): `visit`.
    - 203 functions of other scripts keep a GDScript copy for their callers outside the turn: OverworldRules 60,
      ArtifactRules 42, ScenarioRules 17, HeroCommandRules 16, HeroProgressionRules 12, and 16 more scripts 56. A
      behaviour change to one of them goes into both copies in the same commit (AGENTS.md). Their switches are gone.
      - OverworldRules (60): `_add_dwelling_town_growth`, `_apply_recruit_percent`, `_blocked_tile_index`, `_build_scenario_resource_states`, `_build_scenario_town_states`, `_command_risk_encounter_objective_item`, `_command_risk_pressure_objective_item`, `_delivery_encounter_matches_node`, `_effective_player_town_weekly_growth`, `_enemy_active_raids`, `_enemy_config_for_faction`, `_enemy_max_active_raids_for_strategy`, `_enemy_pressure`, `_enemy_raid_threshold_for_strategy`, `_find_active_town`, `_find_active_town_by_visit_context`, `_lock_town_occupation_reserves`, `_native_passage_endpoint_safety`, `_posture_label`, `_pressure_bonus_from_profile`, `_public_enemy_pressure_gain`, `_raid_target_is_objective_anchor`, `_release_town_occupation_reserves`, `_resource_site_delivery_interception`, `_resource_site_response_profile`, `_route_security_rating_for_hero`, `_rules_profile_add_ms`, `_rules_profile_set`, `_scenario_objective_met`, `_terrain_id_at`, `_terrain_name_at`, `_town_command_risk_consequence`, `_town_defense_summary`, `_town_front_after_control_change`, `_town_front_stabilize_days`, `_town_front_stabilizing_state`, `_town_is_objective_anchor`, `_town_occupation_after_control_change`, `_town_pressure_output`, `_town_role_pressure_bonus`, `_town_scaling_hero`, `_town_weekly_growth`, `apply_resource_site_disruption`, `apply_town_recovery_pressure`, `encounter_commander_name`, `encounter_commander_threat_label`, `encounter_display_name`, `invalidate_spatial_lookup`, `is_tile_explored`, `map_for_level`, `native_exit_roll_key`, `native_passage_travel_check`, `native_random_exit_check`, `note_native_trip`, `placement_level`, `town_capital_project_state`, `town_development_metrics`, `town_recovery_state`, `town_weekly_growth`, `transition_town_control`.
      - ArtifactRules (42): `_already_owned_message`, `_artifact_collection_note`, `_artifact_effect_line`, `_artifact_effect_summary`, `_artifact_equipped_note`, `_artifact_set_id`, `_artifact_source_contract`, `_artifact_source_runtime_policy`, `_artifact_spell_modifier_parts`, `_artifact_taxonomy_payload`, `_artifact_ui_summary`, `_draw_from_rarities`, `_equipment_slot_label`, `_first_empty_compatible_slot`, `_matching_artifact_source_contexts`, `_remove_artifact_from_inventory`, `_resource_display_name`, `_select_class_source_reward`, `_signed_amount_label`, `_source_record_guard_tier`, `_source_record_has_required_categories`, `_source_record_has_required_tags`, `_source_record_reward_categories`, `_stable_source_reward_index`, `_title_label`, `artifact_effect_summary`, `artifact_name`, `artifact_reward_role`, `artifact_set_runtime_state`, `artifact_slot_label`, `artifact_taxonomy`, `artifact_taxonomy_summary`, `claim_artifact`, `describe_artifact`, `equip_artifact`, `has_artifact`, `live_source_reward_tag`, `locate_artifact`, `owned_artifact_ids`, `remove_owned_artifact`, `select_live_source_reward`, `select_live_source_rewards`.
      - ScenarioRules (17): `_army_unit_count`, `_artifact_set_equipment_progress`, `_controlled_hero_army`, `_controlled_hero_state`, `_find_town`, `_hero_army_requirement_progress`, `_hero_progression_requirement_progress`, `_hero_stationing_progress`, `_map_exploration_progress`, `_player_knows_spell`, `_player_owns_artifact`, `_reserve_delivery_progress`, `_resource_site_control_progress`, `_resource_stockpile_progress`, `_titleize_token`, `_town_garrison_requirement_progress`, `_town_has_objective_building`.
      - HeroCommandRules (16): `_faction_creatures`, `_holder_stacks`, `_normalize_resources`, `_seeded_rng`, `_stack_slot_less`, `_starting_company_size`, `army_addition_split`, `build_recruited_hero`, `hero_recruit_cost`, `merge_stacks_into_army`, `scout_row_half_width`, `set_active_hero`, `starting_army_for_hero`, `tavern_offer`, `tavern_week`, `town_has_hall`.
      - HeroProgressionRules (12): `_add_experience`, `_apply_command_gain`, `_enqueue_choice_group`, `add_experience`, `advance_to_level`, `command_gain_stat`, `experience_for_level`, `experience_with_bonus`, `pending_choice_summary`, `pending_choices_remaining`, `rank_label`, `scale_recruit_growth`.
      - TownDevelopmentRules (9): `can_pay`, `construction_growth`, `offers`, `price`, `satisfies`, `trade_artifact`, `train_hero`, `upgrade_army`, `upgrade_cost`.
      - WaterTravelRules (7): `add_boat`, `any_boat_at`, `boat_by_id`, `build_boat`, `dock_blocker`, `free_boat_at`, `hero_at`.
      - OverworldTurnPlayback (5): `_actor_name`, `_visual_actor`, `action`, `move`, `visible`.
      - TownRules (5): `_school_spell_ids_for_town`, `_town_spell_school_access`, `accessible_spell_ids`, `current_spell_tier`, `spell_ids_through_tier`.
      - FactionTownServices (4): `perform`, `recruit_reward`, `unavailable_reason`, `week`.
      - ScenarioFactory (4): `_build_resource_states`, `_build_town_states`, `_copy_resource_runtime_metadata`, `_duplicate_dict`.
      - VisitBuildingRules (4): `_resource_text`, `_thousands`, `effect_summary`, `record_visit`.
      - CreatureDwellingRules (3): `guard_key`, `record_guard_result`, `take`.
      - ScenarioScriptRules (3): `_encounter_resolved`, `_hook_fired`, `build_script_state`.
      - SpellRules (3): `build_spellbook`, `learn_spell`, `mana_state`.
      - NativeTransitRules (2): `exit_order`, `resolve`.
      - PlayerIdentityRules (2): `config_for_controller`, `set_resource_controller`.
      - ScenarioSelectRules (2): `default_difficulty_id`, `normalize_difficulty`.
      - DifficultyRules (1): `adjust_enemy_pressure_gain`.
      - OverworldLevelRules (1): `view_level`.
      - ResourceNodePayloadRules (1): `mark_claimed`.
  - Phase 5's nine forecast stubs (`missing_*` in `overworld_forecast.cpp`) now call 4.2's ports. They cover a human's
    town under threat (its development, objective anchor and the raid commanders' labels), the computer players' raid
    threshold and limits, the town front, and the two authored defeat objectives.
    - The two objectives still leave the day to GDScript: `ScenarioRules._objective_met` leaves the archived authored
      scenarios' objective types to it.
    - The town front is reached only with `include_front`, which the forecast does not pass.
  - The owner's save copies (D9): five saves, 10 days each from where they were saved, with the human doing nothing
    and a battle against the human auto-resolved. In the autosave, a computer hero intercepts the human's hero on
    day 16.
    - Before the deletions, all GDScript (turn and day) and all native gave the same session and forecast every day.
    - Shadow of the turn and day switches: 69,837 checks over 338 functions, 0 mismatches.
    - The codec round trip of each stored payload and of the session each day: 0 differences.
    - Reached only there: `_attack_player_hero`, `_start_player_battle`, `_attack_town` (3 checks), `_note_sightings`
      (100), the snapshots of a human's heroes for sightings and intercepts, `_effective_player_town_weekly_growth`
      (8) and `_linked_player_town_bonus` (82).
    - After the deletions, the native turn gave the same 50 days again.
  - The saves do not reach the forecast stubs: no computer hero marches on a town the way legacy raids did. A scratch
    probe (deleted) built a threat on each save copy in memory: raids on a human town in sight, at its gates and in the
    fog, a siege, and a computer player's raid config.
    - The day's native normalize, its GDScript copy, day shadow and main's all-GDScript turn gave the same session,
      forecast and town front on all five saves.
    - Day shadow: 10 checks, 0 mismatches, none falling back to GDScript.
    - With the two authored objectives added, the native day falls back to GDScript on `_objective_met`, as on main.
  - Day processing's human-only fallbacks are unchanged. A player town's weekly growth
    (`OverworldRules._growth_tick_town`) and a townless human's warning run in GDScript and print a `NATIVE FALLBACK`
    line.
  - Checks: native identical to main on the six seeds; core suite 17/17.
  - Timing: Whole games, the six seeds' seconds summed, interleaved on a quiet machine (Phases 2 and 5 paused): main
    587 s and 586 s, the branch 391 s and 390 s, 1.50x. Main runs the GDScript turn by default; 4.1's 1.46x was native
    mode against it.
  - The Linux libraries in `bin/` wait for the Linux pass.
- Proof per slice: shadow mode on the six seeds; the codec round trip (`to_dict(from_dict(d)) == d`, types and key
  order) on every day of the six seeds; before each push, native mode against main on the six seeds and the core
  suite. Review: none under about 300 lines, otherwise one reviewer on the functions shadow mode did not reach.
  Whole-game timing runs interleaved (main, change, change, main) on a quiet machine: Phases 1 and 5 pause for it.

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

**Slice 08, the merge** (2026-10-22; owner decision 2026-10-22: "Phase 5 merges after its checks"; main tagged
`pre-native-phase5-day` at cf890f9c2 before the merge):
- The switch stays (coordinator, 2026-10-22). `HEROES_NATIVE_DAY` unset runs the day native, and so does an unknown
  value, with an error. `gdscript` is the owner's way back if the native day goes wrong in a real game. `shadow`, with
  `HEROES_NATIVE_DAY_LOG`, is the check. Every ported function keeps its GDScript body (`<name>__gd`) for the paths
  the port leaves to GDScript, so the switch costs almost nothing.
- Two copies: 359 functions have a C++ port that the day calls and a GDScript body that the paths the port leaves out,
  `gdscript` mode, the UI, human actions and battles call. A behaviour change to one goes into both copies in the same
  commit, plus one six-seed shadow run of the day switch (AGENTS.md). 63 of them are the shared helpers that Phase 3's
  AI port also calls, already under its rule. The 8 HeroProgressionRules functions marked "Phase 1's port, copied"
  above are also in Phase 1's branch. The slices' frozen lists end at this merge, but Phase 4's freeze (AGENTS.md)
  covers many of these functions until its own merge.
  - OverworldRules (126): `_add_recruit_growth`, `_add_resources`, `_advance_all_town_occupations`, `_advance_all_town_recovery`, `_advance_player_reserve_deliveries`, `_advance_town_occupation`, `_advance_town_recovery`, `_append_generated_body_tiles_to_blocked_index`, `_apply_hero_reveal`, `_apply_site_reveal`, `_blank_project_vulnerability_penalties`, `_blank_visibility_grid`, `_blocked_scenery_layer`, `_build_blocked_scenery_layer`, `_build_blocked_tile_index`, `_build_fog_payload`, `_build_scenario_army_state`, `_clear_resource_site_delivery`, `_command_risk_field_item`, `_command_risk_forecast`, `_command_risk_forecast_from_normalized_session`, `_command_risk_grade_label`, `_command_risk_items`, `_command_risk_logistics_items`, `_command_risk_objective_items`, `_command_risk_player_town_daybreak_contexts`, `_command_risk_posture_items`, `_command_risk_town_items`, `_compact_enemy_activity_events`, `_copy_resource_runtime_metadata`, `_copy_town_runtime_metadata`, `_count_grid`, `_describe_recruit_delta`, `_describe_resource_delta`, `_duplicate_visibility_grid`, `_end_turn_close_day`, `_end_turn_muster_summary`, `_end_turn_open_day`, `_end_turn_resolution_summary`, `_end_turn_town_economy_summary`, `_enemy_activity_line`, `_enemy_activity_public_text`, `_evaluate_scenario_state`, `_finalize_action_result`, `_find_encounter_by_placement`, `_find_town_by_placement`, `_fog_grids`, `_fog_grids_uncached`, `_fog_state_ready`, `_generated_body_tiles_for_placement`, `_grid_cell`, `_map_object_blocks_body_tiles`, `_map_object_footprint_origin`, `_map_object_for_resource_node`, `_map_object_world_body_tiles`, `_mark_runtime_normalized`, `_merge_visibility_grids`, `_migrate_generated_transit_meanings`, `_nearest_town_for_controller`, `_normalize_active_town_visit_context`, `_normalize_artifact_nodes`, `_normalize_command_briefing`, `_normalize_command_risk_forecast`, `_normalize_delivery_completion_counts`, `_normalize_enemy_states`, `_normalize_fog_of_war`, `_normalize_generated_runtime_materialization`, `_normalize_live_resource_stockpile`, `_normalize_recruit_payload`, `_normalize_resource_nodes`, `_normalize_scenario_resources`, `_normalize_scenario_state_rules`, `_normalize_town_front_state`, `_normalize_town_recovery_state`, `_normalize_towns`, `_normalize_visibility_grid`, `_player_hero_states`, `_player_heroes_daily_income`, `_project_dependency_ids`, `_project_player_town_at_daybreak`, `_raid_is_public`, `_reduce_command_risk_items`, `_refresh_all_player_heroes_for_new_day`, `_refresh_blocked_tile_index`, `_resolved_lookup_entry`, `_resource_keys_for_payload`, `_resource_node_blocks_body_tiles`, `_resource_node_has_runtime_object_contract`, `_resource_node_matches_controller`, `_resource_site_control_income_for_day`, `_resource_site_delivery_target_label`, `_resource_site_is_persistent`, `_resource_site_is_repeatable`, `_resource_site_weekly_recruits`, `_reveal_all_current_fog_sources`, `_reveal_current_fog_sources`, `_runtime_normalization_signature`, `_set_grid_cell`, `_short_player_text`, `_tile_key`, `_town_building_bonus_total`, `_town_capital_project_ids`, `_town_capital_project_recovery_relief`, `_town_capital_project_state`, `_town_command_risk_state`, `_town_matches_controller`, `_town_recovery_relief_rating`, `_weighted_recruit_value`, `_world_tiles_from_payload_array`, `apply_controlled_resource_site_musters`, `controlled_resource_site_income`, `derive_map_size`, `describe_enemy_activity`, `encounter_key`, `fog_for_level`, `held_site_vision_radius`, `hero_level`, `hero_position`, `is_encounter_resolved`, `is_tile_visible`, `is_weekly_growth_day`, `normalize_overworld_state`, `refresh_fog_of_war`, `resolved_encounter_lookup`, `resource_node_is_present`, `town_strategic_role`.
  - EnemyAdventureRules (67): `_active_commander_map`, `_ai_event_summary`, `_apply_commander_army_metadata`, `_apply_commander_memory_metadata`, `_apply_commander_record_metadata`, `_apply_commander_role_metadata`, `_army_continuity_status`, `_army_continuity_summary`, `_army_headcount`, `_army_strength`, `_base_enemy_army`, `_commander_renown_from_record`, `_commander_veterancy_rank_from_record`, `_faction_commander_ids`, `_fallen_hero_settled`, `_hero_starting_spell_ids`, `_is_army_continuity_payload`, `_merge_unique_strings`, `_normalize_army_payload`, `_normalize_command_payload`, `_normalize_commander_roster_entries`, `_normalize_commander_roster_entry`, `_normalize_commander_status`, `_normalize_enemy_hero_sighting_records`, `_normalize_enemy_progression`, `_normalize_enemy_scouted_target_records`, `_normalize_resource_defender_commander_states`, `_normalize_string_array`, `_normalize_town_defender_commander_states`, `_normalized_commander_army_continuity`, `_normalized_commander_memory`, `_normalized_commander_record`, `_normalized_commander_role_state`, `_normalized_commander_target_kind_counts`, `_normalized_specialty_focus_ids`, `_normalized_specialty_ranks`, `_placement_resolved`, `_preferred_enemy_specialty_id`, `_public_event_log_text`, `_public_reason_from_codes`, `_raid_is_public`, `_resolved_encounter_lookup`, `_resource_has_ai_defender`, `_sync_specialty_pick`, `_sync_unit_strength_memo`, `_town_has_ai_defender`, `_unit_strength_value`, `ai_public_event_log`, `ai_public_event_log_entry`, `ai_public_event_log_leak_check`, `build_raid_commander_state`, `build_roster_commander_state`, `commander_army_brief`, `commander_army_continuity`, `commander_army_status`, `commander_army_summary`, `commander_memory_brief`, `commander_memory_summary`, `commander_record_summary`, `commander_roster_for_faction`, `commander_veterancy_label`, `ensure_raid_army`, `normalize_all_commander_rosters`, `normalize_commander_roster`, `normalize_enemy_known_world_memory`, `normalize_raid_armies`, `sync_commander_army_continuity`.
  - HeroProgressionRules (33): `_build_choice_group`, `_distinct_specialty_count`, `_enqueue_missing_choice_groups`, `_merge_bonuses`, `_normalize_pending_choices`, `_normalize_specialties`, `_normalize_specialties_in`, `_normalize_specialty_id_list`, `_offer_order`, `_rank_bonuses`, `_rank_in_array`, `_reconcile_pending_choices`, `_resolve_bonus_key`, `_specialty_catalog`, `_specialty_is_available`, `_specialty_row`, `_sum_bonus`, `aggregate_bonuses`, `available_specialty_ids`, `choose_specialty`, `command_path`, `current_pending_choice`, `daily_income_bonus`, `ensure_hero_progression`, `growth_seed`, `has_specialty`, `mana_max_bonus`, `max_rank_for_specialty`, `max_specialties_per_hero`, `raw_pending_choices_remaining`, `specialties`, `specialty_definition`, `specialty_rank`.
  - ArtifactRules (22): `_append_inventory_artifact`, `_apply_bonus_payload`, `_artifact_exists`, `_artifact_is_owned`, `_artifact_spell_modifier_records`, `_blank_bonus_totals`, `_blank_equipped_slots`, `_compatible_equipment_slots`, `_first_empty_slot_from_candidates`, `_merge_resources`, `_merge_school_resistance`, `_register_equipped_candidate`, `_set_states_for_equipped`, `_string_array`, `aggregate_bonuses`, `artifact_set_insignia_state`, `artifact_set_record`, `artifact_slot`, `build_artifact_nodes`, `ensure_hero_artifacts`, `normalize_artifact_nodes`, `normalize_hero_artifacts`.
  - EnemyTurnRules (15): `_blank_resource_pool`, `_default_raid_encounter_ids_for_faction`, `_default_spawn_points_for_faction`, `_enemy_faction_config_with_runtime_defaults`, `_enemy_faction_configs_for_session`, `_enemy_faction_configs_with_runtime_defaults`, `_find_state`, `_normalize_enemy_states_body`, `_normalize_posture`, `_normalize_rebuild_pressure_request`, `_normalize_resource_pool`, `_normalize_string_array`, `_owned_town_entries`, `_town_controller_faction_id`, `normalize_enemy_states`.
  - HeroCommandRules (14): `_hero_index_by_id`, `_normalize_army`, `_normalize_authored_specialties`, `_normalize_movement`, `_normalize_player_hero`, `_normalize_town_garrison_heroes`, `_replace_hero_in_array`, `_sync_active_hero_mirror`, `active_hero`, `commit_active_hero`, `new_growth_seed`, `normalize_session`, `scout_row_half_width`, `scouting_radius_for_hero`.
  - NativeTransitRules (10): `_network_colour_key`, `_portal_contract_error`, `assign_network_colours`, `contract_error`, `is_dead_end`, `is_native`, `network_index`, `nodes_by_id`, `normalize_legacy_session`, `validate`.
  - PlayerIdentityRules (9): `controller_id`, `enemy_configs`, `faction_id`, `has_human_seat`, `identity_fields`, `normalize_compatibility`, `player`, `raid_controller_id`, `town_controller_id`.
  - GeneratedRewardRules (8): `_gate_site`, `_hash32`, `_node`, `_pick`, `_roll`, `boat_tile`, `is_skipped`, `resolve`.
  - OverworldLevelRules (8): `canonical_spatial_records`, `hero_level`, `level_count`, `level_of`, `on_level`, `position`, `query_level`, `town_entrance`.
  - DifficultyRules (6): `_default_difficulty_id`, `_scale_amount`, `normalize_difficulty`, `normalize_session`, `scale_income_resources`, `scale_resource_payload`.
  - ScenarioRules (6): `_objective_met`, `evaluate_session`, `normalize_scenario_state`, `objective_definitions`, `objectives_for_session`, `scenario_record_for_session`.
  - CommonMineRules (5): `block_tiles`, `body_tiles`, `entry_tile`, `origin`, `resource`.
  - ScenarioScriptRules (5): `_join_messages`, `_retry_pending_reinforcements`, `_sorted_hooks`, `normalize_script_state`, `process_hooks`.
  - SpellRules (5): `_normalize_spell_ids`, `ensure_hero_spellbook`, `mana_max_from_command`, `mana_max_from_hero`, `refresh_daily_mana`.
  - AiHeroRules (4): `active_hero_count`, `is_ai_hero`, `migrate_legacy_raids`, `normalize_ai_heroes`.
  - PlayerEliminationRules (4): `applies`, `apply_daily`, `heroes_held`, `towns_held`.
  - GeneratedScenarioObjectiveRules (3): `definitions`, `progress`, `uses_kind`.
  - MineRules (3): `block_tiles`, `origin`, `resource`.
  - ScenarioFactory (2): `_build_army_state`, `_normalize_resources`.
  - TownDevelopmentRules (2): `convert_reserves`, `migrate_town`.
  - SessionStateStore (1): `normalize_launch_mode`.
  - WaterTravelRules (1): `normalize`.
- Not folded: 11 of them also have a private copy in Phase 3's AI port (`overworld_rules_ai_recovery.cpp`,
  `overworld_rules_ai_sites.cpp`): `_describe_recruit_delta`, `_find_encounter_by_placement`,
  `_nearest_town_for_controller`, `_normalize_town_front_state`, `_normalize_town_recovery_state`,
  `_sync_unit_strength_memo`, `_town_building_bonus_total`, `_town_capital_project_recovery_relief`,
  `_town_matches_controller`, `_town_recovery_relief_rating`, `_weighted_recruit_value`. Slices 02 and 06b planned to
  fold them here. They stay apart because the day's versions leave odd values to GDScript (`gd::stringify_or_fallback`,
  `state::NotPorted`), and in an AI call that fails the call. Phase 4, whose one call runs both, folds them; until then
  a change to one of them goes into all three copies.
- Checks on the merge form:
  - A human seat. A generated medium map with 3 players, played for 12 days through `OverworldShell`: each day the
    human builds, recruits and walks a hero, then ends the turn through the confirmation. Run on main, and on the
    branch in shadow and in native mode: the session was identical to main's after every action and every end of day
    (23 digests). Shadow made 1,139 day checks with 0 mismatches. The human paths the port leaves out ran their
    GDScript: the action result and its scenario check, 136 calls each; the day's close, 11; a player town's growth, 1.
  - The end-turn confirmation's dry run (`OverworldShell._current_end_turn_warning`) never changed the session, in
    any of the 39 dry runs, nor did cancelling it. Sessions are views and no native state outlives a call, so there
    is nothing for it to invalidate.
  - Save and load, both ways. Main and the branch each saved on day 6, and each build loaded both saves and played on
    to day 12. All four games were identical at every step, and the two saves differ only in `saved_at_unix`.
  - The edge cases the slices left to GDScript, on a small 2-player map, in shadow and native mode against main, all
    identical: the human's towns given to the rival (9 days townless, with a battle), the rivals' towns given to the
    human (the scenario completes on the first action), and non-ASCII town and hero names.
  - After merging main's container fill (Phase 4, slice 4.0), shadow on the six seeds: 19,826 day checks, 0
    mismatches, 0 errors; 4 computer-player removals left to GDScript (slice 05).
  - Native mode, the default, against main cf890f9c2: identical on 6/6 seeds (415 daily digests and the match
    records). Core suite 17/17 on Windows. The Linux libraries in `bin/` wait for the Linux pass; a Linux build needs
    them, as it has since Phase 3 for the AI.
- Speed. Whole games on the six seeds, against main cf890f9c2. Six at once with the editor binary, in the order main,
  change, change, main, with Phases 1 and 4 paused. A process sampler saw no other Godot process at any sample;
  Defender, the desktop app and Explorer briefly passed 20% of a core, and the System process took about 1.6 cores
  while games ran. Results: 690, 651, 663 and 686 s, so 688 s on main and 657 s with the day native (1.05x, 4.5% less
  time). l1 180 and 180 s to 173 and 176 s; l2 179 and 180 s to 172 and 175 s. The six games' wall time, set by the
  slowest, went from 181 s to 174 to 177 s. Slice 07's 1.08x was measured beside another session's run.

**Slice 09, frozen functions** (2026-10-22, until slice 09 merges; AGENTS.md; branch `native-phase5-finalize`): the ends
of a human battle, Phase 1's eight host targets `BattleRules._finalize_victory`, `_finalize_player_battle_loss`,
`_finalize_stalemate`, `_finalize_enemy_withdrawal`, `_finalize_retreat`, `_finalize_surrender`,
`_retreat_action_summary` and `_surrender_action_summary`, and the functions slice 09 ports with them: 166 functions
(the Phase 4 ports they call and ContentService's lookups aside). BattleRules 97: `_add_enemy_treasury_resources`,
`_adjust_enemy_pressure`, `_apply_active_hero_aftermath_losses`, `_apply_battle_context_stalemate`,
`_apply_battle_context_victory`, `_apply_collapse_aftermath`, `_apply_collapse_recovery_pressure`,
`_apply_delivery_route_aftermath`, `_apply_encounter_victory_flags`, `_apply_enemy_commander_battle_memory`,
`_apply_enemy_victory_specialties`, `_apply_front_pressure_shift`, `_apply_player_battle_salvage_reward`,
`_apply_town_assault_recovery`, `_apply_town_defense_recovery`, `_apply_victory_front_aftermath`, `_apply_victory_mana`,
`_apply_victory_recovery`, `_apply_withdrawal_aftermath`, `_apply_withdrawal_recovery_pressure`,
`_army_strength_from_stacks`, `_army_totals`, `_award_commander_experience`, `_battle_aftermath_artifact_summary`,
`_battle_aftermath_display_outcome`, `_battle_aftermath_force_summary`, `_battle_aftermath_result_summary`,
`_battle_aftermath_return_summary`, `_battle_aftermath_reward_summary`, `_battle_aftermath_side_force_clause`,
`_battle_aftermath_world_summary`, `_battle_context_controller_id`, `_battle_context_resource_placement_id`,
`_battle_context_town_placement_id`, `_battle_context_trigger_faction_id`, `_battle_enemy_faction_id`,
`_battle_enemy_label`, `_battle_exit_animation_snapshot`, `_battle_report_casualty_ledger`,
`_battle_report_side_casualties`, `_battle_resolution_static_encounter_snapshot`, `_battle_survivor_stacks`,
`_battle_victory_rewards`, `_beaten_enemy_stacks`, `_build_collapse_aftermath_preview`,
`_build_withdrawal_aftermath_preview`, `_capture_town_after_assault`, `_casualty_units_from_ratio`,
`_clamped_resource_loss`, `_collapse_resource_summary`, `_current_battle_encounter_placement`,
`_enemy_commander_exit_reaction`, `_enemy_commander_rivalry_context`, `_enemy_commander_state_for_force_sync`,
`_enemy_commander_state_with_payload`, `_enemy_state_exists`, `_finalize_enemy_withdrawal`,
`_finalize_player_battle_loss`, `_finalize_primary_defeat`, `_finalize_retreat`, `_finalize_secondary_hero_defeat`,
`_finalize_stalemate`, `_finalize_surrender`, `_finalize_town_defense_loss`, `_finalize_victory`,
`_find_encounter_by_key`, `_find_town_at_position`, `_find_town_by_placement`, `_finish_enemy_battle_task_assignment`,
`_is_resource_assault_context`, `_keep_enemy_hero_after_town_capture`, `_mark_resolved_encounter`,
`_normalize_presentation_speed`, `_normalize_stack_animation_states`, `_record_battle_aftermath`,
`_record_enemy_commander_battle_continuity`, `_remove_hero_by_id_after_defeat`, `_remove_units_from_stacks`,
`_resolve_enemy_commander_aftermath`, `_retreat_action_summary`, `_set_enemy_siege_progress`, `_set_player_hero_state`,
`_side_faction_id`, `_stabilize_hostile_town_front`, `_stack_count_total`,
`_station_enemy_commander_after_town_capture`, `_surrender_action_summary`, `_sync_enemy_force_from_battle`,
`_sync_player_force_from_battle`, `_synthetic_battle_encounter_placement`, `_titleize_token`,
`_town_assault_recovery_pressure`, `_town_defense_recovery_pressure`, `_town_name`, `_town_name_from_placement_id`,
`_withdrawal_preview_summary`, `_withdrawal_resource_summary`. OverworldRules 41: `_apply_artifact_claim`,
`apply_delivery_interception_outcome`, `apply_reward_bonus`, `_army_strength_value`,
`capture_dwelling_after_guard_victory`, `capture_resource_after_defender_victory`, `capture_town_by_placement`,
`_claim_town`, `_clear_resource_ai_defender_metadata`, `_deliver_reinforcements_to_hero`,
`_deliver_reinforcements_to_town`, `_describe_reward_delta`, `_enemy_state_for_faction`,
`_find_resource_node_by_placement`, `_movement_max_from_hero`, `_normalized_enemy_front_faction_id`,
`_readiness_bonus_from_profile`, `_record_successful_reserve_delivery`, `_resolve_player_reserve_delivery`,
`_retake_front_from_legacy_state`, `_return_reinforcements_to_source`, `_scenario_town_started_enemy`,
`_spend_resources`, `_split_recruit_payload`, `stabilize_town_front`, `_stacks_to_recruits`, `_sync_movement_to_hero`,
`_teach_visiting_town_spells`, `_town_battle_readiness`, `_town_front_priority_seed`, `_town_front_state`,
`town_front_state`, `_town_garrison_headcount`, `_town_garrison_strength`, `_town_occupation_seed_pressure`,
`_town_reinforcement_quality`, `_town_role_quality_bonus`, `_town_role_readiness_bonus`, `_town_spell_tier`,
`update_dwelling_guard_after_battle`, `update_resource_defender_after_battle`. EnemyAdventureRules 13:
`_active_resource_defender_entry`, `_active_town_defender_entry`, `_ai_hero_task_prune_live_tasks`,
`_ai_hero_task_retention_priority`, `apply_resolved_commander_aftermath`, `_clear_resource_defender_metadata`,
`_clear_town_defender_metadata`, `commander_renown`, `is_active_pressure_host`,
`_normalize_resource_defender_commander_states`, `_normalize_town_defender_commander_states`, `record_rivalry`,
`record_target_assignment`. HeroCommandRules 5: `active_hero_is_primary`, `hand_over_primary`,
`keep_hero_troop_from_garrison`, `remove_active_hero_after_defeat`, `_set_holder_stacks`. ScenarioRules 3:
`_complete_session`, `_merge_result_messages`, `_resolution_text`. PlayerIdentityRules 2: `defender_controller_id`,
`from_slots`. ArtifactRules 1: `_select_rarity_source_reward`. CreatureDwellingRules 1: `placement_from_guard_key`.
DifficultyRules 1: `scale_reward_resources`. PlayerEliminationRules 1: `human_has_nothing_left`. TownRules 1:
`teach_visiting_heroes`. `OverworldRules._collect_resource_node_result`, a site's visit after its guards or defenders
are beaten, stays GDScript until site visits are ported: the battle table's one host target (coordinator, 2026-10-22).
An AI battle preview never reaches it (its scratch session has no resource nodes). Phase 4's freeze covers some of them
too.

**Slice 09, the battle ends** (2026-10-22, branch `native-phase5-finalize`; runtime on main as its own commits
f3747fa49, an object's view, and d634dbf40, a natively made typed Array's script): the eight host targets leave the
battle table's host list and join its ports, 718 with one host target, `OverworldRules._collect_resource_node_result`.
The battle ends take the session as its view and call the other 69 functions natively, unswitched. Phase 4's TownRules
spell lists and `SpellRules.learn_spell` are shared in `town_rules_shared.cpp` and `spell_rules_shared.cpp`, and the turn
calls 23 of the 69 that were stubs in `turn_not_ported.cpp`. The frozen list ends at the merge: the 97 BattleRules functions
keep two copies with the rest of the battle table, and the other 69 keep their GDScript bodies for their GDScript callers
(AGENTS.md). Checks: the twelve ends of a human battle on a small map (victory, loss, retreat, surrender, stalemate, enemy
withdrawal, town assault, dwelling guard, resource defense, a town assault retreated from and stalemated, a resource
defense lost) in shadow 27,928 checks, 0 mismatches, native results identical; shadow of the battle switch on the six
seeds 77,335,601 checks, 0 mismatches (`_finalize_victory` 1,077 calls, `_finalize_player_battle_loss` and
`_finalize_primary_defeat` 16); shadow of the day switch on the six seeds 14,882 checks, 0 mismatches (l1 and l2
after merging main's slice 4.1); after that merge, shadow of the turn switch 1,769,088 checks, 0 mismatches, and
native mode against main 80042d9e4 identical on 6/6 seeds; core suite 17/17 (Windows; the Linux libraries in `bin/` wait for
the Linux pass).

**Slice 10, the day check** (2026-10-23, branch `native-phase5-day-validate`; owner decision 2026-10-22): the day
switch's shadow check is the validating check of the battle switch (and of the turn switch until slice 4.4). A writing
day function's native port runs first, on the arguments themselves and writing nothing back
(`AurelionRules.port_validate_begin`), then its GDScript body, and `port_validate_end` compares the result and what the
port loaded or set; every open check reads one view per session, brought up to date before each check, as the turn
switch's did (`tools/native_battle_switch.py`: the day subsystem validates). Before, `DayEngine.before_writing` copied
every argument for the native port (`port_copy`, the whole session view: about 1.64M values on l1 by day 90) and the
check compared both whole views with `var_to_bytes`. A path the port leaves to GDScript still skips the check. Native
and gdscript mode are unchanged; `port_copy` and `port_report` have no caller left. Checks: a probe that planted a
result and an argument difference in `_end_turn_open_day`'s GDScript body, 32 mismatches reported and the run failed;
the day and turn switches in shadow together on s2, 599 day and 66,094 turn checks, 0 mismatches; day shadow on the six
seeds 8,738 checks, 0 mismatches, the same checks per function as main's copying check (all three on main 618f11309); on
main 2a154550b day shadow on the six seeds 6,989 checks, 0 mismatches (4.4's native turn calls the day ports in C++),
native mode identical to main on 6/6 seeds, core suite 17/17. Day shadow per seed on 618f11309, in seconds, run new,
main, new, main, six seeds at once, measured under load (Phase 2's and Phase 4's checks ran beside it): s2
34/236/25/170, mw 120/1,199/98/1,011, mg-b 215/1,896/187/1,702, mg-a 313/2,467/266/2,287, l1 474/3,567/381/3,217, l2
597/3,933/466/3,534; main/new 6.9x to 10.1x per seed, 7.9x in total.

### Phase 6: match throughput

The runner keeps a native session handle across days and writes Dictionaries back only for the digest and record (with
a check that runner mode and game mode give the same digests); several matches per Godot process (match N identical in a
reused and a fresh process); a pre-generated map corpus for genetic-algorithm work. The GDScript parts do not need C++
and move forward if G0 finds a high fixed cost. **Whole-game genetic algorithms become practical here, if the measured
gain is there.**

**Profile** (2026-10-23, main bb79014da, seeds s2, mw, mg-b and l1, four at once on a quiet machine, scratch timers in
the runner and a scratch timer build of the bridge, which adds 4%, so its splits are ranges):
- The same four games take 205.4 s in `rules_parity.py` and 89.5 s as `tools/ai_match_batch.py` plays them (no
  per-day digest). The digest, `JSON.stringify` of the whole session plus sha256, is 56% of every parity and timing
  run. The session's JSON is 2 to 20 MB a day; about 75% of it is map package data, and the 5.0 MB runtime scenario
  record is held twice, in `overworld` and in `flags`.
- An owner-batch match, 89.5 s:

  | Part | Seconds | Share |
  |---|---|---|
  | The computer players' turn | 38.89 | 43.4% |
  | The day close | 15.35 | 17.1% |
  | Start-up per Godot process | 17.80 | 19.9% |
  | Map generation and package | 9.96 | 11.1% |
  | Session adoption | 2.89 | 3.2% |
  | Other setup | 1.45 | 1.6% |
  | Runner bookkeeping per day | 2.29 | 2.6% |
  | The day open | 0.72 | 0.8% |
  | The record | 0.16 | 0.2% |

- Start-up per Godot process is about 4.4 s: Godot itself 0.1 s, GDExtensions and autoload scripts 0.9 s, compiling
  the runner's script closure 2.1 s, content validation 0.5 s, and process start and exit. That is 50% of an s2 match
  and 12% of l1.
- Native rules against the bridge (loads, lazy fills, exports, write-backs, statics, content lookups, `begin`):
  - The turn: native 52-57%, bridge 43-48%.
  - The day close: bridge 68-73%.
  - No host calls into GDScript during the day.
  - Over a match: bridge 31-34%, native rules work 27-30%.

**Slices** (owner decision 2026-10-23: P6-5 first, then P6-3 and P6-4; P6-1 and P6-2 later; Windows only, lean checks).
Each slice merges to main on its own, the C++ ones with main tagged first (D10). The code stays portable and adds no
Godot dependency, since these slices lead to Phase 8. The bound is 1/(1 - share).

| Slice | Change | Share | Bound |
|---|---|---|---|
| P6-5 | The runner's per-day digest becomes the Variant hash of the session instead of sha256 of its JSON: Godot's `hash()` in the game, `gd::hash` (the C++ copy) in runner mode and Phase 8. The JSON stays for the dump day. | 56% of checks | 2.3x on checks |
| P6-3 | `end_turn` as one native call (done: 1.11x measured; `begin` needed no change) | about 14% | about 1.16x |
| P6-4 | The native session kept across days; runner mode and game mode give the same digests (done: 1.19x measured; write-backs, content lookups and the compaction stay) | 31-34% | 1.45-1.52x |
| P6-1 | Several matches per Godot process (done: 1.26x on the six seeds one after another, 1.49x on a small-map batch) | 19.9% (s2 50%) | 1.25x (s2 2.0x) |
| P6-2 | A map corpus, with the adopted session kept per process (done: 1.20x from the corpus and 1.38x from the kept session on the six seeds in one process, 1.09x on a small-map batch) | 8.3-14.4% | 1.09-1.17x |
| P6-6 | The generator takes a faction per seat ("random" drawn from the map seed); `ai_match_batch.py --rotate` plays one map in every seat rotation, generating it once (done: a rotation's generation 4.4-6.1x faster on small maps, 12-31x on extra large) | generation | |
| P6-7 | Skirmish opponents' factions drawn from the map seed by default; the human keeps their pick or Random (done) | | |

- Checks per C++ slice: shadow on the six seeds while working; before pushing, native against main on the six seeds and
  the core suite, plus P6-4's runner-mode against game-mode digests; timing on a quiet machine with Phases 2 and 5
  paused.
- A runner without Godot (Phase 8) still needs native content tables, the copied Variant hash, package-to-session
  adoption, D4 math, GDScript statics as native state and the runner's setup.

**P6-5, the digest as the Variant hash** (`native-rules-phase6-p5-variant-digest-20261023`, branch
`native-phase6-digest`):
- **What changed.** The match runner writes `day<TAB>digest` each day: the Variant hash (`hash()`) of the header
  fields, overworld, battle and flags, 8 hex digits each. The dump day still writes the full JSON.
  `tools/rules_parity.py` reads both formats; two sides with different formats compare their records only and never
  count as identical.
- **No native change.** The game hashes with Godot's `hash()`, and the rules library's `gd::hash` already copies it for
  runner mode and Phase 8.
- **Checks:**
  - Scratch probe, on a small 2P map (5 days) and a large 4P two-level map (3 days), 68 checks, 0 failures:
    - `gd::hash` gives `hash()`'s value on every part every day. The sessions hold only Dictionaries, Arrays, Strings,
      ints, floats and bools.
    - One planted value at a time changes only its part's digest, and restoring it gives the old digest back: a town's
      `x`, a flag, a computer hero's army count, its commander's experience, an int turned float, and the last bit of
      a float.
  - Six seeds against main 2dfcc8d15: identical match records and final days. The 415 daily digests were not
    compared, since their formats differ.
  - A second run of the six seeds: all 415 daily digests and the records identical to the first.
  - Core suite 17/17.
- **Timing:** the six seeds took 204 s in one run on a quiet machine. 4.4's last measurement with the JSON digest,
  on an older main, was 391 s; the two runs were not interleaved.

**P6-3, one native call per day** (`native-rules-phase6-p3-day-call-20261023`, branch `native-phase6-day-call`):
- **What changed.**
  - `OverworldRules.end_turn` is a day port entry (`day_registry.cpp`, the composite in `day_boundary.cpp`):
    `_end_turn_open_day`, `EnemyTurnRules.run_enemy_turn(session, false)` and `_end_turn_close_day` in one native
    call, with the standard day switch (`tools/native_battle_switch.py`). The session loads once a day, and the
    open day's result and the turn's result stay native.
  - The turn makes no host call, so a path the day port leaves to GDScript, anywhere in the day, undoes the whole
    call. The switch then runs the three parts, as before. Human games reach such paths mostly in the day open
    (a player town's weekly growth, a convoy's arrival), before the turn runs.
  - `State`'s memo hash is `noexcept`: MSVC's `clear()` of the memo then costs its size, not its bucket count, which
    stays as large as the biggest call made it. The memo is cleared at every call's start and after a watched write
    inside a call.
  - `PortBridge::begin` stays as it was. The profile's 330 µs per small call came from its timer build. A scratch
    probe on l1 (days 16 to 25, 2,780 `AiHeroRules.hero_power` calls after the day calls) measured 28 µs a call, and
    65 µs for the first call after a day, with main's library and with this one.
- **Checks:**
  - Day shadow on the six seeds: `end_turn` 405 checks, 0 mismatches, 0 errors; no function with a mismatch or error.
    Four days are not ported: a player's elimination ("a player whose townless days are up", already left to
    GDScript on main). On those days the call is undone and the three parts run, so the turn runs twice.
  - Six seeds native against main 61e73a38c: all 415 daily digests and the match records identical, the four
    fallback days among them.
  - Core suite 17/17.
  - After merging main b49d1bcc9 (Phase 2c) and rebuilding: six seeds against it identical again, core suite 17/17.
- **Timing** (the six seeds as `tools/ai_match_batch.py` plays them, no per-day digest, six at once, three rounds
  alternating main 61e73a38c and P6-3 on a quiet machine):

  | | Wall | Sum of the six runs |
  |---|---|---|
  | main (the baseline for P6-3 and P6-4) | 46.2 s, 46.2 s, 46.2 s | 180.6 s, 179.5 s, 176.6 s |
  | P6-3 | 42.2 s, 42.2 s, 41.2 s | 162.5 s, 161.4 s, 160.5 s |

  1.11x on the summed runs (9.7% less), against the 1.16x bound. Every seed was faster in every round (l1 43 s to
  38–39 s, s2 10 s to 9 s).

**P6-4, the native session across days** (`native-rules-phase6-p4-session-handle-20261023`, branch
`native-phase6-session-handle`):
- **What changed.**
  - `AurelionRules.port_session_call` runs a port with write-back on a bridge of its own that keeps the session from
    one call to the next (`PortBridge::begin_kept` and `keep`). `keep` writes back and exports the result. Then
    `State::compact` keeps the nodes that the arguments and the content rows reach, moved down and renumbered, each
    now a clean loaded node of its container, and drops the rest. The next call finds every container it loaded before
    as the same node, filled as far as it was, and reads none of it again.
  - Between calls only GDScript changes the containers: `port_session_reread` backs a container's node by it again.
    What the session kept is dropped, and the next call loads everything again, after any of these:
    - another port call that writes into a container or runs GDScript at a host call;
    - a session call that fails or falls back to GDScript;
    - a full `State` or a changed content revision.
  - `DayEngine.session_calls` names the functions that run on the session. The match runner puts
    `OverworldRules.end_turn` there and rereads the flags after it empties the decision log;
    `HEROES_AI_MATCH_KEEP_SESSION=0` loads the session every day, as the game does. The game does not change.
  - The day still writes back what it changed every day, since the runner reads the session every day for its ledger.
- **Why the bound is not reached.** Scratch timers on mw and mg-b, the day call in game mode against kept mode:
  - fills and host lookups fell from 2.15 s to 0.21 s (mw) and from 4.00 s to 0.43 s (mg-b);
  - the write-back (0.45 s and 0.82 s), content lookups and one static read on day 2 (1.1–1.3 s, every mode) stay;
  - `keep` adds 0.38 s and 0.74 s (compaction, adopting the exported nodes, renumbering sources and identities): a
    day makes 60,000–150,000 containers and keeps about 10,000–14,000.
  - The day call fell 25% (mw, 7.74 s to 5.77 s) and 20% (mg-b, 14.58 s to 11.59 s); s2 did not change.
- **Checks:**
  - Six seeds, runner mode against game mode in this tree (`HEROES_AI_MATCH_KEEP_SESSION=0`): all 415 daily digests
    and the match records identical, the four fallback days among them.
  - Six seeds native against main 6e490c9e2: all 415 daily digests and the records identical.
  - Day shadow on the six seeds: `end_turn` 405 checks; all functions 7,394 checks, 0 mismatches, 0 errors, 12 not
    ported (the elimination days, as on main).
  - Core suite 17/17.
  - After merging main eda1a4de9 (Phase 2d): six seeds against it identical, core suite 17/17.
- **Timing** (as for P6-3: the six seeds as `tools/ai_match_batch.py` plays them, six at once, three rounds alternating
  main 6e490c9e2 and P6-4 on a quiet machine):

  | | Wall | Sum of the six runs |
  |---|---|---|
  | main (P6-3) | 43.2 s, 43.2 s, 43.2 s | 166.5 s, 168.6 s, 168.5 s |
  | P6-4 | 36.2 s, 36.2 s, 37.1 s | 140.5 s, 140.4 s, 143.4 s |

  1.19x on the summed runs (15.8% less), against the 1.45-1.52x bound. Every seed was faster in every round
  (s2 10 s to 9 s, mw 16-17 s to 14 s, l1 39-40 s to 33-34 s, l2 43 s to 36-37 s).

**P6-1, several matches per Godot process** (`native-rules-phase6-p1-matches-per-process-20261023`, branch
`native-phase6-matches-per-process`):
- **What changed.**
  - The match runner plays a list of matches in one process (`HEROES_AI_MATCH_LIST`: a JSON array whose entries hold
    one match's `HEROES_AI_MATCH_*` settings in place of the environment's). Each match prints a BEGIN line and its
    report line, which now carries the match's own seconds; a failed match no longer quits the process, and the next
    one plays. Between matches the runner closes the digest file, takes `OverworldRules.end_turn` out of
    `DayEngine.session_calls`, closes the native session on every exit path, and clears the generated drafts and
    content overrides; the native port's failures count from the match's start (`port_stats` is per process).
  - `tools/ai_match_batch.py` plays up to `--per-process` matches per Godot process (default 4), fewer when the queue
    is short enough that more would leave slots idle at the end. The process log is split per match at the BEGIN
    lines; a match the process never began, after an earlier one crashed or timed out, goes back into the queue.
  - `tools/rules_parity.py`: `run --one-process` and `check --one-process-a/-b` play a side's seeds in one process.
  - No native change and no game change.
- **What a second match could inherit** (an audit of the 247 static vars, the autoloads, the statics the native port
  reads and writes, and random number use):
  - Content memos are keyed by the content revision or by their sources, and the revision goes up at every match's
    start. Per-day AI caches are cleared at both ends of every computer turn.
  - The AI weight statics hold the last seat's set until a faction turn applies its seat's set again, before any
    read, exactly as one seat's set replaces another's within a match; a batch gives every match the same weights.
  - The other per-session statics (normalize signatures, town visit indexes, terrain rows, scoped reads) are keyed by
    session, opened only on human or save paths, or capped; the global random number generator is not used, and
    every random source the match uses is seeded from the session.
  - What the runner itself must reset is listed above: `port_stats` and the kept session.
- **Checks:**
  - Six seeds, each in a process of its own against all six in one process, in the order l1, l2, mw, s2, mg-a, mg-b
    and again from mg-b to l1: all 415 daily digests and the match records identical both times.
  - Six seeds against main 7bd62e817 (a process per seed): all 415 digests and the records identical.
  - A batch of four small matches in one process: four rows, records and map packages removed.
  - Core suite 17/17.
- **Timing** (a quiet machine, Phases 5 and 7 paused, no per-day digest, two rounds alternating the two ways; the
  wall clock is read every 1-2 s):

  | | A process per match | One process for several | Gain |
  |---|---|---|---|
  | The six seeds one after another | 122.2 s, 122.2 s | 97.3 s, 97.3 s (all six) | 1.26x |
  | 24 small 2P matches (`ai_match_batch.py`, 6 slots) | 34.9 s, 32.9 s | 22.8 s, 22.8 s (`--per-process 4`) | 1.49x |

  The bound was 1.25x, 2.0x on small maps. Every batch match ended on the same day both ways. In one process the
  matches after the first take what they took in a process of their own less the start-up (l1 24.4-24.7 s against
  29-30 s, s2 2.1 s against 7 s).

**P6-2, a map corpus and the adopted session kept per process** (`native-rules-phase6-p2-map-corpus-20261023`, branch
`native-phase6-map-corpus`):
- **What changed.**
  - `HEROES_AI_MATCH_MAP_CORPUS` names a folder of generated maps. A match whose map is there starts from its saved
    package pair and setup: the pair is copied to where the generator writes it and the session is adopted from the
    setup, so the session is the one a newly generated map gives. A map not there yet is generated and saved there
    (the setup with `store_var`, which keeps int and float apart). A map is keyed by everything it depends on: the map
    seed, the first seat's faction, players, size, guards, water, levels and the package folder (`res://maps` in the
    editor, `user://maps` in an export).
  - In a match list, a match on the map of the match before it starts from a copy of the session that match adopted
    (before its handover), with no package load or adoption. The copy duplicates every container, so a container
    the adopted session shared between two places is two, as after saving and loading.
  - `tools/ai_match_batch.py --map-corpus DIR` keeps the batch's maps there, so another batch on the same plan
    (`--seed` and options, for example with other `--weights`) generates none. `corpus.json` names the commit, and a
    batch on another commit refuses the folder. A process plays the matches of one seed one after another, and each
    row says where its map came from (`map`: generated, corpus or kept).
  - The match runner's report line says the same. No native, game or `rules_parity.py` change (`--env` passes the
    folder).
- **Checks:**
  - Six seeds in a process each, with no corpus, against the same with an empty corpus that they fill and against
    the same again from the corpus: all 415 digests and the records identical.
  - All six seeds twice in one process, the first play from the corpus and the second from the kept session: all 12
    plays identical to the plays with no corpus, digests and records.
  - Six seeds against main 2dfeaddb7: identical. Core suite 17/17.
- **Timing** (Phase 5 paused, no per-day digest, two rounds alternating the order; the six seeds in one process,
  the sum of the matches' own seconds; round 1's corpus, generated and batch runs overlapped two Phase 7 Godot
  processes, which made the six seeds 5-7% slower and left the batch walls as they were):

  | | Generated | From the corpus | Gain |
  |---|---|---|---|
  | The six seeds in one process | 97.5 s, 102.8 s | 81.5 s, 87.0 s | 1.20x |
  | The six seeds' second plays, from the kept session | | 70.9 s, 70.7 s | 1.38x on generated |
  | 24 small 2P matches (`ai_match_batch.py`, 6 slots) | 22.8 s, 22.8 s | 20.8 s, 20.9 s (`--map-corpus`) | 1.09x |

  The bound was 1.09-1.17x. Per seed, generated against corpus against kept (round 0): s2 2.3, 1.8, 1.3 s; mw 7.4,
  6.3, 5.1 s; l1 25.0, 22.4, 19.8 s; l2 28.6, 21.8, 19.4 s. Every batch match ended on the same day all four times.

**P6-6, the generator's faction setup and rotated maps** (`native-rules-phase6-faction-setup-20261023`, branch
`native-phase6-faction-setup`; owner decision 2026-10-23: one map with the factions rotated through the starts, and the
generator provisions a random faction):
- **What changed.**
  - `ScenarioSelectRules.build_random_map_player_config` takes `seat_faction_ids`, one entry per seat: a faction id,
    `"random"` (drawn from the normalized seed seat by seat, so the same seed and setup give the same factions) or `""`
    (the next faction no seat has). The resolved list reaches the native normalize as `seat_faction_ids`. The
    skirmish menu's faction picker has a "Random" item: the player's faction is drawn from the seed, with its default
    commander.
  - Native, `map_package_service.cpp`: `normalize_random_map_config` keeps the seat list (a faction may sit twice),
    and each seat's faction goes to its town and to the neutral towns and creature dwellings of its town type, as the
    player's already did. The map and scenario ids hash the seat list, so two line-ups never share a package. A setup with a seat list takes its placement ids from the faction-free id (the map id of a setup that
    names no faction). Placement ids seed which original site or artifact an object becomes, and at adoption the
    guard armies and rewards, so every line-up of a seed plays one map. The generator's faction-free core result is
    kept for the next call with the same generator inputs (`generator_core_reused`). No H3MapEd core change.
  - A setup without a seat list (the menu, a random player faction, every setup on main) generates as before.
  - The match runner hands its line-up to the generator instead of refounding seats after generation
    (`_refound_seat` is gone), so a match's map depends on the seed and setup only. The kept session and the corpus
    stay keyed by the line-up, since a package holds its factions; a corpus of faction-free cores would need the
    generator's projection serialized, which this slice leaves out. A match on the same map with another line-up has
    the generator reuse the core.
  - `tools/ai_match_batch.py --rotate`: one map per line-up, played once in every seat rotation (`--matches` rounded up
    to a multiple of the players); a process takes all the queued matches of a seed.
- **Checks.**
  - Setups without a seat list (small 3P with embercourt, mireclaw and thornwake, medium 2P water with sunvault, small
    2P on two levels with no faction): packages identical to main's apart from the new `generator_core_reused` (false).
  - A seat list naming main's line-up against main's player-only setup: the map and scenario ids and hashes, the
    prefix of the 274 placement ids, 7 original site and artifact picks and the seat list in the metadata differ.
  - One medium 3P map in its three rotations: terrain, route graph, placement ids and every object identical apart from
    the factions (3 towns, the seats, the player setup and hero) and the document ids. Their day-1 sessions: terrain,
    encounters and artifacts identical; the factions, enemy rosters, the 3 player towns, 1 neutral town and 3 creature
    dwellings of a seat's town type and the ids differ.
  - Random seats: the same factions for a seed within a process and across processes. A reused core gives the result
    of a fresh generation apart from the flag. The skirmish menu run once with "Random" picked, with a screenshot.
  - Native RMG: the rules selftest, `map_package_api_skeleton_report` and the object-table proxy report pass;
    `native_rmg_end_to_end_runtime_boundary_report` fails its zero-road check on payload d4f3705f exactly as on main.
    The H3MapEd core is unchanged.
  - Six seeds, native against main ad2c5f24a: all differ from day 1, as they must, since the runner now hands its
    line-up to the generator. The seats and terrain are the same in all six. What differs: neutral towns of a seat's
    town type take that seat's faction (l1 2, l2 4, mw 2, s2 0, mg-a 1, mg-b 1; on main they kept the default
    line-up's faction from before `_refound_seat`), and the faction-free placement ids roll other guard armies (l1
    184 of 192, l2 149/153, mw 82/84, s2 30/30, mg-a 256/261, mg-b 103/105), sites (238/743, 262/1034, 84/249,
    23/62, 179/440, 155/424) and artifacts (19/27, 22/26, 12/13, 2/2, 35/40, 13/15), and the map, scenario and
    session ids. Days played, main against P6-6: l1 90/90, l2 70/70, mw 62/71, s2 33/32, mg-a 80/80, mg-b 80/100.
  - Core suite 17/17. A small 2P `--rotate` batch of 4: each map's second rotation reports its map as `reused`.
- **Timing** (quiet machine, one process, three rounds; `generate_random_map` alone, a line-up's first generation
  against its other rotations, which reuse the core and still project the factions and write the package):

  | | First | Each other rotation | Gain |
  |---|---|---|---|
  | Small 2P | 215-298 ms | 49 ms | 4.4-6.1x |
  | Medium 3P | 741-786 ms | 89-98 ms | 7.6-8.8x |
  | Large 4P | 1,527-1,770 ms | 158-179 ms | 8.5-11.2x |
  | Extra large 6P | 3,479-7,606 ms | 248-288 ms | 12-31x |

  A rotated batch saves this on every match of a map but the first; the rest of a match is unchanged.

**P6-7, random skirmish opponents** (`native-rules-phase6-random-opponents-20261023`, branch
`native-phase6-random-opponents`; owner decision 2026-10-23: in skirmish games the computer opponents' factions are
drawn at random from the map seed by default, and the human keeps their pick or Random):
- **What changed.** `MainMenu._generated_random_map_config` passes P6-6's `seat_faction_ids`: seat 1 gets the
  player's pick (or `"random"`), every other seat `"random"`. `ScenarioSelectRules.random_map_seat_factions` draws
  each seat from the normalized seed on its own, so a seed gives the same opponents whatever the player picks, and two
  seats, the player's included, can share a faction. No change to `ScenarioSelectRules`, the native side or the match
  runner, whose line-ups stay explicit. The setup line names no opponents: it is already cut short at its two lines,
  and with an auto seed the opponents exist only at launch.
- A skirmish now always has a seat list, so its placement ids come from the faction-free id (P6-6): a seed gives other
  guards, sites and artifacts than before this slice. Saves load their packages from disk and are not affected.
- **Checks.** A medium 4P skirmish through the menu (seed `random-opponents-check`, Embercourt): opponents Thornwake,
  Thornwake and Brasshollow, day 1 started, with a screenshot. Three seeds, with a pick and with Random: the same draw
  twice in a process and in two processes. Over 200 seeds in 4P with a pick, an opponent shares the player's faction
  in 86 (43%; 42% expected from six factions) and some faction sits twice in 145 (72.5%; 72% expected). Six seeds against main
  ac046cf67: all 443 daily digests and the records identical. Core suite 17/17.


### Phase 7: every rule native, one copy

The human-side actions and every other GDScript rule move to C++, and the two-copy functions lose their GDScript
bodies. This is needed for the one-copy end state, not for speed. Merging the separate human and AI forms of heroes,
treasury and fog is a later save-schema slice. Branch `native-phase7-human`.

**Owner decisions** (2026-10-23, on the plan below; D11 in section 8):
- **D-a, the check.** A permanent human seat: the `--human` mode of `tools/rules_parity.py`.
- **D-b, the scope.** Every rule moves to C++: panel text, content loading, game setup, the save format, the map
  editor's rules and the campaign runtime. Only the screens stay GDScript: scenes, layout, input, animation, drawing
  and audio, reading native results.
- **D-c, the map views.** One native snapshot per redraw, not one native read per tile.
- **D-d, no way back in GDScript.** `HEROES_NATIVE_HUMAN` exists only on a slice's branch, as the shadow check. The
  day switch's `gdscript` mode and its `__gd` bodies are deleted. The tags before each merge are the way back.
- **D-e, tests.** Tests that call GDScript bodies the phase deletes are retired by the D6 process.

**Plan revision 2** (owner decisions, 2026-10-23; D11 in section 8):
- **D-f, the campaign runtime.** It is ported with the campaign rework, not in Phase 7: 7.14 leaves the phase.
- **D-g, the GDScript generator.** `RandomMapGeneratorRules.generate` and the legacy rebuild path are deleted. Its setup
  part (`normalize_config` and the materialization identity) moves with 7.11. Of the 17 test files that call
  `generate`, the three core tests (`random_map_seeded_generator_core_report`,
  `random_map_final_writeout_export_save_schema_report` and `generated_start_hero_growth_seed_report`) move to the
  native generator in the same slice; the others are retired under D-e.
- **D-h, the map editor.** The editor's export of the archived authored-scenario format is deleted. Only map-package
  editing and saving is ported.
- **Order.** 7.1, then 7.10 to 7.12, then 7.2 to 7.9, 7.13 and 7.15.
- **Merges.** Four: after 7.1 with 7.10 to 7.12, after 7.2, after 7.7, and at the end. The full checks run only at these
  merges; while working, the shadow check on the `--human` run. If the first merge looks too big to debug, a split is
  proposed first.

**Later owner decisions** (2026-10-23; D11 in section 8):
- **D-i, the archived content's start-up checks.** Option (b): they are deleted in 7.10, and the live files' checks
  are ported. ContentService still loads the archived content by id.
- **The first merge is split.** Merge 1a is 7.1 with 7.10, merge 1b is 7.11 with 7.12, each with the full checks once.

**Inventory** (2026-10-23, main 7bd62e817; a static call graph of main from a scratch analyzer: calls through
`class_name`, preload consts, lazy-script getters and autoload names; calls by string, signals and engine callbacks
not followed):
- **What the UI calls.** 500 rules functions at 1,632 call sites. Without the battle screen and setup, 355 functions
  at 1,276 sites.
- **Two copies.** 798 GDScript functions, 13,343 lines, have a C++ port beside them: Phase 3's 309, 4.4's 203, Phase
  5's 359 and 2d's lists, minus overlaps. The UI calls them at 466 sites, and 183 test files at 1,317.
- **The native day** leaves nine human-only paths to GDScript:
  - a player town's weekly growth, and a player convoy's arrival;
  - a human action's scenario check, and a townless human;
  - a human primary hero rebuilt from its template, and the garrison migration;
  - an artifact placement still to be drawn, and sessions without towns or resource nodes;
  - the archived authored objective types.
- **The human route search is UI code.** `OverworldShell._build_path` and `_route_path_lengths` are breadth-first
  searches that call four rules functions per neighbour tile, so the search moves native as one call. The map views
  read fog, positions and levels per tile, for example `is_tile_explored` at 31 sites and `hero_position` at 80.
- **The GDScript map generator.** `RandomMapGeneratorRules.generate` (450 functions, 10,687 lines) only rebuilds a
  save whose map is not a native disk package. All five D9 save copies are native packages. Setup calls
  `normalize_config` (29 functions, 665 lines) and the materialization identity (3 functions, 21 lines).
- **Saves are JSON**, written with `JSON.stringify` and read with `JSON.parse_string`.

**Slices.** "Port" counts GDScript functions without a C++ port, each in the first slice that reaches it. Two-copy
functions lose their GDScript in the slice that removes their last GDScript caller.

| Slice | What moves | Port |
|---|---|---|
| 7.1 Routes | the route search out of `OverworldShell`, `hero_route_*`, `tile_*`, linked transit edges, `route_movement_preview`, guard approach | 22 functions, 516 lines, plus the search |
| 7.2 The move and its arrival | `try_move*`, `execute_prevalidated_route`, the action frame (`_finalize_action_result` and its scenario check), pickups, rewards, sites, dwellings, visit buildings, boats, transit, starting a guard battle, entering a town | 195, 3,655 lines |
| 7.3 Context and site actions | context actions, reward choice, site recruits, dwelling hire, level-up, specialties | 112, 2,543 lines |
| 7.4 Overworld spells | `cast_overworld_spell`, `get_spell_actions` | 23, 517 lines |
| 7.5 Heroes | rendezvous, army slots, field exchange, town transfers, garrison, tavern, artifacts | 84, 1,749 lines |
| 7.6 Town actions | build, recruit, market, responses, spell learning, the two town boards, the action lists | 128, 2,611 lines |
| 7.7 The day's human paths, the outcome screen | the fallbacks above, `build_outcome_model`, `perform_outcome_action` | 38, 796 lines |
| 7.8 Overworld, town and hero panels | `describe_*`, labels, action lists, forecasts, the map views' snapshot (D-c) | 341, 6,326 lines |
| 7.9 Battle screen | battle text, the action surface, forecasts, presentation events, board reads for drawing | 172, 3,677 lines |
| 7.10 Content loading | ContentService parsing and queries; the native content tables built from the JSON files | 112, 2,322 lines |
| 7.11 Game setup | ScenarioSelectRules, ScenarioFactory, package adoption, setup's neutral encounters and rewards, AI seats, MapPackageService's GDScript, the generator's setup part (`generate` deleted, D-g) | 256, 4,763 lines |
| 7.12 Saves | the save format, normalization, validation, migration, summaries, the transactional write | 222, 4,026 lines |
| 7.13 Map editor | TerrainPlacementRules, NativeScenery*, MapDocument, ScenarioDocument, the edit operations inside `MapEditorShell`; the authored-scenario export deleted (D-h) | 84, 1,204 lines, plus about 150 to 195 functions from the screen |
| 7.14 Campaign runtime | out of Phase 7 (D-f): CampaignRules, CampaignProgression, ported with the campaign rework | 146, 2,147 lines |
| 7.15 One copy | the last two-copy bodies, the C++ functions defined twice, AGENTS.md's two-copy rules | deletions |

The slices port 1,935 functions, 36,852 GDScript lines, plus the editor's operations; without 7.14, 1,789 functions and
34,705 lines. Without porting, the phase
deletes 169 functions only tests reach, and about 190 with no caller found.

7.10 to 7.12 depend on none of the human slices. They give Phase 8 content tables, setup from a map package and
saves without Godot.

**Checks.**
- **The `--human` run.** A scripted player drives seat 1 through the real `OverworldShell`, `TownShell` and
  `BattleShell`, headless, with an isolated profile.
  - It routes and moves, answers prompts, uses context actions, spells, level-ups, transfers and artifacts, and runs
    town actions.
  - It plays some battles through `BattleShell` with the battle AI's suggested order, and the rest with Quick
    Resolve. It ends each day through the confirmation.
  - After every action it records the session digest (P6-5) and a digest of the panel texts.
  - It runs on small, medium and large generated maps, at fixed seeds, with water and underground, and on the five
    D9 save copies, copied into a scratch profile.
- **While working.** `HEROES_NATIVE_HUMAN=shadow` on the `--human` run, plus day shadow on the six seeds.
- **Before a merge.** `rules_parity.py check <main copy> . --human`, with every per-action digest identical. Then the
  six seeds against main and the core suite.
- **Coverage.** Functions the runs never reach are listed in the slice entry. Each gets a scratch probe, or is named
  as unproven.
- **UI speed.** Refresh times are compared with main. A panel that got slower moves its loop native.
- **7.10.** The native content tables are identical to ContentService's for every content file.
- **7.11.** New games from fixed seeds give the same session as main's.
- **7.12.** The D9 copies load to the same session as main's; written saves are identical apart from
  `saved_at_unix`, and load on main and on the branch.
- **7.13.** Scripted editor operations on generated packages leave the same document as main's.

**Slice 7.1, routes** (2026-10-23, branch `native-phase7-human`): the human route search is one native call.
`OverworldShell._build_path` and `_route_path_lengths` and the map view's searches call `OverworldRules.hero_route_path`
and `hero_route_path_lengths`. The human registry (`human_registry.cpp`, `HEROES_NATIVE_HUMAN`, no GDScript fallback)
ports them with 15 route queries: `tile_is_blocked`, `tile_step_cuts_blocked_corner`, `tile_has_route_interaction`,
`tile_is_actionable_route_destination`, `hero_route_tile_blocked`, `hero_route_destination`,
`active_linked_transit_edges`, `active_linked_transit_signature`, `linked_transit_neighbors_from_edges`,
`route_movement_preview`, `guard_engagement_approach_route`, `guard_engagement_encounter_at_tile`,
`resource_node_interaction_at_tile`, `blocking_object_feedback_surface_at_tile` and `WaterTravelRules.is_sailing`, and
their seven helpers. The shell's validation hooks (`_build_validation_path`) still call the queries per tile. Checks:
- Human shadow on the eight `--human` seeds (seven before the main merge, h-s2 after it, which the read-scope fix of
  main ac046cf67 lets finish), 0 mismatches and 0 errors: `tile_is_blocked` 1,537,029 checks,
  `tile_step_cuts_blocked_corner` 1,443,258, `tile_has_route_interaction` 643,287, `is_sailing` 630,231,
  `hero_route_tile_blocked` 553,299, `linked_transit_neighbors_from_edges` 435,273, `hero_route_destination` 76,654,
  `tile_is_actionable_route_destination` 76,654, `guard_engagement_encounter_at_tile` 6,637,
  `active_linked_transit_signature` 4,836, `active_linked_transit_edges` 3,800, `resource_node_interaction_at_tile`
  2,089, `route_movement_preview` 1,140, `guard_engagement_approach_route` 802, `hero_route_path` 388,
  `hero_route_path_lengths` 301, `blocking_object_feedback_surface_at_tile` 8.
- Day shadow on the six seeds, after the main merge: 7,829 checks, 0 mismatches, 0 errors.
- The `--human` check against main runs at the first merge.

**Slice 7.10, content loading** (2026-10-23, branch `native-phase7-human`): ContentService's files are parsed,
indexed, looked up and checked in C++.
- `compat::json_parse` (`compat/godot_json.cpp`) is the engine's `JSON.parse`, with its own digest in the selftest's
  compat vectors.
- `content::Store` (`core/content_store.cpp`) loads each document once, read-only (an Array root as `{"items": ...}`,
  the archive's missing files as `{}`), and answers `get_content_by_id`, `get_content_ids`, `get_encounter` (with the
  generated companies), `canonical_town_id`, `normalize_terrain_id`, `get_biome_for_terrain`,
  `get_map_object_for_resource_site`, the overrides (`ai_hero_weights_errors` against the shipped file), `clear_cache`
  and the content revision. A lookup takes ids as `String()` does: a non-text id stops it.
- `AurelionContent` (`gdextension/content_host.cpp`) hands GDScript one read-only Dictionary or Array per node, kept
  until the tables reload. The port bridge's content rows and files read the store; scenarios and terrain layers still
  come from ContentService (its generated drafts).
- `core/content_validate.cpp` is the start-up checks of the live files (36 functions, the art indexes included), with
  GDScript's runtime-error rule: an error ends the function it happens in, and its caller goes on.
- The archived content's start-up checks are deleted (D-i): `_validate_content`, `_index_items`,
  `_validate_terrain_layer`, `_terrain_ids_supporting_roads`, `_terrain_overlay_ids`, `_terrain_id_from_map`,
  `_validate_scenario`, `_validate_objective`, `_validate_script_hook`, `_validate_script_condition`,
  `_validate_script_effect`, `_validate_script_placement`, `_append_hook_spawn_placements`, `_append_unique_string`,
  `_validate_campaign`, `_validate_campaign_chapter_seal`, `_validate_campaign_requirements`,
  `_validate_campaign_carryover`, `_campaign_id_for_scenario` and `_validate_enemy_faction` (970 lines). No core test,
  `tests/validate_repo.py` or other code called them, so no test retires under D-e.
- `ContentService.gd` keeps thin wrappers, a memo per document and found row, and the generated drafts: 2,362 lines
  before, 340 after.
- Fixed on the way: `State::clear` emptied its atoms before the map whose keys view them (MSVC's `clear()` can hash its
  keys); the fix went to main on its own (4eb648cfe).
- `canonical_town_id` answers `""` when an error stops it, as GDScript's typed function does.
Checks:
- Tables, main against the branch: every content file's document, ids and rows by id (each `is_same` as its list's row),
  the art, animation and hero art rows, the encounters with the generated companies, the towns and aliases, terrain ids
  and biomes, the site objects, the failures, overrides and the revision: 8,178 lines identical, with the same errors
  at the same places (in the native messages' words) and the same warnings. 0 start-up warnings on both.
- Start-up checks of the live files, main against the branch (both still running the archived checks then): the shipped
  files and 1,929 broken copies of the 24 live files (a key removed, emptied, a bad reference, a wrong type, nested
  fields; at most 100 a file, spread over its rows). In 1,919 cases the same warnings and the same number of runtime
  errors. In 10 cases with an int id the branch printed one runtime error more, from the archived checks' GDScript index
  beside the native one; rerun after their deletion, heroes.json's 86 cases have main's counts. With `legacy_aliases` a
  list, `canonical_town_id` answered the id instead of `""` after its error, so the archived checks printed 120 warnings
  fewer; fixed, and 28 lookups on broken alias copies now give main's answers.
- Measured in the probes: loading every content file 266 ms on main, 94 to 97 ms on the branch; the start-up checks
  595 ms on main, 331 ms on the branch with the archived checks still in GDScript.

**Merge 1a** (7.1 and 7.10, 2026-10-23): merged to main after main was tagged `pre-native-phase7-merge-1a` (D10).
- 7.1's 17 functions are NATIVE entries of the human registry: `tools/native_battle_switch.py` writes them as thin
  wrappers over `HumanEngine.native` and `native_writing`, and deletes their switches and GDScript bodies (716 lines,
  D-d). No function on main reads `HEROES_NATIVE_HUMAN`; a later slice's switches exist on its branch.
- While working, on 7.10 (3991505dd): human shadow on the eight `--human` seeds, 5,328,486 checks of the 17
  functions, 0 mismatches and 0 errors; day shadow on the six seeds, 7,829 checks, 0 mismatches and 0 errors.
- The merged code (21d6e16b6) against main 4eb648cfe: the `--human` check identical on the eight seeds, 1,896 action
  digests and the records; the six seeds identical, 443 daily digests and the match records; core suite 17/17.
- UI speed, screen time per action in ms, main | branch, with other runs on the machine: town actions 1,371 | 1,134, end of turn 1,416 | 1,406, battle 646 | 643, move 216 | 214; every other kind within 6 ms either way (opening a town 92 | 94). No kind got slower beyond that noise.
- Coverage: the human shadow reached all 17 functions; the two probes above cover 7.10's lookups and checks.

**Slice 7.11, game setup** (2026-10-23, branch `native-phase7-human`): a new game is set up in C++, from the menu's
options to the session.
- Ported to the human registry (`human_registry.cpp`, no GDScript fallback; files `scenario_select_*.cpp`,
  `native_random_map_package_session_bridge.cpp`, `generated_reward_rules.cpp`, `generated_neutral_encounter_rules.cpp`,
  `native_scenery_rules.cpp`, `random_map_generator_rules.cpp`, `game_setup_heroes.cpp`): `ScenarioSelectRules`' options,
  difficulty, random-map setup, template catalog and maps-folder functions (138); `NativeRandomMapPackageSessionBridge`
  (43); `GeneratedRewardRules` (33), which replaces Phase 5's transit subset of `resolve`; `GeneratedNeutralEncounterRules`
  (15); `NativeSceneryRules.is_scenery` and `validate`; `RandomMapGeneratorRules.normalize_config` (29);
  `HeroCommandRules.army_has_troops` and `seed_start_heroes_from_session`; `HeroProgressionRules.brief_summary`. The
  57 that GDScript still calls are thin wrappers over `HumanEngine.native_writing`; the other bodies are deleted.
  `NativeSceneryRules.policy` and `asset_candidates` keep a GDScript copy for the map view.
- The port bridge gained engine services: object method calls, class instancing, autoloads, files and folders,
  `ResourceLoader.exists`, the environment and features, the clocks and the engine's `JSON.stringify`. A human-table
  entry may call a GDScript function as a pure host call (`SessionStateStore.new_session_data`).
- Deleted by D-g: `RandomMapGeneratorRules.generate` and the rest of the GDScript generator (503 functions),
  `ScenarioFactory`'s generated-draft sessions (4), the setup's and the bridge's legacy draft paths (14), the GDScript
  `MapPackageService`, `MapDocument` and `ScenarioDocument`, and the save path that rebuilt a pre-package map (such a
  save is refused with a message). Constants nothing reads any more went with them: 19,211 GDScript lines deleted in all, 74 written.
- Tests: three core tests rewritten onto the native generator, 17 tests retired (`docs/game-setup-test-retirement.md`).
Checks:
- New games, main against the branch, through the functions the menu calls: 27 setups (Small to Extra Large, 2 to 8
  players, land, normal water and Islands, one and two levels, the three monster strengths and difficulties), each
  with its setup, session, summary and maps-folder entry, seven loaded again from the maps folder and four restarted;
  plus the menu's option lists. 28 of 28 identical, apart from the packages' file times. An Extra Large 8-player
  normal-water two-level setup (seed 72136) crashes main's native generator as well as the branch's. Fixed on
  2026-10-26 by `84b035204` (`native-rmg-river-post-pass-vector-walk-20261026`).
- Core tests covering setup: 5 of 5.

**Slice 7.12, saves** (2026-10-23, branch `native-phase7-human`): saves are written, read, summarized and restored in
C++.
- Ported to the human registry (files `save_service_*.cpp` and `save_session_payload.cpp`, 215 functions, 6,548 lines):
  every `SaveService` function (the save format, the slot summaries and their cache, the transactional write with its
  backup, previous generation and recovery, the restore, the campaign progression file, the save screens' texts),
  `SessionStateStore.normalize_payload` with its helpers, and `HeroCommandRules.restore_empty_hero_armies`. The 64
  `SaveService` functions that the game, the tools and the tests call, and `normalize_payload`, are thin wrappers over
  `HumanEngine.native_writing`; the other bodies are deleted (`SaveService.gd` 4,335 lines before, 247 after).
  `SessionData.payload_for_storage` and `share_runtime_scenario_record` keep a GDScript copy for `SessionData`.
- 21 entries call GDScript as host calls: `ProfileLog` (5), `CampaignRules.get_campaign_id_for_scenario`, and the
  `OverworldRules`, `TownRules`, `BattleRules` and `ScenarioRules` read scopes and texts a summary quotes (15).
- Deleted because nothing reaches them (no wrapper, no other port code): `_runtime_session_resume_brief`,
  `_session_changed_recap_line`, `_session_save_resume_recap`, `describe_session_play_check`,
  `describe_session_return_handoff`, `describe_session_save_check`, `describe_session_save_handoff`,
  `describe_session_save_handoff_brief`, `describe_session_save_recap`, `has_any_loadable_session`, `has_slot`,
  `list_loadable_session_summaries` and `save_runtime_selected_manual_session`.
- The port bridge: a DayEngine view handed back is mapped to its object (`adopt_view`). New engine services: a static
  call or method whose answer stays the engine's, the engine's `==`, and builtin methods of a kept value. A save's JSON
  text stays an engine String, written, measured and compared in the engine. Before that change, each autosave grew
  memory by about 48 MB. `engine_duplicate` now copies in the engine a native container that holds one loaded from
  GDScript: copied natively, an autosave's summary built 77,000 native dictionaries and took 180 ms longer. The atom
  table is also cleared past 64 MiB of text. `gd::equal_loaded` compares two containers loaded from GDScript in the
  engine: `payload_for_storage` compares the save's two copies of the scenario record, and the native walk had made the
  end of turn's autosave 90 ms slower than main's.
- Tests: 3 retired (`docs/save-test-retirement.md`). `tools/native_battle_switch.py` reads signatures over several lines.
Checks, main 2abd6e086 against the branch, with a scratch probe and isolated profiles:
- Phase a, the five D9 copies: the file list and slot summaries, the screens' 13 texts for each summary, the loads,
  the in-session surfaces, and a file, manual and autosave write of each loaded session. 54 labels, 0 differ: the
  written files are identical apart from `saved_at_unix`.
- Phase b, each side loading the files the other wrote: 10 labels, 0 differ, and 10 of 10 give the same session as
  the copy.
- Phase c, the rest:
  - payload saves and loads, the slot actions, a rename and a delete;
  - recovery from the backup and from the previous generation, and both failure phases;
  - the progression file empty, current, newer, older, wrongly typed and broken;
  - the generated opening's fast and full autosaves, and the validation hooks;
  - six changed copies: a town visit, a lost town, a missing and a broken battle, a won scenario holding a battle,
    and save version 8.
  49 labels, 0 differ. `load_session` of an empty slot stops with the same script error on both sides (main's
  `_loaded_session_payload`).
- Coverage of main's 229 GDScript functions: 207 reached. The 16 not reached are deleted: the 13 above and the 3
  legacy functions a retired test called. Named unproven:
  - `_battle_aftermath_summary`, which needs a battle save without a recap;
  - `_describe_session_play_check_from_summary`, `_fallback_resume_decision` and `_summary_objective_line`, which
    need summaries without their recap context;
  - `_migrate_progression_payload` and its step, which nothing reaches while the profile version is 1, its minimum;
  - migration from save versions before 9: no real save is older, and the version 8 copy only shows one normalized
    as legacy alike;
  - a save without player records: its stored summary normalizes the session and stops at the day port's left-out
    path "enemy configs without player records", now a native failure. Every generated game writes them.
- Speed, main | branch, in ms:
  - listing the save files 3,503 | 1,026;
  - the slot summaries 376 | 609: the branch frees the previous call's parsed saves at the next call's start;
  - the five loads 574 | 502, 520 | 453, 385 | 313, 336 | 297 and 571 | 443;
  - the 15 saves 125 to 321 ms faster on the branch;
  - the end of turn's autosave of the Veilmourn Day 10 copy (a generated map, no summary): main 1,099 to 1,123, the
    branch 1,007 to 1,037; the save bar's status after it 342 to 366 | 267 to 276;
  - 15 autosaves of the same copy, before the engine compare: main 1,125 to 1,146 ms with 530 to 570 MB private
    memory, the branch 1,123 to 1,161 ms with 465 to 585 MB.

**Merge 1b** (7.11 and 7.12, 2026-10-24): merged to main after main was tagged `pre-native-phase7-merge-1b` (D10).
- Main was merged into the branch twice on the way, at 92c672a3e (Phase 8's P8-1 and P8-2) and at 36ea734e1 (P8-3 to
  P8-6). Only the Windows binaries conflicted, and they were rebuilt.
- Fixed on the way, found by the merge's checks:
  - The end of turn was about 140 ms slower than main's on all eight `--human` seeds. `payload_for_storage` compared
    the save's two copies of the scenario record natively; `gd::equal_loaded` compares them in the engine.
  - `battle_ai_flow_report`: an engine service's null object (`DirAccess.open` of a missing folder) loaded as an
    opaque value, not null (`PortBridge::load_answer`).
  - `save_summary_deferred_payload_report` crashed at exit. `engine_singleton` reached `Time` through
    `Engine::get_singleton(name)`, which leaves an instance binding that the engine frees after the library is gone.
    `Time` and `ProjectSettings` now come through their own `get_singleton()`, whose bindings godot-cpp frees. A
    non-session port call also drops what it loaded when it returns (`PortBridge::end`).
- Checks of the merged code against main 36ea734e1:
  - the `--human` check identical on the eight seeds, 1,896 action digests and the records;
  - the six seeds identical, 443 daily digests and the match records;
  - core suite 17/17.
- UI speed, screen time per action in ms, main | branch: end of turn 1,350 | 1,305 (before the engine compare
  1,387 | 1,527), town actions 1,086 | 1,072, battle 622 | 594, move 203 | 192, opening a town 88 | 80, dialogs
  146 | 140; every other kind within 4 ms either way. No kind got slower.
- Coverage: the 7.11 and 7.12 entries above.

**Slice 7.2, the move and its arrival** (2026-10-24, branch `native-phase7-human`): a human move and what its
destination does run in C++.
- Ported to the human registry (header `overworld_rules_move.hpp`, eleven files `overworld_rules_move.cpp`,
  `water_travel_rules_human.cpp`, `overworld_rules_arrival.cpp`, `overworld_rules_collect.cpp`,
  `overworld_rules_site_queries.cpp`, `overworld_rules_site_effects.cpp`, `overworld_rules_site_rewards.cpp`,
  `overworld_rules_encounter_text.cpp`, `overworld_rules_recap.cpp`, `scenario_event_check.cpp` and
  `scenario_objective_label.cpp`; 177 functions, 6,754 lines): the keyboard step, the route (cached and not), native
  transit and levels, boats and whirlpools, the arrival (encounters, rendezvous, towns), resource sites, their claims,
  rewards, guards and texts, dwellings, visit buildings, artifact pickups, the encounter's texts, the post-action
  recap, `ScenarioRules.evaluate_session_for_event` with its dependency helpers, and `_objective_label`.
- The action frame: the C++ `_finalize_action_result` records the rules profile and checks the scenario narrowed to
  the action's event facts, as its GDScript copy does; the fog payload and sources, the encounter lookup and the
  blocked-tile index record their profile lines. `_end_turn_open_day` and `_end_turn_close_day` still refuse a
  recording profile.
- 69 entries: what the screens, the panels, the battle end, `ScenarioScriptRules` (`_award_experience`) and the tests
  call. `NativeTransitRules.network_colour` keeps a GDScript copy for the map view, which calls it for every portal
  it draws; its C++ copy reads the GDScript const `NETWORK_COLOURS`.
- The port bridge: a missing content row answers Nil, so `gd::content_row` gives the port a new empty Dictionary of its
  own, as ContentService gives a new `{}` (a shadow check had counted it as one the port was given). The scenario
  check's dependency signature stringifies the record natively where `json_stringify` covers it.
Checks:
- Human shadow on the eight `--human` seeds, 0 mismatches and 0 errors: 62,274 checks on 58 entries.
- With a scratch copy of the runner that also steps by keyboard, makes the route take its uncached path, presses the
  collect context actions and asks the panels' texts: 97,365 checks on all 69 entries, 0 mismatches and 0 errors
  (`try_move` 380, `try_move_along_route` 500, `execute_prevalidated_route` 123, `collect_active_resource` 453,
  `collect_active_artifact` 351, `_collect_resource_node_result` 322, `_award_experience` 94,
  `evaluate_session_for_event` 12, `travel_native_passage` 9, `capture_active_town` 3,
  `_collect_artifact_node_result` 1).
- Day shadow on the six seeds: 7,775 checks, 0 mismatches, 0 errors.

**Merge 2** (7.2, 2026-10-24): merged to main after main was tagged `pre-native-phase7-merge-2` (D10). Main was merged
into the branch first, at 95804319f (Phase 8's P8-8).
- The 70 entries are NATIVE: their GDScript functions are thin wrappers over `HumanEngine.native`. The 104 bodies that
  no GDScript outside the slice called are deleted (`OverworldRules.gd` 16,052 lines on main, 13,042 after).
  `ScenarioRules._scenario_objective_dependency` became an entry at the merge, for `objective_artifact_ids` (the
  towns' artifact trade). No test calls a deleted body, so none is retired.
- The battle end visits a site through the C++ port (`battle_end_sites.cpp`). Its host call to
  `OverworldRules._collect_resource_node_result` and the battle table's HOST entry are gone, and so is
  `battle_sim_cli`'s answer to it (an arena quick run with `--plain`: 72 games, no failure).
- Checks of the merged code against main 268324fec:
  - the `--human` check identical on the eight seeds, 1,896 action digests and the records;
  - the six seeds identical, 443 daily digests and the match records;
  - core suite 17/17.
- UI speed, screen time per action in ms, main | branch: end of turn 1,311 | 1,312, town actions 1,080 | 1,068,
  battle 597 | 600, move 197 | 196, opening a town 88 | 79, dialogs 137 | 136; every other kind within 3 ms either way.
- Coverage: the 7.2 entry above.

**Slice 7.3, context and site actions** (2026-10-24, branch `native-phase7-human`): the map's context and what it
offers run in C++.
- Ported to the human registry (header `overworld_rules_context.hpp`, six files `overworld_rules_context.cpp`,
  `overworld_rules_site_response.cpp`, `overworld_rules_site_text.cpp`, `overworld_rules_town_actions.cpp`,
  `overworld_rules_hero_choices.cpp` and `artifact_rules_text.cpp`; 101 functions, 4,160 lines): the context and its
  actions, a site's response order and reserve delivery, the resource sites' surfaces, building and recruiting in the
  visited town from the map, the reward choice, dwelling hire, site recruits, level-up, specialties, army slots and the
  artifact texts.
- 59 entries: what the overworld and town screens, the map editor, the other rules scripts and the tests call. The
  site texts and the response state and yield line take a session that may be Nil, for the map editor before a map is
  loaded.
Checks:
- Human shadow on the eight `--human` seeds, with a scratch copy of the runner that also presses the context's build,
  recruit and response actions, hires at dwellings and asks the site and artifact texts: 244,759 checks on 56 of the
  59 entries, 0 mismatches and 0 errors. Not reached: `_consume_recruit_payload`, `take_site_recruits_by_dismissing`
  and `leave_site_recruits` (recruits beyond the army's room). The day still left to GDScript a player town's weekly
  growth and a townless human's warning and defeat, which 7.7 ports.

**Slices 7.4 to 7.7, spells, heroes, town actions, the day's human paths and the outcome screen** (2026-10-24, branch
`native-phase7-human`, ported together): what the human player does on the map, with heroes, in towns and on the
outcome screen runs in C++, and so do the day's human paths.
- Ported to the human registry (four headers, 20 files, 9,663 lines; 289 functions):
  - 7.4, `overworld_rules_spells.hpp` (`overworld_rules_spells.cpp`, `spell_rules_overworld.cpp`; 23 functions):
    casting a spell on the map, the spell actions, the target contract, the preview and their texts.
  - 7.5, `overworld_rules_heroes.hpp` (`overworld_rules_heroes.cpp`, `hero_command_rules_army.cpp`,
    `hero_command_rules_field.cpp`, `hero_command_rules_town.cpp`, `town_rules_heroes.cpp`,
    `artifact_rules_management.cpp`; 92 functions): switching heroes, rendezvous and the field exchange, army slots,
    town transfers, the garrison, artifact management, with TownRules' read cache.
  - 7.6, `town_rules_actions.hpp` (`town_rules_build.cpp`, `town_rules_recruit.cpp`, `town_rules_market.cpp`,
    `town_rules_services.cpp`, `town_development_rules_services.cpp`, `spell_rules_town.cpp`,
    `hero_command_rules_tavern.cpp`, `town_building_panel.cpp`, `town_construction_board.cpp`,
    `overworld_rules_town_wrappers.cpp`; 135 functions): building, recruiting, the market, responses, spell learning,
    the town's services and tavern hire, the building panel and the construction board, their action lists, and the
    town's readiness, pressure and reinforcement ratings.
  - 7.7, `scenario_outcome.hpp` (`scenario_outcome.cpp`, `scenario_outcome_texts.cpp`; 39 functions): the outcome
    model, its actions and texts, and the progress recap. The campaign's branches stay out (D-f) and refuse, as an
    authored skirmish (archived) does; a maps-folder package starts as the setup port starts it.
- The day's human paths, in the day's C++ (`day_economy.cpp`, `overworld_state_normalize.cpp`,
  `overworld_towns_normalize.cpp`, `player_elimination.cpp`): a player town's weekly growth, a player convoy's
  arrival and follow-up, a human defeat for holding no town and the townless warning, a session rebuilt without towns
  or resource nodes, an artifact placement drawn from its reward table, a missing primary hero rebuilt from its
  template and the garrison hero migration. What the day still refuses no generated game reaches: authored
  objectives and script hooks, the campaign, old saves' fields, and values GDScript would reject too.
- 136 entries: what the overworld, town and outcome screens, the other rules scripts and the tests call. The town's
  ratings, its recovery and occupation states take a session that may be Nil, as their GDScript does.
- The ports read eleven more native content tables: unit, hero and building art, unit animations, neutral
  dwellings, spell, spell school and building category icons, faction crests, biomes and campaigns.
Checks:
- Human shadow on the eight `--human` seeds, with a scratch copy of the runner that also casts spells, manages
  artifacts and army slots, meets heroes, trades at the market, takes responses, buys artifacts and specialties,
  sets the garrison, opens the building panel and the construction board, uses the town's services and asks the
  recap, the outcome model and the field exchange's texts: 1,374,553 checks on 130 of the 136 entries, 0 mismatches and 0
  errors. Not reached: `SpellRules.effect_summary` (the battle screen's spell text), `OverworldRules.perform_rendezvous_action` (no two heroes met), and TownRules' `switch_active_hero_at_town`, `learn_spell_at_active_town`, `choose_specialty_at_active_town` and `_describe_vulnerability_penalties`.
- Day shadow in the same run: 20,450 checks on the 12 day entries (`end_turn` 105), 0 mismatches, 0 errors and no path
  left to GDScript.
- Day shadow on the six seeds: 7,775 checks, 0 mismatches, 0 errors, none left to GDScript.

**Merge 3** (7.3 to 7.7, 2026-10-24): merged to main after main was tagged `pre-native-phase7-merge-3` (D10). Main had
no commits since merge 2.
- The 220 entries of 7.3 to 7.7 are NATIVE: their GDScript functions are thin wrappers over `HumanEngine.native`. 195
  are the slices'; 25 functions that only tests call became entries at the merge, as 7.2's did (13 that GDScript tests
  call, 12 that the Python regressions' GDScript calls). The 166 other bodies of the slices that no GDScript outside
  them calls are deleted, with the day's 12 `__gd` bodies: the 16 scripts the merge touches have 29,035 lines on main
  and 20,736 after. No test calls a deleted body, so none is retired.
- The day runs native only (D-d): the day registry's 12 entries are NATIVE wrappers over `DayEngine.native`, and its
  table has no GDScript fallback. `HEROES_NATIVE_DAY` with its `gdscript` and `shadow` modes and the day's `__gd`
  bodies are gone; a path the port leaves out is a native failure. `ScenarioRules.evaluate_session` on a null session
  answers `{"status": "invalid", "message": ""}` as its GDScript did. `DayEngine.gd` keeps the views and the shadow
  checks that HumanEngine's switch borrows.
- The save service calls the town's read scopes, `can_visit_active_town` and the progress recaps in C++; their five
  host entries are gone.
- Checks of the merged code against main 3a9edbca9:
  - the `--human` check identical on the eight seeds, 1,896 action digests and the records;
  - the six seeds identical, 443 daily digests and the match records;
  - core suite 17/17.
- UI speed, screen time per action in ms, main | branch: town actions 1,094 | 249, end of turn 1,326 | 1,295,
  battle 597 | 594, move 197 | 193, opening a town 84 | 72, dialogs 141 | 97, hero 83 | 77; every other kind
  within 1 ms either way.

**Slice 7.8, the panels** (2026-10-24, branch `native-phase7-human`): the texts, boards, forecasts and feeds the
overworld, town and hero screens show, and the queries they read, run in C++.
- Ported to the human registry (header `overworld_rules_panels.hpp`, 13 files `overworld_rules_panel_status.cpp`,
  `overworld_rules_panel_objectives.cpp`, `overworld_rules_panel_forecast.cpp`, `overworld_rules_panel_feed.cpp`,
  `town_rules_panels.cpp`, `town_rules_handoff.cpp`, `scenario_rules_panels.cpp`, `enemy_rules_panels.cpp`,
  `artifact_rules_panels.cpp`, `spell_rules_panels.cpp`, `hero_rules_panels.cpp`, `map_view_rules.cpp` and
  `town_panel_boards.cpp`; 294 functions, 9,054 lines): the overworld's status, objectives and stakes, the end-turn
  forecast and the command risk, the dispatch and event feed, the town panels and the town handoff, the operational
  board, the enemy pressure texts, the artifact, spell and hero panels, the map view's reads and the town panels'
  boards.
- 192 entries: what the screens, the other rules scripts and the tests call, with the two-copy functions the screens
  call (`NativeTransitRules.network_colour` keeps its GDScript copy for the map view).
- The save service calls the read scopes, the command risk, the frontier threats, the management watch and the
  town's defense texts in C++; their nine host entries are gone.
- The map view and the minimap read the fog from one snapshot per redraw, the level's explored and visible grids
  (D-c), instead of one native read per tile.
- A projected session (a town at daybreak, `_project_player_town_at_daybreak`) has its own instance id, -1, -2 and on,
  for the read scopes' cache keys, as GDScript's new SessionData has its own object id. The shadow check reads such
  a key as GDScript's (`battle_port_bridge.cpp`, `same_projected_key`).
Checks:
- Human shadow on the eight `--human` seeds: 16,781,929 checks on 152 of the 192 entries, 0 mismatches and 0 errors.
  Not reached: the overworld panels the runner never opens (status, heroes, objectives, the stakes board, threats,
  defense warnings, spellbook rail, specialties, artifacts, the commitment board, the end-turn forecast and its
  surfaces, dispatch and event feed, the management watch), the operational board's lines, the pending choice
  texts, specialty and spell action ids, the construction board's slots, artifact location and equipping,
  `army_addition_plan`, `_resource_site_delivery_interception` and the pathing profile's validation functions.
- The same eight seeds with a scratch copy of the runner that also asks for those after each move and in each town:
  37,746,798 checks on all 192 entries, 0 mismatches and 0 errors.
- `OverworldRules.terrain_id_is_passable` fills OverworldRules' terrain cache, a static var, so its entry writes. As a
  read-only entry, native mode refused it in the map editor, which calls it while drawing; shadow mode does not see
  such a write.

**Slice 7.9, the battle screen** (2026-10-24, branch `native-phase7-human`): the battle screen's texts, its action
surface, the forecasts and recaps, the presentation reads and the board reads it draws run in C++.
- Ported to the human registry (header `battle_screen.hpp`, 8 files `battle_screen_entry.cpp`,
  `battle_screen_forecast.cpp`, `battle_screen_actions.cpp`, `battle_screen_abilities.cpp`, `battle_screen_risk.cpp`,
  `battle_screen_surface.cpp`, `battle_screen_details.cpp` and `battle_screen_context.cpp`; 167 functions of
  `BattleRules`, `SpellRules`, `TownBattleRules` and `BattleActionPlayback`, 5,926 lines): the entry and tactical
  briefings, the intent forecast and the enemy's reply, the action surface and the presented action, the ability and
  spell timing texts, the risk board, the stack, hero and roster details, the field objectives' texts and the board's
  occupancy, legal targets and hex states.
- 61 entries: what the battle screen, the board view, the other rules scripts and the tests call.
- The board read scope and its memo are deleted: since the battle port nothing read the memo. Its test is retired
  (`docs/battle-entry-transition.md`).
- The save service builds the battle's risk board in C++; its host entry is gone.
Checks:
- Human shadow on the eight `--human` seeds: 22,610 checks on 26 of the 61 entries, 0 mismatches and 0 errors. The
  runner's battles never open the details panel, the tooltips or the board's hover reads.
- h-s2, sv-v5 and sv-m1 with a scratch copy of the runner that asks for them before each order: 28,123 checks on 60
  entries, 0 mismatches and 0 errors. With the first run every entry is checked.

**Slice 7.13, the map editor** (2026-10-24, branch `native-phase7-human`): the map editor's rules run in C++: the
palette and pickers, the placement checks and guidance, the authoring validation, the working copy and Save Copy, the
terrain and road tools, the object commands, the handoffs and inspection texts, and the terrain placement.
- Ported to the human registry (header `map_editor.hpp`, 12 files `map_editor_common.cpp`, `map_editor_palette.cpp`,
  `map_editor_checks.cpp`, `map_editor_guidance.cpp`, `map_editor_validation.cpp`, `map_editor_working_copy.cpp`,
  `map_editor_terrain.cpp`, `map_editor_objects.cpp`, `map_editor_export.cpp`, `map_editor_handoffs.cpp`,
  `map_editor_inspection.cpp` and `terrain_placement_rules.cpp`; 338 functions, 268 of `MapEditorShell` and 70 of
  `TerrainPlacementRules`, 6,888 GDScript lines). The screen code (nodes, input, audio, the router) stays GDScript;
  the functions that mixed both are split into a rule and its screen part.
- 104 entries: 101 `MapEditorShell` methods, which take the screen first and read and write its members through the
  object (`_session` and `_dirty` through their setters' revision bump), and `TerrainPlacementRules.apply_paint`,
  `final_normalization_payload` and `visual_selection_payload`. The editor's rules call the engine: the SessionState
  autoload, `MapPackageService`, `DirAccess` and `ProjectSettings`.
- D-h: the authored-scenario export is deleted. The export contract becomes Save Copy's gate and draft; the export
  intent text, the legacy authored loads and their validation hooks are gone, and the scenario template and objectives
  lose their archived-scenario branch. Four tests that called the deleted hooks are retired (D-e): `map_editor_smoke`,
  `map_editor_scenario_export_contract_report`, `map_editor_canvas_failed_action_audio_report` and
  `map_editor_terrain_paint_performance_report`.
- `NativeSceneryRules` and `NativeSceneryFormation`, the map view's drawing helpers, move to 7.15 with the map view's
  snapshot per redraw (D-c). MapDocument and ScenarioDocument were deleted in 7.11.
- `OverworldRules.describe_recruit_source_compact` (7.8) takes the session as a value: the palette calls it with none
  before a map is loaded.
- The shadow check keeps each object's metadata Dictionary until its diff ends (`battle_port_bridge.cpp`,
  `verify_after`). In a call that loads two objects, the editor and its session, the second's metadata took the
  first's freed address, which the diff read as a Dictionary that GDScript repeats.
- `tools/rules_parity.py --editor` (seeds e-s2, e-m3 and e-dusk) runs `tests/map_editor_seat_report.tscn`. It opens a
  one-level package in the editor and, through its pickers, buttons and map clicks, paints, fills, draws lines,
  rectangles and roads, moves the hero start, and places, edits, rethemes, moves, duplicates and removes an object of
  each family. It also restores tiles, saves a copy, plays it and returns: 121 digest rows per seed.
  `tools/native_battle_switch.py` switches the editor's methods (`scenes/editor`).
Checks:
- Native mode against the branch's GDScript on the three editor seeds: 121 of 121 rows identical on each, 0 script
  errors; 66, 144 and 197 s native, 77, 171 and 225 s GDScript.
- Human shadow on the three editor seeds: 317,276 checks on 96 of the 104 entries. There are 0 mismatches apart from
  two explained kinds, 3 of each:
  - `_edit_selected_object_properties` on a town's owner: GDScript's copy of `OverworldRules.transition_town_control`
    finds the town through the spatial lookup index and so fills that cache, where the C++ `_find_town_by_placement`
    scans the towns. It is the same town, and native and GDScript mode leave the same caches after each edit. 7.15
    deletes the GDScript copy.
  - `_finish_package_copy`: `SessionStateStore.new_session_data`, a host call, has no shadow point in its GDScript
    body, so the check stops there.
  Shadow cannot run the four entries that call the engine (`_open_maps_folder_package_entry`, `_write_package_copy`,
  `_stage_working_copy_for_play` and `_resume_working_copy_session`, which gets the session as the snapshot's view):
  15 errors. The native run checks them. Not reached: the map cursor's semantic texts
  (`_editor_map_direction_for_action`, `_editor_map_cursor_semantic_context`,
  `_editor_map_action_result_semantic_text`, `_bounded_editor_map_semantic_text` and `_editor_tile_payload`),
  `_select_property_object_at_tile`, `_apply_object_property_value` and `_save_copy_failure`.
- One review of the 12 entries shadow did not check, and the helpers only they reach: no differences.

**Slice 7.15, one copy** (2026-10-24, branch `native-phase7-human`): each rule gets one copy, its C++ port. On the
branch, the two-copy bodies that GDScript still reaches become human registry entries, and the C++ functions defined
twice are folded into one. The merge deletes the GDScript bodies that nothing reaches any more.
- C++ folded, one definition each:
  - the private copies in `overworld_forecast.cpp` (enemy state, pressure, posture, town defence and command risk,
    the occupation release, terrain names, town lookups);
  - `overworld_rules_ai_towns.cpp` (the resource site guard checks) and `overworld_rules_ai_sites.cpp`;
  - `enemy_states.cpp` (army strength, now with its memo), `ai_hero_rules_turn_towns.cpp` (the opening stockpile),
    `overworld_level_rules_ai.cpp` (`level_of`) and `map_generation.cpp` (`num_real`);
  - `HeroProgressionRules.choose_specialty`: one function (`overworld_rules_hero_choices.cpp`) that the hero turn, the
    AI's commanders and the human choice call;
  - `random_growth_seed` moved into `hero_command_rules`. `new_growth_seed` without a session draws it, as
    `build_hero_from_template` does.

  Left as they are: the battle files' `_find_resource_node_by_placement` (`battle_context.cpp`,
  `battle_payload_callers.cpp`, `battle_resume.cpp`), the forwarders (`_town_controller_faction_id`, `risk_board_of`,
  `progress_recap_of`) and `copy_resource_amounts`, which differs from its namesakes.
- 59 entries in five groups. Each takes the C++ the game already ran inside the native calls:
  - 23 bodies that GDScript still reached beside their C++ copies: artifacts, the hero builder, the scenario state and
    objectives, the setup helpers, `NativeSceneryRules.policy` and `asset_candidates`, and
    `NativeTransitRules.network_colour`;
  - 5 that the campaign (GDScript, D-f) calls, with `ArtifactRules.merge_hero_artifacts` ported for its carry-over;
  - 11 that the router, the audio palette, the battle screen's snapshot, the editor's close guard and the battle AI
    arena's worker call;
  - 16 that the core tests and the AI match runner's `AiSeatRules` call;
  - 4 that the full-match quality tool calls (`tests/generated_full_match_quality.py`).
- Phase 7's five functions with a GDScript copy:
  - `NativeSceneryRules.policy`, `asset_candidates` and `NativeTransitRules.network_colour` are entries. The map view
    memoizes the first two by what they read (`drawn_policy`, `drawn_asset_candidates`).
  - `SessionData.from_dict` reads the C++ `normalize_payload` and `normalize_launch_mode`. `payload_for_storage` and
    `share_runtime_scenario_record` are deleted, with the autoload's copies.
Checks:
- Six seeds, native against main 77e4ef2a7, with all 59 entries: identical (443 daily digests and the match
  records). The same six seeds through the match runner (`--runner-b`) were identical after the C++ folds.
- Human shadow, 8 seeds, with a probe in the runner that calls every 7.15 entry after each move: 18,555,825 checks
  on 238 functions. 58 of the 59 entries were reached. Every mismatch comes from the probe's own calls (843 of
  843 traced to it):
  - growth seeds that both sides draw at random;
  - `movement_max_for_hero` and `normalize_difficulty` with a null argument: GDScript fails (`String(null)`), and
    the C++ uses the default difficulty;
  - `new_growth_seed` without a session, which C++ refused at the time (now fixed, see above).
- Editor shadow, 3 seeds: 1,381,269 checks on 181 functions, only 7.13's known kinds (15 engine-call errors, 3 + 3
  explained mismatches). The one entry no run reached, `MapEditorShell.consume_safe_close_guard_confirmation`, was
  read against its GDScript body: the same.
- Shadow on the six AI seeds: 1,024,369 checks on 25 functions; on five core tests (`ai_town_knowledge_report`,
  `battle_ai_flow_report`, `battle_deterministic_rng_state_report`, `player_elimination_rules_report`,
  `generated_start_hero_growth_seed_report`; all pass): 276,677 checks on 74 functions. 0 mismatches in both.

**Merge 4** (7.8, 7.9, 7.13 and 7.15, 2026-10-24): merged to main after main was tagged `pre-native-phase7-merge-4`
(D10). Main 6ef5ae55c was merged into the branch first.
- The 416 entries of 7.8 (192), 7.9 (61), 7.13 (104) and 7.15 (59) are NATIVE: their GDScript functions are thin
  wrappers over `HumanEngine.native`, and their 416 `__gd` bodies (12,871 lines) are gone. The human registry has no
  PORT entry left.
- 1,320 other GDScript functions (23,734 lines) that only each other and the tests reached are deleted: 402 in
  `OverworldRules`, 166 in `MapEditorShell`, 120 each in `BattleRules` and `EnemyAdventureRules`, 74 in `TownRules`,
  67 in `TerrainPlacementRules`, 66 in `ArtifactRules` and 305 in 26 other scripts. The 43 scripts the merge touches
  have 63,152 lines on main and 30,111 after.
- 166 tests and the harness `tests/support/HeadlessSimulationHarnessRules.gd` are retired (D-e,
  `docs/one-copy-test-retirement.md`): 113 tests and the harness called deleted bodies, and the others load, run or
  list one of them. Two tests read a site's controller through the public `PlayerIdentityRules.resource_controller_id`
  instead, which keeps the 21 tests and three tools that run on them. Seven tests' packaged modes stay broken.
- Rules with only a GDScript copy (345 functions, 5,786 lines): the campaign (`CampaignRules`, 115, D-f); the
  skirmish browser and setup (`ScenarioSelectRules`, 31); `ScenarioFactory.create_session` and its 12 helpers; the
  briefing and operational boards (`ScenarioRules`, 13); the battle screen's header, status, pressure, commander,
  initiative, effect and dispatch texts and its cue payloads (`BattleRules`, 20); `AnimationCueCatalog` (22) and
  `ProfileLog` (18); the overworld's getters, fog read scope and small accessors (`OverworldRules`, 20); the spell and
  artifact reports with `describe_battle_spellbook` and `describe_loadout`; `AiSeatRules`, the field transfers
  (`HeroCommandRules`) and the engines' view helpers.
  Follow-up (owner request 2026-10-27, pending slice `native-rules-gdscript-only-rules-20261027`): the game rules
  among them move to C++: the skirmish browser and setup, `ScenarioFactory.create_session` and its helpers, the
  field transfers and `AiSeatRules`. The texts, reports, boards, cue payloads, `AnimationCueCatalog`, `ProfileLog`,
  the getters and the view helpers stay GDScript.
- Checks of the merged code against main 6ef5ae55c:
  - the `--human` check identical on the eight seeds, 1,896 action digests and the records;
  - the `--editor` check on its three seeds: the state identical at every step main runs, and the panels too once
    main's "Export intent" line (the authored export, deleted by D-h) is left out of their hash. That covers the first
    116 of the 121 steps. On main 6ef5ae55c, step 117 (Save Copy) fails:
    `ScenarioSelectRules.load_maps_folder_package_session_from_entry` stops on `String(float) is not ported`, so
    the saved pair is not adopted. On the branch, Save Copy and the steps after it run clean;
  - the six seeds identical, 443 daily digests and the match records, and the same six through the match runner
    (`--runner-b`);
  - core suite 17/17.
- UI speed, screen time per action in ms, main | branch (the eight seeds, six runs at once): opening a town 73.5 |
  56.4, town actions 239 | 219, end of turn 1,244 | 1,227, battle 577 | 573, leaving a town 7.5 | 7.5. Slower on
  the branch: arming a move 38.4 | 53.7, hero 74.9 | 88.2, dialogs 95.1 | 109.1, move 190 |
  200, hover 1.4 | 4.6.

**UI speed after merge 4** (2026-10-24, owner decision: speed up the screen actions merge 4 made slower, results
identical). Profiled per native call: arming a move made 1,571 native calls, 1,022 of them `level_of`.
- The map view's placement signature hashes the level fields instead of calling `level_of` per entry; the shell's
  town, resource, artifact and encounter lookups read the view level once per loop, and it keeps each resource node's
  pathing surface while the node is unchanged; the stockpile menu keeps its resource definitions.
- Seven `OverworldLevelRules` entries that write nothing are no longer writing calls. A writing call that changed
  nothing it loaded and made no host call leaves its arguments as they were (`AurelionRules.port_last_wrote`), and
  `DayEngine.native_writing` then skips taking the views back. `_view` reads the session's members directly.
- Checks against main 6ef5ae55c: the `--human` check identical on the eight seeds (1,896 action digests and the
  records), the six seeds identical (443 daily digests and the match records) and the core suite 17/17.
- Screen time per action in ms, main 6ef5ae55c | merge 4 | now (the eight seeds, two runs at once for main and now;
  merge 4's numbers are its six-at-once run): arming a move 37.3 | 53.7 | 40.7, hero 75.1 | 88.2 | 75.7, dialogs
  94.5 | 109.1 | 98.6, hover 1.4 | 4.6 | 1.3, move 185.8 | 200 | 186.7. Arming a move still makes about 400 small
  native calls (view level, hero position, level checks), each about 10 µs of view and boundary.

### Phase 8: a match runner without Godot

Wanted, not optional (owner decision 2026-10-22, D7). The same core as a command-line tool, `match_sim_cli` beside
`battle_sim_cli`. It runs alongside Phase 7 and touches none of the setup and save code Phase 7 has frozen.

**Owner decisions** (2026-10-23, on the inventory and plan; D4 and D12 in section 8):
- **D4, option B.** One portable `pow`/`exp`/`log` in the core, used by the game's host and by the runner, accepted
  as one named behaviour change (P8-2). Every rules copy uses it: the GDScript offer draw (`HeroProgressionRules.gd`,
  human level-ups) calls the native function.
- **The elimination day.** Phase 8 ports the computer-player branch of `PlayerEliminationRules.apply_daily` (P8-1);
  Phase 7's 7.7 keeps the human branches.
- **Statics.** Native state in the runner first; the game keeps reading GDScript until Phase 7 deletes the last
  GDScript readers.
- **Generation in the runner last** (P8-8), after Phase 7's merge 1b frees `MapPackageService`.
- **Order and merges.** P8-1, P8-2, then P8-3 to P8-6 as one milestone, P8-7 after merge 1b, P8-8. Main is tagged
  before each merge (D10).

**Inventory** (main 2abd6e086):
- `aurelion_rules_core` has no godot-cpp; the Godot-facing code is `rules/gdextension/`. The core has the engine
  copies a runner needs (Variant hash, JSON, float text, PCG32, rounding, the content tables of 7.10) and reaches the
  outside through `state::Backing`. `battle_sim_cli` is already such a host, playing Godot-written snapshots
  (`ARSNAP01`) on threads.
- An AI-only day is one native call (`end_turn` on the kept session). The runner's digest, standings, notes and
  record are GDScript around it. Setup (generation, the package save and load, adoption, the seat handover) is
  GDScript and the map GDExtension, which is Godot-typed throughout; packages are JSON text. The H3MapEd generator
  core is Godot-free.
- The one rules path an AI-only match still ran in GDScript: a computer player whose townless days are up
  (`player_elimination.cpp`), 4 days on the six seeds, each rerunning the day's close in GDScript and dropping the
  kept session.
- The port reads GDScript statics through the bridge: 16.2 million reads in four games of the Phase 6 profile.
- `pow`, `exp` and `log` (7 call sites: `army_power`, `hero_power`, the route loss limit, the specialty offer draw) go
  to the engine in the game and to the UCRT in the tools. The engine's are MinGW-w64's, linked into the Godot binary
  (it imports only `_vsnprintf` and `log10` from msvcrt). On 65,536 inputs per function in the game's ranges they
  differ by 1 ulp in 0.18% (army-power pow), 0.20% (offer-draw pow), 0.49% (exp) and 0.04% (log) of calls; neither
  side is correctly rounded every time (engine 9 to 40 misses per 65,536, UCRT 16 to 333).

**Slices:**

| Slice | What | After |
|---|---|---|
| P8-1 Elimination day | the computer branch of `apply_daily` in C++ (done) | |
| P8-2 D4 | one `pow`/`exp`/`log` in the core for the game and the runner; the named behaviour change (done) | P8-1 |
| P8-3 Statics | a native statics store in the runner's host, initial values checked against Godot's (done) | |
| P8-4 The runner | `match_sim_cli` playing sessions Godot prepared (snapshots), the runner's glue in C++, the same outputs (done) | P8-2, P8-3 |
| P8-5 The proof | a runner side in `rules_parity.py`: the six seeds' digests and records identical to game mode (done) | P8-4 |
| P8-6 Batches | `ai_match_batch.py --runner`: Godot prepares, the runner plays on threads; timing (done) | P8-5 |
| P8-7 Packages and setup | packages read in the core; sessions created natively from a package and a seed (7.11) (done) | merge 1b |
| P8-8 Generation | the map library's projection Godot-free; the runner generates its maps (done) | P8-7 |

**P8-1, the AI-match elimination day** (`native-rules-phase8-01-elimination-20261023`, branch
`native-phase8-elimination`):
- **What changed.** `player_elimination_rules::apply_daily` runs a computer player's removal when its townless days
  are up: the rosters normalized once (`normalize_all_commander_rosters`), the player's heroes marked resolved and
  their defeats recorded (`_remove_computer_player`), and the message with the faction's name. All the helpers had
  C++ ports already. The human branches (the defeat with no town and no hero, the townless warning, the townless
  defeat) stay `NotPorted` for 7.7, and `apply_daily__gd` stays for them. No AI-only day falls back now.
- **Checks.** Day shadow on the six seeds: 7,841 checks, 0 mismatches, 0 errors, 0 left to GDScript;
  `apply_daily` checked 437 times, the 4 elimination days (l1 2, mw 2) among them. Native against main 2abd6e086:
  all 443 daily digests and the records identical; NATIVE FALLBACK lines 12 on main, 0 on the branch. Core suite
  17/17.

**P8-2, one `pow`/`exp`/`log`** (`native-rules-phase8-02-math-20261023`, branch `native-phase8-math`; D4 option B):
- **What changed.** The rules' `pow`, `exp` and `log` are Arm's optimized-routines v26.07
  (`src/gdextension/rules/third_party/arm_optimized_routines`, MIT; its README records the source, the version, the
  three local changes and why not CORE-MATH), built as `aurelion_rules_math` on the generic paths: no FMA, no
  rounding instructions. `Backing::math_pow`, `math_exp` and `math_log` answer with them (`compat/portable_math.hpp`);
  the game's host no longer overrides them with the engine's, and `battle_sim_cli` overrides them only to count the
  calls. `gd::engine_pow`, `engine_exp` and `engine_log` are renamed `gd::math_pow`, `math_exp` and `math_log`. The
  GDScript offer draw (`HeroProgressionRules._offer_order`, human level-ups) calls `AurelionRules.math_pow`. No other
  GDScript the game runs as a rule calls `pow`, `exp` or `log`; the rest are animation and sound (`CombatVfxMotion`,
  `OverworldGainFloaters`, `OverworldMapView`, `OverworldPortalFx`, the audio autoloads) and one test report.
  `rules_selftest` digests the three on 2^20 rounds (`portable_math`), a digest every build must give.
- **The behaviour change.** On 1,000,000 offer draws and 1,000,000 army-power calls in the game's ranges, the new
  `pow` differs from the engine's by 1 ulp in 710 (0.071%) and 1,276 (0.128%) calls, never by more. Neither rounds
  correctly every time: where they differ, the engine's result is the correctly rounded one in 625 and 708 of the
  calls, the new one in 85 and 568. The game takes the new one because every build gives the same bits, not for
  accuracy.
- **Checks.** Native against main f5d2ddfb8 on the six seeds: all 443 daily digests and the records identical, so no
  rounding difference changed a game there. `--human` against main: all 1,896 action digests and the records of the
  eight human seeds identical. Core suite 17/17. `rules_selftest` ok (13 helpers).

**P8-3 to P8-6, the runner** (`native-rules-phase8-03-statics-20261023` to `native-rules-phase8-06-batch-20261023`,
branch `native-phase8-runner`, one milestone):
- **P8-3, statics.** `match_sim_cli`'s host keeps the rules scripts' static vars as native state
  (`Backing::static_get` and `static_set`, one table per match), kept from day to day as the game keeps them. They
  start as a capture of a game that has played nothing (`tools/rules_snapshot/rules_snapshot.gd`, `static_vars`,
  written into `content.snap` by the first prepare): memos and caches empty, the weight revision cold, so the native
  `_use_weights` loads `content/ai_hero_weights.json` (or the seat's weight set) where the game's GDScript loads it.
  A day answers no host call; a host call or a NATIVE FALLBACK path fails the match. The game itself still reads
  the GDScript statics.
- **P8-4, `match_sim_cli`.** The match runner scene's prepare mode (`HEROES_AI_MATCH_PREPARE`) sets a match up as
  before (map, adoption, the seats' handover), writes the session as a snapshot (the session view, seats, setup,
  handover, seeds, map, scenario row and terrain layers, content revision, the weight document of weighted seats)
  and `content.snap` beside it when missing (content tables and files, the statics capture), and stops.
  `src/gdextension/rules/cli/match_sim_cli.cpp` plays the days from there: each day is the registry's
  `OverworldRules.end_turn` on one State kept across the days and compacted after each, and the scene's GDScript
  around it (digest, notes, ledger, town weeks, the end of the match, the record and the report line) is C++ calling
  the same native functions. It reads the scene's settings (`HEROES_AI_MATCH_*` or `HEROES_AI_MATCH_LIST`) and writes
  the scene's outputs: the record JSON text byte for byte apart from the timing fields, the report and BEGIN lines,
  the digest file. Matches play on `--threads`, one per thread; the rules core has no mutable statics.
  `battle_sim_cli` and the battle arena's worker share the snapshot reader and writer (`cli/snapshot_store.hpp`,
  `rules_snapshot.gd`); `godot_string`'s `json_float` gains the full-precision form. Built by `build_native.py`
  with the rules part.
- **P8-5, the proof.** `rules_parity.py` has a runner side: `--runner-a`/`--runner-b` for `check`, `--runner` for
  `run`; Godot prepares each seed, then `match_sim_cli` plays it, with `--one-process` all six in one CLI process on
  threads. Game mode against the runner on the six seeds: all 443 daily digests and the records identical, and
  again with the six in one process. Host calls 0; content misses only the empty-id scenario and terrain-layer
  lookups the scene makes too.
- **P8-6, batches.** `ai_match_batch.py --runner`: the Godot processes prepare the matches (slots and matches per
  process as before; a snapshot already there counts as prepared, so a resumed batch reuses it), then one
  `match_sim_cli` process plays them, biggest first, on the batch's slots as threads, writing each row as its match
  ends and deleting its snapshot. Rows, records and summary are the current path's; not with `--release`. A three-match
  batch gave records equal to the editor path, the summaries differing only in the slowest AI day's time.
- **Timing** (Windows, 32 logical cores, nothing else running):
  - The six seeds, each side in one process: game 125.6 s (one Godot process, one seed after another), runner
    56.6 s (prepared in 28.5 s in one Godot process, then the 437 days in 22.7 s on 6 threads), 2.2 times faster.
  - 24 small 2P matches (plan seed 8231, 16 slots): game 17.0 s, runner 19.5 s (705 days in 4.4 s; the rest is
    the setup in Godot).
  - 24 medium 3P matches (plan seed 8232, 16 slots): game 41.3 s, runner 43.4 s (1,820 days in 23.5 s).
  - All 48 batch records equal apart from the timing fields.
  - So at the same slot count the runner gives no batch speed-up yet. The days are the same native code on both
    sides and about as fast (l1: about 25 s of days in the game, 22.6 s in the runner), and a batch's Godot
    processes already fill its slots. The runner gains where the game would play one match after another in one
    process. The setup stays in Godot until P8-7 and P8-8.
- **Checks.** Six seeds, game against runner and against runner in one process: 443 digests and the records
  identical both ways; main 92c672a3e's game against the branch's runner: identical again. The battle arena's
  quick suite (`--plain`) plays its 72 games from the worker's new content snapshot. Core suite 17/17. Windows only: the Linux libraries in `bin/` are not rebuilt and the Linux
  `match_sim_cli` is not built.

**P8-7, packages and setup** (`native-rules-phase8-07-packages-setup-20261023`, branch `native-phase8-packages`,
after Phase 7's merge 1b):
- **Packages in the core.** `aurelion_rules/map_packages.hpp` (`core/map_packages.cpp`) ports
  `MapPackageService.load_map_package` and `load_scenario_package`: the file, the engine's JSON parse
  (`compat::json_parse`), the schema, document and dimension checks, the same result and failure dictionaries. Like
  the game's load it does not check `package_hash`. It ports the `MapDocument` and `ScenarioDocument` methods too,
  all but `get_objects_in_rect`, which takes a `Rect2i` and stays NotPorted. A host keeps each document behind an
  opaque value. `content::DiskFiles` (`aurelion_rules/disk_files.hpp`) reads res:// files from a project folder,
  files added in memory first. It answers `ResourceLoader.exists` as the editor does: an imported file's `.import`,
  or a resource the engine loads as it is.
- **Sessions created natively.** The scene's prepare mode now stops after the map (generated, from the corpus, or
  kept in a list). It writes the setup, both packages' bytes, the project folder and the match's settings.
  `match_sim_cli` starts the session from them with Phase 7's native setup
  (`ScenarioSelectRules.start_random_map_skirmish_session_from_setup`, 7.11) and answers the engine calls it makes:
  - the package service and documents: the core port, reading the snapshot's packages;
  - the art lookups: the project folder on disk;
  - `SessionStateStore.new_session_data`: a SessionData of its own, as `_init` sets it;
  - `ContentService.canonical_town_id`: the towns file;
  - `OS.has_feature("editor")`: true.

  Then the scene's normalize and handover run in C++: `AiSeatRules.hand_human_seat_to_ai` as glue over the
  ported `transition_town_control`, `normalize_overworld_state` and `invalidate_spatial_lookup`, then the battle
  log flag, the seats' weight sets, `_check_handover` and the record's setup. `content.snap` gains the three
  overworld art files the adoption reads and the static vars of `scripts/persistence` (the adoption's caches).
  The packages travel in the snapshot, so a batch can still delete them from `maps/` after the prepare. Content
  still comes from `content.snap`, and generation stays in Godot until P8-8.
- **Checks.** Six seeds, game against runner and against runner in one process: all 443 daily digests and the
  records identical both ways. The runner's host calls are one `SessionStateStore.new_session_data` per match;
  its content misses are only the empty-id scenario lookups the scene makes too. A scratch list of one map twice:
  the kept second match's record equals the first's. The battle arena's quick suite (`--plain`) plays its 72
  games. Core suite 17/17. Windows only: the Linux libraries in `bin/` are not rebuilt.

**P8-8, generation in the runner** (`native-rules-phase8-08-generation-20261023`, branch `native-phase8-generation`):
- **The projection in the core.** `aurelion_rules/map_generation.hpp` (`core/map_generation.cpp`, the library
  `aurelion_rules_generation`) ports the map library's `MapPackageService.normalize_random_map_config`,
  `generate_random_map`, `convert_generated_payload`, `save_map_package` and `save_scenario_package` and what they
  call (`src/gdextension/src/map_package_service.cpp`). It runs over the H3MapEd generator core, which the runner now
  compiles from the map library's own sources (`aurelion_h3maped_rmg`), so the generator stays one copy. The content
  catalogs come from files through the engine's JSON parse. The packages are written as `JSON.stringify(package,
  "\t", true)` writes them (`compat::JsonWriter`, new in the core) into `content::Files`, which the runner keeps in
  memory. The generator's last result is kept per thread, as the map library keeps it per process. The package
  browser cache is not written.
- **Two copies.** The map library keeps its copy for the game, the editor and the tools. A behaviour change to the
  projection, the package writes and loads or their checks (P8-7's loads too) goes into both copies in the same
  commit, plus one six-seed `rules_parity.py check . . --runner-b`.
- **The runner generates.** The match runner scene's `HEROES_AI_MATCH_CONTENT_SNAPSHOT` writes only the content
  snapshot, with the project folder, and stops. With `HEROES_AI_MATCH_CONTENT`, `match_sim_cli` does the scene's
  match start in C++:
  - the match seed and the line-up's draw (`ScenarioSelectRules.random_map_faction_options`, the scene's PCG);
  - the map seed and the player config;
  - `build_random_map_skirmish_setup_with_retry` (7.11's native setup, now over the core's package service);
  - then the session as in P8-7.

  It answers `ContentService.get_content_ids` from the content snapshot. Weight sets go by name. A `.json` weight
  set or a map corpus still needs the scene's prepare mode (`HEROES_AI_MATCH_SNAPSHOT`), which stays. On a thread,
  a match on the map and line-up of the match before it is "kept", and one on the same map with another line-up
  is "reused". Those are labels only; the session is the same either way.
- **Tools.**
  - `rules_parity.py --runner-a/--runner-b/--runner`: one Godot run writes the content snapshot, then the runner
    generates and plays.
  - `ai_match_batch.py --runner`: the same. Matches with a map corpus or a `.json` weight set are still set up in
    Godot first.

  One Godot run per batch remains, for the content snapshot.
- **Checks.**
  - Six seeds, game against the runner in one process: all 443 daily digests and the records identical.
  - Four setups generated by the game and by the runner: all eight package files byte-identical and the records'
    setups equal. The setups were small 2P, medium 3P normal water, large 4P two levels and extra large 6P islands
    two levels.
  - A two-match `ai_match_batch.py --runner` smoke run. Core suite 17/17.
  - Not run: the generator crash Phase 7 found on main (extra large, 8 players, normal water, two levels, seed
    72136). It was a task of its own, fixed on 2026-10-26 by `84b035204`
    (`native-rmg-river-post-pass-vector-walk-20261026`).
  - Windows only: the Linux libraries in `bin/` are not rebuilt and the Linux `match_sim_cli` is not built.

**P8-9, one copy of the package code** (`native-rules-phase8-09-fold-20261024`, branch `native-phase8-fold`):
- **The map library over the core.** `MapPackageService` (`src/gdextension/src/map_package_service.cpp`) is thin
  wrappers over the core: the package loads and document checks (`core/map_packages.cpp`), and the config normalize
  and identity, generation, conversion, package writes and document hashes (`core/map_generation.cpp`). The map
  library compiles those core files (`aurelion_map_rules_core`, with the core's `pow`/`exp`/`log`), and its own
  copies are gone (`map_package_service.cpp` from 3,789 lines to 1,034; the boundary is 640). What only the map
  library has stays there: the legacy scenario conversion, the package inspection and its browser manifest cache,
  which a package write still fills.
- **The boundary** (`src/gdextension/src/core_bridge.cpp`). A call's Godot values go into a core `State`, where a
  container that comes in twice is one node. The answer comes back as Godot values: a container the core left unchanged as the
  one it came from, a changed one refilled in place. `MapDocument` and `ScenarioDocument` objects are read into the
  core's documents when the core first asks for one, and documents the core makes come back as new objects. Files go
  through `FileAccess`; a package is written beside its target and renamed over it after a checked write, as before.
  The generator's last result is kept per process, as before. The map library is built with exceptions
  (`GODOTCPP_DISABLE_EXCEPTIONS OFF`): a core failure is a `push_error` and a `native_failure` result.
- **One copy.** A change to the package loads, the projection, the package writes or their checks goes into the core
  only, plus one six-seed `--runner-b` check. The `MapDocument` and `ScenarioDocument` accessors keep a Godot copy
  beside the core's: a behaviour change to one of them goes into both.
- **Checks.**
  - Four setups generated by the game (small 2P, medium 3P normal water, large 4P two levels, extra large 6P islands
    two levels): all eight package files byte-identical to main's and the records' setups equal.
  - Six seeds against main, the game and the runner (`--runner-b`): all 443 daily digests and the records identical
    both ways.
  - Core suite 17/17. Windows only: the Linux libraries in `bin/` are not rebuilt.

**AI turn speed** (`native-rules-phase8-ai-speed-20261024`, owner decision 2026-10-24). On large and extra large maps
about two-thirds of a match's time was in the generic State dictionary and value layer. Four changes, in this order,
each merged on its own, each keeping games identical: A, the key index for Int and Vector2i keys; B, the placement-id
tables apart from the tile tables, then the spatial index updated instead of rebuilt; C, the day close's repeated
enemy-state normalizes skipped when they would rebuild identical states, or dropped; D, the runner compacting every
N days. Timing: eight AI games on the runner (large 3P and 4P, extra large 5P and 6P, one and two levels, land,
normal guards, day cap 320, seeds `p8prof-<game>`), the build before and after side by side, 16 runners at once, two
rounds, the runner's own seconds.

**P8-10, the key index** (`native-rules-phase8-10-keyindex-20261024`, branch `native-phase8-keyindex`):
- `KeyList` (`battle_state.hpp`) puts Int, Vector2i and Vector3i keys in the table its string keys use, the first
  slot of each key, built at the same point and following `push_back`. Nil, bool, float and container keys are
  scanned as before. A key matches as before: the same kind and value.
- Checks: six seeds against main, game and `--runner-b`, all 443 daily digests and the records identical;
  `--human` on its eight seeds, 1,896 action digests identical; core suite 17/17.
- Timing: 710.1 s to 622.6 s (-12.3%). Per game -3.4% (large 3P two levels) to -23.4% (extra large 5P one level).
  Records identical. Windows only: the Linux libraries in `bin/` are not rebuilt.

**P8-11, cheaper spatial index rebuilds** (`native-rules-phase8-11-spatial-20261024`, branch `native-phase8-spatial`):
- `State::pair_atom` keeps the atoms of the tile keys ("x,y") by their numbers, so a rebuild formats and hashes each
  tile's text once per State.
- `_spatial_resource_section` compares the resource nodes' fingerprint fields with the kept copy in place and builds
  the fingerprint only when it rebuilds the section.
- The index is built and dropped at the same points as before. The index is read stale: during an AI hero's walk
  the hero's steps are written before `invalidate_spatial_lookup`, and queries in the walk read the index built
  before it. In the extra large 6P one-level game, 139 such reads use an index that `placement_level` built.
  Skipping that build, or updating the index in place, would hand those reads a fresher index and change games, so
  neither is done.
- Checks: six seeds against main, game and `--runner-b`, all 443 daily digests and the records identical; core suite
  17/17.
- Timing: 599.0 s to 584.0 s (-2.5%), per game -0.2% to -4.3%. Records identical. Windows only.

**C and D, not merged.**
- C, the day close's second enemy-state normalize skipped: dropped, since it cannot be shown to rebuild identical
  states. On the eight games it never changed a value in 1,406 day closes. But between the two calls
  `normalize_overworld_state` rewrites session fields, towns, resource nodes and heroes that the normalize reads, and
  the State's watch counts every write, so an exact guard needs the normalize's whole read set audited.
- D, the runner compacting every N days: N stays 1. With 16 extra large 6P games at once and a compaction every day,
  the runner's peaks sum to 92 GB (2.5 GB to 12.8 GB per game) on a 64 GB machine; the machine restarted during the
  run at every fourth day. Alone, a 320-day game peaks at 15.6 GB instead of 12.8 GB at every second day (-8.8% time),
  a 119-day game at 3.1 and 4.3 GB instead of 2.5 GB at every second and fourth day. Records identical at every
  interval. The option (`--compact-every`, with `State::settle` marking the day's new nodes as a compaction would)
  is on branch `native-phase8-compact`.
- D after P8-12, still not merged: with the node buffers freed, compacting less often no longer pays. The 320-day
  game alone: 1.36, 2.11 and 3.37 GB and 258.9, 273.3 and 294.8 s at every 1, 2 and 4 days. 16 games at once
  (seeds `p8mem-0` to `p8mem-15`): every day, the peaks sum to 15.3 GB, at most 12.7 GB in use at once. Both builds
  side by side, 8 + 8 games, two rounds: every second day 2,803.9 s against 2,827.9 s (-0.85%; -1.7% and 0.0%) for
  about 30% more memory. Records identical at every interval (16/16). N stays 1.

**P8-12, node buffers freed on reset** (`native-rules-phase8-12-buffers-20261024`, branch `native-phase8-buffers`):
- Cause: `NodePool` reuses node slots after each compaction, and `ArrayNode`, `DictNode` and `PackedNode::reset()`
  kept their lists' heap buffers (the `ValueList` capacity, the `KeyList` table, the packed vectors). A game makes
  1.4 to 2.6 million nodes a day and keeps about 0.65 million, so every slot came to hold the largest list it ever
  held: an extra large 6P game grew about 37 MB a day while its live nodes stayed flat.
- Change: `reset()` frees them (`ValueList::reset`, `KeyList::reset`, the packed vectors swapped empty).
- Peak private memory, extra large 6P, land, normal guards, one game at a time (seeds `p8mem-2`, 119 days, and
  `p8mem-9`, 320 days):

  | | Day 119 | Day 320 | 320-day game |
  |---|---:|---:|---:|
  | Godot, before | 3.0 GB | 13.6 GB | 376 s |
  | Godot, after | 1.2 GB | 2.3 GB | 281 s |
  | Runner, before | 2.5 GB | 12.8 GB | 354.2 s |
  | Runner, after | | 1.4 GB | 319.9 s |

  The runner's times are three games at once; the records are identical in every pair.
- What still grows: 1.6 GB to 2.3 GB from day 30 to day 320 in Godot. The atom table only grows (43,072 to 576,407
  strings in the 320-day runner game); the rest is not split further.
- Checks: six seeds against main, game and `--runner-b`, all 443 daily digests and the records identical;
  core suite 17/17. Windows only: the Linux libraries in `bin/` are not rebuilt.

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
| D4 | **Decided 2026-10-23, option B:** one portable `pow`/`exp`/`log` in the core for the game and the runner, accepted as one named behaviour change (Phase 8, P8-2); every rules copy uses it. Options A (copy the engine's MinGW-w64 math) and C (accept last-bit differences) were declined. Done in P8-2 (Arm optimized-routines v26.07) | Phase 8 |
| D5 | **Phase 1 decided 2026-10-20:** battle-rule and battle-AI code take no behaviour changes from the start of Phase 1 to its merge; an urgent fix lands in GDScript on main and is ported on the branch; content JSON and `battle_ai_weights.json` stay open (AGENTS.md "Native rules port"). AI code: decided before Phase 4 | before each |
| D6 | **Decided 2026-10-20:** tests that call private battle functions the port deletes are retired at the Phase 1 merge by the `docs/rmg-test-retirement.md` process; the parity corpus and the core suite cover battles. Done with Phase 2d, 2026-10-23: 46 tests (`docs/battle-test-retirement.md`) | Phase 1 |
| D7 | **Decided 2026-10-22:** battle and match simulators run outside Godot, as command-line tools built from the same core: `battle_sim_cli` is Phase 2's battle tool, and Phase 8's match runner is wanted. There was never an owner rule against a simulator outside Godot; that wording in PLAN.md was an agent's, and it is removed | Phase 2 |
| D8 | **Decided 2026-10-20:** Phase 1 lives on one port branch, `native-phase1-battle` on GitHub, rebased on main at least weekly and before each slice, and merges to main once, when every battle is native and identical; it is dropped if checkpoint G1 stays under 5x after the interface fix (AGENTS.md "Native rules port") | Phase 1 |
| D9 | **Decided 2026-10-22:** copies of the owner's five saves on this computer (Mireclaw Zhorra Fenwake days 1 and 14; Veilmourn Ivara Blacktide days 5 and 10 and the autosave; save version 9) and the two generated maps they reference live in `D:\Games\godot\heroes-like-save-copies` (outside git, with `SHA256SUMS` and a README). The originals are never touched; runs read the copies with an isolated user profile | Phase 4 (4.4) |
| D10 | **Decided 2026-10-20:** main is tagged before each port merge. Owner 2026-10-21: no waiting period after it (the 7 days without behaviour commits was removed) | each merge |
| D11 | **Decided 2026-10-23:** Phase 7's scope and checks (Phase 7, "Owner decisions", D-a to D-e): a permanent human seat in `tools/rules_parity.py`; every rule native, only the screens in GDScript; one map snapshot per redraw; no GDScript way back; retired tests by D6. Plan revision 2 (D-f to D-h): the campaign runtime moves with the campaign rework, `RandomMapGeneratorRules.generate` and the editor's authored-scenario export are deleted; order 7.1, 7.10 to 7.12, 7.2 to 7.9, 7.13, 7.15; four merges. Later (D-i): the archived content's start-up checks are deleted and the live files' checks ported; the first merge is split into 1a (7.1, 7.10) and 1b (7.11, 7.12) | Phase 7 |
| D12 | **Decided 2026-10-23:** Phase 8's plan (Phase 8, "Owner decisions"): D4 option B; Phase 8 ports the computer branch of the elimination day and Phase 7's 7.7 keeps the human branches; statics native in the runner first; generation in the runner last; P8-1, P8-2, P8-3 to P8-6 as one milestone, P8-7 after Phase 7's merge 1b, P8-8 | Phase 8 |

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
