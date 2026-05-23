# Battle Autoplay Balance Tuning Queue Report

Date: 2026-05-23
Task: #10184

## Scope

This slice adds a deterministic `battle_autoplay_balance_tuning_queue_v1` surface to the existing headless battle autoplay harness. The queue turns sampled combat-feel and balance-matrix evidence into report-only tuning items with priorities, source context, suggested ownership, and remediation hints.

The policy is `report_only_no_runtime_tuning`: the harness reports candidate work, but it does not rewrite encounters, unit stats, AI weights, scenario content, or saves.

## Implementation

- `BattleAutoplayBalanceHarnessRules.build_sampling_report()` now includes `summary.balance_tuning_queue` and top-level `balance_tuning_queue`.
- `BattleAutoplayBalanceHarnessRules.balance_tuning_queue(...)` derives items from combat-feel gate failures/warnings, balance-matrix gate failures/warnings, terminal-margin sample watches, pacing-band sample watches, matrix outliers, and cohort watch bands.
- Each item carries `category`, `priority`, `priority_band`, `metric`, `observed`, `target`, `source`, `context`, `suggested_owner`, and `remediation_hint`.
- The queue includes a deterministic `queue_signature`, sorted items, coverage counts, category ids, and up to five `top_contributors`.
- `tests/battle_autoplay_balance_tuning_queue_report.tscn` validates schema, report-only policy, deterministic signature, sorted item shape, terminal-margin watch coverage, and remediation hints.
- `tests/validate_repo.py` gates the new report, scene, harness tokens, and this evidence document.

## Current Evidence

The default 12-sample authored battle set still passes the broad combat-feel gate and balance-matrix gate, but the queue now keeps visible watch items for current balance work instead of hiding them behind a green threshold:

- terminal-margin sample watches for high-margin victories/defeats below the hard outlier threshold;
- cohort watches for one-sided terrain or difficulty bands;
- optional gate warnings/failures when future content changes trip the existing combat-feel or balance-matrix gates.

This gives combat-feel work a stable triage artifact before broader encounter, unit, terrain, initiative, and AI balance passes.

## Non-Goals

- No automatic tuning or content writeback.
- No final combat balance approval.
- No authored encounter retune in this slice.
- No spell/autocast expansion, strategic AI rewrite, or manual-play replacement.
