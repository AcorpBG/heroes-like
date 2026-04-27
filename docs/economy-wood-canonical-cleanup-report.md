# Economy Wood Canonical Cleanup Report

Status: implemented canonical cleanup.
Date: 2026-04-27.
Slice: `economy-wood-canonical-cleanup-10184`.

## Decision

`wood` remains the live authored-content, runtime, and save resource id for this stage.

There is no alternate target id, alias, or compatibility path for the wood resource. Reports and fixtures treat `wood` as the canonical resource id.

No save migration is required for this decision. `SAVE_VERSION` remains `9`.

## Executable Proof

The validator now checks the `wood_canonical_v1` policy during default validation:

- live stockpile ids are exactly `gold`, `wood`, and `ore`;
- no target-only resource ids or alias pairs are reported;
- production content has positive `wood` occurrences;
- production migration, compatibility-adapter adoption, save rewrite, save-version bump, and rare-resource activation are all disabled;
- `experience` remains a non-stockpile reward;
- the old-save fixture omits `resource_schema_version` and preserves `wood`;
- `SessionStateStore.gd` and autoload `SessionState.gd` keep `SAVE_VERSION := 9`.

The opt-in economy/resource report exposes the same policy and old-save compatibility summary. Strict economy fixtures reject unknown resources, negative amounts, stockpiled `experience`, missing registry metadata, and normal-market rare-resource buying while keeping `wood` as a valid stockpile resource.

## Non-Changes

This slice did not migrate production JSON, add `content/resources.json`, route runtime economy through a new adapter, activate rare resources, change market behavior, rebalance faction costs, or rewrite saves.
