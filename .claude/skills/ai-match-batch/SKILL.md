---
name: ai-match-batch
description: Owner-requested evaluation only. Runs a batch of headless AI-vs-AI matches on random generated maps (one cheap subagent per match, in parallel) and reports one comparison table. Use only when the owner explicitly asks for AI matches in this conversation, e.g. "run N AI matches", "test the AI on medium/large maps", "AI vs AI with 3/4 players", "how does the AI do now". Never use it on your own initiative to validate a code, AI, balance or content change; that is what tools/core_suite.py is for.
---

# AI match batch

Plays several complete AI-vs-AI games at once with `tests/ai_versus_ai_match_report.tscn` and
compares them. Every game gets its own random map; faction line-ups differ between matches unless
the owner asks otherwise. One subagent per match runs the game and returns a fixed JSON summary;
you collect the summaries and report.

## When to use it

- **Only when the owner asks for AI matches.** A batch costs 5–60 minutes and one subagent per
  match. It is an evaluation tool for the owner to see how the computer players behave, not a
  regression test (owner decision, 2026-10-10; AGENTS.md "Validation budget").
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

| Parameter | Default | Values |
|---|---|---|
| matches | 5 | 1–12 (one Godot process each; ~1 CPU core per match) |
| players | 3 | 2–8 computer players |
| size | `homm3_medium` | `homm3_small`, `homm3_medium`, `homm3_large`, `homm3_extra_large` |
| line-ups | different random factions per match, no faction twice in a match | `--mirrors` allows repeats; or exact line-ups from the owner |
| guards | `normal` (as a new game from the main menu) | `weak`, `normal`, `strong` |
| day cap | 160 | an undecided game stops here |
| subagent model | `haiku`, effort `high` | only change if the owner asks |

Expected wall time per match: small 1–3 min, medium 3–12 min (longer games take longer), all
matches in parallel.

## 2. Prepare

1. The worktree must be current with `origin/main` (the owner changes balance and content often).
   In an app-made worktree use the `sync_with_base_branch` tool; otherwise
   `git fetch && git status`. Report the commit the batch runs on.
2. Pick the line-ups:
   `python .claude/skills/ai-match-batch/scripts/pick_lineups.py <matches> <players>`
   (one comma-separated line per match).
3. Choose an output folder in your scratchpad, e.g. `<scratchpad>/ai_batch_<date>`.

## 3. Launch one subagent per match, all in one message

Use the Agent tool with `model: "haiku"` and `effort: "high"` (the owner chose these), one call per
match, all in the same message so they run in parallel. Fill in the placeholders; keep the rest of
the prompt as is:

```
You are running ONE headless AI-vs-AI game simulation for a Godot game and reporting the result.
Do not edit any repository files. Only create files under OUT.

REPO=<absolute repo path>   OUT=<output folder>   RUN=<run id, e.g. m1>
PLAYERS=<n>   SIZE=<size class>   FACTIONS=<comma-separated line-up or random>   DAYS=<day cap>   GUARDS=<weak|normal|strong>

Step 1. With the Bash tool and run_in_background: true (the match takes minutes; never run it in
the foreground), run:
bash "$REPO/.claude/skills/ai-match-batch/scripts/run_match.sh" "$OUT" "$RUN" "$PLAYERS" "$SIZE" "$FACTIONS" "$DAYS" "$GUARDS"
(write the literal values in place of the variables).

Step 2. Wait until "$OUT/$RUN.done" exists. If you get a background-task completion notification,
use it. Otherwise run in the foreground with a Bash timeout of 590000 ms, repeating until it
prints DONE:
timeout 580 bash -c "until [ -f '$OUT/$RUN.done' ]; do sleep 15; done"; [ -f "$OUT/$RUN.done" ] && echo DONE && cat "$OUT/$RUN.done" || echo STILL_RUNNING

Step 3. Run: grep -m5 "SCRIPT ERROR" "$OUT/$RUN.log" ; python "$REPO/.claude/skills/ai-match-batch/scripts/summarize_match.py" "$OUT/$RUN.json"

Step 4. Reply with the exit code, any SCRIPT ERROR lines (or "none"), the JSON summary exactly as
printed, and 2-4 plain sentences on how the game went: who won and on which day (or that nobody
won by the day cap), when each loser was knocked out, and notable facts such as captures without a
defender or large unspent gold. Battles are logged from the attacker's side, so few lost battles is
normal; last_day_standing is the final day for the winner. Do not speculate about bugs. If the
match failed, give the last 30 lines of "$OUT/$RUN.log" instead. Do not delete any files.
```

While they run, tell the owner the line-ups and that results come in as each match finishes.
Relay each finished match in one or two lines; do not wait silently.

## 4. Report

When all matches are in, give one table:

| # | Setup | Factions | Towns on map | Winner | Day | Captures (no defender) | Winner's gold at end |

(from each summary: players/`map_size`/`guards`, `factions`, `towns_on_map`, `winner_faction`/`winner`, `final_day`,
`town_captures`, `captures_without_defender`, `final_sides[winner].gold`), then a few bullets:

- how many games were decided and the day range; any game that hit the cap;
- recurring patterns: many captures without a defender, large unspent gold, very slow AI days
  (`slowest_ai_day_ms` over ~10 s);
- anything that needs a closer look, by match seed.

Diagnosing a stalled or odd game is your job, not the subagents'. Read the match record first;
it is written with full tracing on, so a replay is rarely needed:

- `ledger[day].decisions`: every hero decision of the day: player, hero, position, strength,
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

Only when the record cannot answer it, replay the `match_seed` with the same parameters
(`HEROES_AI_MATCH_SEED=<seed>`, players, size, guards, factions) and add temporary prints. A seed
replays exactly only on the same commit: content and balance changes alter the map. If the owner
wants a report page, build an artifact from these records.

## 5. Clean up

After reporting, delete the batch's `profile_*` folders, `.log` and `.done` files. Keep the
`.json` records only while a follow-up (replay, report page) may need them, then delete them too.
Never run a match on the owner's real game profile; `run_match.sh` isolates it.

## Notes

- The runner and its options are documented in `docs/ai-plays-by-player-rules.md` (AI against AI).
- Before 2026-10-09 the runner passed no guard strength, so its matches had weak guards.
- Matches with the same seed must not run at the same time (they share the map package file);
  random seeds make that practically impossible.
- On Linux set `GODOT_BIN` if `godot` is not on the PATH.
