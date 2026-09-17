# Validation artifact lifecycle

Owner-approved Phase 6 tooling slice:
`tooling-validation-artifact-lifecycle-20260917`. Status: completed, 2026-09-17.

## Requirement

The 2026-09-17 cleanup policy in `AGENTS.md` removes disposable non-RMG
reports after results are recorded. The repository validator still requires
26 historical campaign/content smoke reports under `.artifacts`, so cleaning
approved outputs breaks validation without changing source or gameplay.

Default repository validation must not require retaining those generated reports.
It must still validate the real content, source owners, test launchers, art and
provenance, and apply the existing result assertions whenever a report is present.
An absent report is not a successful gameplay test or fresh runtime evidence.
Print that distinction and offer `--require-historical-smoke-reports` for callers
that deliberately require the 26 historical outputs to be present.

The exception applies only at those explicit non-RMG report call sites. Do not
make all missing files optional, change native RMG/parity requirements, invent
passing reports, or rerun unrelated campaigns just to recreate disposable history.
Malformed or unsuccessful present reports must still fail validation.

## Acceptance

- Focused Python tests cover absent reports in default/strict modes, existing
  reports, invalid JSON, failed assertions and unchanged source/content checks.
- All 26 report integrations are covered; missing evidence is disclosed and is
  never counted as executed or passed gameplay coverage.
- `python3 tests/validate_repo.py` passes on the cleaned workspace.
- `git diff --check` passes; only scoped files are committed and pushed.
- Preserve unrelated untracked retention tooling, original art, saves, caches and
  all RMG recovery material. Remove only this task's disposable outputs.

This is platform-neutral Python validation tooling. Linux/Windows runtime and
export code are unchanged; the preceding retaliation slice's successful platform
checks remain valid and do not need another export cycle for this tooling fix.

## Validation

The implementation changes only the 26 explicit presence guards and the CLI's
policy/summary handling. All pre-existing report predicates and other validator
function bodies are structurally identical (AST comparison against `f42b585b`,
reversing only those 26 presence-guard replacements). In particular, source,
content, provenance and native RMG assertions are unchanged.

```sh
python3 -B -m unittest discover -s tests -p test_validation_artifact_lifecycle.py -v
python3 tests/validate_repo.py
# Optional, only when those historical outputs are deliberately required:
python3 tests/validate_repo.py --require-historical-smoke-reports
```

The focused suite passed all 11 tests. It executes the actual 26 report branches
with missing/failed/malformed fixtures, checks both policy modes, accepts a valid
report and rejects a corrupted battle counter, rejects invalid paths, and proves
the real Uncrowned Circuit owner still rejects broken campaign content and smoke
source. The CLI exposes the strict option. Fixtures live in automatically cleaned
temporary directories, not retained `.artifacts` reports.

Full `python3 tests/validate_repo.py` passed (exit 0) on the cleaned workspace,
explicitly disclosing 26 absent historical reports and that those runtime smokes
were not executed or counted as passing. `git diff --check` passed. This resolves
the retaliation slice's repository-only blocker; its prior source/rendered and
Linux/Windows package results remain unchanged. The historical campaign smokes
were not rerun, and this is not a whole-game release-readiness claim.

Cleanup verified no `heroes-report-policy-*` fixture directories remain under
`/tmp`. No export packages or persistent evidence files were created, and nothing
additional needed removal. Existing untracked retention files remain unchanged;
RMG recovery material, caches, saves and original art were untouched.
