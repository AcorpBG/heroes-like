---
name: ai-match-batch
description: Run owner-requested AI-vs-AI evaluation on generated maps and report balance, including full faction arrangements and fixed hero/army rolls. Use only for explicit match requests, never as regression validation.
---

# AI match batch

Plays many complete AI-vs-AI games at once and compares them. `tools/ai_match_batch.py` plans the
batch (an explicit seed, setup and line-up per match), plays the matches from one queue, by default
in `bin/match_sim_cli` outside Godot (`--runner`) or else in headless Godot with
`tests/ai_versus_ai_match_report.tscn`, and writes `summary.md`. You start it, relay its progress
lines and report from the summary.

## When to use it

- **Only when the owner asks for AI matches.** A batch takes the whole machine for minutes to a
  couple of hours. It is an evaluation tool for the owner to see how the computer players behave,
  not a regression test (owner decision, 2026-10-10; AGENTS.md "Validation budget").
- **Not as validation.** Do not run it, `run_match.sh` or `tests/ai_versus_ai_match_report.tscn`
  to check your own change, including AI, balance or content changes. Verify those with the focused
  tests for the code you touched and `python tools/core_suite.py`. If you think a batch would
  tell the owner something useful, say so in one line and let them decide.
- **Not repeatedly.** Run the batch the owner asked for, once, and report. Rerun only if the owner
  asks, for example after a fix they want to compare.
- Debugging one specific stuck or odd match the owner pointed at may replay that seed (see the
  end of section 4). That is not a new batch.

## 1. Settle the parameters

Take these from the request; use the defaults for anything not given. Do not ask about defaults.

| Parameter | Default | Option |
|---|---|---|
| where the days play | `--runner`: `bin/match_sim_cli`, outside Godot | without `--runner`: headless Godot; `--release`: an exported release build in Godot |
| matches | 5 | `--matches N`, any number |
| players | 3 | `--players 2`-`8` |
| size | medium | `--size small`, `medium`, `large`, `xl` |
| several setups in one queue | | `--group 3:medium:30 --group 4:large:30` (players:size:matches) |
| line-ups | balanced | `--lineups random` (distinct sets), `mirrors` (a faction may repeat), or `--lineup a,b,c` per line-up in seat order |
| faction arrangements on one map | all for balance checks | `--all-arrangements`: every permutation (24 for 4P), with fixed faction hero/army rolls; balanced counts round up to complete faction-set cycles |
| legacy cyclic rotations | | `--rotate`: only cyclic rotations; `--fixed-rolls` pins hero/army rolls but does not add the missing arrangements |
| AI weight sets | default | `--weights W1,W2,...` per seat: `default`, a set in `content/ai_hero_weights.json` or a `.json` file of changed values |
| guards | normal (as a new game) | `--guards weak,normal,strong` |
| water | land (as a new game) | `--water land,normal_water,islands` |
| levels | 1 (as a new game) | `--levels 1,2` (2 adds the underground) |
| day cap | 320 | `--days N` (160 before 2026-10-16) |
| worker processes at once | 16 | `--slots N`; each native worker has one thread; lowered when other games or native workers are running |
| desktop use | | `--desktop` selects 8 worker processes; an explicit `--slots N` takes precedence |
| matches before recycling a process | native 32, Godot 4 | `--per-process N`; whole rotation groups stay together, so one group can exceed a smaller explicit limit |
| timeout per match | small 30, medium 90, large 180, xl 360 min | `--timeout-min N` |
| plan seed | random | `--seed N`: the same seed and options give the same plan |
| kept maps | | `--map-corpus DIR`: keeps each generated map so another batch on the same plan and commit skips generation (to compare weight sets on the same maps) |
| only plan, or only summarize | | `--plan-only` writes `plan.json` and stops; `--summarize` rewrites `summary.md` from `results.jsonl` |

- **Pass `--runner`** unless the owner asks for games in Godot or a release build.
  - **How it runs:** one Godot process writes the content snapshot into `<out>/snapshots`. A
    refilling pool of **16 `bin/match_sim_cli` processes, one thread each**, generates and plays
    the matches, biggest first. Use **`--desktop` for 8 processes**. Each process exits after a
    bounded list (up to 32 games by default), releasing its accumulated RAM; a replacement takes
    more queued work. Lists are shorter near the end so more workers can stay busy. A map's
    rotations run together in one process. Matches from a `--map-corpus` or with a `.json` weight
    set are set up in Godot first, in batches of at most four games (whole rotation groups).
  - **Controls:** `--slots` counts processes, not threads. `--per-process` controls recycling,
    not concurrent games. Queueing more games keeps workers supplied. The execution settings
    are saved in the plan and reused on resume; explicit flags override them.
  - **What you get:** the same games as in Godot (`tools/rules_parity.py --runner-b` checks it), and
    the same records, rows and summary.
  - **Why:** each game is faster and lighter than in Godot (see the times below).
  - **What it needs:** the commit's `bin/match_sim_cli`, which is tracked in git; after a native
    change it is rebuilt with `python tools/build_native.py windows --part rules`. `--runner`
    takes no `--release`.
  - **Failures:** anything the native rules cannot do on their own fails the match (a `FAILED` row)
    instead of printing a SCRIPT ERROR. Report it as a bug with its seed.

- **Player counts follow the map size** (owner, 2026-10-18): small 2, medium 2-3, large 3-4,
  xl 5-6. Never large maps with 2 players; the tool warns about it.
- **Lists are crossed.** `--guards weak,normal,strong --levels 1,2` spreads the line-ups evenly
  over all six setups, so consecutive seat rotations of one faction set get different setups.
- **Balanced line-ups** play each set of factions in every seat rotation, each set once before
  any set repeats, so every faction gets the same games and first seats. For balance checks, pass **`--all-arrangements`**: a full cycle with six factions is 30 games for 2P, 120 for 3P, 360 for 4P, 720 for 5P and 720 for 6P. Counts round up to full cycles (about 600 4P games becomes 720). Each map uses all permutations of one faction set; the tool balances faction sets and starting slots. `--rotate` covers only cyclic orders and must not be described as all arrangements.

Windows measurements before pool integration, 2026-10-24, Ryzen 9 5950X (16 cores / 32 logical processors), 64 GB,
build `9b2fd219d`, large 3P two-level maps, land/normal water and normal/strong guards:
- On the same 96 games stopped at day 60, one process with 16 threads took 18m 57s;
  16 single-threaded processes took 2m 24s, with identical records apart from timing.
- On 288 games stopped at day 20, 16 / 24 / 32 single-threaded processes took 138 / 136 / 135 s
  and peaked at 9.5 / 13.4 / 17.1 GiB private RAM. Sixteen processes with two threads took 148 s
  and 17.0 GiB. Keep one thread per process; higher CPU percentages did not improve throughput
  enough to justify the extra RAM. Eight single-threaded processes took 189 s and 5.2 GiB.
- In a ten-minute queued-work run, 16 single-threaded workers reached 13.6 GiB and memory was
  still growing by about 0.5 GiB/minute. Recycling controls this retained history; the measurements
  do not establish a long-run RAM ceiling. Full-game wall time varies with seeds and endgame tails.
- **Never run extra large batches on commits before 0f400b130.** The native rules leaked memory
  there: an extra large game grew to about 13 GB by day 320, and 16 at once overcommitted the
  machine.

**Controlled balance design.** All-arrangements plans save a roll seed for each map. Hero offers, hire levels, starting armies and growth rolls use that seed and faction/hero identity, independently of slot, session hash or hire day. Weekly offer priority is rolled before filtering unavailable heroes; actual hiring can still differ because of survival, money and decisions. Different maps get different rolls. Normal games and old plans keep their original RNG behavior. Faction-specific dwellings still follow faction placement. Reuse the frozen plan for before/after comparisons, then confirm on untouched maps; do not tune repeatedly on the validation bank.

All permutations trade map breadth for stronger within-map control: 720 4P games are only 30 maps, and each faction sees 20. Report map counts explicitly. Do not call 24 arrangements independent maps.

## 2. Prepare

1. The checkout must be current with `origin/main` (the owner changes balance and content often).
   Use `git fetch` and `git status`, following the repository's checkout rules. Commit or set aside your own edits first: `plan.json` records the
   commit, and a dirty tree means the batch does not match it.
2. Choose an output folder that outlives this session, in the main checkout's `.artifacts/`
   (ignored by git), e.g. `D:/Games/godot/heroes-like/.artifacts/ai_batch_<yyyymmdd>_<label>`.
   The folder must not hold a plan yet.

## 3. Run

Start the runner in the background with the available command tool and retain its execution
handle so it can be waited on or stopped:

```
python tools/ai_match_batch.py <out> --runner --players 4 --size large --matches 720 --all-arrangements --guards weak,strong --water land,normal_water --levels 2
```

Add `--desktop` to use 8 processes while the owner uses the PC. The native default is 16
processes with one thread each and recycling after up to 32 games; no extra flags are needed.

It prints, in order:

- `PLAN`: games per faction, first seats and setups, as soon as `plan.json` is written;
- `START`: the commit and how many run at once, with a warning first if it lowered the slots;
- with `--runner`, `CONTENT` while Godot writes the content snapshot, then `PLAY`: the process
  limit and recycling batch size; `WORKER` identifies each launched process and its match count;
- one line per finished match: run, setup, line-up, `-> winner day N` (or `no winner by day N`,
  `FAILED: ...`, `TIMEOUT: ...`), minutes and `[done/total, running]`;
- `DONE` with the path of `summary.md`.

Tell the owner the plan line and the expected wall time. Wait using the host's background
execution mechanism. When the owner asks how it is going, or you
have a natural moment, read the last lines of its output (the same lines are in
`<out>/runner.log`) and relay the new finished matches in a line or two. Do not open the match
records while it runs.

If the run was cut off (the session ended, the machine restarted), rerun with
`python tools/ai_match_batch.py <out> --resume`. It plays only the matches `results.jsonl` lacks,
from the start with their planned seeds, in Godot or on the runner as the plan says. It refuses a
different commit, and refuses while recorded Godot or native workers of the interrupted run are
still running. Normal interruption stops the workers; a forced parent termination can leave
workers alive, which the resume guard detects. Never start two drivers for the same folder.
Completed rows stay complete; games a crashed or timed-out worker never began go back into the
queue. A timeout fails its active game and stops that worker.

## 4. Report

When the runner prints `DONE`, read `<out>/summary.md`, not the match records. It holds:

- **Factions**: place points by elimination order (3-2-1-0 with four players, ties share) and wins
  in decided games, each against a fair share. The legacy ±1 sd bands and stars assume independent equal-faction games: they are not fresh-map confidence intervals or a test between batches. Report the map-bootstrap score intervals and number of maps, keeping every map's arrangements together. Few maps and repeated tuning limit the inference; do not assert balance or dominance from a single bank.
- **Look closer**: the day range of decided games, every capped, failed or timed-out match and every
  match with script errors (by seed), AI days over 10 s, captures without a defender, the winners'
  unspent gold, and minutes per setup.
- **Matches**: one row per match:
  `| # | Setup | Factions | Towns on map | Winner | Day | Captures (no defender) | Winner's gold at end |`.

Give the owner the faction table and the match table. For a batch of more than about 15 matches,
link `summary.md` instead of pasting the match table and quote only the rows your bullets name.
Then add a few bullets:

- how many games were decided and the day range; any game that hit the cap;
- water and underground maps are ordinary games: the AI sails and crosses subterranean gates (since
  2026-10-17). A capped game there is a failure to explain like any other, not an expected gap;
  a walkable-area check of such a map must cover both levels and the water;
- recurring patterns: many captures without a defender, large unspent gold, very slow AI days;
- anything that needs a closer look, by match seed.

Diagnosing a stalled or odd game is your job. Read that match's record `<out>/<run>.json` first;
it holds the daily state, economy, battles and town history:

- When decision tracing was enabled, `ledger[day].decisions`: every hero decision of the day: player, hero, position, strength,
  movement left, the plan taken (`[kind, id, value, distance]`) and the best alternatives it
  scored (`[score, kind, id, value, distance]`). Why an army did not attack a town, chased a
  courier or stood still is answered here.
- `ledger[day].sides[player].turn_ms`: that player's turn time by phase (`choose_ms`,
  `preview_ms` fight previews, `search_ms`, `strategic_ms`, `towns_ms`, counts of previews and
  searches).
- `ledger[day].sides[player].economy`: running totals of recruited strength and gold, buildings,
  hires, dismissals.
- `town_weeks`: each town's owner, buildings, unbought creatures and garrison every week.
- `battles`, `timeline`: every auto-resolved fight (both commanders' stats, spells, how it ended)
  and every capture, hire and fallen hero.

`results.jsonl` has each match's plan entry, status, minutes, first script errors and the fixed
summary (`summarize_match.py <record>` prints the same for one record). Only when the record
cannot answer it, replay the match alone with its seed and parameters from `plan.json`, and add
temporary prints:

```
bash .claude/skills/ai-match-batch/scripts/run_match.sh <scratch> <run> <players> <size> <factions> <days> <guards> <water> <levels> <seed>
```

A match played on the runner replays the same game in Godot. A seed replays exactly only on the
same commit: content and balance changes alter the map. Never
replay a seed while a match with that seed is running: both write the same map package under
`maps/`. If the owner wants a report page, build an artifact from these records.

## 5. Clean up

The batch tool deletes each match's profile when it ends, its log unless it failed or printed
script errors, and the map package it wrote under `maps/`. With `--runner` the maps stay in memory:
only matches set up in Godot write one. If `DONE` warns that `maps/` holds files no
finished match names, they come from a failed match or from someone else's game. Those packages
can be the owner's saves: compare their mtimes with the failed match's times and list running
Godot processes before deleting any.

Keep interrupted batches for resume. After reporting and any requested diagnosis, follow
AGENTS.md's retention and cleanup rules; retain completed generated outputs only when the owner
requests it. Never run a match on the owner's real game profile;
the runner and `run_match.sh` both isolate it.

## Notes

- The runner and its options are documented in `docs/ai-plays-by-player-rules.md` (AI against AI).
- Before 2026-10-09 the runner passed no guard strength, so its matches had weak guards.
- Before 2026-10-17 `run_match.sh` took no water or levels, so its matches were land maps on one level.
- Until 2026-10-19 the skill ran 1-12 matches through one haiku subagent each, with random seeds;
  larger batches used untracked drivers that ran 12 at once.
- The tool has played the days in `bin/match_sim_cli` with `--runner` since 2026-10-23 (Phase 8,
  P8-6), generating the maps there too since P8-8. The skill passes `--runner` by default since
  2026-10-24.
- On Linux set `GODOT_BIN` (or pass `--godot`) if `godot` is not on the PATH.
