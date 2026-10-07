# Town recruit responsiveness

Owner report (2026-10-07): recruiting felt delayed, worst on the full Muster Hall
screen. On the owner's Day 8 save a recruit click took about 410 ms in the Muster
Hall, 455 ms in a dwelling popout and 380 ms as a plain order. A HoMM-style
recruit click must feel instant: the new reserve, stores and army show in the
same frame, with no visible hitch.

## Rules

- A recruit runs three phases: a preflight read (the before-signature for the
  action recap), the rules order, and everything after the order. The
  preflight's read scope ends before the order mutates (unchanged contract).
  Everything after the order only reads, so the recap, the town refresh, an
  open dwelling popout and the presentation share one
  `OverworldRules`/`TownRules` read scope (`TownShell._commit_recruit_order`).
- The post-order consequence signature is read once and shared by the recap,
  the presentation and the next order's preflight. A stored signature is reused
  only while a hash stamp of the session's mutable state (all flags and
  overworld entries except large static package/map data and the action
  recaps) is unchanged; any change, including a direct session edit, reads it
  again. Each refresh primes it inside its own read scope.
- The Town screen runtime-normalizes the session in every order preflight, so
  `TownRules.recruit_active_town(..., runtime_normalized = true)` skips a second
  full `normalize_overworld_state` pass. Other callers keep the full pass.
- Muster Hall cards and dwelling-popout recruit cards update in place
  (`TownRecruitCard.update_state`) when the line-up and prices are unchanged;
  the popout redraws only its upgrade line when that line's order or the stores
  its cost row shows changed. Anything else redraws as before.
- Rules-level caches, all exact:
  - `TownDevelopmentRules.active_buildings` and `satisfies` are memoized by
    town template and built list; the memo drops on content reload.
  - Inside a read scope, `get_town_build_status`, seeded weekly growth and the
    muster catalog are cached. The town digest for read-scope keys is computed
    once per town dictionary and re-checked by its content hash.
- Hidden surfaces stay lazy: the hidden event strip's tooltip no longer builds
  a detached copy of the whole session for its "Saving now" lines (it is added
  when the strip shows; snapshots always include it). The hero portrait keeps
  its texture when the hero is unchanged, and the resource popup updates its
  items in place.

## Validation

- `tests/town_recruit_responsiveness_report.tscn` recruits through a Muster
  card, a dwelling popout and the plain order on a real TownShell. Right after
  each click it checks the screen against a fresh render of the new state
  (cards, popout, stores, army bar, stage, cached town view, stored preflight
  signature) and the fast-path counters: one town-view build, preflight
  signature reuse, in-place card and popout updates, no hidden save-context
  build. A direct session edit between recruits must force a fresh preflight.
- Timings come from the owner-save perf probe (not committed); see the
  coordinator's batch notes for before/after numbers.
